# sdwan-nac-demo

Network-as-Code demo ([netascode/nac-sdwan](https://registry.terraform.io/modules/netascode/nac-sdwan/sdwan)) with GitHub Actions on a **self-hosted** runner.

**Requirements:** DevNet sandbox **VPN on the runner**, secrets `SDWAN_URL` / `SDWAN_USERNAME` / `SDWAN_PASSWORD`, correct `chassis_id` in `data/sites.nac.yaml`.

**Normal flow:** commit → push to `main` → pipeline plan + apply. State is kept on the runner at `~/terraform-state/sdwan-nac-demo/`.

## If pipeline says “already exists” (one-time lab reset)

State and vManage are out of sync. Do **not** use import scripts—reset the lab:

1. **vManage** (VPN on): delete configuration group **branches** (if any), then feature profiles **system** and **transport** (and their features).
2. **Runner:** `rm -f ~/terraform-state/sdwan-nac-demo/terraform.tfstate*`
3. **Re-run** the workflow once (VPN on). One apply should create everything and save state.

## Device UUID

`./scripts/list-vmanage-devices.sh` (WSL, VPN on) — use **Edge1** `C8K-…` in `data/sites.nac.yaml`.