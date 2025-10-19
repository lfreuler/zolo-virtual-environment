# ================================
# Windows - SUPER EINFACH
# ================================

variable "node_name" {
  default = "pve"
}

# ================================
# WINDOWS TEMPLATE - MINIMAL
# ================================
resource "proxmox_virtual_environment_vm" "win_template" {
  name      = "win-template"
  node_name = var.node_name
  vm_id     = 9002
  
  cpu {
    cores = 2
  }
  
  memory {
    dedicated = 4096
  }
  
  # Eine Disk
  disk {
    datastore_id = "local-lvm"
    interface    = "ide0"
    size         = 60
  }
  
  # Windows ISO
  cdrom {
    file_id = "local:iso/windows-server.iso"
  }
  
  # Network
  network_device {
    bridge = "vmbr0"
  }
  
  # QEMU Guest Agent für Automation
  agent {
    enabled = true
  }
  
  # Fertig
  started = true
}

# ================================
# WINDOWS VMs mit Post-Install Scripts
# ================================
resource "proxmox_virtual_environment_vm" "win_vms" {
  count = 1
  
  name      = "win-vm-${count.index + 1}"
  node_name = var.node_name
  vm_id     = 300 + count.index
  
  clone {
    vm_id = 9002
    full  = true
  }
  
  cpu {
    cores = 4
  }
  
  memory {
    dedicated = 8192
  }
  
  disk {
    datastore_id = "local-lvm"
    interface    = "ide0"
    size         = 100
  }
  
  network_device {
    bridge = "vmbr0"
  }
  
  # QEMU Guest Agent aktivieren (WICHTIG!)
  agent {
    enabled = true
  }
  
  started = true
  
  depends_on = [proxmox_virtual_environment_vm.win_template]
  
  # Post-Install Automation via PowerShell
  provisioner "local-exec" {
    command = <<-EOF
      # Warten bis VM gebootet ist
      sleep 60
      
      # PowerShell Commands via Guest Agent
      ssh root@${var.proxmox_host} << 'REMOTE'
        # IIS installieren
        qm guest exec ${300 + count.index} -- powershell.exe "Install-WindowsFeature -Name Web-Server -IncludeManagementTools"
        
        # Firewall Regel
        qm guest exec ${300 + count.index} -- powershell.exe "New-NetFirewallRule -DisplayName 'Allow HTTP' -Direction Inbound -Protocol TCP -LocalPort 80"
        
        # Benutzer erstellen
        qm guest exec ${300 + count.index} -- powershell.exe "New-LocalUser -Name 'webadmin' -Password (ConvertTo-SecureString 'SecurePass123!' -AsPlainText -Force)"
        
        # Windows Updates
        qm guest exec ${300 + count.index} -- powershell.exe "Install-Module PSWindowsUpdate -Force; Get-WUInstall -AcceptAll -AutoReboot"
REMOTE
    EOF
  }
}

# ================================
# Proxmox Host Variable hinzufügen
# ================================
variable "proxmox_host" {
  description = "Proxmox Host IP"
  type        = string
  default     = "192.168.1.10"  # DEINE PROXMOX IP
}

# ================================
# Info
# ================================
output "info" {
  value = "1. Windows installieren 2. qm template 9002 3. terraform apply"
}