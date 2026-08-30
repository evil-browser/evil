# Building on Windows

Reference platform: Windows 11 x64 or Windows Server 2022, Visual Studio 2022.

Chromium cannot be cross-compiled to Windows from Linux or macOS. Upstream does
not support it and never has. A Windows build needs a Windows machine — a VM, a
cloud instance, or a physical box.

## What the machine needs

| | Minimum | Sensible |
| --- | --- | --- |
| Cores | 4 | 16 |
| RAM | 16 GB | 32 GB |
| Disk | 150 GB | 250 GB SSD |
| OS | Windows 10 21H2 | Windows 11 or Server 2022 |

Visual Studio alone is 20–30 GB before the Chromium checkout.

## Automatic setup

From an **elevated PowerShell**:

```powershell
irm https://raw.githubusercontent.com/evil-browser/evil/main/scripts/windows-provision.ps1 -OutFile provision.ps1
Set-ExecutionPolicy -Scope Process Bypass -Force
.\provision.ps1
```

It enables long paths, adds a Defender exclusion for the work directory,
installs git, Python 3.12 and the VS 2022 Build Tools with the components
Chromium needs, sets `DEPOT_TOOLS_WIN_TOOLCHAIN=0`, clones the repository to
`C:\evil`, and sizes `build/args/local.gni` to the machine's RAM.

**One step it cannot do:** winget cannot add *Debugging Tools for Windows* to
the SDK. Open **Apps → Installed apps → Windows Software Development Kit →
Modify**, tick **Debugging Tools for Windows**, and let it install. Chromium
will not link without it, and the error you get if it is missing does not
mention the SDK.

Reboot afterwards if long paths were only just enabled.

## Manual setup

1. **Visual Studio 2022** (Community or Build Tools) with:
   - Desktop development with C++
   - MSVC v143 build tools
   - Windows 11 SDK 10.0.22621 or newer, **including Debugging Tools for Windows**
   - C++ ATL and MFC
2. **Git for Windows**, with symlinks enabled during setup.
3. **Python 3.9+** on `PATH`.
4. Long paths:
   ```powershell
   git config --system core.longpaths true
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
     -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
   ```
5. Defender exclusion for the checkout. Without it the build is roughly twice as slow.
6. `setx /M DEPOT_TOOLS_WIN_TOOLCHAIN 0`

## Build

Windows uses its own driver, `scripts/windows-build.ps1`, not the bash scripts
and Makefile the other platforms use. Two reasons: Git Bash ships no `make`, and
Chromium's own documentation warns against running depot_tools under MSYS, where
its path handling misbehaves. The PowerShell driver runs `fetch`, `gclient`,
`gn` and `autoninja` natively through cmd, and calls the same cross-platform
Python tooling for patching.

From **PowerShell** in the repository root:

```powershell
.\scripts\windows-build.ps1 -Stage all
```

Or one stage at a time, which is what you want the first time through:

```powershell
.\scripts\windows-build.ps1 -Stage bootstrap
.\scripts\windows-build.ps1 -Stage sync
.\scripts\windows-build.ps1 -Stage upstream
.\scripts\windows-build.ps1 -Stage patch
.\scripts\windows-build.ps1 -Stage build -Jobs 8
.\scripts\windows-build.ps1 -Stage package
```

Each stage appends to `build-status.txt`, so a detached run can be followed
without attaching to its console. `-Stage package` produces
`dist\evil-<version>-x64.exe`, a portable `.zip`, and `SHA256SUMS`.

For an unattended run, register it as a scheduled task so it survives your
session disconnecting:

```powershell
$a = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument '-NoProfile -ExecutionPolicy Bypass -File D:\evil\scripts\windows-build.ps1 -Stage all'
$p = New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
$s = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::FromHours(72)) -StartWhenAvailable
Register-ScheduledTask -TaskName evilbuild -Action $a -Principal $p -Settings $s
Start-ScheduledTask -TaskName evilbuild
```

## Known annoyances

| Symptom | Fix |
| --- | --- |
| `Windows SDK not found` at gn gen | Debugging Tools for Windows is not installed |
| Paths over 260 characters | Enable long paths, keep the checkout near the drive root |
| `gclient sync` crawls | Defender is scanning the tree; add the exclusion |
| Link killed with no message | Raise the pagefile to 32 GB or more |
| `make: command not found` | You are in PowerShell. Use Git Bash. |
