# Import blocks map existing Cloudflare resources into state. Resource
# bodies are generated via:
#   terraform plan -generate-config-out=generated.tf
# Once generated.tf is reviewed and `terraform apply` has imported these,
# this file can be deleted (imports are idempotent no-ops afterwards).

# ---- Tunnel ingress config -------------------------------------------------
import {
  to = cloudflare_zero_trust_tunnel_cloudflared_config.homelab
  id = "e34e1aabbaa8c7a5ca6a7a229dea2ae7/1e1fd0a8-4d55-4eb1-ba74-2e6829b36100"
}

# ---- DNS records (orange-clouded CNAMEs -> tunnel) -------------------------
import {
  to = cloudflare_dns_record.audiobooks
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/a4b883e61562c8c6d1c22de0e1ed1672"
}
import {
  to = cloudflare_dns_record.c2c
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/a1e932c601062227f88421c85eec835d"
}
import {
  to = cloudflare_dns_record.paste
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/6ae048e319c3017e39bc6ef36d6db700"
}
import {
  to = cloudflare_dns_record.qbit
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/ffb5b71f46a830646ed83c59e7eefa3f"
}
import {
  to = cloudflare_dns_record.radarr
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/2c1fdfc1bf6fc53aaf4b154a715010b7"
}
import {
  to = cloudflare_dns_record.rancher
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/840ef69fc6734b5acdbd45b1459db012"
}
import {
  to = cloudflare_dns_record.sonarr
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/bacd164f4cca352854630fe828931c77"
}
import {
  to = cloudflare_dns_record.ssh
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/b8190572c86a2ebb58bdb19f70fd31dc"
}
import {
  to = cloudflare_dns_record.chat
  id = "45bbfa2da6b4eac2713d440e0f4e5f8d/31525df843ff7c8ab697f6dca483780d"
}

# ---- Access applications ---------------------------------------------------
import {
  to = cloudflare_zero_trust_access_application.homelab
  id = "accounts/e34e1aabbaa8c7a5ca6a7a229dea2ae7/5e463ac3-82aa-48d6-ae27-bdd8dc8c3e92"
}
import {
  to = cloudflare_zero_trust_access_application.ssh_bastion
  id = "accounts/e34e1aabbaa8c7a5ca6a7a229dea2ae7/379c4b6c-ec66-4b37-85fd-c19da0788378"
}
import {
  to = cloudflare_zero_trust_access_application.ai
  id = "accounts/e34e1aabbaa8c7a5ca6a7a229dea2ae7/c24b2229-9145-4656-9168-3d7fb6e17736"
}

# NOTE: The Access policies (operator email allow-list, nzb360 service token)
# are legacy app-embedded policies. They cannot be managed as standalone
# cloudflare_zero_trust_access_policy resources (the account-level policies
# API 404s on them). They are instead referenced inline by ID in each
# application's `policies` block below.

# ---- Access service token --------------------------------------------------
import {
  to = cloudflare_zero_trust_access_service_token.nzb360
  id = "accounts/e34e1aabbaa8c7a5ca6a7a229dea2ae7/ac88c1ef-f5e0-4f10-80a4-41ad08ddbff7"
}
