# Samsung Multi Control Patcher for non-Galaxy Book PCs

Experimental patch flow for running Samsung Multi Control / Nearby Devices on unsupported Windows laptops.

Tested target package:

- `SAMSUNGELECTRONICSCoLtd.SamsungContinuityService` version `2.1.11.0`

What this does:

- Copies the installed Galaxy Connect / Samsung Continuity package from `C:\Program Files\WindowsApps`.
- Patches the copied package, not the Store package in-place.
- Repackages it as a locally signed MSIX.
- Installs the patched MSIX so `WindowsMCFCore` can run with package identity.
- Resets Samsung Cloud / Account / MyDevices state when discovery is stuck.

What this does not include:

- No Samsung binaries are included in this repository.
- No prebuilt patched MSIX is included.
- The scripts patch files already installed on your own PC.

## Requirements

- Windows 11
- Samsung Galaxy phone with Multi Control support
- Galaxy Connect installed from Microsoft Store
- Windows SDK Packaging Tools, for `makeappx.exe` and `signtool.exe`
- PowerShell running as Administrator

Install Windows SDK Packaging Tools:

```powershell
winget install --source winget --id Microsoft.WindowsSDK.10.0.26100 --accept-package-agreements --accept-source-agreements
```

Install Galaxy Connect if missing:

```powershell
winget install --source msstore --id 9NGW9K44GQ5F --accept-package-agreements --accept-source-agreements
```

## Install

Run PowerShell as Administrator:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\Install-PatchedContinuity.ps1"
```

After install, verify:

```powershell
Get-AppxPackage -Name SAMSUNGELECTRONICSCoLtd.SamsungContinuityService | Select Name,Version,SignatureKind,Status,InstallLocation
Get-Process WindowsMCFCore -ErrorAction SilentlyContinue | Select Id,Path
Get-NetTCPConnection -LocalPort 45823 -ErrorAction SilentlyContinue | Select LocalAddress,LocalPort,State,OwningProcess
```

Expected:

- `SignatureKind` is `Developer`.
- `WindowsMCFCore.exe` is running from the Samsung Continuity package folder.
- Port `45823` is listening.

## Repair Discovery

If Multi Control opens but devices disappear:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\Reset-Discovery.ps1"
```

## Restore Store Version

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\Restore-StoreGalaxyConnect.ps1"
```

## Notes

- `Galaxy Connect` UI can still show "not working" even when Multi Control / Nearby Devices works.
- Do not update Galaxy Connect after patching unless you are ready to rerun the installer.
- This is version-specific. If Samsung updates `SamsungContinuityService`, the binary patch offsets may need updating.

## Current patch details

For package version `2.1.11.0`:

- `WindowsMCFCore\Commons.dll`: patches `DeviceDetailsHelper.GetDeviceDetailsStatus()` to return `Supported`.
- `SamsungContinuityWindowsService\SamsungContinuityWindowsService.exe`: patches `MCFCoreTurnnedOff` command string to a harmless value.
