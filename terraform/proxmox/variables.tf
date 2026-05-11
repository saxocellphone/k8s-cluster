variable "pve_ssh_user" {
  description = "SSH user on Proxmox hosts (used by some bpg/proxmox resources for file uploads)"
  type        = string
  default     = "root"
}

# ---- pve1 (192.168.8.191) ----

variable "pve1_endpoint" {
  description = "Proxmox API endpoint URL for pve1"
  type        = string
}

variable "pve1_api_token" {
  description = "Proxmox API token for pve1, format: user@realm!tokenid=UUID"
  type        = string
  sensitive   = true
}

variable "pve1_node_name" {
  description = "Name of the Proxmox node on pve1 (host .191) — confirmed via API as 'pve2'"
  type        = string
  default     = "pve2"
}

# ---- pve2 (192.168.8.226) ----

variable "pve2_endpoint" {
  description = "Proxmox API endpoint URL for pve2"
  type        = string
}

variable "pve2_api_token" {
  description = "Proxmox API token for pve2, format: user@realm!tokenid=UUID"
  type        = string
  sensitive   = true
}

variable "pve2_node_name" {
  description = "Name of the Proxmox node on pve2 (host .226) — confirmed via API as 'pve'"
  type        = string
  default     = "pve"
}
