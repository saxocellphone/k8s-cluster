# Cloudflare Zero Trust resources for the homelab tunnel, imported from the
# live account via `terraform plan -generate-config-out`. Covers tunnel
# ingress routing, orange-clouded DNS CNAMEs, Access applications, and the
# nzb360 service token. See README.md for the import history and the note on
# legacy app-embedded Access policies (managed inline, not as standalone
# cloudflare_zero_trust_access_policy resources).

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/2c1fdfc1bf6fc53aaf4b154a715010b7"
resource "cloudflare_dns_record" "radarr" {
  comment         = "managed by scripts/setup-cloudflare-arr-stack.sh"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "radarr.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/bacd164f4cca352854630fe828931c77"
resource "cloudflare_dns_record" "sonarr" {
  comment         = "managed by scripts/setup-cloudflare-arr-stack.sh"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "sonarr.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/6ae048e319c3017e39bc6ef36d6db700"
resource "cloudflare_dns_record" "paste" {
  comment         = null
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "paste.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/ffb5b71f46a830646ed83c59e7eefa3f"
resource "cloudflare_dns_record" "qbit" {
  comment         = "managed by scripts/setup-cloudflare-arr-stack.sh"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "qbit.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

resource "cloudflare_dns_record" "ai" {
  comment         = "AI mode switcher"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "ai.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

resource "cloudflare_dns_record" "llm" {
  comment         = "Local LLM backend"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "llm.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

resource "cloudflare_dns_record" "chat" {
  comment         = "Open WebUI chat frontend"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "chat.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

resource "cloudflare_dns_record" "comfyui" {
  comment         = "ComfyUI image backend"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "comfyui.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# Notion-writer webhook receiver (created by Terraform, not imported).
resource "cloudflare_dns_record" "writer" {
  comment         = "openclaw cron --webhook target (notion-writer)"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "writer.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/cf65ccee5d593c1ea3c162dd6225f130"
resource "cloudflare_dns_record" "openclaw" {
  comment         = null
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "openclaw.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}



# Zone-apex wildcard for dynamic first-level public hosts.
# Specific DNS records (sonarr, memos, …) take precedence over this
# wildcard. Required for CF Universal SSL (only covers one label under apex).
resource "cloudflare_dns_record" "openhands_runtime_wildcard" {
  comment         = "Zone apex wildcard (specifics win; CF Universal SSL)"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "*.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# __generated__ by Terraform from "accounts/e34e1aabbaa8c7a5ca6a7a229dea2ae7/ac88c1ef-f5e0-4f10-80a4-41ad08ddbff7"
resource "cloudflare_zero_trust_access_service_token" "nzb360" {
  account_id                        = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  duration                          = "forever"
  name                              = "arr-stack-nzb360"
  previous_client_secret_expires_at = null
  zone_id                           = null
}

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/840ef69fc6734b5acdbd45b1459db012"
resource "cloudflare_dns_record" "rancher" {
  comment         = null
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "rancher.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/b8190572c86a2ebb58bdb19f70fd31dc"
resource "cloudflare_dns_record" "ssh" {
  comment         = null
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "ssh.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/a1e932c601062227f88421c85eec835d"
resource "cloudflare_dns_record" "c2c" {
  comment         = null
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "c2c.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

# __generated__ by Terraform from "e34e1aabbaa8c7a5ca6a7a229dea2ae7/1e1fd0a8-4d55-4eb1-ba74-2e6829b36100"
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  config = {
    ingress = [
      {
        hostname       = "c2c.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://mirotalkc2c.mirotalkc2c.svc.cluster.local:8080"
      },
      {
        hostname = "audiobooks.victornazzaro.com"
        origin_request = {
          access                   = null
          ca_pool                  = null
          connect_timeout          = null
          disable_chunked_encoding = null
          http2_origin             = null
          http_host_header         = null
          keep_alive_connections   = null
          keep_alive_timeout       = null
          match_sn_ito_host        = null
          no_happy_eyeballs        = null
          no_tls_verify            = null
          origin_server_name       = null
          proxy_type               = null
          tcp_keep_alive           = null
          tls_timeout              = null
        }
        path    = null
        service = "http://audiobookshelf.torrenting.svc.cluster.local:13378"
      },
      {
        hostname = "paste.victornazzaro.com"
        origin_request = {
          access                   = null
          ca_pool                  = null
          connect_timeout          = null
          disable_chunked_encoding = null
          http2_origin             = null
          http_host_header         = null
          keep_alive_connections   = null
          keep_alive_timeout       = null
          match_sn_ito_host        = null
          no_happy_eyeballs        = null
          no_tls_verify            = null
          origin_server_name       = null
          proxy_type               = null
          tcp_keep_alive           = null
          tls_timeout              = null
        }
        path    = null
        service = "http://memos.memos.svc.cluster.local:5230"
      },
      {
        hostname       = "sonarr.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://sonarr.torrenting.svc.cluster.local:8989"
      },
      {
        hostname       = "radarr.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://radarr.torrenting.svc.cluster.local:7878"
      },
      {
        hostname       = "qbit.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://qbittorrent.torrenting.svc.cluster.local:8080"
      },
      {
        hostname       = "ssh.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "ssh://192.168.8.140:22"
      },
      {
        hostname = "rancher.victornazzaro.com"
        origin_request = {
          access                   = null
          ca_pool                  = null
          connect_timeout          = null
          disable_chunked_encoding = null
          http2_origin             = null
          http_host_header         = null
          keep_alive_connections   = null
          keep_alive_timeout       = null
          match_sn_ito_host        = null
          no_happy_eyeballs        = null
          no_tls_verify            = null
          origin_server_name       = null
          proxy_type               = null
          tcp_keep_alive           = null
          tls_timeout              = null
        }
        path    = null
        service = "http://rancher.cattle-system.svc.cluster.local:80"
      },
      {
        hostname       = "openclaw.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://openclaw.openclaw.svc.cluster.local:18789"
      },
                  {
        hostname       = "ai.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://mode-switcher.ai-inference.svc.cluster.local:8080"
      },
      {
        hostname       = "llm.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://llm.ai-inference.svc.cluster.local:8080"
      },
      {
        hostname       = "chat.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://open-webui.ai-inference.svc.cluster.local:8080"
      },
      {
        hostname       = "comfyui.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://comfyui.ai-inference.svc.cluster.local:8188"
      },
      {
        # Public ingress for the deterministic Notion writer. OpenClaw's cron
        # --webhook refuses to POST to private/cluster IPs (SSRF guard), so the
        # writer is reached via this public hostname instead. Protected by the
        # WEBHOOK_TOKEN bearer the writer enforces (no CF Access app, since the
        # caller is OpenClaw's server-side POST, not a browser login).
        hostname       = "writer.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://notion-writer.openclaw.svc.cluster.local:80"
      },
      {
        # Catch-all for unlisted first-level subdomains. Named routes above win.
        # Must hit ingress-nginx so Host-based Ingress rules are honored.
        hostname       = "*.victornazzaro.com"
        origin_request = null
        path           = null
        service        = "http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80"
      },
      {
        hostname       = null
        origin_request = null
        path           = null
        service        = "http_status:404"
      },
    ]
    origin_request = null
  }
  source    = "cloudflare"
  tunnel_id = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100"
}

# __generated__ by Terraform from "accounts/e34e1aabbaa8c7a5ca6a7a229dea2ae7/c6948052-8a41-4c2d-830e-427b3b6cc4b4"

# OpenCode server (multi-client coding harness). Public host uses tunnel wildcard
# → ingress-nginx; Access app gates browsers before OpenCode basic auth.
resource "cloudflare_dns_record" "opencode" {
  comment         = "OpenCode serve (API + clients)"
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "opencode.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}

resource "cloudflare_zero_trust_access_application" "opencode" {
  account_id                   = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  allow_authenticate_via_warp  = null
  allow_iframe                 = null
  allowed_idps                 = null
  app_launcher_logo_url        = null
  app_launcher_visible         = true
  auto_redirect_to_identity    = false
  bg_color                     = null
  cors_headers                 = null
  custom_deny_message          = null
  custom_deny_url              = null
  custom_non_identity_deny_url = null
  custom_pages                 = null
  destinations = [
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "opencode.victornazzaro.com"
      vnet_id       = null
    },
  ]
  domain                     = "opencode.victornazzaro.com"
  enable_binding_cookie      = false
  footer_links               = null
  header_bg_color            = null
  http_only_cookie_attribute = true
  landing_page_design        = null
  logo_url                   = null
  mfa_config                 = null
  name                       = "OpenCode"
  oauth_configuration        = null
  options_preflight_bypass   = false
  path_cookie_attribute      = null
  # Inline allow-list (same operator email as AI Services app) — legacy policy
  # id attachment fails for new apps (CF 12130).
  policies = [
    {
      connection_rules = null
      decision         = "allow"
      exclude          = null
      id               = null
      include = [
        {
          email = {
            email = "nazzav923@gmail.com"
          }
        }
      ]
      mfa_config = null
      name       = "Operator email allow-list"
      precedence = 1
      require    = null
    },
  ]
  read_service_tokens_from_header = null
  saas_app                        = null
  same_site_cookie_attribute      = null
  scim_config                     = null
  service_auth_401_redirect       = null
  session_duration                = "24h"
  skip_interstitial               = null
  tags                            = null
  target_criteria                 = null
  type                            = "self_hosted"
  zone_id                         = null
}

resource "cloudflare_zero_trust_access_application" "openclaw" {
  account_id                   = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  allow_authenticate_via_warp  = null
  allow_iframe                 = null
  allowed_idps                 = null
  app_launcher_logo_url        = null
  app_launcher_visible         = true
  auto_redirect_to_identity    = false
  bg_color                     = null
  cors_headers                 = null
  custom_deny_message          = null
  custom_deny_url              = null
  custom_non_identity_deny_url = null
  custom_pages                 = null
  destinations = [
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "openclaw.victornazzaro.com"
      vnet_id       = null
    },
  ]
  domain                     = "openclaw.victornazzaro.com"
  enable_binding_cookie      = false
  footer_links               = null
  header_bg_color            = null
  http_only_cookie_attribute = true
  landing_page_design        = null
  logo_url                   = null
  mfa_config                 = null
  name                       = "OpenClaw"
  oauth_configuration        = null
  options_preflight_bypass   = false
  path_cookie_attribute      = null
  policies = [
    {
      connection_rules = null
      decision         = null
      exclude          = null
      id               = "0febeabd-8492-480f-96ae-55ea5dad764c"
      include          = null
      mfa_config       = null
      name             = null
      precedence       = 1
      require          = null
    },
  ]
  read_service_tokens_from_header = null
  saas_app                        = null
  same_site_cookie_attribute      = null
  scim_config                     = null
  service_auth_401_redirect       = null
  session_duration                = "24h"
  skip_interstitial               = null
  tags                            = null
  target_criteria                 = null
  type                            = "self_hosted"
  zone_id                         = null
}

# __generated__ by Terraform from "accounts/e34e1aabbaa8c7a5ca6a7a229dea2ae7/5e463ac3-82aa-48d6-ae27-bdd8dc8c3e92"
resource "cloudflare_zero_trust_access_application" "homelab" {
  account_id                   = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  allow_authenticate_via_warp  = null
  allow_iframe                 = null
  allowed_idps                 = null
  app_launcher_logo_url        = null
  app_launcher_visible         = true
  auto_redirect_to_identity    = false
  bg_color                     = null
  cors_headers                 = null
  custom_deny_message          = null
  custom_deny_url              = null
  custom_non_identity_deny_url = null
  custom_pages                 = null
  destinations = [
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "sonarr.victornazzaro.com"
      vnet_id       = null
    },
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "radarr.victornazzaro.com"
      vnet_id       = null
    },
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "qbit.victornazzaro.com"
      vnet_id       = null
    },
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "tesla.victornazzaro.com"
      vnet_id       = null
    },
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "tesla-grafana.victornazzaro.com"
      vnet_id       = null
    },
  ]
  domain                     = "sonarr.victornazzaro.com"
  enable_binding_cookie      = false
  footer_links               = null
  header_bg_color            = null
  http_only_cookie_attribute = true
  landing_page_design        = null
  logo_url                   = null
  mfa_config                 = null
  name                       = "Homelab"
  oauth_configuration        = null
  options_preflight_bypass   = false
  path_cookie_attribute      = null
  policies = [
    {
      connection_rules = null
      decision         = null
      exclude          = null
      id               = "2de5ea37-30d9-4337-9e24-297b08053d3a"
      include          = null
      mfa_config       = null
      name             = null
      precedence       = 1
      require          = null
    },
    {
      connection_rules = null
      decision         = null
      exclude          = null
      id               = "d65a9d4c-b263-4714-bb09-3fe88be8da5f"
      include          = null
      mfa_config       = null
      name             = null
      precedence       = 2
      require          = null
    },
  ]
  read_service_tokens_from_header = null
  saas_app                        = null
  same_site_cookie_attribute      = null
  scim_config                     = null
  service_auth_401_redirect       = null
  session_duration                = "24h"
  skip_interstitial               = null
  tags                            = null
  target_criteria                 = null
  type                            = "self_hosted"
  zone_id                         = null
}

resource "cloudflare_zero_trust_access_application" "ai" {
  account_id                   = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  allow_authenticate_via_warp  = null
  allow_iframe                 = null
  allowed_idps                 = null
  app_launcher_logo_url        = null
  app_launcher_visible         = true
  auto_redirect_to_identity    = false
  bg_color                     = null
  cors_headers                 = null
  custom_deny_message          = null
  custom_deny_url              = null
  custom_non_identity_deny_url = null
  custom_pages                 = null
  destinations = [
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "ai.victornazzaro.com"
      vnet_id       = null
    },
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "llm.victornazzaro.com"
      vnet_id       = null
    },
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "comfyui.victornazzaro.com"
      vnet_id       = null
    },
  ]
  domain                     = "ai.victornazzaro.com"
  enable_binding_cookie      = false
  footer_links               = null
  header_bg_color            = null
  http_only_cookie_attribute = true
  landing_page_design        = null
  logo_url                   = null
  mfa_config                 = null
  name                       = "AI Services"
  oauth_configuration        = null
  options_preflight_bypass   = false
  path_cookie_attribute      = null
  policies = [
    {
      connection_rules = null
      decision         = "allow"
      exclude          = null
      id               = null
      include = [
        {
          email = {
            email = "nazzav923@gmail.com"
          }
        }
      ]
      mfa_config = null
      name       = "Operator email allow-list"
      precedence = 1
      require    = null
    },
  ]
  read_service_tokens_from_header = null
  saas_app                        = null
  same_site_cookie_attribute      = null
  scim_config                     = null
  service_auth_401_redirect       = null
  session_duration                = "24h"
  skip_interstitial               = null
  tags                            = null
  target_criteria                 = null
  type                            = "self_hosted"
  zone_id                         = null
}

# __generated__ by Terraform from "accounts/e34e1aabbaa8c7a5ca6a7a229dea2ae7/379c4b6c-ec66-4b37-85fd-c19da0788378"
resource "cloudflare_zero_trust_access_application" "ssh_bastion" {
  account_id                   = "e34e1aabbaa8c7a5ca6a7a229dea2ae7"
  allow_authenticate_via_warp  = null
  allow_iframe                 = null
  allowed_idps                 = null
  app_launcher_logo_url        = null
  app_launcher_visible         = true
  auto_redirect_to_identity    = false
  bg_color                     = null
  cors_headers                 = null
  custom_deny_message          = null
  custom_deny_url              = null
  custom_non_identity_deny_url = null
  custom_pages                 = null
  destinations = [
    {
      cidr          = null
      hostname      = null
      l4_protocol   = null
      mcp_server_id = null
      port_range    = null
      type          = "public"
      uri           = "ssh.victornazzaro.com"
      vnet_id       = null
    },
  ]
  domain                     = "ssh.victornazzaro.com"
  enable_binding_cookie      = false
  footer_links               = null
  header_bg_color            = null
  http_only_cookie_attribute = true
  landing_page_design        = null
  logo_url                   = null
  mfa_config                 = null
  name                       = "SSH Bastion"
  oauth_configuration        = null
  options_preflight_bypass   = false
  path_cookie_attribute      = null
  policies = [
    {
      connection_rules = null
      decision         = null
      exclude          = null
      id               = "9d9a2567-5a78-4a23-9f37-0c24a4ca8387"
      include          = null
      mfa_config       = null
      name             = null
      precedence       = 1
      require          = null
    },
  ]
  read_service_tokens_from_header = null
  saas_app                        = null
  same_site_cookie_attribute      = null
  scim_config                     = null
  service_auth_401_redirect       = null
  session_duration                = "24h"
  skip_interstitial               = null
  tags                            = null
  target_criteria                 = null
  type                            = "self_hosted"
  zone_id                         = null
}

# __generated__ by Terraform from "45bbfa2da6b4eac2713d440e0f4e5f8d/a4b883e61562c8c6d1c22de0e1ed1672"
resource "cloudflare_dns_record" "audiobooks" {
  comment         = null
  content         = "1e1fd0a8-4d55-4eb1-ba74-2e6829b36100.cfargotunnel.com"
  data            = null
  name            = "audiobooks.victornazzaro.com"
  priority        = null
  private_routing = null
  proxied         = true
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "45bbfa2da6b4eac2713d440e0f4e5f8d"
}
