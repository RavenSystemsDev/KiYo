param(
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64',
    [string]$Version = '0.1.0-alpha.1'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$output = Join-Path $root "artifacts/KiYo-Windows-$Version-$Runtime"
if (Test-Path $output) { Remove-Item -Recurse -Force $output }
dotnet publish "$root/KiYo.Windows/KiYo.Windows.csproj" -c Release -r $Runtime --self-contained true -p:PublishSingleFile=false -p:Version=$Version -o $output
if ($LASTEXITCODE -ne 0) { throw 'Publish failed' }
# Runtime license files come from the same official packages used by publish.
$nuget = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $HOME '.nuget/packages' }
$notices = Join-Path $output 'runtime-notices'
New-Item -ItemType Directory -Force $notices | Out-Null
foreach ($package in @("microsoft.netcore.app.runtime.$Runtime", "microsoft.windowsdesktop.app.runtime.$Runtime")) {
    $packagePath = Join-Path $nuget $package
    $versions = Get-ChildItem $packagePath -Directory | Sort-Object { [version]$_.Name } -Descending
    if (-not $versions) { throw "Runtime package missing: $package" }
    $files = Get-ChildItem $versions[0].FullName -File -Recurse | Where-Object { $_.Name -match '^(LICENSE|ThirdPartyNotices)\.(txt|TXT)$' }
    if (-not $files) { throw "Runtime license notices missing: $package" }
    $destination = Join-Path $notices $package
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
