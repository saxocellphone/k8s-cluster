# Provider auth via env vars — keep secrets out of Git:
#   export PROXMOX_VE_ENDPOINT='https://192.168.8.191:8006/'
#   export PROXMOX_VE_API_TOKEN='root@pam!terraform=<UUID-from-proxmox-ui>'
#   export PROXMOX_VE_INSECURE=true   # self-signed cert is OK on LAN
#
# (The provider also accepts username + password via PROXMOX_VE_USERNAME /
# PROXMOX_VE_PASSWORD; tokens are preferred since they can be revoked.)
provider "proxmox" {
  # All settings come from env vars above. Endpoint defaults to one host;
  # if your two PVE hosts are clustered, this works for both — any node in
  # the cluster serves the API for the whole cluster.
  ssh {
    agent    = true
    username = var.pve_ssh_user
  }
}
