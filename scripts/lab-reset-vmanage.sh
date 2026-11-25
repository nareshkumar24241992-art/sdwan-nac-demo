#!/usr/bin/env bash
# Remove NAC demo config group + feature profiles from vManage. Needs VPN.
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

XSRF="$(curl -sk -b "$COOKIE_JAR" "${VMANAGE_URL}/dataservice/client/token")"
export VMANAGE_URL COOKIE_JAR XSRF

python3 <<'PY'
import json, os, subprocess

vmanage = os.environ["VMANAGE_URL"].rstrip("/")
cj = os.environ["COOKIE_JAR"]
xsrf = os.environ.get("XSRF", "").strip()

def curl(method, path):
    url = vmanage + path
    cmd = [
        "curl", "-sk", "-w", "\nHTTP:%{http_code}",
        "-b", cj, "-X", method,
        "-H", "Accept: application/json",
        "-H", f"X-XSRF-TOKEN: {xsrf}",
        url,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True)
    body, _, code = r.stdout.rpartition("\nHTTP:")
    return code.strip() or "000", body

def get_json(path):
    code, body = curl("GET", path)
    print(f"GET {path} -> {code}")
    if not body.strip():
        return {}
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        print("  body:", body[:250])
        return {}

def items(payload):
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("data", "profiles", "payload"):
            v = payload.get(key)
            if isinstance(v, list):
                return v
            if isinstance(v, dict):
                return [v]
        if payload.get("profileId") or payload.get("id"):
            return [payload]
    return []

def delete(path, label):
    code, body = curl("DELETE", path)
    print(f"DELETE {label} {path} -> {code} {body[:180]}")

for path in ("/dataservice/v1/config-group", "/dataservice/v1/configuration-group"):
    for item in items(get_json(path)):
        name = (item.get("name") or "").lower()
        gid = item.get("id") or item.get("groupId") or item.get("configGroupId")
        if name == "branches" and gid:
            delete(f"{path}/{gid}", "config-group branches")

for ptype in ("system", "transport"):
    list_path = f"/dataservice/v1/feature-profile/sdwan/{ptype}"
    for item in items(get_json(list_path)):
        name = (item.get("profileName") or item.get("name") or "").lower()
        pid = item.get("profileId") or item.get("id")
        if not pid:
            continue
        if name and name != ptype:
            continue
        delete(f"/dataservice/v1/feature-profile/sdwan/{ptype}/{pid}", f"{ptype} profile {name or pid}")

print("Lab reset finished.")
PY
