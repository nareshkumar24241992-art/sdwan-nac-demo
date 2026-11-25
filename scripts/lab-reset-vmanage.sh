#!/usr/bin/env bash
# Delete NAC demo objects from vManage so a clean terraform apply works. Run once in WSL with VPN on.
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

api() {
  curl -sk -b "$COOKIE_JAR" -H "Accept: application/json" "$@"
}

echo "Listing configuration groups..."
CG_JSON="$(api "${VMANAGE_URL}/dataservice/v1/configuration-group")"
echo "Listing feature profiles..."
FP_JSON="$(api "${VMANAGE_URL}/dataservice/v1/feature-profile/sdwan?limit=200")"

export CG_JSON FP_JSON VMANAGE_URL COOKIE_JAR
python3 <<'PY'
import json, os, subprocess, urllib.parse

vmanage = os.environ["VMANAGE_URL"]
cj = os.environ["COOKIE_JAR"]

def api(method, path):
    url = vmanage.rstrip("/") + path
    cmd = ["curl", "-sk", "-b", cj, "-X", method, "-H", "Accept: application/json", url]
    if method != "GET":
        cmd += ["-H", "Content-Type: application/json"]
    out = subprocess.check_output(cmd, text=True)
    try:
        return json.loads(out) if out.strip() else {}
    except json.JSONDecodeError:
        print(out[:400])
        return {}

cg = json.loads(os.environ["CG_JSON"])
for item in cg.get("data", cg if isinstance(cg, list) else []):
    if isinstance(item, dict) and item.get("name") in ("branches",):
        pid = item.get("id") or item.get("groupId")
        print(f"DELETE configuration-group: {item.get('name')} ({pid})")
        api("DELETE", f"/dataservice/v1/configuration-group/{pid}")

fp = json.loads(os.environ["FP_JSON"])
profiles = fp.get("data", fp if isinstance(fp, list) else [])
for item in profiles:
    if not isinstance(item, dict):
        continue
    name = item.get("profileName") or item.get("name", "")
    if name not in ("system", "transport"):
        continue
    pid = item.get("profileId") or item.get("id")
    print(f"DELETE feature-profile: {name} ({pid})")
    api("DELETE", f"/dataservice/v1/feature-profile/{pid}")

print("Done. On runner: rm -f ~/terraform-state/sdwan-nac-demo/terraform.tfstate*")
print("Then re-run the GitHub Actions workflow.")
PY