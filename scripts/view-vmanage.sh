#!/usr/bin/env bash
# Print NaC objects in vManage. Run in WSL with sandbox VPN connected.
set -euo pipefail

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

def get(path):
    r = subprocess.run(
        [
            "curl", "-sk", "-b", cj,
            "-H", "Accept: application/json",
            "-H", f"X-XSRF-TOKEN: {xsrf}",
            vmanage + path,
        ],
        capture_output=True, text=True,
    )
    try:
        return json.loads(r.stdout) if r.stdout.strip() else {}
    except json.JSONDecodeError:
        print("Not JSON:", path, r.stdout[:200])
        return {}

def rows(payload):
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for k in ("data", "profiles", "payload"):
            v = payload.get(k)
            if isinstance(v, list):
                return v
    return []

print("=== Feature profiles: system ===")
for p in rows(get("/dataservice/v1/feature-profile/sdwan/system")):
    print(" ", p.get("profileName") or p.get("name"), p.get("profileId") or p.get("id"))

print("=== Feature profiles: transport ===")
for p in rows(get("/dataservice/v1/feature-profile/sdwan/transport")):
    print(" ", p.get("profileName") or p.get("name"), p.get("profileId") or p.get("id"))

print("=== Configuration groups ===")
for path in ("/dataservice/v1/config-group", "/dataservice/v1/configuration-group"):
    items = rows(get(path))
    if not items:
        continue
    for g in items:
        print(" ", g.get("name"), g.get("id") or g.get("groupId"))
    break

print("=== Devices (host / uuid / group if present) ===")
dev = get("/dataservice/device")
for d in rows(dev):
    print(
        " ",
        d.get("host-name"),
        d.get("uuid"),
        d.get("reachability"),
        d.get("device-model"),
    )
PY
