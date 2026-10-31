# Empacota o canal e instala na TV Roku pelo modo desenvolvedor.
# Uso: powershell -ExecutionPolicy Bypass -File deploy.ps1 -RokuIp 192.168.18.93
# Na primeira vez pede a senha e oferece guardá-la criptografada (DPAPI, só este
# usuário do Windows consegue ler). -ForgetPassword apaga a senha guardada.
param(
    [Parameter(Mandatory = $true)][string]$RokuIp,
    [string]$Password,
    [string]$User = "rokudev",
    [switch]$ForgetPassword
)
$ErrorActionPreference = "Stop"
$credFile = Join-Path $env:APPDATA "tv-livre\roku-dev.cred"
if ($ForgetPassword -and (Test-Path $credFile)) {
    Remove-Item $credFile -Force
    Write-Output "Senha guardada apagada."
}
if (-not $Password) {
    $secure = $null
    if (Test-Path $credFile) {
        try { $secure = Get-Content $credFile | ConvertTo-SecureString } catch { $secure = $null }
    }
    if (-not $secure) {
        $secure = Read-Host "Senha do modo desenvolvedor da Roku" -AsSecureString
        $save = Read-Host "Guardar a senha neste PC para as próximas instalações? (s/n)"
        if ($save -match '^[sS]') {
            New-Item -ItemType Directory -Force (Split-Path $credFile) | Out-Null
            $secure | ConvertFrom-SecureString | Set-Content $credFile
        }
    }
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$src = Join-Path $PSScriptRoot "roku-tv-livre"
$zip = Join-Path $PSScriptRoot "tv-livre.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
# Build entries by hand: .NET Framework's CreateFromDirectory writes "source\main.brs"
# (backslashes), which the Roku rejects as a missing /source directory.
$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem -Path $src -Recurse -File | Where-Object { $_.FullName -notmatch '\\out\\' } | ForEach-Object {
        $entry = $_.FullName.Substring($src.Length + 1).Replace('\', '/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $entry)
    }
} finally {
    $archive.Dispose()
}
Write-Output "Pacote criado: $zip"

$bodyFile = Join-Path $PSScriptRoot "deploy-response.html"
# Credentials go through a temporary curl config file (UTF-8) so special characters
# in the password are not mangled by Windows PowerShell argument quoting.
$curlCfg = Join-Path $env:TEMP ("roku-" + [guid]::NewGuid().ToString() + ".cfg")
$escaped = ("${User}:${Password}").Replace('\', '\\').Replace('"', '\"')
[System.IO.File]::WriteAllText($curlCfg, "user = `"$escaped`"`n", (New-Object System.Text.UTF8Encoding $false))
try {
    $status = & curl.exe --silent --show-error --digest -K $curlCfg `
        -F "mysubmit=Install" -F "archive=@$zip" -o $bodyFile -w "%{http_code}" "http://$RokuIp/plugin_install"
} finally {
    Remove-Item $curlCfg -Force -ErrorAction SilentlyContinue
}
if ($LASTEXITCODE -ne 0) { throw "Falha ao enviar para a Roku (curl código $LASTEXITCODE)." }
if ($status -eq "401") {
    if (Test-Path $credFile) { Remove-Item $credFile -Force }
    throw "Senha recusada pela Roku (HTTP 401). Confira a senha do modo desenvolvedor."
}
if ($status -ne "200") { throw "A Roku respondeu HTTP $status." }

$body = ""
if (Test-Path $bodyFile) { $body = [string](Get-Content -Raw $bodyFile) }
$msgs = [regex]::Matches($body, "<font color=`"red`">([^<]*)</font>") | ForEach-Object { $_.Groups[1].Value }
$msgs += [regex]::Matches($body, "'(Install Success[^']*|Identical to previous[^']*|Failure[^']*)'") | ForEach-Object { $_.Groups[1].Value }
if ($msgs) { $msgs | ForEach-Object { Write-Output "Roku: $_" } } else { Write-Output "Enviado (HTTP 200). Confira a TV." }
