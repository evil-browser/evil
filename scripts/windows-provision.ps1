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

$script:Downloads = Join-Path $env:TEMP "evil-provision"
New-Item -ItemType Directory -Force -Path $script:Downloads | Out-Null

function Get-Installer($url, $name) {
    $out = Join-Path $script:Downloads $name
    if (Test-Path $out) { Write-Info "$name already downloaded"; return $out }
    Write-Info "downloading $name"
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    return $out
}

function Invoke-Installer($path, $arguments, $label) {
    Write-Info "installing $label"
    $p = Start-Process -FilePath $path -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
        Write-Warn "$label exited with $($p.ExitCode)"
    }
    return $p.ExitCode
}

Write-Step "Package manager"
$useWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
if ($useWinget) {
    Write-Info "winget $(winget --version)"
} else {
    Write-Info "no winget (normal on Windows Server), using direct downloads"
}

Write-Step "Git"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Info "already present"
} elseif ($useWinget) {
    winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
} else {
    $rel = Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest" -UseBasicParsing
    $asset = $rel.assets | Where-Object { $_.name -like "Git-*-64-bit.exe" } | Select-Object -First 1
    $exe = Get-Installer $asset.browser_download_url $asset.name
    Invoke-Installer $exe '/VERYSILENT /NORESTART /NOCANCEL /SP- /SUPPRESSMSGBOXES /o:PathOption=CmdTools /o:EnableSymlinks=Enabled' "git" | Out-Null
}

Write-Step "Python"
$pythonOk = $false
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) {
    $v = & $py.Source --version 2>&1
    if ($v -match "Python 3\.(9|1[0-9])") { $pythonOk = $true; Write-Info "$v already present" }
}
if (-not $pythonOk) {
    if ($useWinget) {
        winget install --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    } else {
        $exe = Get-Installer "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe" "python-3.12.7-amd64.exe"
        Invoke-Installer $exe '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_doc=0' "python 3.12" | Out-Null
    }
}

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
        Write-Info "this downloads several GB and takes a while"
        $exe = Get-Installer "https://aka.ms/vs/17/release/vs_BuildTools.exe" "vs_BuildTools.exe"
        $vsArgs = @(
            "--quiet", "--wait", "--norestart", "--nocache"
            "--add", "Microsoft.VisualStudio.Workload.VCTools"
            "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
            "--add", "Microsoft.VisualStudio.Component.VC.ATL"
            "--add", "Microsoft.VisualStudio.Component.VC.ATLMFC"
            "--add", "Microsoft.VisualStudio.Component.Windows11SDK.22621"
            "--includeRecommended"
        )
        Invoke-Installer $exe ($vsArgs -join ' ') "Visual Studio Build Tools" | Out-Null
    }

    Write-Step "Debugging Tools for Windows"
    $dbg = "${env:ProgramFiles(x86)}\Windows Kits\10\Debuggers\x64\cdb.exe"
    if (Test-Path $dbg) {
        Write-Info "already present"
    } else {
        $exe = Get-Installer "https://go.microsoft.com/fwlink/?linkid=2196241" "winsdksetup.exe"
        Invoke-Installer $exe '/features OptionId.WindowsDesktopDebuggers /quiet /norestart /ceip off' "Debugging Tools" | Out-Null
        if (Test-Path $dbg) { Write-Info "installed" } else { Write-Warn "still missing; Chromium will not link without it" }
    }
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
