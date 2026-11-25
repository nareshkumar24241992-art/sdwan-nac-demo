# sdwan-nac-demo

Catalyst SD-WAN **Network as Code** demo using [netascode/nac-sdwan](https://registry.terraform.io/modules/netascode/nac-sdwan/sdwan) and the [CiscoDevNet/sdwan](https://registry.terraform.io/providers/CiscoDevNet/sdwan) provider. CI runs on a self-hosted GitHub Actions runner.

## Sandbox setup (DevNet 20.18)

1. Reserve **Catalyst SD-WAN, Release 20.18** in [Cisco DevNet Sandbox](https://developer.cisco.com/sandbox/).
2. Open **Credentials** on the sandbox page and copy the vManage URL, username, and password.
3. If the lab requires **VPN**, connect before running Terraform from your runner or laptop.
4. In vManage, find your edge device **UUID** (chassis ID) and set it in `data/sites.nac.yaml` instead of `REPLACE-WITH-DEVICE-UUID-FROM-VMANAGE`.

## GitHub Actions secrets

Repository **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|--------|
| `SDWAN_URL` | vManage URL from sandbox (e.g. `https://…`) |
| `SDWAN_USERNAME` | Sandbox username |
| `SDWAN_PASSWORD` | Sandbox password |

The workflow maps these to `TF_VAR_sdwan_*` for Terraform.

## Local commands

```bash
export TF_VAR_sdwan_url="https://your-vmanage"
export TF_VAR_sdwan_username="admin"
export TF_VAR_sdwan_password="your-password"

terraform init
terraform plan
terraform apply
```

## Layout

- `main.tf` — provider + `nac-sdwan` module
- `data/*.nac.yaml` — declarative SD-WAN intent (configuration, sites, defaults)

Based on [netascode/nac-sdwan-simple-example](https://github.com/netascode/nac-sdwan-simple-example).