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

# K8s control plane on pve226: Talos hostname talos-mru-smr, IP 192.168.8.227
resource "proxmox_virtual_environment_vm" "k8s_control_plane" {
  provider  = proxmox.pve2
  node_name = var.pve2_node_name
  vm_id     = 100
  name      = "talos-cp-pve226-01"

  bios          = "seabios"
  boot_order    = ["scsi0", "ide2", "net0"]
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true
  started       = true

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

# K8s worker on pve226: Talos hostname talos-gcx-zwd, IP 192.168.8.125
# Has the dedicated Longhorn disk (scsi1, 128GB).
resource "proxmox_virtual_environment_vm" "k8s_worker_gcx" {
  provider  = proxmox.pve2
  node_name = var.pve2_node_name
  vm_id     = 101
  name      = "talos-worker-pve226-01"

  bios          = "seabios"
  boot_order    = ["scsi0", "ide2", "net0"]
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true
  started       = true

  agent {
    type    = "virtio"
    enabled = true
  }
  cpu {
    cores   = 3
    sockets = 1
    type    = "host"
  }
  # The EQ14 host has only ~15.4 GiB physical RAM. The previous 16384 MiB,
  # plus 4096 MiB for the control-plane VM on the same host, over-committed
  # the box by ~33% and only "fit" because the host silently ballooned this
  # guest down (runtime was ~10.7 GiB, never the configured 16). Set to a
  # value that actually fits: 10240 + cp's 4096 = 14336 MiB, leaving ~1.4 GiB
  # for the hypervisor. Longhorn instance-manager (~5.8 GiB) still leaves
  # ~4.4 GiB for prometheus/postgres/the rest — honest, no overcommit.
  memory {
    dedicated = 10240
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

# K8s worker on pve191: Talos hostname talos-worker-pve191-01.
# Has the dedicated Longhorn disk (scsi1, 128GB) and uses the
# Longhorn-capable Talos schematic.
resource "proxmox_virtual_environment_vm" "k8s_worker_pve191" {
  provider  = proxmox.pve1
  node_name = var.pve1_node_name
  vm_id     = 101
  name      = "talos-worker-pve191-01"

  bios            = "seabios"
  boot_order      = ["scsi0", "net0"] # Boot installed Talos from disk; install is long done
  scsi_hardware   = "virtio-scsi-single"
  on_boot         = true
  started         = true
  keyboard_layout = "en-us"

  agent {
    enabled = true
    type    = "virtio"
  }
  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }
  # pve1 had ~3.6 GiB physical RAM sitting idle while this worker ran pinned
  # at its 8000 MiB ceiling. Raise to 10240 MiB (apollo1's 4096 + 10240 =
  # 14336, ~1.4 GiB hypervisor headroom) to match the pve2 worker.
  memory {
    dedicated = 10240
  }
  network_device {
    bridge      = "vmbr0"
    firewall    = true
    mac_address = "BC:24:11:AA:F7:3B"
    model       = "virtio"
  }
  # OS disk
  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    iothread     = true
    size         = 32
  }
  # Longhorn data disk (mounted at /var/mnt/longhorn by Talos disk config)
  disk {
    interface    = "scsi1"
    datastore_id = "local-lvm"
    file_format  = "raw"
    iothread     = true
    size         = 128
  }
  # Empty CDROM drive. The Talos installer ISO that used to live here is
  # removed (install is long done). bpg defaults an undeclared cdrom to a
  # physical host passthrough (ide3=cdrom), which fails to start on a host
  # with no optical drive — so pin an explicitly empty drive instead.
  cdrom {
    file_id   = "none"
    interface = "ide3"
  }
  operating_system {
    type = "l26"
  }
}
