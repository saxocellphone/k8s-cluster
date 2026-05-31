#!/usr/bin/env fish
# Source me into a fish session — don't execute:
#   source scripts/tf-env.fish
#
# Pulls TF_VAR_pve{1,2}_{endpoint,api_token} from the in-cluster Secret
# terraform-state/proxmox-tokens (decrypted by SOPS / KSOPS in Argo CD) and
# exports them globally so `terraform` in terraform/proxmox/ picks them up.

set -l script_dir (dirname (status filename))
set -l repo_dir (realpath $script_dir/..)
set -l kubeconfig $repo_dir/kubeconfig

for k in TF_VAR_pve1_endpoint TF_VAR_pve1_api_token TF_VAR_pve2_endpoint TF_VAR_pve2_api_token
    set -gx $k (kubectl --kubeconfig=$kubeconfig get secret -n terraform-state proxmox-tokens -o jsonpath="{.data.$k}" | base64 -d)
end

echo "Loaded TF_VAR_pve{1,2}_{endpoint,api_token} into this fish session."
