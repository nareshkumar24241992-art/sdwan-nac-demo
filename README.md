# sdwan-nac-demo

Network-as-Code demo ([netascode/nac-sdwan](https://registry.terraform.io/modules/netascode/nac-sdwan/sdwan)) with GitHub Actions on a **self-hosted** runner.

**Requirements:** DevNet sandbox **VPN on the runner**, secrets `SDWAN_URL` / `SDWAN_USERNAME` / `SDWAN_PASSWORD`, correct `chassis_id` in `data/sites.nac.yaml`.

**Normal flow:** commit → push to `main` → pipeline plan + apply. State is kept on the runner at `~/terraform-state/sdwan-nac-demo/`.

If apply hits **“already exists”**, the pipeline runs `scripts/lab-reset-vmanage.sh`, clears saved state, and **applies again** automatically (VPN must be up on the runner).

## Device UUID

`./scripts/list-vmanage-devices.sh` (WSL, VPN on) — use **Edge1** `C8K-…` in `data/sites.nac.yaml`.