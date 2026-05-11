# VM resource definitions for the Talos K8s cluster.
#
# These are placeholders — fill in real values after running `terraform import`
# on each existing VM (see README.md for the procedure). Don't apply until each
# resource block matches what's actually on the Proxmox host, or Terraform will
# try to "fix" the live VM by replacing settings.
#
# Recommended import workflow:
#   1. terraform plan against an empty resource → shows "would create"
#   2. terraform import proxmox_virtual_environment_vm.<name> <node>/<vmid>
#   3. terraform plan again → should now show only diff between live state
#      and the resource block. Update block until plan is empty.
#   4. Repeat for each VM.

# Example skeleton — uncomment and adapt after import:
#
# resource "proxmox_virtual_environment_vm" "pik" {
#   name      = "pik-q76"
#   node_name = var.pve_node_primary
#   vm_id     = 165
#   on_boot   = true
#
#   cpu {
#     cores = 4
#     type  = "host"
#   }
#   memory {
#     dedicated = 8192
#   }
#   disk {
#     datastore_id = "local-lvm"  # adjust to your storage
#     interface    = "scsi0"
#     size         = 80
#   }
#   network_device {
#     bridge = "vmbr0"
#     model  = "virtio"
#   }
# }
