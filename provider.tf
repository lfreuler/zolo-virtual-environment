# ================================
# Moderner Proxmox Provider (bpg/proxmox)
# ================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.78.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.1.36:8006/"  # DEINE PROXMOX IP
  username = "root@pam"
  password = "070576"  # DEIN PASSWORT
  insecure = true
}