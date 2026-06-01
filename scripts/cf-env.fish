#!/usr/bin/env fish
# Source me into a fish session — don't execute:
#   source scripts/cf-env.fish
#
# Pulls the Cloudflare API token from the in-cluster Secret
# terraform-state/cloudflare-token (decrypted by SOPS / KSOPS in Argo CD)
# and exports it as CLOUDFLARE_API_TOKEN so the cloudflare Terraform
# provider in terraform/cloudflare/ picks it up automatically.

set -l script_dir (dirname (status filename))
set -l repo_dir (realpath $script_dir/..)
set -l kubeconfig $repo_dir/kubeconfig

set -gx CLOUDFLARE_API_TOKEN (kubectl --kubeconfig=$kubeconfig get secret -n terraform-state cloudflare-token -o jsonpath="{.data.CLOUDFLARE_API_TOKEN}" | base64 -d)

echo "Loaded CLOUDFLARE_API_TOKEN into this fish session."
