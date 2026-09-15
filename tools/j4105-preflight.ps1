<#
.SYNOPSIS
  Pre-flight for putting Home Assistant OS on the J4105 box. Run in an ADMIN PowerShell ON THAT BOX.

  .\j4105-preflight.ps1          Report: firmware mode, Secure Boot, disks, Ethernet MAC, and whether
                                 a BIOS trip is needed.
  .\j4105-preflight.ps1 -Bios    Reboot straight into the BIOS/UEFI setup screen. No key-mashing.
  .\j4105-preflight.ps1 -Usb     Reboot into Windows' Advanced Startup menu. Pick "Use a device" and
                                 the Ubuntu stick. Boots the USB without touching the BIOS.

  Get it onto the box with:
    iwr -useb https://raw.githubusercontent.com/stevenxlayton/LaytonFamilyCommandCenter/main/tools/j4105-preflight.ps1 -OutFile j4105-preflight.ps1
    powershell -ExecutionPolicy Bypass -File .\j4105-preflight.ps1
#>
[CmdletBinding()]
param(
    [switch]$Bios,
    [switch]$Usb
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Run this from an ADMIN PowerShell (Start -> type powershell -> Run as administrator)." -ForegroundColor Red
    exit 1
}

if ($Bios) { Write-Host "Rebooting into firmware setup in 3 seconds..."; shutdown /r /fw /t 3; exit 0 }
if ($Usb)  { Write-Host "Rebooting into Advanced Startup in 3 seconds. Choose: Use a device -> the USB stick."; shutdown /r /o /t 3; exit 0 }

# --- gather ---
$fw = $env:firmware_type
try   { $sb = Confirm-SecureBootUEFI }
catch { $sb = $null }   # firmware has no Secure Boot at all -> effectively off

$disks = Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType,
    @{ n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB) } }

$eth = Get-NetAdapter -Physical |
    Where-Object { $_.PhysicalMediaType -eq '802.3' -and $_.InterfaceDescription -notmatch 'Wi-?Fi|Wireless|Bluetooth' } |
    Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress

# --- report ---
Write-Host ""
Write-Host "Firmware mode : $fw"
Write-Host ("Secure Boot   : " + $(if ($null -eq $sb) { 'not present in this firmware (= off)' } elseif ($sb) { 'ON' } else { 'OFF' }))
Write-Host ""
Write-Host "Disks:"
$disks | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
Write-Host "Ethernet:"
if ($eth) { $eth | Format-Table -AutoSize | Out-String -Width 200 | Write-Host }
else      { Write-Host "  (no wired adapter found)`n" -ForegroundColor Yellow }

# --- verdict ---
$bios = $false
if ($fw -ne 'UEFI') {
    Write-Host "PROBLEM: Windows is not booted in UEFI mode. HAOS needs UEFI. In the BIOS, turn CSM/Legacy off." -ForegroundColor Red
    $bios = $true
}
if ($sb -eq $true) {
    Write-Host "BIOS trip needed: Secure Boot is ON, and HAOS will not boot with it on." -ForegroundColor Yellow
    Write-Host "  .\j4105-preflight.ps1 -Bios   then: Security (or Boot) tab -> Secure Boot -> Disabled -> F10 Save & Exit."
    $bios = $true
}
if (-not $eth) {
    Write-Host "PROBLEM: no wired Ethernet adapter. The server has to be on a cable." -ForegroundColor Red
}
if (-not $bios) {
    Write-Host "No BIOS trip needed." -ForegroundColor Green
}
Write-Host ""
Write-Host "Write down the Ethernet MacAddress above - the .212 DHCP reservation on the router moves to it."
Write-Host "Next: plug in the Ubuntu USB stick and run   .\j4105-preflight.ps1 -Usb"
