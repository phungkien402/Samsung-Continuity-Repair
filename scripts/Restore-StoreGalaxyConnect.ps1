$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Run this script from an elevated PowerShell window.'
}

Stop-Service 'Samsung Multi Control Service' -Force -ErrorAction SilentlyContinue
Stop-Service SamsungContinuityWindowsService -Force -ErrorAction SilentlyContinue
Stop-Process -Name WindowsMCFCore,SamsungContinuityWindowsService,SamsungMultiControlService,SamsungMultiControl,SamsungMultiControlHelper,NearbyDevices,backgroundTaskHost -Force -ErrorAction SilentlyContinue

Get-AppxPackage -Name 'SAMSUNGELECTRONICSCoLtd.SamsungContinuityService' -ErrorAction SilentlyContinue |
  Remove-AppxPackage -ErrorAction SilentlyContinue

winget install --source msstore --id 9NGW9K44GQ5F --accept-package-agreements --accept-source-agreements

Get-AppxPackage -Name 'SAMSUNGELECTRONICSCoLtd.SamsungContinuityService' |
  Select-Object Name, Version, InstallLocation, SignatureKind, Status |
  Format-List
