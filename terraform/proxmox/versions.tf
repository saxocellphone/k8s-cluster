terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }

  # State lives in-cluster as Secret/terraform-state/tfstate-default-proxmox.
  # Locking uses a Lease in the same namespace, so multiple operators on
  # different machines can collaborate safely.
  # Override the kubeconfig location via KUBE_CONFIG_PATH if running from a
  # different working directory.
  backend "kubernetes" {
    secret_suffix = "proxmox"
    namespace     = "terraform-state"
    config_path   = "../../kubeconfig"
  }
}
