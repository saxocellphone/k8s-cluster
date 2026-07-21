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

# llm.victornazzaro.com removed with SGLang deployment

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
      # ---- runkorepo.com (Runko's product domain) ---------------------------
      # A separate zone, so the wildcard above does NOT cover it. The APEX
      # needs its own entry regardless of any wildcard (an apex is not a
      # subdomain). Both go to ingress-nginx; the Host rules that split
      # runkod from the web UI live in the Runko repo's k8s manifests
      # (k8s-cluster/apps/monorepo-platform/ingress.yaml).
      #
      # www.runkorepo.com is deliberately absent: its 301 to the apex is an
      # edge redirect rule (cloudflare_ruleset.runko_www_redirect below), so
      # that hostname never reaches the tunnel.
      {
        hostname       = "runkorepo.com"
        origin_request = null
        path           = null
        service        = "http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80"
      },
      {
        hostname       = "*.runkorepo.com"
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

# OpenCode Access app removed: use OpenCode HTTP Basic Auth so CLI/attach
# gets JSON, not CF Access HTML. DNS record opencode.victornazzaro.com remains.
# Destroy leftover Access app in CF UI or: terraform destroy -target=...
# if state still tracks it — apply after removing from state if needed.

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

# ---- Runko (monorepo platform, maas-dev namespace) --------------------------
# Both hosts ride the tunnel wildcard -> ingress-nginx (Host-based Ingress
# rules live in apps/monorepo-platform/), so no per-host tunnel ingress
# entries are needed - these explicit DNS records follow the opencode
# pattern of naming every real service even where the zone wildcard would
# cover it.

resource "cloudflare_dns_record" "runko" {
  # NO Access app on prod: the challenge breaks git/API clients; runkod
  # enforces its own deploy-token auth. (CF caps comments at 100 chars.)
  comment         = "Runko prod (web UI + runkod API/git); deliberately no Access"
  content         = "${local.tunnel_id}.cfargotunnel.com"
  data            = null
  name            = "runko.victornazzaro.com"
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
  zone_id = local.zone_id
}

resource "cloudflare_dns_record" "runko_dev" {
  comment         = "Runko dev (Vite HMR on carbon-node); Access-guarded"
  content         = "${local.tunnel_id}.cfargotunnel.com"
  data            = null
  name            = "runko-dev.victornazzaro.com"
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
  zone_id = local.zone_id
}

# Edge caching for the Runko public host (added for external-traffic
# readiness, 2026-07-10). Cloudflare never caches HTML without an explicit
# cache rule; this one makes the ORIGIN's Cache-Control headers the single
# source of truth (edge_ttl "bypass_by_default" = "use cache-control header
# if present, bypass cache if not"), so what gets cached is declared in the
# Runko repo's web/nginx.conf, not here: landing + SPA shell 5 min, hashed
# /assets/ a year, unhashed statics 1 h. runkod never sends a public
# Cache-Control, so even if a dynamic path slipped the expression below it
# would still bypass - the path exclusions (git, REST, RPC, org mounts,
# probes) are defense in depth on top, not the only guard. Scoped to the
# prod host only: runko-dev is Access-guarded and must stay uncached.
#
# NOTE: a zone gets ONE ruleset per phase - if another
# http_request_cache_settings ruleset is ever created outside Terraform,
# import it here rather than adding a second resource.
resource "cloudflare_ruleset" "runko_cache" {
  zone_id = local.zone_id
  name    = "Cache rules"
  kind    = "zone"
  phase   = "http_request_cache_settings"
  rules = [
    {
      ref         = "runko_public_cache"
      description = "Runko public host: cache what the origin marks cacheable"
      expression  = "(http.host eq \"runko.victornazzaro.com\" and not starts_with(http.request.uri.path, \"/api\") and not starts_with(http.request.uri.path, \"/o/\") and not starts_with(http.request.uri.path, \"/monorepo.git\") and not starts_with(http.request.uri.path, \"/runko.v1.\") and not starts_with(http.request.uri.path, \"/internal\") and not http.request.uri.path in {\"/healthz\" \"/readyz\" \"/metrics\"})"
      action      = "set_cache_settings"
      action_parameters = {
        cache = true
        edge_ttl = {
          mode = "bypass_by_default"
        }
        browser_ttl = {
          mode = "respect_origin"
        }
      }
    },
  ]
}

# Smart Tiered Cache: misses fan through one upper-tier PoP instead of
# every PoP fetching from the homelab origin independently. Zone-wide, but
# only cached content is affected - the Runko host is the only one that
# marks anything cacheable, so other hosts see no behavior change.
resource "cloudflare_tiered_cache" "zone" {
  zone_id = local.zone_id
  value   = "on"
}

# First-class reusable Access policy. The existing operator-email policies
# are legacy app-embedded (see "Note on Access policies" in README.md) and
# cannot be attached to a new application, so this is the first
# account-level one; future apps can reference it too.
resource "cloudflare_zero_trust_access_policy" "owner_email" {
  account_id = local.account_id
  name       = "Owner email allow-list (reusable)"
  decision   = "allow"
  include = [
    {
      email = {
        email = "nazzav923@gmail.com"
      }
    },
  ]
}

# Access gate for the dev server: a Vite dev host (unminified source, HMR
# endpoint) must not be world-reachable even though exposing it through
# the tunnel was an explicit owner decision (2026-07-08). Browser-only
# traffic, so the Access HTML challenge costs nothing here - unlike the
# prod host, which stays Access-free for git/API clients.
resource "cloudflare_zero_trust_access_application" "runko_dev" {
  account_id = local.account_id
  name       = "Runko dev (Vite HMR)"
  type       = "self_hosted"
  domain     = "runko-dev.victornazzaro.com"
  destinations = [
    {
      type = "public"
      uri  = "runko-dev.victornazzaro.com"
    },
  ]
  session_duration           = "24h"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  enable_binding_cookie      = false
  http_only_cookie_attribute = true
  options_preflight_bypass   = false
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.owner_email.id
      precedence = 1
    },
  ]
}

# =============================================================================
# runkorepo.com - Runko's product domain (cutover from runko.victornazzaro.com,
# 2026-07-21). Zone 22c98370..., delegated from GoDaddy to Cloudflare NS.
#
# Migration shape: the two hosts DUAL-SERVE. Every runko.victornazzaro.com
# resource above stays live and untouched while clones, credentials and the
# GitHub Actions RUNKO_URL secret move over; only then does the old host get
# its 301 (and this file lose the resources that serve it).
#
# Cloudflare's zone onboarding scraped GoDaddy's parking DNS into this zone
# (2x apex A -> AWS parking, _domainconnect, pay -> GoDaddy paylinks, www,
# and a GoDaddy default _dmarc). Those were deleted out-of-band before the
# first apply of this section - an apex CNAME cannot coexist with apex A
# records - and everything this zone should hold is declared below.
# =============================================================================

# The apex serves the WHOLE platform (web UI + runkod REST/RPC/git), exactly
# as runko.victornazzaro.com does - path-routed by the Ingress objects in
# apps/monorepo-platform/ingress.yaml. Proxied CNAME at the apex is legal
# via Cloudflare's CNAME flattening.
#
# NO Access app here, same reasoning as the old prod host: the challenge
# breaks git/API clients and runkod enforces its own auth.
resource "cloudflare_dns_record" "runkorepo" {
  comment         = "Runko prod (web UI + runkod API/git); deliberately no Access"
  content         = "${local.tunnel_id}.cfargotunnel.com"
  data            = null
  name            = "runkorepo.com"
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
  zone_id = local.runko_zone_id
}

# www exists only to be redirected (runko_www_redirect below). It must still
# be a PROXIED record: an edge redirect rule only runs on traffic that
# reaches Cloudflare's proxy.
resource "cloudflare_dns_record" "runkorepo_www" {
  comment         = "301 -> apex via the dynamic-redirect ruleset; never reaches origin"
  content         = "runkorepo.com"
  data            = null
  name            = "www.runkorepo.com"
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
  zone_id = local.runko_zone_id
}

resource "cloudflare_dns_record" "runkorepo_dev" {
  comment         = "Runko dev (Vite HMR on carbon-node); Access-guarded"
  content         = "${local.tunnel_id}.cfargotunnel.com"
  data            = null
  name            = "dev.runkorepo.com"
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
  zone_id = local.runko_zone_id
}

# Anti-spoofing for a domain that sends no mail. Runko's outbound mail
# (runko-mailer) goes out over Gmail SMTP as nazzav923@gmail.com, NOT as
# @runkorepo.com - so a hard-fail SPF and a reject DMARC cost nothing and
# stop a fresh, unprotected domain from being a convenient spoof target.
# Adding mail here later = relax both records in the same change.
#
# No rua= on the DMARC record on purpose: aggregate reports to an address
# outside the domain need the receiving domain to publish an authorization
# record, which gmail.com does not do - a rua that silently fails is worse
# than none.
resource "cloudflare_dns_record" "runkorepo_spf" {
  comment         = "No mail originates from this domain"
  content         = "\"v=spf1 -all\""
  data            = null
  name            = "runkorepo.com"
  priority        = null
  private_routing = null
  proxied         = false
  tags            = []
  ttl             = 1
  type            = "TXT"
  zone_id         = local.runko_zone_id
}

resource "cloudflare_dns_record" "runkorepo_dmarc" {
  comment         = "Replaces GoDaddy's default p=quarantine record"
  content         = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s\""
  data            = null
  name            = "_dmarc.runkorepo.com"
  priority        = null
  private_routing = null
  proxied         = false
  tags            = []
  ttl             = 1
  type            = "TXT"
  zone_id         = local.runko_zone_id
}

# Same contract as runko_cache on the old zone: the ORIGIN's Cache-Control
# is the single source of truth (edge_ttl bypass_by_default), with the
# dynamic paths excluded as defense in depth. Kept as a SEPARATE resource
# because a ruleset is scoped to one zone - a zone gets one ruleset per
# phase, so this cannot be a second rule inside runko_cache.
resource "cloudflare_ruleset" "runkorepo_cache" {
  zone_id = local.runko_zone_id
  name    = "Cache rules"
  kind    = "zone"
  phase   = "http_request_cache_settings"
  rules = [
    {
      ref         = "runkorepo_public_cache"
      description = "Runko public host: cache what the origin marks cacheable"
      expression  = "(http.host eq \"runkorepo.com\" and not starts_with(http.request.uri.path, \"/api\") and not starts_with(http.request.uri.path, \"/o/\") and not starts_with(http.request.uri.path, \"/monorepo.git\") and not starts_with(http.request.uri.path, \"/runko.v1.\") and not starts_with(http.request.uri.path, \"/internal\") and not http.request.uri.path in {\"/healthz\" \"/readyz\" \"/metrics\"})"
      action      = "set_cache_settings"
      action_parameters = {
        cache = true
        edge_ttl = {
          mode = "bypass_by_default"
        }
        browser_ttl = {
          mode = "respect_origin"
        }
      }
    },
  ]
}

# www -> apex, 301, path and query preserved. Edge-only: nothing about this
# reaches the cluster, which is why no Ingress rule or tunnel entry names
# www. This ruleset is also where the old host's eventual 301 will go -
# on the OTHER zone, as its own resource.
resource "cloudflare_ruleset" "runkorepo_www_redirect" {
  zone_id = local.runko_zone_id
  name    = "Redirect rules"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"
  rules = [
    {
      ref         = "runkorepo_www_to_apex"
      description = "www.runkorepo.com -> runkorepo.com"
      expression  = "(http.host eq \"www.runkorepo.com\")"
      action      = "redirect"
      action_parameters = {
        from_value = {
          status_code = 301
          target_url = {
            expression = "concat(\"https://runkorepo.com\", http.request.uri.path)"
          }
          preserve_query_string = true
        }
      }
    },
  ]
}

# Smart Tiered Cache for the new zone (the old zone has its own; the
# resource is per-zone). Same rationale: misses fan through one upper-tier
# PoP instead of every PoP hitting the homelab origin.
resource "cloudflare_tiered_cache" "runkorepo" {
  zone_id = local.runko_zone_id
  value   = "on"
}

# Dev-server Access gate on the new domain. Reuses the account-level
# owner_email policy (account-scoped, so it spans zones). The old
# runko-dev.victornazzaro.com app above stays until the dev host is
# retired - two gates on the same origin, both owner-only.
resource "cloudflare_zero_trust_access_application" "runkorepo_dev" {
  account_id = local.account_id
  name       = "Runko dev (Vite HMR, runkorepo.com)"
  type       = "self_hosted"
  domain     = "dev.runkorepo.com"
  destinations = [
    {
      type = "public"
      uri  = "dev.runkorepo.com"
    },
  ]
  session_duration           = "24h"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  enable_binding_cookie      = false
  http_only_cookie_attribute = true
  options_preflight_bypass   = false
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.owner_email.id
      precedence = 1
    },
  ]
}
