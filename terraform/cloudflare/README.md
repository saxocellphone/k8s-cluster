# Cloudflare Zero Trust as Terraform

Manages the homelab's Cloudflare Tunnel routing, DNS, and Access (Zero Trust)
configuration declaratively, using the
[cloudflare/cloudflare](https://registry.terraform.io/providers/cloudflare/cloudflare/latest)
provider (**v5**). Separate from Argo CD's GitOps loop — Terraform does not run
on commit; apply manually.

The tunnel **connector** (the `cloudflared` daemon) is still GitOps-managed in
`apps/cloudflared/`. This module manages the **cloud-side** config the connector
relies on: which hostnames route where, the DNS records, and who can log in.

## What's managed

| Resource | Name(s) |
|---|---|
| `cloudflare_zero_trust_tunnel_cloudflared_config` | `homelab` (all ingress rules) |
| `cloudflare_dns_record` | `ai`, `audiobooks`, `c2c`, `chat`, `comfyui`, `paste`, `qbit`, `radarr`, `rancher`, `runko`, `runko_dev`, `sonarr`, `ssh` (orange-clouded CNAMEs → tunnel) |
| `cloudflare_zero_trust_access_application` | `ai`, `homelab`, `runko_dev`, `ssh_bastion` |
| `cloudflare_zero_trust_access_policy` | `owner_email` (first-class reusable; new apps should reference this, not the legacy embedded ones) |
| `cloudflare_zero_trust_access_service_token` | `nzb360` |
| `cloudflare_ruleset` | `runko_cache` (zone cache rules — Runko public host edge caching; the origin's Cache-Control is the source of truth, see the resource comment) |
| `cloudflare_tiered_cache` | `zone` (Smart Tiered Cache, zone-wide) |

### Note on Access policies

The operator-email and nzb360 service-token policies are **legacy
app-embedded** policies created via the older Access API. They cannot be
managed as standalone `cloudflare_zero_trust_access_policy` resources — the
account-level policies endpoint returns 404 for them. They are instead
referenced inline by ID in each application's `policies` block in
`resources.tf`. To migrate them to first-class reusable policies, recreate
them (new IDs) — a deliberate, separate change.

## Auth

The Cloudflare API token lives in the SOPS-encrypted Secret
`terraform-state/cloudflare-token` (see `apps/terraform-state/`). Load it:

```fish
source ../../scripts/cf-env.fish
```

That exports `CLOUDFLARE_API_TOKEN`, which the provider reads automatically.

To rotate the token: edit the Secret in place, then `git push` (Argo CD syncs):

```bash
SOPS_AGE_KEY_FILE=../../key.txt sops ../../apps/terraform-state/cloudflare-token-secret.yaml
```

## State

Remote, in-cluster — same pattern as `terraform/proxmox/`. State lives as
`Secret/terraform-state/tfstate-default-cloudflare`; locking uses
`Lease/terraform-state/lock-tfstate-default-cloudflare`. Configured in
`versions.tf` via the `kubernetes` backend with `config_path = "../../kubeconfig"`.

## Routine workflow

```bash
source ../../scripts/cf-env.fish
cd terraform/cloudflare
terraform init    # first time / after provider changes
terraform plan
terraform apply
```

### Example changes

- **New protected hostname:** add an ingress entry to the `homelab` tunnel
  config, add a `cloudflare_dns_record` CNAME (proxied, → tunnel target), and
  add the hostname to the relevant Access application's domains.
- **Add an allowed email:** because policies are legacy/embedded, edit them in
  the Cloudflare dashboard for now (see the policy note above).

## Import history

All resources were imported from the live account on first setup via
`import {}` blocks (`imports.tf`) + `terraform plan -generate-config-out`. The
import blocks remain as documentation of the source resource IDs; they are
no-ops now that the resources are in state.
