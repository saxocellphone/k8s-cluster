# Proxmox VMs as Terraform

Manages the VMs that host the Talos Kubernetes cluster (and anything else
running on Proxmox). Uses the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest)
provider.

## Bootstrap (one-time)

### 1. Create a Proxmox API token

In the Proxmox UI (https://192.168.8.191:8006/):

1. **Datacenter → Permissions → API Tokens → Add**
2. User: `root@pam`
3. Token ID: `terraform`
4. **Uncheck** "Privilege Separation" (so the token inherits root's perms)
5. Click Add → copy the displayed `Token ID` (`root@pam!terraform`) and
   `Secret` (a UUID). The secret is shown only once.

### 2. Set credentials in your shell (don't commit these)

```bash
export PROXMOX_VE_ENDPOINT='https://192.168.8.191:8006/'
export PROXMOX_VE_API_TOKEN='root@pam!terraform=<UUID-secret>'
export PROXMOX_VE_INSECURE=true   # self-signed cert on LAN
```

Optional: drop the same lines in `~/.config/proxmox-tf.env` and `source` it.

### 3. Initialize

```bash
cd terraform/proxmox
terraform init
```

### 4. Find your node + VM names

```bash
# What does Proxmox call its nodes?
curl -sk -H "Authorization: PVEAPIToken=$PROXMOX_VE_API_TOKEN" \
  https://192.168.8.191:8006/api2/json/nodes | jq -r '.data[].node'

# What VMs exist?
curl -sk -H "Authorization: PVEAPIToken=$PROXMOX_VE_API_TOKEN" \
  https://192.168.8.191:8006/api2/json/cluster/resources?type=vm \
  | jq -r '.data[] | "\(.vmid) \(.name) on=\(.node) status=\(.status)"'
```

Update `pve_node_primary` (and `pve_node_secondary` if clustered) in
`variables.tf` with what comes back.

### 5. Import existing VMs one at a time

For each VM:

```bash
# Add a stub resource in vms.tf (see the example skeleton)
# Then import:
terraform import proxmox_virtual_environment_vm.pik <node-name>/165

# Now check what differs:
terraform plan
# Edit vms.tf until plan is clean (no changes proposed)
```

Repeat for every VM you want under management.

## Routine workflow

```bash
# Edit vms.tf — change CPU, memory, disk, etc.
terraform plan       # preview
terraform apply      # apply

# To create a new VM:
# Add a new resource block, then `terraform apply`.
```

## State

State is local in `terraform.tfstate` (gitignored). Fine for a single
operator. To collaborate or run from a CI/CD runner later, switch to a
remote backend (S3-compatible, or `kubernetes` backend storing state in a
cluster Secret).

## What this does NOT do

- Install Proxmox itself (manual: ISO → installer → network config)
- Manage Talos OS config inside the VM (use `talosctl apply-config` on top
  of the configs in `../../talos/`)
- Run on a schedule / from a runner — Terraform applies are local. To make
  apply automatic on Git push, add Atlantis, tofu-controller, or a GitHub
  Action that runs `terraform apply` after PR merge.
