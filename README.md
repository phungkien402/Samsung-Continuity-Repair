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

## Known Working Setup

This setup has been confirmed working with:

- Windows 11, x64
- Non-Galaxy Book Lenovo laptop
- Samsung Galaxy S22 Ultra
- `SAMSUNGELECTRONICSCoLtd.SamsungContinuityService` version `2.1.11.0`
- `SAMSUNGELECTRONICSCoLtd.MultiControl` version `2.7.1300.0`
- Galaxy Connect installed from Microsoft Store
- Samsung account signed in on both Windows and phone
- Bluetooth and Wi-Fi enabled on both devices

Expected working signs:

```powershell
Get-AppxPackage -Name SAMSUNGELECTRONICSCoLtd.SamsungContinuityService | Select Name,Version,SignatureKind,Status,InstallLocation
Get-Process WindowsMCFCore -ErrorAction SilentlyContinue | Select Id,Path
Get-NetTCPConnection -LocalPort 45823 -ErrorAction SilentlyContinue | Select LocalAddress,LocalPort,State,OwningProcess
```

Expected output:

- `SignatureKind` is `Developer`.
- `WindowsMCFCore.exe` is running.
- TCP port `45823` is listening.
- Multi Control and Nearby Devices can discover the Galaxy phone.

## Troubleshooting

### Galaxy Connect says "not working", but Multi Control works

This can happen. Galaxy Connect UI depends on Samsung cloud/account components, and those can crash or report an unhealthy state even while the actual Multi Control stack is working.

If these are true, you can ignore the Galaxy Connect warning:

- Multi Control opens.
- Nearby Devices can see the phone.
- Mouse/keyboard handoff works.
- `WindowsMCFCore.exe` is running.
- Port `45823` is listening.

Check:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\Get-Status.ps1"
```

If devices disappear, reset discovery:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\Reset-Discovery.ps1"
```

### Multi Control opens but no device appears

Check the phone first:

- Same Samsung account on PC and phone.
- Bluetooth enabled.
- Wi-Fi enabled.
- Phone is nearby and unlocked.
- Multi Control enabled on the phone.
- Nearby device scanning enabled on the phone.

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\Reset-Discovery.ps1"
```

### Install fails with certificate/root trust error

Run the installer from an elevated PowerShell window. The script imports the local signing certificate into:

- `CurrentUser\TrustedPeople`
- `CurrentUser\Root`
- `LocalMachine\TrustedPeople`
- `LocalMachine\Root`

### Install fails because package version is unsupported

The current patch offsets target `SamsungContinuityService` `2.1.11.0`. If Samsung updates the package, restore the Store version or adjust the patch offsets before installing.

## Current patch details

For package version `2.1.11.0`:

- `WindowsMCFCore\Commons.dll`: patches `DeviceDetailsHelper.GetDeviceDetailsStatus()` to return `Supported`.
- `SamsungContinuityWindowsService\SamsungContinuityWindowsService.exe`: patches `MCFCoreTurnnedOff` command string to a harmless value.
