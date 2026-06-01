# Auth comes from the CLOUDFLARE_API_TOKEN env var, exported by:
#   source scripts/cf-env.fish
# (pulls it from the SOPS-encrypted Secret terraform-state/cloudflare-token).
provider "cloudflare" {}

locals {
  account_id = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  zone_id    = "45bbfa2da6b4eac2713d440e0f4e5f8d"
  tunnel_id  = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100"
}
