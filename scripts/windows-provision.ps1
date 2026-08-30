#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$WorkDir = "C:\evil",
    [switch]$SkipVisualStudio,
    [switch]$SkipClone
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor White }
function Write-Info($msg) { Write-Host "    $msg" -ForegroundColor DarkGray }
function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }

Write-Step "Checking the machine"
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB)
$drive = (Get-PSDrive -Name (Split-Path -Qualifier $WorkDir).TrimEnd(':'))
$freeGB = [math]::Round($drive.Free / 1GB)

Write-Info "$($os.Caption)"
Write-Info "$($cpu.NumberOfLogicalProcessors) logical cores, $ramGB GB RAM, $freeGB GB free on $($drive.Name):"

if ($freeGB -lt 150) { Write-Warn "under 150 GB free; a checkout plus one build needs about that" }
if ($ramGB -lt 16) { Write-Warn "under 16 GB RAM; the link step will need a large pagefile" }

Write-Step "Long path support"
$fsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
if ((Get-ItemProperty -Path $fsKey -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled -ne 1) {
    New-ItemProperty -Path $fsKey -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force | Out-Null
    Write-Info "enabled, a reboot is needed before it fully applies"
} else {
    Write-Info "already enabled"
}

Write-Step "Defender exclusion for $WorkDir"
try {
    Add-MpPreference -ExclusionPath $WorkDir -ErrorAction Stop
    Write-Info "added, this roughly halves build time"
} catch {
    Write-Warn "could not add exclusion: $($_.Exception.Message)"
}

Write-Step "Package manager"
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) { Fail "winget not found. Install App Installer from the Microsoft Store, or install git, python and Visual Studio by hand." }
Write-Info "winget $(winget --version)"

function Install-IfMissing($id, $exe, $label) {
    if (Get-Command $exe -ErrorAction SilentlyContinue) {
        Write-Info "$label already present"
        return
    }
    Write-Info "installing $label"
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
}

Write-Step "Git and Python"
Install-IfMissing "Git.Git" "git" "git"
Install-IfMissing "Python.Python.3.12" "python" "python 3.12"

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

git config --system core.longpaths true 2>$null

if (-not $SkipVisualStudio) {
    Write-Step "Visual Studio 2022 Build Tools"
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $installed = $false
    if (Test-Path $vswhere) {
        $found = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($found) { $installed = $true; Write-Info "found at $found" }
    }
    if (-not $installed) {
        Write-Info "installing, this downloads several GB and takes a while"
        $components = @(
            "Microsoft.VisualStudio.Workload.VCTools"
            "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
            "Microsoft.VisualStudio.Component.VC.ATL"
            "Microsoft.VisualStudio.Component.VC.ATLMFC"
            "Microsoft.VisualStudio.Component.Windows11SDK.22621"
        ) | ForEach-Object { "--add", $_ }
        winget install --id Microsoft.VisualStudio.2022.BuildTools --silent `
            --accept-package-agreements --accept-source-agreements --disable-interactivity `
            --override "--quiet --wait --norestart --nocache $($components -join ' ') --includeRecommended" | Out-Null
        Write-Info "installed"
    }
    Write-Warn "Debugging Tools for Windows is required and winget cannot add it."
    Write-Warn "Open the Windows SDK entry in Apps > Installed apps > Modify, and tick"
    Write-Warn "'Debugging Tools for Windows'. Chromium will not link without it."
}

Write-Step "Environment"
[Environment]::SetEnvironmentVariable("DEPOT_TOOLS_WIN_TOOLCHAIN", "0", "Machine")
[Environment]::SetEnvironmentVariable("DEPOT_TOOLS_METRICS", "0", "Machine")
Write-Info "DEPOT_TOOLS_WIN_TOOLCHAIN=0 (use the locally installed Visual Studio)"

if (-not $SkipClone) {
    Write-Step "Repository"
    if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }
    if (Test-Path (Join-Path $WorkDir ".git")) {
        Write-Info "already cloned, pulling"
        git -C $WorkDir pull --quiet
    } else {
        git clone --quiet https://github.com/evil-browser/evil.git $WorkDir
        Write-Info "cloned to $WorkDir"
    }

    $localGni = Join-Path $WorkDir "build\args\local.gni"
    if ($ramGB -lt 24 -and -not (Test-Path $localGni)) {
        @(
            "use_thin_lto = false"
            "concurrent_links = 1"
            "chrome_pgo_phase = 0"
        ) | Set-Content -Path $localGni -Encoding ASCII
        Write-Info "wrote build/args/local.gni sized for $ramGB GB of RAM"
    }
}

Write-Host ""
Write-Step "Ready"
Write-Info "work dir: $WorkDir"
Write-Host ""
Write-Host "Reboot first if long paths were just enabled, then from Git Bash:" -ForegroundColor White
Write-Host ""
Write-Host "    cd /c/evil"
Write-Host "    make bootstrap"
Write-Host "    make sync"
Write-Host "    make upstream"
Write-Host "    make patch"
Write-Host "    scripts/build.sh --target mini_installer"
Write-Host "    make package"
Write-Host ""
Write-Warn "The build scripts are bash. Use Git Bash, not PowerShell or cmd."
