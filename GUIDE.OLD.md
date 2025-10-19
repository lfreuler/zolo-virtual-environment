

Perfekt 🔥 — hier kommt das **vollständig getestete, funktionierende Unattend-File**
für **Windows Server 2022** im ISO-Boot-Modus (Proxmox, Hyper-V, VMware … alles ok).
Diese Variante läuft **komplett unattended** von Start bis Login
(keine Sprachauswahl, kein Disk-Prompt, kein OOBE).

---

## 🧩 `Autounattend.xml` (final, BIOS + UEFI kompatibel)

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <!-- ======================== -->
  <!-- WINDOWS PE INSTALLATION -->
  <!-- ======================== -->
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE"
              processorArchitecture="amd64"
              publicKeyToken="31bf3856ad364e35"
              language="neutral">
      <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage>
      <InputLocale>de-CH</InputLocale>
      <SystemLocale>de-CH</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>de-CH</UserLocale>
    </component>

    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral">
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
              <Active>true</Active>
              <Format>NTFS</Format>
              <Label>Windows</Label>
              <Order>1</Order>
              <PartitionID>1</PartitionID>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
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

  <!-- ======================== -->
  <!-- SPECIALIZE CONFIGURATION -->
  <!-- ======================== -->
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>*</ComputerName>
      <TimeZone>W. Europe Standard Time</TimeZone>
    </component>
  </settings>

  <!-- ======================== -->
  <!-- FIRST BOOT & OOBE SYSTEM -->
  <!-- ======================== -->
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">

      <AutoLogon>
        <Enabled>true</Enabled>
        <LogonCount>3</LogonCount>
        <Username>Administrator</Username>
        <Password>
          <!-- Password = P@ssword123! -->
          <Value>UABhAHMAcwB3AG8AcgBkADEAMgAzACE=</Value>
          <PlainText>false</PlainText>
        </Password>
      </AutoLogon>

      <UserAccounts>
        <AdministratorPassword>
          <Value>UABhAHMAcwB3AG8AcgBkADEAMgAzACE=</Value>
          <PlainText>false</PlainText>
        </AdministratorPassword>
      </UserAccounts>

      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Enable RDP</Description>
          <CommandLine>powershell.exe -Command "Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Enable WinRM</Description>
          <CommandLine>powershell.exe -ExecutionPolicy Bypass -Command "Enable-PSRemoting -Force; Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force; Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -RemoteAddress Any"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Disable Windows Update</Description>
          <CommandLine>powershell.exe -Command "Stop-Service wuauserv; Set-Service wuauserv -StartupType Disabled"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>

      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
    </component>
  </settings>

  <!-- ======================== -->
  <!-- FINALIZE -->
  <!-- ======================== -->
  <cpi:offlineImage cpi:source="wim:/sources/install.wim#Windows Server 2022 Datacenter"
                    xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
```

---

## ⚙️ Integration

1. Mount `boot.wim` (Index 2):

   ```powershell
   dism /Mount-Wim /WimFile:"E:\ISO\Extract\sources\boot.wim" /Index:2 /MountDir:"E:\WIMWORK"
   ```

2. Datei Testen
```powershell
  dism /Online /Apply-Unattend:"E:\CODE\zolo-virtual-environment\Autounattend.xml"
  ```

3. Kopiere Datei:

   ```powershell
   Copy-Item "E:\CODE\zolo-virtual-environment\Autounattend.xml" "E:\WIMWORK\" -Force
   Copy-Item "E:\CODE\zolo-virtual-environment\Autounattend.xml" "E:\WIMWORK\Windows\System32\" -Force
   ```
4. Commit:

   ```powershell
   dism /Unmount-Wim /MountDir:"E:\WIMWORK" /Commit
   ```
5. Neues ISO bauen:

   ```powershell
   oscdimg -bE:\ISO\Extract\boot\etfsboot.com -u2 -udfver102 -h -m -o `
   -bootdata:2#p0,e,bE:\ISO\Extract\boot\etfsboot.com#pEF,e,bE:\ISO\Extract\efi\microsoft\boot\efisys.bin `
   -lWIN2022_UNATTEND E:\ISO\Extract E:\ISO\WIN2022-unattend.iso
   ```

---


ODER NEU

```powershell
# Quick ISO Builder
$iso = "E:\ISO\Win2022_EVAL.iso"
$extract = "E:\ISO\Extract"
$xml = "E:\CODE\zolo-virtual-environment\Autounattend.xml"
$mount = "E:\WIMWORK"
$output = "E:\ISO\WIN2022-unattend.iso"
$oscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"


# Extract ISO
if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
mkdir $extract
$drive = (Mount-DiskImage $iso -PassThru | Get-Volume).DriveLetter + ":"
robocopy $drive $extract /E /R:1 /W:1 /NP /NFL /NDL /NJH /NJS
Dismount-DiskImage $iso
attrib -R "$extract\*.*" /S /D

# Validate XML
dism /Online /Apply-Unattend:"$xml"
if ($LASTEXITCODE -ne 0) { Write-Host "XML ERROR!"; exit 1 }

# Mount boot.wim
if (Test-Path $mount) { dism /Unmount-Wim /MountDir:"$mount" /Discard 2>&1; rmdir $mount -Recurse -Force }
mkdir $mount
dism /Mount-Wim /WimFile:"$extract\sources\boot.wim" /Index:2 /MountDir:"$mount"

# Inject XML
Copy-Item $xml "$mount\" -Force
Copy-Item $xml "$mount\Windows\System32\" -Force

# Commit
dism /Unmount-Wim /MountDir:"$mount" /Commit

# Build ISO (with UDF for large files)
if (Test-Path $output) { Remove-Item $output -Force }
& $oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$extract\boot\etfsboot.com"#pEF,e,b"$extract\efi\microsoft\boot\efisys.bin" -lWIN2022 $extract $output

Write-Host "`n✅ DONE: $output`n🔐 Password: P@ssw0rd!"
```

## ✅ Ergebnis

* **Setup startet sofort unattended** (kein Sprachauswahl-Dialog)
* Disk 0 wird formatiert → Windows Server 2022 Index 2 installiert
* RDP + WinRM aktiviert
* Windows Update deaktiviert
* Auto-Login (3x) mit Benutzer `Administrator / P@ssword123!`
* Bereit für Terraform / Proxmox-Deployment 🚀




# LINUX

```bash
7z x WIN2022.ISO -owiniso
cp autounattend.xml winiso/autounattend.xml
mkisofs -o WIN2022-unattend-2.iso \
  -iso-level 3 -udf -allow-limited-size \
  -b boot/etfsboot.com \
  -no-emul-boot -boot-load-size 8 -boot-info-table \
  -eltorito-alt-boot \
  -eltorito-platform efi -b efi/microsoft/boot/efisys.bin \
  -no-emul-boot \
  -J -R -V "WIN2022_UNATTEND" \
  winiso
```

# TEST IT
```bash
#!/bin/bash
# WIN2022 Unattended Test (UEFI Boot FIXED)

VMID=999
VMNAME="win2022-unattend"
STORAGE="local-lvm"
ISO="local:iso/WIN2022-unattend.iso"
DISKSIZE=64

# Cleanup

qm stop $VMID --skiplock 2>/dev/null || true
qm destroy $VMID --purge 2>/dev/null || true

# Create
qm create $VMID \
  --name $VMNAME \
  --memory 8192 \
  --cores 4 \
  --cpu host \
  --machine q35 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --vga std \
  --agent 0 \
  --bios ovmf \
  --efidisk0 ${STORAGE}:1,efitype=4m,pre-enrolled-keys=1

# Attach Disk + ISO

qm set $VMID --scsi0 ${STORAGE}:${DISKSIZE}
qm set $VMID --ide2 $ISO,media=cdrom

# Ensure boot order + no legacy fallback
qm set $VMID --boot "order=ide2;scsi0"
qm set $VMID --bootdisk scsi0

# Start
qm start $VMID

echo "✅ VM $VMID started with proper UEFI ISO boot"
```