$packages = @(
  'SAMSUNGELECTRONICSCoLtd.SamsungContinuityService',
  'SAMSUNGELECTRONICSCoLtd.MultiControl',
  'SAMSUNGELECTRONICSCoLtd.SamsungMyDevices',
  'SAMSUNGELECTRONICSCO.LTD.SamsungCloudPlatformManag'
)

Write-Host 'Packages:'
foreach ($name in $packages) {
  Get-AppxPackage -Name $name -ErrorAction SilentlyContinue |
    Select-Object Name, Version, SignatureKind, Status, InstallLocation |
    Format-List
}

Write-Host 'Services:'
Get-Service SamsungContinuityWindowsService,'Samsung Multi Control Service',SamsungSystemSupportService,GBeSupportService -ErrorAction SilentlyContinue |
  Select-Object Name, Status, StartType |
  Format-Table -AutoSize

Write-Host 'MCF:'
Get-Process WindowsMCFCore -ErrorAction SilentlyContinue | Select-Object Id, Path | Format-List
Get-NetTCPConnection -LocalPort 45823 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress, LocalPort, State, OwningProcess |
  Format-Table -AutoSize
