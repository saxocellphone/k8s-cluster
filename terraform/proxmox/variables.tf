variable "pve_ssh_user" {
  description = "SSH user on Proxmox hosts for file uploads (used by some bpg/proxmox resources)"
  type        = string
  default     = "root"
}

variable "pve_node_primary" {
  description = "Name of the primary Proxmox node (as it appears in the PVE UI sidebar)"
  type        = string
  default     = "pve"
}

variable "pve_node_secondary" {
  description = "Name of the secondary Proxmox node (empty string if standalone, not clustered)"
  type        = string
  default     = ""
}
