#!/usr/bin/env bash
# Remove NAC demo profiles from vManage (idempotent). Needs VPN. Uses VMANAGE_* or prompts for password.
set -uo pipefail

VMANAGE_URL="${VMANAGE_URL:-https://10.10.20.90}"
VMANAGE_USER="${VMANAGE_USER:-admin}"
COOKIE_JAR="${TMPDIR:-/tmp}/vmanage-cookies-$$.txt"
trap 'rm -f "$COOKIE_JAR"' EXIT

if [[ -z "${VMANAGE_PASSWORD:-}" ]]; then
  read -r -s -p "vManage password for ${VMANAGE_USER}: " VMANAGE_PASSWORD
  echo
fi

curl -sk -c "$COOKIE_JAR" -X POST "${VMANAGE_URL}/j_security_check" \
  -d "j_username=${VMANAGE_USER}&j_password=${VMANAGE_PASSWORD}" -o /dev/null

export VMANAGE_URL VMANAGE_USER COOKIE_JAR
python3 <<'PY'
import json, os, subprocess

vmanage = os.environ["VMANAGE_URL"].rstrip("/")
cj = os.environ["COOKIE_JAR"]

def curl(method, path, body=None):
    url = vmanage + path
    cmd = ["curl", "-sk", "-b", cj, "-X", method, "-H", "Accept: application/json", url]
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "-d", body]
    return subprocess.run(cmd, capture_output=True, text=True)

def get_json(path):
    r = curl("GET", path)
    if r.returncode != 0 or not r.stdout.strip():
        return {}
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        print("GET", path, "non-JSON:", r.stdout[:300])
        return {}

def delete(path, label):
    r = curl("DELETE", path)
    code = r.stdout[:200] if r.stdout else r.stderr[:200]
    print(f"DELETE {label}: HTTP ok={r.returncode} {code}")

# 1) Configuration group branches
for path in (
    "/dataservice/v1/configuration-group",
    "/dataservice/v1/configuration-group?limit=200",
):
    data = get_json(path)
    items = data.get("data", data if isinstance(data, list) else [])
    for item in items:
        if not isinstance(item, dict):
            continue
        if (item.get("name") or "").lower() != "branches":
            continue
        gid = item.get("id") or item.get("groupId")
        if gid:
            delete(f"/dataservice/v1/configuration-group/{gid}", f"config-group branches ({gid})")
    if items:
        break

# 2) Feature profiles system + transport
list_paths = [
    "/dataservice/v1/feature-profile/sdwan?limit=200",
    "/dataservice/v1/feature-profile/sdwan/system",
    "/dataservice/v1/feature-profile/sdwan/transport",
]
seen = set()
for path in list_paths:
    data = get_json(path)
    items = data.get("data", [data] if data.get("profileId") or data.get("id") else data if isinstance(data, list) else [])
    if not isinstance(items, list):
        items = [items] if isinstance(items, dict) else []
    for item in items:
        if not isinstance(item, dict):
            continue
        name = (item.get("profileName") or item.get("name") or "").lower()
        if name not in ("system", "transport"):
            continue
        pid = item.get("profileId") or item.get("id")
        if not pid or pid in seen:
            continue
        seen.add(pid)
        delete(f"/dataservice/v1/feature-profile/{pid}", f"profile {name} ({pid})")

print("Lab reset finished (check DELETE lines above).")
PY