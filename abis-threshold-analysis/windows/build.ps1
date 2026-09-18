param(
    [string]$RVersion = "4.5.2",
    [bool]$IncludeResults = $false
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if ($env:OS -ne "Windows_NT") { throw "Build on Windows x64." }
if ($RVersion -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid R version." }

$project = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $project -Parent
$dist = Join-Path $repo "dist"
$stage = Join-Path $dist "stage"
$bundle = Join-Path $stage "ABIS"
if (Test-Path $dist) { throw "dist already exists; use a clean checkout for this build." }
New-Item -ItemType Directory -Force -Path $bundle | Out-Null
$runtime = Join-Path $bundle "runtime"
$library = Join-Path $bundle "library"
$app = Join-Path $bundle "app"
$installers = Join-Path $bundle "installers"
New-Item -ItemType Directory -Force -Path $library, $app, $installers | Out-Null

# Install the official distribution into the staging folder on the build machine.
# The ZIP contains this runtime and the original installer for offline installation.
$installer = Join-Path $installers "R-$RVersion-win.exe"
$url = "https://cran.r-project.org/bin/windows/base/old/$RVersion/R-$RVersion-win.exe"
Invoke-WebRequest -Uri $url -OutFile $installer
$process = Start-Process -FilePath $installer -ArgumentList @(
    "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", "/NOICONS",
    "/DIR=`"$runtime`"", "/MERGETASKS=!desktopicon,!quicklaunchicon,!recordversion,!associate"
) -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "R installer failed: $($process.ExitCode)" }

function Find-Rscript([string]$Root) {
    foreach ($relative in @("bin\Rscript.exe", "bin\x64\Rscript.exe")) {
        $path = Join-Path $Root $relative
        if (Test-Path $path) { return $path }
    }
    throw "Rscript.exe not found in $Root"
}
function Run-R([string]$Executable, [string[]]$RArgs) {
    & $Executable @RArgs
    if ($LASTEXITCODE -ne 0) { throw "R command failed: $($RArgs -join ' ')" }
}

$rscript = Find-Rscript $runtime
$env:R_LIBS_USER = $library
$env:R_LIBS_SITE = $library
Run-R $rscript @("--vanilla", (Join-Path $PSScriptRoot "install_packages.R"), $library)

Copy-Item (Join-Path $project "app.R") $app
Copy-Item (Join-Path $project "R") $app -Recurse
Copy-Item (Join-Path $project "tests") $app -Recurse
Copy-Item (Join-Path $project "README.md") $app
New-Item -ItemType Directory -Force -Path (Join-Path $app "data") | Out-Null
$dataFile = if ($IncludeResults) { Join-Path $project "data/results.csv" } else { Join-Path $PSScriptRoot "sample-results.csv" }
Copy-Item $dataFile (Join-Path $app "data/results.csv")
$thresholdFile = Join-Path $project "data/thresholds.csv"
if (Test-Path $thresholdFile) { Copy-Item $thresholdFile (Join-Path $app "data/thresholds.csv") }
foreach ($file in @("Start ABIS.cmd", "Test offline runtime.cmd", "launch.R", "verify_runtime.R")) {
    Copy-Item (Join-Path $PSScriptRoot $file) $bundle
}
# Windows command files use CRLF even when Git checked out LF source files.
foreach ($file in @("Start ABIS.cmd", "Test offline runtime.cmd")) {
    $path = Join-Path $bundle $file
    $text = [IO.File]::ReadAllText($path) -replace '\r?\n', "`r`n"
    [IO.File]::WriteAllText($path, $text, [Text.Encoding]::ASCII)
}
Copy-Item (Join-Path $PSScriptRoot "README.md") (Join-Path $bundle "WINDOWS-README.md")
[IO.File]::WriteAllText((Join-Path $bundle "R-version.txt"), $RVersion)

# Test a moved copy with spaces in its path and no build-time library references.
$relocated = Join-Path ([IO.Path]::GetTempPath()) ("ABIS portable check " + [guid]::NewGuid())
Copy-Item $bundle $relocated -Recurse
$env:R_LIBS_USER = Join-Path $relocated "library"
$env:R_LIBS_SITE = $env:R_LIBS_USER
$movedR = Find-Rscript (Join-Path $relocated "runtime")
Run-R $movedR @("--vanilla", (Join-Path $relocated "verify_runtime.R"))
Push-Location (Join-Path $relocated "app")
try {
    Run-R $movedR @("--vanilla", "tests/run_tests.R")
    Run-R $movedR @("--vanilla", "tests/test_shiny.R")
} finally { Pop-Location }

# Verify Shiny serves HTTP using the launcher in test mode without opening a browser.
$stdout = Join-Path $dist "smoke-stdout.log"
$stderr = Join-Path $dist "smoke-stderr.log"
$server = Start-Process -FilePath $movedR -ArgumentList @(
    "--vanilla", "`"$(Join-Path $relocated 'launch.R')`"", "--smoke-test"
) -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try {
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        if ($server.HasExited) { throw "Shiny exited early: $(Get-Content $stderr -Raw)" }
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:3876" -TimeoutSec 2
            if ($response.StatusCode -eq 200 -and $response.Content -match 'ABIS') { $ready = $true; break }
        } catch { Start-Sleep -Seconds 1 }
    }
    if (-not $ready) { throw "Shiny HTTP smoke test failed: $(Get-Content $stderr -Raw)" }
} finally {
    # Rscript can launch a child process on Windows; stop the entire tree.
    if (-not $server.HasExited) {
        & taskkill.exe /PID $server.Id /T /F | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $server.Refresh()
            if (-not $server.HasExited) { throw "Could not stop the Shiny test process tree." }
        }
    }
    if (-not $server.WaitForExit(15000)) { throw "Shiny test process did not exit." }
    $server.Dispose()
}
# Windows may retain directory/DLL locks briefly after process termination.
for ($attempt = 1; $attempt -le 6; $attempt++) {
    try {
        Remove-Item $relocated -Recurse -Force -ErrorAction Stop
        break
    } catch {
        if ($attempt -eq 6) {
            Write-Warning "Temporary test folder could not be removed: $relocated. Continuing ZIP creation. $($_.Exception.Message)"
        } else { Start-Sleep -Seconds 1 }
    }
}

$zip = Join-Path $dist "abis-windows-x64.zip"
Compress-Archive -Path $bundle -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$zip.sha256", "$hash  abis-windows-x64.zip`n")
Write-Host "Created $zip"
