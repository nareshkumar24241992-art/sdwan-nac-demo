#!/usr/bin/env bash
# List Catalyst SD-WAN devices (chassis UUID) from vManage. Run in WSL with sandbox VPN connected.
set -euo pipefail

VMANAGE_URL="${VMANAGE_URL:-https://10.10.20.90}"
VMANAGE_USER="${VMANAGE_USER:-admin}"
COOKIE_JAR="${TMPDIR:-/tmp}/vmanage-cookies-$$.txt"

cleanup() {
  rm -f "$COOKIE_JAR"
}
trap cleanup EXIT

command -v curl >/dev/null 2>&1 || {
  echo "Missing curl. Install: sudo apt-get update && sudo apt-get install -y curl"
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "Missing python3. Install: sudo apt-get update && sudo apt-get install -y python3"
  exit 1
}

if [[ -z "${VMANAGE_PASSWORD:-}" ]]; then
  read -r -s -p "vManage password for ${VMANAGE_USER}: " VMANAGE_PASSWORD
  echo
fi

echo "Checking reachability to ${VMANAGE_URL} ..."
if ! curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 10 "${VMANAGE_URL}/" | grep -q '^[23]'; then
  echo "Cannot reach vManage. Connect the DevNet sandbox VPN in WSL, then retry."
  exit 1
fi

echo "Logging in ..."
curl -sk -c "$COOKIE_JAR" -X POST "${VMANAGE_URL}/j_security_check" \
  -d "j_username=${VMANAGE_USER}&j_password=${VMANAGE_PASSWORD}" -o /dev/null

echo "Fetching devices ..."
RESPONSE="$(curl -sk -b "$COOKIE_JAR" "${VMANAGE_URL}/dataservice/device")"

export DEVICE_JSON="$RESPONSE"
python3 <<'PY'
import json, os, re, sys

raw = os.environ.get("DEVICE_JSON", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError:
    print("API error or login failed. Check username/password and VPN.")
    print(raw[:500])
    sys.exit(1)

data = payload.get("data")
if not data:
    print("No devices in response or login failed.")
    print(raw[:500])
    sys.exit(1)

def g(d, *keys, default="-"):
    for k in keys:
        if k in d and d[k] not in (None, ""):
            return d[k]
    return default

print()
print("=== Devices (use UUID as chassis_id in data/sites.nac.yaml) ===")
print(f"{'HOST':<20} {'UUID':<40} {'MODEL':<18} REACHABILITY")
print("-" * 110)
for d in data:
    print(
        f"{g(d, 'host-name', 'hostName'):<20} "
        f"{g(d, 'uuid', 'deviceId'):<40} "
        f"{g(d, 'device-model', 'deviceModel'):<18} "
        f"{g(d, 'reachability', 'status')}"
    )

print()
print("=== Suggested edge (C8000 / vedge) ===")
edge = None
for d in data:
    model = g(d, "device-model", "deviceModel", default="")
    if re.search(r"c8000|c8k", model, re.I):
        edge = d
        break

if edge:
    uuid = g(edge, "uuid", "deviceId")
    print(f"  chassis_id: {uuid}")
    print(
        f"  # host: {g(edge, 'host-name', 'hostName')}, "
        f"model: {g(edge, 'device-model', 'deviceModel')}, "
        f"reachability: {g(edge, 'reachability', 'status')}"
    )
else:
    print("  No obvious edge found; pick uuid from the table above.")
PY