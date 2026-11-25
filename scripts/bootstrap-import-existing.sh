#!/usr/bin/env bash
# One-time: import objects already created in vManage (e.g. after CI lost terraform.tfstate).
# Run from repo root with sandbox VPN up. IDs are from the first partial apply in this lab.
set -euo pipefail

cd "$(dirname "$0")/.."

# Lab object IDs (from first successful terraform apply)
TRANSPORT_PROFILE_ID="3674e29b-680e-4d2f-9c9f-0e52d0c37eca"
SYSTEM_PROFILE_ID="525c88a0-b2f2-4dce-aab6-91dc6db6d005"

terraform init -input=false

import_one() {
  local addr="$1"
  local id="$2"
  if terraform state show "$addr" >/dev/null 2>&1; then
    echo "skip (already in state): $addr"
  else
    echo "import: $addr <- $id"
    terraform import "$addr" "$id"
  fi
}

# Feature profiles (single id)
import_one 'module.sdwan.sdwan_transport_feature_profile.transport_feature_profile["transport"]' "${TRANSPORT_PROFILE_ID}"
import_one 'module.sdwan.sdwan_system_feature_profile.system_feature_profile["system"]' "${SYSTEM_PROFILE_ID}"

# Transport features: feature_id,feature_profile_id
import_one 'module.sdwan.sdwan_transport_gps_feature.transport_gps_feature["transport-gps"]' \
  "7c628ba6-d3f9-4ff8-bef1-211e70312d1d,${TRANSPORT_PROFILE_ID}"
import_one 'module.sdwan.sdwan_transport_wan_vpn_feature.transport_wan_vpn_feature["transport-wan_vpn"]' \
  "ee838ec9-64ff-438f-96b5-2250f648ddea,${TRANSPORT_PROFILE_ID}"

# Ethernet: feature_id,feature_profile_id,transport_wan_vpn_feature_id
import_one 'module.sdwan.sdwan_transport_wan_vpn_interface_ethernet_feature.transport_wan_vpn_interface_ethernet_feature["transport-wan_vpn-inet"]' \
  "d98a0a28-dc34-4dc3-884f-ae725f275d9f,${TRANSPORT_PROFILE_ID},ee838ec9-64ff-438f-96b5-2250f648ddea"
import_one 'module.sdwan.sdwan_transport_wan_vpn_interface_ethernet_feature.transport_wan_vpn_interface_ethernet_feature["transport-wan_vpn-mpls"]' \
  "a6ced33b-0846-492d-b2c3-9eb89b1fca97,${TRANSPORT_PROFILE_ID},ee838ec9-64ff-438f-96b5-2250f648ddea"

# System features: feature_id,feature_profile_id
import_one 'module.sdwan.sdwan_system_bfd_feature.system_bfd_feature["system-bfd"]' \
  "f81a8a34-3480-40d6-8d10-47f00d12b54f,${SYSTEM_PROFILE_ID}"
import_one 'module.sdwan.sdwan_system_logging_feature.system_logging_feature["system-logging"]' \
  "56579bbc-67fd-4f59-89cc-fac3dcb0077e,${SYSTEM_PROFILE_ID}"
import_one 'module.sdwan.sdwan_system_global_feature.system_global_feature["system-global"]' \
  "f72a918b-95a1-458a-808c-919fc849b265,${SYSTEM_PROFILE_ID}"
import_one 'module.sdwan.sdwan_system_aaa_feature.system_aaa_feature["system-aaa"]' \
  "8ecaff1c-0f4d-4189-9167-35e0a94ccd43,${SYSTEM_PROFILE_ID}"
import_one 'module.sdwan.sdwan_system_omp_feature.system_omp_feature["system-omp"]' \
  "4f9ab6db-e454-413e-b6ea-c9540dd2aa77,${SYSTEM_PROFILE_ID}"
import_one 'module.sdwan.sdwan_system_basic_feature.system_basic_feature["system-basic"]' \
  "c93b2cdc-d328-461d-b836-cb3a0d5d0f6c,${SYSTEM_PROFILE_ID}"

echo
echo "Done. Run: terraform plan"
echo "Expect ~1 to add (configuration group). Then: terraform apply"