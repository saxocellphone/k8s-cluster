terraform {
  required_version = ">= 1.6.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # State lives in-cluster as Secret/terraform-state/tfstate-default-cloudflare.
  # Locking uses a Lease in the same namespace, mirroring terraform/proxmox/.
  # Override the kubeconfig location via KUBE_CONFIG_PATH if running from a
  # different working directory.
  backend "kubernetes" {
    secret_suffix = "cloudflare"
    namespace     = "terraform-state"
    config_path   = "../../kubeconfig"
  }
}
