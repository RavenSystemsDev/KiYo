# Build dependency only, installed into the ephemeral CI runner's temporary folder.
param([Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows is required.' }
$download = Join-Path ([IO.Path]::GetTempPath()) ('kiyo-inno-' + [Guid]::NewGuid() + '.exe')
try {
    Invoke-WebRequest 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe' -OutFile $download
    $expected = '9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732'
    if ((Get-FileHash $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'Inno Setup SHA256 mismatch' }
    $signature = Get-AuthenticodeSignature $download
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Pyrsys B\.V\.') {
        throw 'Inno Setup publisher verification failed'
    }
    $process = Start-Process $download -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-', "/DIR=`"$Destination`"") -PassThru
    if (-not $process.WaitForExit(120000)) { $process.Kill(); throw 'Compiler installation timed out' }
    if ($process.ExitCode -ne 0) { throw "Compiler installation failed: $($process.ExitCode)" }
} finally { Remove-Item $download -Force -ErrorAction SilentlyContinue }
