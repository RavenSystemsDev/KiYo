param(
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64',
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$Version = '0.1.0-alpha.3'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$output = Join-Path $root "artifacts/KiYo-Windows-$Version-$Runtime"
if (Test-Path $output) { Remove-Item -Recurse -Force $output }
dotnet publish "$root/KiYo.Windows/KiYo.Windows.csproj" -c Release -r $Runtime --self-contained true -p:PublishSingleFile=false -p:DebugType=None -p:DebugSymbols=false -p:IncludeSourceRevisionInInformationalVersion=false -p:Version=$Version -o $output
if ($LASTEXITCODE -ne 0) { throw 'Publish failed' }
# Resolve exact runtime versions from this build, not another cached package version.
$nuget = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $HOME '.nuget/packages' }
$dependencies = Get-Content (Join-Path $output 'KiYo.deps.json') -Raw | ConvertFrom-Json
$notices = Join-Path $output 'runtime-notices'
New-Item -ItemType Directory -Force $notices | Out-Null
foreach ($package in @("microsoft.netcore.app.runtime.$Runtime", "microsoft.windowsdesktop.app.runtime.$Runtime")) {
    $entries = @($dependencies.libraries.PSObject.Properties.Name | Where-Object {
        ($_ -split '/', 2)[0] -ieq "runtimepack.$package"
    })
    if ($entries.Count -ne 1) { throw "Runtime dependency missing or ambiguous: $package" }
    $runtimeVersion = ($entries[0] -split '/', 2)[1]
    $packagePath = Join-Path (Join-Path $nuget $package) $runtimeVersion
    $files = @(Get-ChildItem $packagePath -File | Where-Object {
        $_.Name -match '^(LICENSE|THIRD[-]?PARTY[-]?NOTICES)(\.(TXT|MD))?$'
    })
    if (-not ($files | Where-Object { $_.Name -match '^LICENSE' })) {
        throw "Runtime license missing: $package/$runtimeVersion"
    }
    $destination = Join-Path $notices "$package-$runtimeVersion"
    New-Item -ItemType Directory -Force $destination | Out-Null
    $files | ForEach-Object { Copy-Item $_.FullName (Join-Path $destination $_.Name) -Force }
}
Copy-Item "$root/INSTALL.txt" "$output/START-HERE.txt"
$zip = "$output.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $output -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($zip))" | Set-Content "$zip.sha256" -Encoding ascii
Write-Output $zip
