[CmdletBinding()]
param(
    [ValidateSet('all','bootstrap','sync','upstream','patch','build','package')]
    [string]$Stage = 'all',
    [string]$Target = 'mini_installer',
    [string]$Config = 'release',
    [int]$Jobs = 0
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Src = Join-Path $Root "src"
$DepotTools = Join-Path $Root "third_party\depot_tools"
$Ungoogled = Join-Path $Root "third_party\ungoogled-chromium"
$OutDir = Join-Path $Root "out\$Config"
$StatusFile = Join-Path $Root "build-status.txt"

$ChromiumVersion = (Get-Content (Join-Path $Root "CHROMIUM_VERSION")).Trim()
$UngoogledVersion = (Get-Content (Join-Path $Root "UNGOOGLED_VERSION")).Trim()

function Resolve-Tooling {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = ($machine, $user, $env:Path | Where-Object { $_ }) -join ';'

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        foreach ($c in @("$env:ProgramFiles\Git\cmd", "${env:ProgramFiles(x86)}\Git\cmd", "$env:LOCALAPPDATA\Programs\Git\cmd")) {
            if (Test-Path (Join-Path $c "git.exe")) { $env:Path = "$c;$env:Path"; break }
        }
    }
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        $py = Get-ChildItem "$env:ProgramFiles\Python3*", "$env:LOCALAPPDATA\Programs\Python\Python3*" -Directory -ErrorAction SilentlyContinue |
              Sort-Object Name -Descending | Select-Object -First 1
        if ($py) { $env:Path = "$($py.FullName);$($py.FullName)\Scripts;$env:Path" }
    }

    foreach ($tool in @('git', 'python')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            throw "$tool not found on PATH and not in the usual install locations"
        }
    }
}

function Write-Step($m) { $t = Get-Date -Format "HH:mm:ss"; Write-Host "[$t] ==> $m" -ForegroundColor White }
function Write-Info($m) { Write-Host "         $m" -ForegroundColor DarkGray }
function Set-Status($m) { "$(Get-Date -Format o) $m" | Add-Content -Path $StatusFile }
function Fail($m) { Set-Status "FAILED $m"; Write-Host "error: $m" -ForegroundColor Red; exit 1 }

function Use-DepotTools {
    if (-not (Test-Path $DepotTools)) { Fail "depot_tools missing, run -Stage bootstrap" }
    $env:Path = "$DepotTools;$env:Path"
    $env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"
    $env:DEPOT_TOOLS_METRICS = "0"
    $env:DEPOT_TOOLS_UPDATE = "1"
}

function Invoke-Git($arguments, $label, [switch]$Tolerate) {
    $out = & git @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($Tolerate) {
            Write-Info "$label returned $LASTEXITCODE, continuing"
            return $false
        }
        $out | Select-Object -Last 5 | ForEach-Object { Write-Info $_ }
        Fail "$label failed with $LASTEXITCODE"
    }
    return $true
}

function Invoke-Native($file, $arguments, $workdir, $label) {
    Write-Info "$file $arguments"
    $p = Start-Process -FilePath $file -ArgumentList $arguments -WorkingDirectory $workdir `
        -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) { Fail "$label exited $($p.ExitCode)" }
}

function Stage-Bootstrap {
    Write-Step "depot_tools"
    if (Test-Path (Join-Path $DepotTools ".git")) {
        Write-Info "already present, it self-updates on each gclient invocation"
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $DepotTools) | Out-Null
        Invoke-Git @('clone', '--quiet', 'https://chromium.googlesource.com/chromium/tools/depot_tools.git', $DepotTools) "depot_tools clone" | Out-Null
    }
    [Environment]::SetEnvironmentVariable("DEPOT_TOOLS_WIN_TOOLCHAIN", "0", "Machine")
    Use-DepotTools
    Write-Info "priming depot_tools"
    cmd /c "gclient version" 2>&1 | Select-Object -Last 1 | ForEach-Object { Write-Info $_ }
    Set-Status "bootstrap ok"
}

function Stage-Sync {
    Use-DepotTools
    Write-Step "Chromium $ChromiumVersion"
    if (-not (Test-Path $Src)) {
        Write-Info "first checkout, tens of gigabytes"
        if (Test-Path (Join-Path $Root ".gclient")) {
            Invoke-Native "cmd.exe" "/c gclient sync --nohooks --no-history --shallow" $Root "gclient sync"
        } else {
            Invoke-Native "cmd.exe" "/c fetch --nohooks --no-history chromium" $Root "fetch"
        }
    }
    if (-not (Test-Path $Src)) { Fail "fetch produced no src directory" }

    $dirty = & git -C $Src status --porcelain 2>$null
    if ($dirty) { Fail "src has local modifications, run -Stage patch after a revert" }

    Write-Info "checking out tag $ChromiumVersion"
    Invoke-Git @('-C', $Src, 'fetch', '--tags', '--depth', '1', 'origin', "refs/tags/$ChromiumVersion") "tag fetch" | Out-Null
    Invoke-Git @('-C', $Src, 'checkout', '--detach', $ChromiumVersion) "tag checkout" | Out-Null
    Invoke-Native "cmd.exe" "/c gclient sync --with_branch_heads --with_tags --delete_unversioned_trees --reset" $Root "gclient sync"
    Set-Status "sync ok $ChromiumVersion"
}

function Stage-Upstream {
    Write-Step "ungoogled-chromium $UngoogledVersion"
    if (Test-Path (Join-Path $Ungoogled ".git")) {
        Invoke-Git @('-C', $Ungoogled, 'fetch', '--tags', '--quiet', 'origin') "ungoogled fetch" -Tolerate | Out-Null
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $Ungoogled) | Out-Null
        Invoke-Git @('clone', '--quiet', 'https://github.com/ungoogled-software/ungoogled-chromium.git', $Ungoogled) "ungoogled clone" | Out-Null
    }
    Invoke-Git @('-C', $Ungoogled, 'checkout', '--quiet', '--detach', $UngoogledVersion) "ungoogled checkout" | Out-Null
    $theirs = (Get-Content (Join-Path $Ungoogled "chromium_version.txt")).Trim()
    if ($theirs -ne $ChromiumVersion) { Fail "ungoogled targets Chromium $theirs, we pin $ChromiumVersion" }
    Write-Info "$((Get-Content (Join-Path $Ungoogled 'patches\series') | Where-Object { $_ -match '\S' }).Count) upstream patches"
    Set-Status "upstream ok $UngoogledVersion"
}

function Stage-Patch {
    if (-not (Test-Path $Src)) { Fail "no checkout" }
    if (Test-Path (Join-Path $Src ".evil-patches-applied")) { Fail "already patched, revert first" }
    Use-DepotTools

    Write-Step "pruning bundled binaries"
    Invoke-Native "python" "`"$Ungoogled\utils\prune_binaries.py`" `"$Src`" `"$Ungoogled\pruning.list`"" $Root "prune"

    Write-Step "staging the upstream series"
    $staged = Join-Path $Root "out\upstream-patches"
    if (Test-Path $staged) { Remove-Item -Recurse -Force $staged }
    New-Item -ItemType Directory -Force -Path (Split-Path $staged) | Out-Null
    Copy-Item -Recurse (Join-Path $Ungoogled "patches") $staged

    $excludeFile = Join-Path $Root "patches\upstream-exclude.list"
    $excluded = 0
    if (Test-Path $excludeFile) {
        $seriesPath = Join-Path $staged "series"
        $series = Get-Content $seriesPath
        foreach ($skip in (Get-Content $excludeFile | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' })) {
            if ($series -contains $skip) {
                $series = $series | Where-Object { $_ -ne $skip }
                $excluded++
                Write-Info "excluded $skip"
            } else {
                Write-Host "         warning: exclusion not found upstream: $skip" -ForegroundColor Yellow
            }
        }
        Set-Content -Path $seriesPath -Value $series -Encoding ascii
    }

    $count = (Get-Content (Join-Path $staged "series") | Where-Object { $_ -match '\S' }).Count
    Write-Step "applying $count upstream patches ($excluded excluded)"
    Invoke-Native "python" "`"$Ungoogled\utils\patches.py`" apply `"$Src`" `"$staged`"" $Root "upstream patches"

    if ($env:EVIL_DOMSUB -eq "1") {
        Write-Step "domain substitution"
        Invoke-Native "python" "`"$Ungoogled\utils\domain_substitution.py`" apply -r `"$Ungoogled\domain_regex.list`" -f `"$Ungoogled\domain_substitution.list`" -c `"$Root\out\domsubcache.tar.gz`" `"$Src`"" $Root "domain substitution"
    } else {
        Write-Info "domain substitution skipped, set EVIL_DOMSUB=1 to enable"
    }

    $ourSeries = Join-Path $Root "patches\series"
    $ours = @(Get-Content $ourSeries -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' })
    if ($ours.Count) {
        Write-Step "applying $($ours.Count) evil patches"
        foreach ($rel in $ours) {
            $file = Join-Path $Root "patches\$rel"
            if (-not (Test-Path $file)) { Fail "listed in series but missing: $rel" }
            Invoke-Git @('-C', $Src, 'apply', '--3way', '--whitespace=nowarn', $file) "patch $rel" | Out-Null
            Write-Info "$rel ok"
        }
    } else {
        Write-Info "no evil patches yet"
    }

    Set-Content -Path (Join-Path $Src ".evil-patches-applied") -Value (Get-Date -Format o)
    Set-Status "patch ok"
}

function Stage-Build {
    Use-DepotTools
    if ($Jobs -le 0) { $Jobs = [Environment]::ProcessorCount }

    Write-Step "assembling GN args"
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $argsFiles = @()
    $ungoogledFlags = Join-Path $Ungoogled "flags.gn"
    if (Test-Path $ungoogledFlags) { $argsFiles += $ungoogledFlags }
    $argsFiles += (Join-Path $Root "build\args\common.gni")
    $argsFiles += (Join-Path $Root "build\args\win.gni")
    $argsFiles += (Join-Path $Root "build\args\$Config.gni")
    if ($Config -eq 'release') { $argsFiles += (Join-Path $Root "build\args\performance.gni") }
    $local = Join-Path $Root "build\args\local.gni"
    if (Test-Path $local) { $argsFiles += $local }

    $lines = @("target_cpu = `"x64`"")
    foreach ($f in $argsFiles) { $lines += ""; $lines += (Get-Content $f) }
    Set-Content -Path (Join-Path $OutDir "args.gn") -Value $lines -Encoding ascii
    Write-Info "$($argsFiles.Count) argument files merged into out\$Config\args.gn"

    Write-Step "gn gen"
    Invoke-Native "cmd.exe" "/c gn gen `"$OutDir`"" $Src "gn gen"

    Write-Step "building $Target with $Jobs jobs"
    Set-Status "build started $Target"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Native "cmd.exe" "/c autoninja -j $Jobs -C `"$OutDir`" $Target" $Src "autoninja"
    $sw.Stop()
    Write-Info "built in $([math]::Round($sw.Elapsed.TotalHours,2)) hours"
    Set-Status "build ok $Target in $([math]::Round($sw.Elapsed.TotalHours,2))h"
}

function Stage-Package {
    Write-Step "packaging"
    $dist = Join-Path $Root "dist"
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    $version = (Get-Content (Join-Path $Src "chrome\VERSION")) -join "." -replace '[A-Z_]+=', ''
    $installer = Join-Path $OutDir "mini_installer.exe"
    if (-not (Test-Path $installer)) { Fail "mini_installer.exe not found, build it first" }
    Copy-Item $installer (Join-Path $dist "evil-$version-x64.exe") -Force
    Write-Info "dist\evil-$version-x64.exe"

    $zip = Join-Path $dist "evil-$version-x64-portable.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    $items = @('chrome.exe','*.dll','*.pak','*.bin','icudtl.dat','locales','resources') |
        ForEach-Object { Get-ChildItem -Path $OutDir -Filter $_ -ErrorAction SilentlyContinue }
    Compress-Archive -Path $items.FullName -DestinationPath $zip -CompressionLevel Optimal
    Write-Info "dist\$(Split-Path $zip -Leaf)"

    Get-ChildItem $dist -File | ForEach-Object {
        "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower())  $($_.Name)"
    } | Set-Content -Path (Join-Path $dist "SHA256SUMS") -Encoding ascii
    Get-Content (Join-Path $dist "SHA256SUMS") | ForEach-Object { Write-Info $_ }
    Set-Status "package ok"
}

Resolve-Tooling

Write-Host ""
Write-Step "evil windows build, stage: $Stage"
Write-Info "root:      $Root"
Write-Info "git:       $((git --version) -replace 'git version ','')"
Write-Info "python:    $((python --version) -replace 'Python ','')"
Write-Info "chromium:  $ChromiumVersion"
Write-Info "ungoogled: $UngoogledVersion"
Write-Host ""

switch ($Stage) {
    'bootstrap' { Stage-Bootstrap }
    'sync'      { Stage-Sync }
    'upstream'  { Stage-Upstream }
    'patch'     { Stage-Patch }
    'build'     { Stage-Build }
    'package'   { Stage-Package }
    'all'       { Stage-Bootstrap; Stage-Sync; Stage-Upstream; Stage-Patch; Stage-Build; Stage-Package }
}

Write-Host ""
Write-Step "stage '$Stage' complete"
