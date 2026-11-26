#!/usr/bin/env bash
# Open vManage in a browser from WSL (needs WSLg + VPN in WSL).
set -euo pipefail

VMANAGE_URL="${VMANAGE_URL:-https://10.10.20.90}"

if ! curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 "${VMANAGE_URL}/" | grep -q '^[23]'; then
  echo "Cannot reach ${VMANAGE_URL}. Connect DevNet sandbox VPN in WSL first."
  exit 1
fi

for bin in firefox firefox-esr chromium-browser google-chrome chromium; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "Opening ${VMANAGE_URL} in ${bin} ..."
    exec "$bin" "${VMANAGE_URL}" >/dev/null 2>&1 &
  fi
done

echo "No browser found in WSL. Install one (WSLg required for GUI):"
echo "  sudo apt-get update && sudo apt-get install -y firefox"
echo "Or run: bash scripts/view-vmanage.sh  (text summary, no GUI)"