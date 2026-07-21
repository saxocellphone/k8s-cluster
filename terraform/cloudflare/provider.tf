# Auth comes from the CLOUDFLARE_API_TOKEN env var, exported by:
#   source scripts/cf-env.fish
# (pulls it from the SOPS-encrypted Secret terraform-state/cloudflare-token).
provider "cloudflare" {}

locals {
  account_id = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  # The homelab zone. Everything predating runkorepo.com lives here, so
  # `zone_id` stays the unqualified name rather than being renamed under
  # every resource.
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
  # Runko's own product domain (added 2026-07-21). A SECOND zone, not a
  # subdomain: the *.victornazzaro.com tunnel wildcard does not cover it,
  # so every hostname here needs an explicit tunnel ingress entry, and
  # per-zone resources (cache ruleset, tiered cache) are duplicated
  # rather than shared - a ruleset is scoped to one zone per phase.
  runko_zone_id = "22c98370a4a05b3ea52606283a40cc69"
  tunnel_id     = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100"
}
