# Windows Server 2022 Unattended Installation Guide

**Vollautomatische Installation auf Proxmox VE**

---

## 📋 Voraussetzungen

### Windows (für ISO Build)
- Windows Server 2022 Evaluation ISO
- Windows ADK (Assessment and Deployment Kit)
  - Download: https://go.microsoft.com/fwlink/?linkid=2243390
  - Installiere nur: **Deployment Tools**
- PowerShell (als Administrator)

### Proxmox
- Proxmox VE 7.x oder 8.x
- Storage: `local-lvm` (oder anpassen)
- Netzwerk: `vmbr0`

---

## 📁 Verzeichnisstruktur (Windows)

```
E:\
├── ISO\
│   ├── Win2022_EVAL.iso          # Original ISO
│   ├── Extract\                   # Temp (wird erstellt)
│   └── WIN2022-unattend.iso      # Output
├── WIMWORK\                       # Temp (wird erstellt)
└── CODE\
    └── zolo-virtual-environment\
        └── Autounattend.xml       # Deine Config
```

---

## 🔧 1. XML Konfiguration erstellen

### **Variante A: BIOS (empfohlen - einfacher)**

**Datei:** `E:\CODE\zolo-virtual-environment\Autounattend.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">

  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

    <component name="Microsoft-Windows-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">

      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Type>Primary</Type>
              <Extend>true</Extend>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add">
              <Order>1</Order>
              <PartitionID>1</PartitionID>
              <Format>NTFS</Format>
              <Label>Windows</Label>
              <Letter>C</Letter>
              <Active>true</Active>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
        <WillShowUI>OnError</WillShowUI>
      </DiskConfiguration>

      <ImageInstall>
        <OSImage>
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/INDEX</Key>
              <Value>2</Value>
            </MetaData>
          </InstallFrom>
          <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>1</PartitionID>
          </InstallTo>
        </OSImage>
      </ImageInstall>

      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>Administrator</FullName>
        <Organization>MyCompany</Organization>
      </UserData>

    </component>
  </settings>

  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <ComputerName>WIN2022</ComputerName>
      <RegisteredOwner>Administrator</RegisteredOwner>
      <TimeZone>W. Europe Standard Time</TimeZone>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <AdministratorPassword>
          <Value>UABAAHMAcwB3ADAAcgBkACEA</Value>
          <PlainText>false</PlainText>
        </AdministratorPassword>
      </UserAccounts>
    </component>
  </settings>

</unattend>
```

**Anpassungen:**
- `<ComputerName>`: Hostname ändern
- `<Value>UABAAHMAcwB3ADAAcgBkACEA</Value>`: Base64 für `P@ssw0rd!`
- `<Value>2</Value>`: IMAGE/INDEX (1=Datacenter, 2=Standard)

---

### **Variante B: UEFI/GPT (modern)**

Falls du UEFI statt BIOS willst, verwende diese Disk-Config:

```xml
<DiskConfiguration>
  <Disk wcm:action="add">
    <DiskID>0</DiskID>
    <WillWipeDisk>true</WillWipeDisk>
    <CreatePartitions>
      <!-- EFI System Partition -->
      <CreatePartition wcm:action="add">
        <Order>1</Order>
        <Type>EFI</Type>
        <Size>100</Size>
      </CreatePartition>
      <!-- MSR Partition -->
      <CreatePartition wcm:action="add">
        <Order>2</Order>
        <Type>MSR</Type>
        <Size>16</Size>
      </CreatePartition>
      <!-- Windows Partition -->
      <CreatePartition wcm:action="add">
        <Order>3</Order>
        <Type>Primary</Type>
        <Extend>true</Extend>
      </CreatePartition>
    </CreatePartitions>
    <ModifyPartitions>
      <ModifyPartition wcm:action="add">
        <Order>1</Order>
        <PartitionID>1</PartitionID>
        <Format>FAT32</Format>
        <Label>System</Label>
      </ModifyPartition>
      <ModifyPartition wcm:action="add">
        <Order>2</Order>
        <PartitionID>2</PartitionID>
      </ModifyPartition>
      <ModifyPartition wcm:action="add">
        <Order>3</Order>
        <PartitionID>3</PartitionID>
        <Format>NTFS</Format>
        <Label>Windows</Label>
        <Letter>C</Letter>
      </ModifyPartition>
    </ModifyPartitions>
  </Disk>
  <WillShowUI>OnError</WillShowUI>
</DiskConfiguration>

<ImageInstall>
  <OSImage>
    <InstallFrom>
      <MetaData wcm:action="add">
        <Key>/IMAGE/INDEX</Key>
        <Value>2</Value>
      </MetaData>
    </InstallFrom>
    <InstallTo>
      <DiskID>0</DiskID>
      <PartitionID>3</PartitionID>  <!-- Achtung: Partition 3! -->
    </InstallTo>
  </OSImage>
</ImageInstall>
```

---

## 🔨 2. ISO Build Script

**Datei:** `E:\CODE\build-unattend-iso.ps1`

```powershell
# ================================================
# Windows Server 2022 Unattended ISO Builder
# ================================================

# Configuration
$iso = "E:\ISO\Win2022_EVAL.iso"
$extract = "E:\ISO\Extract"
$xml = "E:\CODE\zolo-virtual-environment\Autounattend.xml"
$mount = "E:\WIMWORK"
$output = "E:\ISO\WIN2022-unattend.iso"
$oscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Windows Server 2022 Unattended ISO Builder" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Extract ISO
Write-Host "[1/6] Extracting ISO..." -ForegroundColor Yellow
if (Test-Path $extract) { 
    Remove-Item $extract -Recurse -Force 
}
New-Item -ItemType Directory -Path $extract | Out-Null

$drive = (Mount-DiskImage $iso -PassThru | Get-Volume).DriveLetter + ":"
Write-Host "      Mounted at $drive" -ForegroundColor Gray
robocopy $drive $extract /E /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
Dismount-DiskImage $iso | Out-Null
attrib -R "$extract\*.*" /S /D
Write-Host "      ✅ Extracted" -ForegroundColor Green

# Step 2: Validate XML
Write-Host "[2/6] Validating XML..." -ForegroundColor Yellow
$null = dism /Online /Apply-Unattend:"$xml" 2>&1
if ($LASTEXITCODE -ne 0) { 
    Write-Host "      ❌ XML validation failed!" -ForegroundColor Red
    Write-Host "      Run manually: dism /Online /Apply-Unattend:`"$xml`"" -ForegroundColor Gray
    exit 1 
}
Write-Host "      ✅ Valid" -ForegroundColor Green

# Step 3: Mount boot.wim
Write-Host "[3/6] Mounting boot.wim..." -ForegroundColor Yellow
if (Test-Path $mount) { 
    dism /Unmount-Wim /MountDir:"$mount" /Discard 2>&1 | Out-Null
    Remove-Item $mount -Recurse -Force 
}
New-Item -ItemType Directory -Path $mount | Out-Null
$null = dism /Mount-Wim /WimFile:"$extract\sources\boot.wim" /Index:2 /MountDir:"$mount" 2>&1
Write-Host "      ✅ Mounted" -ForegroundColor Green

# Step 4: Inject XML
Write-Host "[4/6] Injecting Autounattend.xml..." -ForegroundColor Yellow
Copy-Item $xml "$mount\" -Force
Copy-Item $xml "$mount\Windows\System32\" -Force
Write-Host "      ✅ Injected" -ForegroundColor Green

# Step 5: Commit boot.wim
Write-Host "[5/6] Committing boot.wim..." -ForegroundColor Yellow
$null = dism /Unmount-Wim /MountDir:"$mount" /Commit 2>&1
Write-Host "      ✅ Committed" -ForegroundColor Green

# Step 6: Build ISO
Write-Host "[6/6] Building bootable ISO..." -ForegroundColor Yellow
if (Test-Path $output) { Remove-Item $output -Force }

if (!(Test-Path $oscdimg)) {
    Write-Host "      ❌ oscdimg.exe not found!" -ForegroundColor Red
    Write-Host "      Install Windows ADK from:" -ForegroundColor Gray
    Write-Host "      https://go.microsoft.com/fwlink/?linkid=2243390" -ForegroundColor Gray
    exit 1
}

$null = & $oscdimg -m -o -u2 -udfver102 `
    -bootdata:2#p0,e,b"$extract\boot\etfsboot.com"#pEF,e,b"$extract\efi\microsoft\boot\efisys.bin" `
    -lWIN2022 $extract $output 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "      ✅ Built" -ForegroundColor Green
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "              ✅ SUCCESS!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📀 ISO File: " -NoNewline; Write-Host "$output" -ForegroundColor Cyan
    Write-Host "🔐 Password: " -NoNewline; Write-Host "P@ssw0rd!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Upload to Proxmox:" -ForegroundColor Gray
    Write-Host "   scp `"$output`" root@YOUR-PROXMOX:/var/lib/vz/template/iso/" -ForegroundColor White
    Write-Host "2. Run VM creation script on Proxmox" -ForegroundColor Gray
} else {
    Write-Host "      ❌ Build failed!" -ForegroundColor Red
    exit 1
}
```

**Ausführen:**
```powershell
cd E:\CODE
.\build-unattend-iso.ps1
```

---

## 🚀 3. VM auf Proxmox erstellen

**Datei:** `/root/create-win2022-vm.sh`

```bash
#!/bin/bash
# ================================================
# Windows Server 2022 Unattended VM Creator
# ================================================

VMID=999
VMNAME="win2022-unattend"
STORAGE="local-lvm"
ISO="local:iso/WIN2022-unattend.iso"
DISKSIZE=64

echo "============================================"
echo " Creating Windows Server 2022 VM"
echo "============================================"
echo ""

# Cleanup
echo "[1/3] Cleaning up old VM..."
qm stop $VMID --skiplock 2>/dev/null || true
qm destroy $VMID --purge 2>/dev/null || true
echo "      ✅ Cleaned"

# Create VM
echo "[2/3] Creating VM..."
qm create $VMID \
  --name $VMNAME \
  --memory 8192 \
  --cores 4 \
  --cpu host \
  --machine pc-i440fx-8.1 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --vga std \
  --agent 0 \
  --bios seabios

# CRITICAL: Use SATA not SCSI (no VirtIO drivers in setup!)
qm set $VMID --sata0 ${STORAGE}:${DISKSIZE}
qm set $VMID --ide2 $ISO,media=cdrom

# Boot order
qm set $VMID --boot "order=ide2;sata0"
echo "      ✅ Created"

# Start
echo "[3/3] Starting VM..."
qm start $VMID
echo "      ✅ Started"

echo ""
echo "============================================"
echo "              ✅ SUCCESS!"
echo "============================================"
echo ""
echo "VM ID:       $VMID"
echo "Console:     qm terminal $VMID"
echo "Password:    P@ssw0rd!"
echo "Installation will start automatically..."
```

**Ausführen:**
```bash
chmod +x /root/create-win2022-vm.sh
/root/create-win2022-vm.sh
```

---

## 📝 4. Schritt-für-Schritt

### **Auf Windows:**

1. **XML erstellen/anpassen**
   ```powershell
   notepad E:\CODE\zolo-virtual-environment\Autounattend.xml
   ```

2. **ISO Build Script ausführen**
   ```powershell
   cd E:\CODE
   .\build-unattend-iso.ps1
   ```

3. **ISO zu Proxmox hochladen**
   ```powershell
   scp "E:\ISO\WIN2022-unattend.iso" root@192.168.1.100:/var/lib/vz/template/iso/
   ```

### **Auf Proxmox:**

4. **VM Script erstellen**
   ```bash
   nano /root/create-win2022-vm.sh
   # [Script einfügen]
   chmod +x /root/create-win2022-vm.sh
   ```

5. **VM erstellen und starten**
   ```bash
   /root/create-win2022-vm.sh
   ```

6. **Installation beobachten**
   ```bash
   qm terminal 999
   # oder Proxmox Web-GUI → VM 999 → Console
   ```

---

## 🔍 Troubleshooting

### ❌ "Could not apply DiskConfiguration"
**Ursache:** Partition-Mismatch (erstellt 2, installiert auf 3)  
**Lösung:** Prüfe XML - `CreatePartitions` Count muss mit `InstallTo/PartitionID` übereinstimmen

### ❌ "Boot failed: Could not read from CDROM"
**Ursache:** ISO nicht bootbar  
**Lösung:** oscdimg braucht `-bootdata` Parameter (im Script enthalten)

### ❌ "Error 0x8007000D"
**Ursache:** install.wim >4GB, ISO9660 zu klein  
**Lösung:** `-u2 -udfver102` verwenden (im Script enthalten)

### ❌ "Disk not found"
**Ursache:** VirtIO SCSI braucht Treiber  
**Lösung:** `--sata0` statt `--scsi0` verwenden (im Script enthalten)

---

## 🎯 Advanced: Passwort ändern

**Plaintext (unsicher):**
```xml
<AdministratorPassword>
  <Value>MyNewPassword!</Value>
  <PlainText>true</PlainText>
</AdministratorPassword>
```

**Base64 (sicher):**
```powershell
# Passwort encodieren:
$password = "MyNewPassword!"
$bytes = [System.Text.Encoding]::Unicode.GetBytes($password + "AdministratorPassword")
$encoded = [Convert]::ToBase64String($bytes)
Write-Host $encoded
```

Dann im XML:
```xml
<AdministratorPassword>
  <Value>DEIN_BASE64_HIER</Value>
  <PlainText>false</PlainText>
</AdministratorPassword>
```

---

## 📊 Vergleich BIOS vs UEFI

| Feature | BIOS | UEFI |
|---------|------|------|
| **Partitionen** | 1 Primary | EFI + MSR + Primary |
| **Boot** | MBR | GPT |
| **Komplexität** | ⭐ Einfach | ⭐⭐⭐ Komplex |
| **VM Typ** | `--bios seabios` | `--bios ovmf --efidisk0` |
| **Empfohlung** | ✅ Für Tests | Für Production |

---

## ✅ Checkliste

- [ ] Windows ADK installiert
- [ ] Original ISO vorhanden
- [ ] XML angepasst (Computername, Passwort)
- [ ] XML validiert mit DISM
- [ ] ISO gebaut (ohne Fehler)
- [ ] ISO auf Proxmox hochgeladen
- [ ] VM Script angepasst (VMID, Storage, Bridge)
- [ ] VM gestartet
- [ ] Installation läuft automatisch durch
- [ ] Login mit `P@ssw0rd!` funktioniert

---

## 🎓 Credits

- **Disk Config Fix:** Partition Count = InstallTo PartitionID
- **Boot Fix:** oscdimg `-bootdata` Parameter
- **Large File Fix:** UDF statt ISO9660
- **Driver Fix:** SATA statt VirtIO SCSI

---

**Viel Erfolg! 🚀**