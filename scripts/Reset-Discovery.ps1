$ErrorActionPreference = 'Continue'

$packagesToReset = @(
  'SAMSUNGELECTRONICSCO.LTD.SamsungCloudPlatformManag',
  'SAMSUNGELECTRONICSCO.LTD.SamsungAccount',
  'SAMSUNGELECTRONICSCoLtd.SamsungMyDevices'
)

Write-Host 'Stopping Samsung UI/background processes...'
Stop-Process -Name NearbyDevices,SamsungMultiControl,SamsungMultiControlHelper,backgroundTaskHost -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Write-Host 'Resetting Samsung Cloud/Account/MyDevices package state...'
foreach ($name in $packagesToReset) {
  $pkg = Get-AppxPackage -Name $name -ErrorAction SilentlyContinue
  if ($pkg) {
    Write-Host "Reset-AppxPackage: $name"
    try {
      Reset-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    } catch {
      Write-Warning "Reset failed for $name : $($_.Exception.Message)"
    }
  } else {
    Write-Warning "Package not found: $name"
  }
}

Write-Host 'Restarting core services...'
Restart-Service SamsungContinuityWindowsService -Force -ErrorAction SilentlyContinue
Restart-Service 'Samsung Multi Control Service' -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 75

Write-Host ''
Write-Host 'MCF status:'
Get-Process WindowsMCFCore -ErrorAction SilentlyContinue | Select-Object Id, Path | Format-List
Get-NetTCPConnection -LocalPort 45823 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress, LocalPort, State, OwningProcess |
  Format-Table -AutoSize

Write-Host ''
Write-Host 'Recent crashes:'
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddMinutes(-15) } -ErrorAction SilentlyContinue |
  Where-Object {
    $_.ProviderName -match 'Application Error|Windows Error Reporting|\.NET Runtime' -and
    $_.Message -match 'WindowsMCFCore|SamsungContinuity|SamsungMultiControl|NearbyDevices|SamsungCloudPlatformManag|SamsungAccount'
  } |
  Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message |
  Format-List
