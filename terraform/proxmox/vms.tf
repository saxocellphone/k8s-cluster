# VMs across both Proxmox hosts. Each block sets `provider = proxmox.<alias>`
# explicitly so Terraform knows which host to talk to.
#
# Discovered via API + imported into state. To make changes, edit here and
# run `terraform plan` / `terraform apply`.

# ---------- pve1 (192.168.8.191) ----------

# apollo1 — non-K8s workload (no Talos guest agent detected)
resource "proxmox_virtual_environment_vm" "apollo1" {
  provider  = proxmox.pve1
  node_name = var.pve1_node_name
  vm_id     = 100
  name      = "apollo1"

  bios          = "seabios"
  boot_order    = ["scsi0", "ide2", "net0"]
  scsi_hardware = "virtio-scsi-single"
  on_boot       = false

  cpu {
    cores   = 2
    sockets = 1
    type    = "x86-64-v2-AES"
  }
  memory {
    dedicated = 4096
  }
  network_device {
    bridge      = "vmbr0"
    firewall    = true
    mac_address = "BC:24:11:E2:C5:33"
    model       = "virtio"
  }
  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    iothread     = true
    size         = 32
  }
  disk {
    interface    = "scsi1"
    datastore_id = "local-lvm"
    file_format  = "raw"
    iothread     = true
    size         = 128
  }
  operating_system {
    type = "l26"
  }
}

# ---------- pve2 (192.168.8.226) ----------

# K8s control plane: Talos hostname talos-mru-smr, IP 192.168.8.227
resource "proxmox_virtual_environment_vm" "k8s_control_plane" {
  provider  = proxmox.pve2
  node_name = var.pve2_node_name
  vm_id     = 100
  name      = "talos2"

  bios          = "seabios"
  boot_order    = ["scsi0", "ide2", "net0"]
  scsi_hardware = "virtio-scsi-single"
  on_boot       = false

  agent {
    type    = "virtio"
    enabled = true
  }
  cpu {
    cores   = 1
    sockets = 1
    type    = "x86-64-v2-AES"
  }
  memory {
    dedicated = 4096
  }
  network_device {
    bridge      = "vmbr0"
    firewall    = true
    mac_address = "BC:24:11:BC:80:85"
    model       = "virtio"
  }
  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    iothread     = true
    size         = 32
  }
  operating_system {
    type = "l26"
  }
}

# K8s worker: Talos hostname talos-gcx-zwd, IP 192.168.8.126
# Has the dedicated Longhorn disk (scsi1, 128GB).
resource "proxmox_virtual_environment_vm" "k8s_worker_gcx" {
  provider  = proxmox.pve2
  node_name = var.pve2_node_name
  vm_id     = 101
  name      = "zeus1"

  bios          = "seabios"
  boot_order    = ["scsi0", "ide2", "net0"]
  scsi_hardware = "virtio-scsi-single"
  on_boot       = false

  agent {
    type    = "virtio"
    enabled = true
  }
  cpu {
    cores   = 3
    sockets = 1
    type    = "host"
  }
  memory {
    dedicated = 12000
  }
  network_device {
    bridge      = "vmbr0"
    firewall    = true
    mac_address = "BC:24:11:F7:2C:CB"
    model       = "virtio"
  }
  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    iothread     = true
    size         = 32
  }
  disk {
    interface    = "scsi1"
    datastore_id = "local-lvm"
    file_format  = "raw"
    iothread     = true
    size         = 128
  }
  operating_system {
    type = "l26"
  }
}
