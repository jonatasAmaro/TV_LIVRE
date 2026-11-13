#!/usr/bin/env pwsh
# Deploy Amaro TV to LG webOS TV
# Requires: npm install -g @webos-tools/cli

$ErrorActionPreference = "Stop"
$TV_IP = "192.168.18.162"
$DEVICE_NAME = "LGTV"
$APP_ID = "com.amarotv.app"
$APP_DIR = $PSScriptRoot

Write-Host "`n=== Amaro TV - webOS Deploy ===" -ForegroundColor Cyan

# Check ares-cli
$ares = Get-Command ares-package -ErrorAction SilentlyContinue
if (-not $ares) {
    Write-Host "ERRO: ares-cli nao instalado." -ForegroundColor Red
    Write-Host "Instale: npm install -g @webos-tools/cli" -ForegroundColor Yellow
    exit 1
}

# Generate placeholder icons if missing
if (-not (Test-Path "$APP_DIR\icon.png")) {
    Write-Host "Gerando icones placeholder..." -ForegroundColor Yellow
    python -c @"
from PIL import Image, ImageDraw, ImageFont
import os

sizes = {'icon.png': (80, 80), 'largeIcon.png': (130, 130), 'splash.png': (1920, 1080)}
for name, size in sizes.items():
    img = Image.new('RGB', size, '#0B0F1A')
    draw = ImageDraw.Draw(img)
    text = 'ATV' if size[0] < 200 else 'Amaro TV'
    bbox = draw.textbbox((0, 0), text)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((size[0]-tw)//2, (size[1]-th)//2), text, fill='#E67E22')
    img.save(os.path.join(r'$APP_DIR', name))
    print(f'  {name} ({size[0]}x{size[1]})')
"@
    if ($LASTEXITCODE -ne 0) {
        Write-Host "PIL nao disponivel, criando icones minimos com canvas..." -ForegroundColor Yellow
        # Create minimal valid PNGs using .NET
        Add-Type -AssemblyName System.Drawing
        foreach ($item in @(@("icon.png",80,80), @("largeIcon.png",130,130), @("splash.png",1920,1080))) {
            $fname = $item[0]; $w = [int]$item[1]; $h = [int]$item[2]
            $bmp = New-Object System.Drawing.Bitmap($w, $h)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.Clear([System.Drawing.Color]::FromArgb(11, 15, 26))
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 126, 34))
            $font = New-Object System.Drawing.Font("Arial", [Math]::Max(10, $w / 6))
            $text = if ($w -lt 200) { "ATV" } else { "Amaro TV" }
            $sz = $g.MeasureString($text, $font)
            $g.DrawString($text, $font, $brush, ($w - $sz.Width) / 2, ($h - $sz.Height) / 2)
            $g.Dispose()
            $bmp.Save("$APP_DIR\$fname", [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
            Write-Host "  $fname ($w x $h)"
        }
    }
}

# Check device setup
Write-Host "`nVerificando device '$DEVICE_NAME'..." -ForegroundColor Cyan
$devices = ares-setup-device --list 2>&1
if ($devices -notmatch $DEVICE_NAME) {
    Write-Host "Device '$DEVICE_NAME' nao encontrado. Configurando..." -ForegroundColor Yellow
    Write-Host "ATENCAO: Voce precisa do Key Server password da tela Dev Mode na TV" -ForegroundColor Yellow
    $pass = Read-Host "Key Server password (da TV)"
    ares-setup-device --add $DEVICE_NAME --info "{'host':'$TV_IP','port':'9922','username':'prisoner','password':'$pass'}"
}

# Package
Write-Host "`nEmpacotando app..." -ForegroundColor Cyan
Push-Location $APP_DIR
ares-package .
$ipk = Get-ChildItem -Filter "${APP_ID}_*.ipk" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $ipk) {
    Write-Host "ERRO: empacotamento falhou" -ForegroundColor Red
    Pop-Location; exit 1
}
Write-Host "  Pacote: $($ipk.Name)" -ForegroundColor Green

# Install
Write-Host "`nInstalando na TV..." -ForegroundColor Cyan
ares-install --device $DEVICE_NAME $ipk.Name
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: instalacao falhou. Verifique Dev Mode na TV." -ForegroundColor Red
    Pop-Location; exit 1
}
Write-Host "  Instalado!" -ForegroundColor Green

# Launch
Write-Host "`nLancando app..." -ForegroundColor Cyan
ares-launch --device $DEVICE_NAME $APP_ID
Write-Host "  Lancado!" -ForegroundColor Green

Pop-Location
Write-Host "`n=== Deploy completo! ===" -ForegroundColor Green
Write-Host "Para debug: ares-inspect --device $DEVICE_NAME $APP_ID"
