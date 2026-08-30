# Building on Windows

Reference platform: Windows 11 x64, Visual Studio 2022.

## Prerequisites

1. **Visual Studio 2022** (Community is fine) with:
   - "Desktop development with C++"
   - MSVC v143 build tools
   - Windows 11 SDK (10.0.22621 or newer), including **Debugging Tools for Windows**
     (Control Panel → the SDK installer → Modify → check Debugging Tools).
2. **Git for Windows**, with symlinks enabled during setup.
3. **Python 3.9+** on `PATH`.
4. Long paths enabled, or the checkout will fail in confusing ways:
   ```powershell
   git config --global core.longpaths true
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
     -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
   ```
5. Windows Defender exclusion for the checkout directory. Without it the build
   is roughly twice as slow.

## Shell

The scripts are bash. Use **Git Bash** or WSL-with-Windows-toolchain; plain
PowerShell will not run them. Under Git Bash:

```sh
export DEPOT_TOOLS_WIN_TOOLCHAIN=0   # use your local Visual Studio
make bootstrap
make sync
make patch
make build
```

`DEPOT_TOOLS_WIN_TOOLCHAIN=0` is required unless you have access to Google's
internal toolchain package. Set it in your environment permanently.

## Installer

```sh
scripts/build.sh --target mini_installer
make package
```

That produces `dist/evil-<version>-x64.exe` and a portable `.zip`.

## Known annoyances

| Symptom | Fix |
| --- | --- |
| `Windows SDK not found` | Install Debugging Tools for Windows in the SDK installer |
| Paths over 260 characters | Enable long paths (above), keep the checkout near the drive root |
| `gclient sync` hangs on hooks | Antivirus scanning the tree — add the exclusion |
| Build works, tests hang | Run from Git Bash, not from an MSYS2 shell |
