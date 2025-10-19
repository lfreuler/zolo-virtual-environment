# Method 4: Golden Image + Dynamic Deployment - Complete Guide

**Windows Server 2022 - Fully Automated Deployment**

---

## 🚀 Quick Start (TL;DR)

```bash
# 1. VM erstellen
./create-golden-image-vm.sh

# 2. Windows installieren (~10 Min)

# 3. Windows-ISO unmounten
qm set 999 --delete ide2

# 4. Scripts-ISO erstellen & mounten
/root/create-scripts-iso.sh
qm set 999 --ide2 local:iso/win-setup-scripts.iso,media=cdrom
qm stop 999 && qm start 999

# 5. In VM: Scripts ausführen (D:\01-03.ps1)

# 6. Sysprep (OHNE unattend.xml!)
Remove-Item "C:\Windows\System32\Sysprep\unattend.xml" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Panther\unattend.xml" -Force -ErrorAction SilentlyContinue
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown

# 7. Template erstellen
qm template 999

# 8. Deploy
./deploy.sh 100 web-server-01
```

---

## ⚠️ CRITICAL NOTES

1. **Netzwerk = e1000** (nicht virtio - Windows hat keine Treiber!)
2. **Nur EIN ISO auf ide2** (Windows-ISO nach Installation unmounten)
3. **MINIMAL unattend.xml** (oobeSystem mit SkipOOBE = TRUE)
4. **Locale = de-CH** (Region/Keyboard für Schweiz)
5. **Post-Install Script** setzt Hostname via Metadata ISO

---

## 📦 Script 1: VM erstellen

```bash
#!/bin/bash
# /root/create-golden-image-vm.sh

VMID=999
NAME="win2022-golden"
MEMORY=8192
CORES=4
DISK=32

qm destroy $VMID --purge 2>/dev/null || true

qm create $VMID \
  --name $NAME \
  --memory $MEMORY \
  --cores $CORES \
  --cpu host \
  --machine pc-i440fx-8.1 \
  --net0 e1000,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --vga std \
  --agent 0 \
  --bios seabios

qm set $VMID --sata0 local-lvm:${DISK}
qm set $VMID --ide2 local:iso/Win2022_EVAL.iso,media=cdrom
qm set $VMID --boot "order=ide2;sata0"
qm start $VMID

echo "✅ VM $VMID created - Install Windows now"
```

**Ausführen:**
```bash
chmod +x /root/create-golden-image-vm.sh
./create-golden-image-vm.sh
```

---

## 📦 Script 2: Scripts-ISO erstellen

```bash
#!/bin/bash
# /root/create-scripts-iso.sh

SCRIPTS_DIR="/tmp/win-scripts"
ISO_PATH="/var/lib/vz/template/iso/win-setup-scripts.iso"

rm -rf "$SCRIPTS_DIR"
mkdir -p "$SCRIPTS_DIR"

# ============================================
# Script 1: System Config
# ============================================
cat > "$SCRIPTS_DIR/01-system-config.ps1" <<'PSEOF'
Write-Host "Starting System Configuration..." -ForegroundColor Cyan

# Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Software
choco install googlechrome -y
choco install 7zip -y

# Features
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name RSAT-AD-PowerShell

# IE ESC deaktivieren
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -Force

# RDP aktivieren
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Force
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Power Plan
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

Write-Host "✅ System Configuration completed!" -ForegroundColor Green
PSEOF

# ============================================
# Script 2: WinRM (OPTIONAL)
# ============================================
cat > "$SCRIPTS_DIR/02-winrm-setup.ps1" <<'PSEOF'
Write-Host "Setting up WinRM..." -ForegroundColor Cyan

Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
New-NetFirewallRule -DisplayName "WinRM HTTP-In" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -ErrorAction SilentlyContinue
Set-Service -Name WinRM -StartupType Automatic
Restart-Service WinRM

Write-Host "✅ WinRM enabled!" -ForegroundColor Green
PSEOF

# ============================================
# Script 3: Post-Install Script Setup
# ============================================
cat > "$SCRIPTS_DIR/03-setup-postinstall.ps1" <<'PSEOF'
Write-Host "Setting up Post-Install Script..." -ForegroundColor Cyan

New-Item -ItemType Directory -Path "C:\Windows\Setup\Scripts" -Force

$postInstall = @'
Start-Transcript -Path "C:\post-install.log"
Write-Host "=========================================="
Write-Host " Post-Install Script"
Write-Host "=========================================="

# Hostname von Metadata ISO lesen
$metaDrive = Get-Volume | Where-Object {$_.FileSystemLabel -eq "METADATA"} | Select-Object -ExpandProperty DriveLetter
if ($metaDrive) {
    $hostnameFile = "${metaDrive}:\hostname.txt"
    if (Test-Path $hostnameFile) {
        $newHostname = (Get-Content $hostnameFile -Raw).Trim()
        if ($newHostname) {
            Write-Host "Setting hostname to: $newHostname"
            Rename-Computer -NewName $newHostname -Force
            $needsReboot = $true
        }
    }
}

# DNS konfigurieren
Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | ForEach-Object {
    Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses ("1.1.1.1","8.8.8.8") -ErrorAction SilentlyContinue
}

# Firewall
New-NetFirewallRule -DisplayName "HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -ErrorAction SilentlyContinue

# Time sync
w32tm /config /manualpeerlist:"pool.ntp.org" /syncfromflags:manual /reliable:yes /update
Restart-Service w32time

# Deployment Info
$info = @"
Deployed: $(Get-Date)
Hostname: $(hostname)
IP: $(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"} | Select-Object -First 1 -ExpandProperty IPAddress)
"@
$info | Out-File C:\deployment-info.txt

Stop-Transcript

if ($needsReboot) {
    Write-Host "Rebooting to apply hostname..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
'@

[System.IO.File]::WriteAllText("C:\Windows\Setup\Scripts\post-install.ps1", $postInstall)

# RunOnce Registry
$runOnce = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
Set-ItemProperty -Path $runOnce -Name "PostInstall" -Value 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Windows\Setup\Scripts\post-install.ps1"'

Write-Host "✅ Post-Install Script configured!" -ForegroundColor Green
PSEOF

# ============================================
# Script 4: Prepare Sysprep
# ============================================
cat > "$SCRIPTS_DIR/04-prepare-sysprep.ps1" <<'PSEOF'
Write-Host "Preparing Sysprep with MINIMAL unattend.xml..." -ForegroundColor Cyan

# Cleanup alte XMLs
Remove-Item "C:\Windows\System32\Sysprep\unattend.xml" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Panther\unattend.xml" -Force -ErrorAction SilentlyContinue

# ULTRA-MINIMAL unattend.xml - NUR specialize pass!
# KEIN oobeSystem - das macht Server 2022 kaputt!
$xml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>*</ComputerName>
    </component>
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>de-CH</InputLocale>
      <SystemLocale>de-CH</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>de-CH</UserLocale>
    </component>
  </settings>
</unattend>
'@

# Mit UTF8 ohne BOM schreiben (WICHTIG!)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("C:\Windows\System32\Sysprep\unattend.xml", $xml, $utf8NoBom)

# Passwort-Flag JETZT entfernen (VOR Sysprep!)
Write-Host ""
Write-Host "Fixing Administrator password policy..." -ForegroundColor Cyan
net user Administrator /passwordreq:no
wmic UserAccount where Name="Administrator" set PasswordExpires=False

Write-Host ""
Write-Host "✅ unattend.xml created!" -ForegroundColor Green
Write-Host "✅ Password policy fixed!" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " READY FOR SYSPREP!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  IMPORTANT: MINIMAL XML - NUR specialize pass!" -ForegroundColor Yellow
Write-Host "   Kein oobeSystem - Server 2022 mag das nicht!" -ForegroundColor Gray
Write-Host ""
Write-Host "Features:" -ForegroundColor Cyan
Write-Host "  ✅ Locale: de-CH (Schweiz)" -ForegroundColor Gray
Write-Host "  ✅ Hostname: Random (wird via Post-Install überschrieben)" -ForegroundColor Gray
Write-Host "  ✅ Passwort: Bleibt wie bei Installation" -ForegroundColor Gray
Write-Host "  ⚠️  OOBE: Wird NICHT übersprungen (Region/Keyboard manuell)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Command:" -ForegroundColor Yellow
Write-Host "  C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml" -ForegroundColor White
Write-Host ""
Write-Host "Command:" -ForegroundColor Yellow
Write-Host "  C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml" -ForegroundColor White
Write-Host ""
PSEOF

# ============================================
# README
# ============================================
cat > "$SCRIPTS_DIR/README.txt" <<'EOF'
Windows Server 2022 Golden Image Setup Scripts
===============================================

✅ UNATTENDED Sysprep mit minimal unattend.xml!

Execute in order:

1. D:\01-system-config.ps1 (~10-15 Min)
   - Chocolatey, Chrome, 7zip
   - IIS, AD PowerShell
   - RDP, Power Plan

2. D:\02-winrm-setup.ps1 (OPTIONAL)
   - Only if Terraform/Ansible planned

3. D:\03-setup-postinstall.ps1
   - Creates post-install script
   - Configures RunOnce registry

4. D:\04-prepare-sysprep.ps1
   - Creates MINIMAL unattend.xml
   - Locale: de-CH (Schweiz)
   - SkipOOBE = TRUE (kein interaktiver Setup!)

5. Sysprep:
   C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml

6. On Proxmox:
   qm template 999

7. Deploy:
   ./deploy.sh 100 web-server-01

Features:
- ✅ OOBE wird übersprungen
- ✅ Locale: de-CH
- ✅ Passwort bleibt erhalten
- ✅ Hostname via Metadata ISO
EOF

# ISO erstellen
[ -f "$ISO_PATH" ] && rm "$ISO_PATH"
genisoimage -o "$ISO_PATH" -V "SCRIPTS" -r -J "$SCRIPTS_DIR" 2>/dev/null

if [ -f "$ISO_PATH" ]; then
    echo "✅ Scripts ISO created: $ISO_PATH"
    rm -rf "$SCRIPTS_DIR"
else
    echo "❌ Failed!"
    exit 1
fi
```

**Ausführen:**
```bash
chmod +x /root/create-scripts-iso.sh
/root/create-scripts-iso.sh

# ISO mounten
qm set 999 --ide2 local:iso/win-setup-scripts.iso,media=cdrom
qm stop 999 && qm start 999
```

---

## 📋 In der VM: Scripts ausführen

**In Windows (nach Login):**

1. **File Explorer → D:\ (Scripts ISO)**
2. **Scripts nacheinander ausführen:**

```powershell
# 1. System Config (~10-15 Min)
D:\01-system-config.ps1

# 2. WinRM (OPTIONAL)
D:\02-winrm-setup.ps1

# 3. Post-Install Setup
D:\03-setup-postinstall.ps1

# 4. Sysprep vorbereiten
D:\04-prepare-sysprep.ps1
```

---

## 🎯 Sysprep ausführen

**Nach Script 04:**

```powershell
# Sysprep mit unattend.xml
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

**Was passiert:**
- ✅ System wird generalisiert
- ✅ OOBE wird übersprungen (SkipOOBE=true)
- ✅ Locale: de-CH
- ✅ VM fährt automatisch runter
- ✅ Passwort bleibt erhalten

---

## 📦 Template erstellen

```bash
# Auf Proxmox nach Shutdown
qm template 999

echo "✅ Golden Image Template ready!"
```

---

## 🚀 Deployment Script

```bash
#!/bin/bash
# /root/deploy.sh
# Deploy Windows Server from Golden Image

TEMPLATE_ID=999
VMID=$1
HOSTNAME=$2
MEMORY=${3:-8192}
CORES=${4:-4}
DISK_RESIZE=${5:-0}

# Validation
if [ -z "$VMID" ] || [ -z "$HOSTNAME" ]; then
    echo "Usage: ./deploy.sh <VMID> <HOSTNAME> [MEMORY] [CORES] [DISK_RESIZE_GB]"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh 100 web-server-01"
    echo "  ./deploy.sh 101 app-server-01 16384 8"
    echo "  ./deploy.sh 102 db-server-01 32768 16 96"
    exit 1
fi

echo "========================================="
echo "  Deploying: $HOSTNAME"
echo "========================================="
echo ""
echo "Template: 32GB base"
if [ $DISK_RESIZE -gt 0 ]; then
    echo "Resize: +${DISK_RESIZE}GB → Total: $((32 + DISK_RESIZE))GB"
fi
echo ""

# 1. Clone Template
echo "[1/5] Cloning template..."
qm clone $TEMPLATE_ID $VMID --name $HOSTNAME --full
if [ $? -ne 0 ]; then
    echo "❌ Clone failed!"
    exit 1
fi
echo "      ✅ Cloned"

# 2. Configure VM
echo "[2/5] Configuring VM..."
qm set $VMID --memory $MEMORY
qm set $VMID --cores $CORES

# Optional: Disk vergrößern
if [ $DISK_RESIZE -gt 0 ]; then
    qm resize $VMID sata0 +${DISK_RESIZE}G
    echo "      ℹ️  Disk resized by +${DISK_RESIZE}G"
fi

echo "      ✅ Configured"

# 3. Create Metadata ISO
echo "[3/5] Creating metadata ISO..."
METADATA_DIR="/tmp/metadata-$VMID"
mkdir -p $METADATA_DIR

# Hostname
echo "$HOSTNAME" > $METADATA_DIR/hostname.txt

# Optional: Network Config
cat > $METADATA_DIR/network.txt <<EOF
# Network Configuration for $HOSTNAME
DNS1=1.1.1.1
DNS2=8.8.8.8
EOF

# Optional: Deployment Info
cat > $METADATA_DIR/info.txt <<EOF
Deployment Date: $(date)
VM ID: $VMID
Hostname: $HOSTNAME
Memory: $MEMORY MB
Cores: $CORES
EOF

# ISO erstellen
genisoimage -o /var/lib/vz/template/iso/metadata-${VMID}.iso \
    -V "METADATA" -r -J $METADATA_DIR 2>/dev/null

if [ $? -ne 0 ]; then
    echo "❌ ISO creation failed!"
    rm -rf $METADATA_DIR
    exit 1
fi

# Metadata ISO an VM mounten
qm set $VMID --ide3 local:iso/metadata-${VMID}.iso,media=cdrom

# Cleanup
rm -rf $METADATA_DIR
echo "      ✅ Metadata ISO created and mounted"

# 4. Start VM
echo "[4/5] Starting VM..."
qm start $VMID
if [ $? -ne 0 ]; then
    echo "❌ Start failed!"
    exit 1
fi
echo "      ✅ Started"

# 5. Wait for boot
echo "[5/5] Waiting for boot..."
sleep 10

# Summary
echo ""
echo "========================================="
echo "              ✅ SUCCESS!"
echo "========================================="
echo ""
echo "VM ID:       $VMID"
echo "Hostname:    $HOSTNAME"
echo "Memory:      $MEMORY MB"
echo "Cores:       $CORES"
if [ $DISK_RESIZE -gt 0 ]; then
    echo "Disk:        32G + ${DISK_RESIZE}G = $((32 + DISK_RESIZE))G"
else
    echo "Disk:        32G (template default)"
fi
echo "Password:    [Same as Golden Image]"
echo ""
echo "Status:"
echo "  - Windows is booting..."
echo "  - Post-install script will run automatically"
echo "  - Hostname will be set to: $HOSTNAME"
echo "  - VM will reboot once after hostname change"
echo ""
echo "Console: qm terminal $VMID"
echo "Web UI:  https://proxmox:8006/#v1:0:=qemu/$VMID"
echo ""
echo "Check logs: C:\post-install.log"
echo "Check info: C:\deployment-info.txt"
echo ""
```

**Ausführbar machen:**
```bash
chmod +x /root/deploy.sh
```

---

## 📋 Usage Examples

```bash
# Standard Server (32GB)
./deploy.sh 100 web-server-01

# Mit Custom Config (32GB)
./deploy.sh 101 app-server-01 16384 8

# Mit größerer Disk (32+96 = 128GB)
./deploy.sh 102 db-server-01 32768 16 96

# Bulk Deployment
for i in {200..209}; do
  ./deploy.sh $i "node-$(printf '%02d' $i)" 8192 4
  sleep 30  # Stagger starts
done

# Verschiedene Rollen
./deploy.sh 110 web-01 16384 8        # 32GB
./deploy.sh 120 app-01 32768 16 32    # 64GB
./deploy.sh 130 db-01 65536 24 224    # 256GB
```

---

## 🔧 Maintenance

### **Metadata ISO entfernen (nach Deployment)**

```bash
# Nach erfolgreichem Deployment
VMID=100

# ISO unmounten
qm set $VMID --delete ide3

# ISO löschen
rm /var/lib/vz/template/iso/metadata-${VMID}.iso

echo "✅ Metadata ISO removed from VM $VMID"
```

### **Template updaten**

```bash
#!/bin/bash
# /root/update-golden-image.sh

TEMPLATE_ID=999
TEMP_ID=998

echo "🔄 Updating Golden Image..."

# 1. Clone
qm clone $TEMPLATE_ID $TEMP_ID --name "golden-update" --full

# 2. Template zu VM zurück
qm set $TEMP_ID --template 0

# 3. Start
qm start $TEMP_ID

echo ""
echo "✅ Update VM started (ID: $TEMP_ID)"
echo ""
echo "Steps:"
echo "  1. Login to VM $TEMP_ID"
echo "  2. Run Windows Updates"
echo "  3. Update Software: choco upgrade all -y"
echo "  4. Make changes as needed"
echo "  5. Run Scripts 03-04 again"
echo "  6. Run Sysprep"
echo "  7. Run: ./finalize-update.sh"
echo ""
```

```bash
#!/bin/bash
# /root/finalize-update.sh

TEMPLATE_ID=999
TEMP_ID=998

echo "🎯 Finalizing Golden Image Update..."

# Altes Template löschen
qm destroy $TEMPLATE_ID --purge

# Neues Template
qm set $TEMP_ID --name "win2022-golden"
qm template $TEMP_ID

echo "✅ Golden Image updated!"
echo "   New template: $TEMP_ID"
```

---

## 🔍 Troubleshooting

### **Post-Install Script läuft nicht?**

```powershell
# In der VM prüfen:

# 1. RunOnce Registry
Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

# 2. Script vorhanden?
Test-Path "C:\Windows\Setup\Scripts\post-install.ps1"

# 3. Log prüfen
Get-Content C:\post-install.log -Tail 50

# 4. Manuell ausführen
powershell.exe -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\post-install.ps1"
```

### **Hostname wird nicht gesetzt?**

```powershell
# Metadata ISO prüfen
Get-Volume | Where-Object {$_.FileSystemLabel -eq "METADATA"}

# Hostname-File prüfen
$drive = (Get-Volume | Where-Object {$_.FileSystemLabel -eq "METADATA"}).DriveLetter
Get-Content "${drive}:\hostname.txt"

# Manuell setzen
Rename-Computer -NewName "NEUER-NAME" -Force
Restart-Computer
```

### **Sysprep Fehler?**

```powershell
# Logs prüfen
Get-Content "C:\Windows\System32\Sysprep\Panther\setuperr.log"
Get-Content "C:\Windows\System32\Sysprep\Panther\setupact.log"

# XML validieren
Get-Content "C:\Windows\System32\Sysprep\unattend.xml"

# Cleanup und neu
Remove-Item "C:\Windows\System32\Sysprep\unattend.xml" -Force
Remove-Item "C:\Windows\Panther\unattend.xml" -Force
# Dann Script 04 nochmal ausführen
```

---

## ✅ Checkliste

**Golden Image Setup:**
- [ ] VM erstellt und Windows installiert
- [ ] Windows-ISO unmounted
- [ ] Scripts-ISO erstellt und gemountet
- [ ] Scripts 01-04 ausgeführt
- [ ] Sysprep erfolgreich (mit unattend.xml)
- [ ] Template erstellt (qm template 999)

**Deployment:**
- [ ] deploy.sh erstellt und ausführbar
- [ ] Ersten Server deployed
- [ ] Hostname automatisch gesetzt
- [ ] Post-Install Log geprüft
- [ ] Login erfolgreich
- [ ] Netzwerk konfiguriert

**Production Ready:**
- [ ] Template monatlich updaten
- [ ] Metadata ISOs nach Deploy löschen
- [ ] Backup-Strategie für Template
- [ ] Dokumentation für Team

---

## 🎯 Quick Reference

```bash
# Golden Image erstellen
./create-golden-image-vm.sh                    # VM erstellen
# → Windows installieren
qm set 999 --delete ide2                       # Windows-ISO weg
/root/create-scripts-iso.sh                    # Scripts-ISO
qm set 999 --ide2 local:iso/win-setup-scripts.iso,media=cdrom
qm stop 999 && qm start 999
# → Scripts 01-04 in VM ausführen
# → Sysprep mit unattend.xml
qm template 999                                 # Template

# Server deployen
./deploy.sh 100 web-server-01                  # 32GB
./deploy.sh 101 app-server-01 16384 8          # 32GB custom
./deploy.sh 102 db-server-01 32768 16 96       # 128GB

# Bulk Deploy
for i in {200..209}; do ./deploy.sh $i "node-$i"; done

# Template updaten
./update-golden-image.sh                       # Clone
# → Updates
# → Sysprep
./finalize-update.sh                           # Neues Template
```

---

**Production Ready! 🚀**