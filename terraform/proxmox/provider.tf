# Two standalone Proxmox hosts, each managed via its own provider alias.
# Auth is per-host since each host has its own user/token database.
#
# Set via env vars (Terraform reads TF_VAR_* automatically):
#   set -gx TF_VAR_pve1_endpoint  'https://192.168.8.191:8006/'
#   set -gx TF_VAR_pve1_api_token 'root@pam!terraform=<UUID-on-pve1>'
#   set -gx TF_VAR_pve2_endpoint  'https://192.168.8.226:8006/'
#   set -gx TF_VAR_pve2_api_token 'root@pam!terraform=<UUID-on-pve2>'

provider "proxmox" {
  alias     = "pve1"
  endpoint  = var.pve1_endpoint
  api_token = var.pve1_api_token
  insecure  = true

  ssh {
    agent    = true
    username = var.pve_ssh_user
  }
}

provider "proxmox" {
  alias     = "pve2"
  endpoint  = var.pve2_endpoint
  api_token = var.pve2_api_token
  insecure  = true

  ssh {
    agent    = true
    username = var.pve_ssh_user
  }
}
