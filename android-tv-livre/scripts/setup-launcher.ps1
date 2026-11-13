# Setup Amaro TV como launcher padrão no MIRAGE
# Executa via ADB após instalar o APK
param(
    [string]$DeviceIP = "192.168.18.16:5555"
)

Write-Host "=== Amaro TV - Setup Launcher ===" -ForegroundColor Cyan

# 1. Conectar ADB
adb connect $DeviceIP
Start-Sleep -Seconds 2

# 2. Instalar APK (se existir)
$apkPath = Join-Path $PSScriptRoot "..\app\build\outputs\apk\release\app-release.apk"
if (Test-Path $apkPath) {
    Write-Host "Instalando APK..." -ForegroundColor Yellow
    adb -s $DeviceIP install -r $apkPath
}

# 3. Configurar como launcher padrão
Write-Host "Configurando como launcher padrão..." -ForegroundColor Yellow
# Limpar launcher atual
adb -s $DeviceIP shell cmd package set-home-activity com.amarotv.tvlivre/.ui.MainActivity

# 4. Habilitar auto-start no boot
adb -s $DeviceIP shell pm enable com.amarotv.tvlivre/.BootReceiver

Write-Host "=== Concluído! Reinicie o MIRAGE para testar ===" -ForegroundColor Green
Write-Host "Para reverter: adb shell cmd package set-home-activity com.android.tv.settings/.MainSettings" -ForegroundColor DarkGray
