param(
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$Version = '0.1.0-alpha.4',
    [string]$Compiler,
    [switch]$SkipPublish
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'The installer compiler requires Windows.' }
if (-not $Compiler) { $Compiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe' }
if (-not (Test-Path $Compiler)) { throw 'Install Inno Setup 6.7.3, or pass -Compiler with its ISCC.exe path.' }
$compilerVersion = (Get-Item $Compiler).VersionInfo.FileVersion
if ($compilerVersion -notmatch '^6\.7\.3(?:\.|$)') { throw "Expected Inno Setup 6.7.3, got $compilerVersion" }
foreach ($runtime in @('win-x64', 'win-arm64')) {
    if (-not $SkipPublish) { & "$PSScriptRoot/package.ps1" -Runtime $runtime -Version $Version -NoArchive }
    $payload = Join-Path $PSScriptRoot "artifacts/KiYo-Windows-$Version-$runtime"
    foreach ($required in @('KiYo.exe','KiYo.dll','KiYo.deps.json','LICENSE.txt','THIRD-PARTY-NOTICES.txt','runtime-notices')) {
        if (-not (Test-Path (Join-Path $payload $required))) { throw "Missing $runtime payload file: $required" }
    }
    $actualVersion = (Get-Item (Join-Path $payload 'KiYo.dll')).VersionInfo.ProductVersion
    if ($actualVersion -ne $Version) { throw "Stale payload version: $actualVersion, expected $Version" }
}
$output = Join-Path $PSScriptRoot 'artifacts/KiYo-Setup.exe'
Remove-Item $output, "$output.sha256" -Force -ErrorAction SilentlyContinue
& $Compiler "/DAppVersion=$Version" "$PSScriptRoot/Installer/KiYo.iss"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $output)) { throw 'Installer compilation failed' }
$hash = (Get-FileHash $output -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  KiYo-Setup.exe" | Set-Content "$output.sha256" -Encoding ascii
Write-Output "Built $output"
