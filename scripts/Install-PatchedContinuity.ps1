$ErrorActionPreference = 'Stop'

$PackageName = 'SAMSUNGELECTRONICSCoLtd.SamsungContinuityService'
$ExpectedVersion = '2.1.11.0'
$Publisher = 'CN=14C847C8-791E-46EB-9C0D-7CADAF31C930'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BuildRoot = Join-Path $Root 'build\SamsungContinuityService'
$Artifacts = Join-Path $Root 'artifacts'
$MsixPath = Join-Path $Artifacts 'SamsungContinuityService.patched.msix'
$CertPath = Join-Path $Artifacts 'SamsungContinuityService.local.cer'
$MakeAppx = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter makeappx.exe -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\x64\\' } |
  Sort-Object FullName -Descending |
  Select-Object -First 1 -ExpandProperty FullName
$SignTool = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\x64\\' } |
  Sort-Object FullName -Descending |
  Select-Object -First 1 -ExpandProperty FullName

function Assert-Admin {
  $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell window.'
  }
}

function Patch-AsciiAndUnicodeString {
  param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $From,
    [Parameter(Mandatory)] [string] $To
  )

  if ($From.Length -ne $To.Length) {
    throw "Replacement must have the same length: '$From' -> '$To'"
  }

  $bytes = [IO.File]::ReadAllBytes($Path)
  $patched = 0

  foreach ($encoding in @([Text.Encoding]::ASCII, [Text.Encoding]::Unicode)) {
    $needle = $encoding.GetBytes($From)
    $replacement = $encoding.GetBytes($To)
    for ($i = 0; $i -le $bytes.Length - $needle.Length; $i++) {
      $match = $true
      for ($j = 0; $j -lt $needle.Length; $j++) {
        if ($bytes[$i + $j] -ne $needle[$j]) {
          $match = $false
          break
        }
      }
      if ($match) {
        [Array]::Copy($replacement, 0, $bytes, $i, $replacement.Length)
        $patched++
        $i += $needle.Length - 1
      }
    }
  }

  if ($patched -lt 1) {
    throw "Could not find string '$From' in $Path"
  }

  [IO.File]::WriteAllBytes($Path, $bytes)
  Write-Host "Patched $patched string occurrence(s): $Path"
}

function Patch-CommonsDeviceStatus {
  param([Parameter(Mandatory)] [string] $Path)

  # SamsungContinuityService 2.1.11.0 Commons.dll:
  # RVA 0x1f1d8 -> file offset 0x1d3d8, method body becomes tiny IL:
  # 02       tiny header, code size 2
  # 16       ldc.i4.1 (DeviceDetailsStatus.Supported)
  # 2A       ret
  $offset = 0x1d3d8
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -le ($offset + 3)) {
    throw "Commons.dll is smaller than expected: $Path"
  }

  $old = ($bytes[$offset..($offset + 2)] | ForEach-Object { $_.ToString('X2') }) -join ' '
  $bytes[$offset] = 0x02
  $bytes[$offset + 1] = 0x16
  $bytes[$offset + 2] = 0x2A
  [IO.File]::WriteAllBytes($Path, $bytes)
  Write-Host "Patched DeviceDetailsHelper.GetDeviceDetailsStatus at 0x$($offset.ToString('X')); previous bytes: $old"
}

Assert-Admin

if (-not $MakeAppx -or -not $SignTool) {
  throw 'Windows SDK Packaging Tools not found. Install Microsoft.WindowsSDK.10.0.26100 with winget first.'
}

$pkg = Get-AppxPackage -Name $PackageName
if (-not $pkg) {
  throw "Package not found. Install Galaxy Connect first: winget install --source msstore --id 9NGW9K44GQ5F"
}
if ($pkg.Version.ToString() -ne $ExpectedVersion) {
  throw "Unsupported $PackageName version $($pkg.Version). Expected $ExpectedVersion."
}

Write-Host 'Stopping Samsung continuity stack...'
Stop-Service 'Samsung Multi Control Service' -Force -ErrorAction SilentlyContinue
Stop-Service SamsungContinuityWindowsService -Force -ErrorAction SilentlyContinue
Stop-Process -Name WindowsMCFCore,SamsungContinuityWindowsService,SamsungMultiControlService,SamsungMultiControl,SamsungMultiControlHelper,NearbyDevices,backgroundTaskHost -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

New-Item -ItemType Directory -Path $Artifacts -Force | Out-Null
if (Test-Path -LiteralPath $BuildRoot) {
  Remove-Item -LiteralPath $BuildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $BuildRoot -Force | Out-Null

Write-Host "Copying package from: $($pkg.InstallLocation)"
Copy-Item -Path (Join-Path $pkg.InstallLocation '*') -Destination $BuildRoot -Recurse -Force

Remove-Item -LiteralPath (Join-Path $BuildRoot 'AppxSignature.p7x') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $BuildRoot 'AppxBlockMap.xml') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $BuildRoot 'AppxMetadata') -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $BuildRoot 'microsoft.system.package.metadata') -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $BuildRoot -Recurse -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'AppxBundleManifest|BundleManifest' } |
  Remove-Item -Force -ErrorAction SilentlyContinue

$commons = Join-Path $BuildRoot 'WindowsMCFCore\Commons.dll'
$serviceExe = Join-Path $BuildRoot 'SamsungContinuityWindowsService\SamsungContinuityWindowsService.exe'
$manifest = Join-Path $BuildRoot 'AppxManifest.xml'
foreach ($path in @($commons, $serviceExe, $manifest)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required package file missing after copy: $path"
  }
}

Patch-CommonsDeviceStatus -Path $commons
Patch-AsciiAndUnicodeString -Path $serviceExe -From 'MCFCoreTurnnedOff' -To 'MCFCoreIgnoredOff'

Write-Host 'Preparing local signing certificate...'
$cert = Get-ChildItem Cert:\CurrentUser\My |
  Where-Object { $_.Subject -eq $Publisher -and $_.HasPrivateKey } |
  Sort-Object NotAfter -Descending |
  Select-Object -First 1
if (-not $cert) {
  $cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $Publisher `
    -KeyUsage DigitalSignature `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3') `
    -NotAfter (Get-Date).AddYears(5)
}
Export-Certificate -Cert $cert -FilePath $CertPath -Force | Out-Null
Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\CurrentUser\Root' | Out-Null
Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null

if (Test-Path -LiteralPath $MsixPath) {
  Remove-Item -LiteralPath $MsixPath -Force
}

Write-Host 'Packing MSIX...'
& $MakeAppx pack /d $BuildRoot /p $MsixPath /o
if ($LASTEXITCODE -ne 0) {
  throw "makeappx failed with exit code $LASTEXITCODE"
}

Write-Host 'Signing MSIX...'
& $SignTool sign /fd SHA256 /sha1 $cert.Thumbprint $MsixPath
if ($LASTEXITCODE -ne 0) {
  throw "signtool failed with exit code $LASTEXITCODE"
}

Write-Host 'Installing patched MSIX...'
$existing = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
if ($existing) {
  Remove-AppxPackage -Package $existing.PackageFullName -ErrorAction Stop
  Start-Sleep -Seconds 5
}
Add-AppxPackage -Path $MsixPath -ForceUpdateFromAnyVersion
Start-Sleep -Seconds 8

Start-Service SamsungContinuityWindowsService -ErrorAction SilentlyContinue
Start-Service 'Samsung Multi Control Service' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 90

Write-Host ''
Write-Host 'Installed package:'
Get-AppxPackage -Name $PackageName |
  Select-Object Name, Version, SignatureKind, Status, InstallLocation |
  Format-List

Write-Host ''
Write-Host 'MCF status:'
Get-Process WindowsMCFCore -ErrorAction SilentlyContinue | Select-Object Id, Path | Format-List
Get-NetTCPConnection -LocalPort 45823 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress, LocalPort, State, OwningProcess |
  Format-Table -AutoSize

Write-Host ''
Write-Host "Patched MSIX written to: $MsixPath"
