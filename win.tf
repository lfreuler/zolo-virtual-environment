variable "node_name"   { default = "pve" }
variable "vm_id"       { default = 100 }
variable "vm_hostname" { default = "WIN-SERVER-01" }

resource "proxmox_virtual_environment_vm" "windows_server" {
  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.vm_hostname
  started   = true

  # CPU + RAM
  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  # Disk
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 100
    file_format  = "raw"
  }

  # Netzwerk
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Windows-ISO (bereits mit autounattend.xml integriert)
  cdrom {
    file_id   = "local:iso/WIN2022-unattend.iso"
    interface = "ide2"
  }

  # Boot-Reihenfolge
  boot_order    = ["ide2", "scsi0"]
  scsi_hardware = "virtio-scsi-single"

  vga {
    type = "std"
  }

  agent {
    enabled = false
  }
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.windows_server.name
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.windows_server.vm_id
}