# Proxmox VMs as Terraform

Manages VMs across **two standalone Proxmox hosts** (not clustered) using
the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest)
provider with **two aliased provider blocks**:

| Alias | Host | Endpoint | Node name (in PVE UI) |
|---|---|---|---|
| `proxmox.pve1` | `192.168.8.191` | `https://192.168.8.191:8006/` | `pve2` |
| `proxmox.pve2` | `192.168.8.226` | `https://192.168.8.226:8006/` | `pve` |

Each VM resource declares `provider = proxmox.<alias>` to pin it to a host.

## Bootstrap (one-time)

### 1. Create one API token on EACH Proxmox host

In each Proxmox UI:

1. **Datacenter → Permissions → API Tokens → Add**
2. User: `root@pam`
3. Token ID: `terraform`
4. **Uncheck** "Privilege Separation" (so the token inherits root's perms)
5. Click Add → copy the displayed `Secret` (UUID, shown once)

### 2. Set Terraform variables in your shell (don't commit these)

Fish:
```fish
set -gx TF_VAR_pve1_endpoint  'https://192.168.8.191:8006/'
set -gx TF_VAR_pve1_api_token 'root@pam!terraform=AAA-...'
set -gx TF_VAR_pve2_endpoint  'https://192.168.8.226:8006/'
set -gx TF_VAR_pve2_api_token 'root@pam!terraform=BBB-...'
```

Bash/zsh:
```bash
export TF_VAR_pve1_endpoint='https://192.168.8.191:8006/'
export TF_VAR_pve1_api_token='root@pam!terraform=AAA-...'
export TF_VAR_pve2_endpoint='https://192.168.8.226:8006/'
export TF_VAR_pve2_api_token='root@pam!terraform=BBB-...'
```

### 3. Initialize + plan

```bash
cd terraform/proxmox
terraform init
terraform plan
terraform apply
```

## Currently managed

| Resource | Provider | VM ID | PVE name | Talos hostname / IP |
|---|---|---|---|---|
| `proxmox_virtual_environment_vm.apollo1` | pve1 | 100 | `apollo1` | non-K8s |
| `proxmox_virtual_environment_vm.k8s_worker_pve191` | pve1 | 101 | `talos-worker-pve191-01` | talos-worker-pve191-01 (192.168.8.194) |
| `proxmox_virtual_environment_vm.k8s_control_plane` | pve2 | 100 | `talos-cp-pve226-01` | talos-mru-smr (192.168.8.227) |
| `proxmox_virtual_environment_vm.k8s_worker_gcx` | pve2 | 101 | `talos-worker-pve226-01` | talos-gcx-zwd (192.168.8.125) |

Former pve2 worker `pik2`/`talos-im5-2ok` (VM 102) was removed after repeated
userspace hangs and pve2 memory pressure. The steady-state topology is now one
control plane on pve2 plus one Longhorn-capable Talos worker on each Proxmox
host.

## Routine workflow

```bash
terraform plan       # preview
terraform apply      # apply
```

To create a new VM: add a new resource block, then `terraform apply`.

## State

Local `terraform.tfstate` (gitignored). Fine for single operator. Switch to
remote backend (S3-compatible or `kubernetes` Secret backend) for CI/CD.

## What this does NOT do

- Install Proxmox itself (manual: ISO → installer → network config)
- Manage Talos OS config inside the VM (use `talosctl apply-config` on the
  configs in `../../talos/`)
- Run on a schedule. Add Atlantis, tofu-controller, or GitHub Actions to
  apply on git push.
