# Restaurar MIRAGE ao estado original
# Reverte debloat e remove launcher customizado
param(
    [string]$DeviceIP = "192.168.18.16:5555"
)

Write-Host "=== MIRAGE - Restauração Completa ===" -ForegroundColor Yellow

adb connect $DeviceIP
Start-Sleep -Seconds 2

# 1. Restaurar launcher original
Write-Host "Restaurando launcher original..." -ForegroundColor Cyan
adb -s $DeviceIP shell cmd package set-home-activity com.android.tv.settings/.MainSettings

# 2. Re-habilitar todos os pacotes do backup
$backupFile = Join-Path $PSScriptRoot "..\..\mirage-backup\system-packages.txt"
if (Test-Path $backupFile) {
    $packages = Get-Content $backupFile | ForEach-Object { $_ -replace "package:", "" }
    foreach ($pkg in $packages) {
        adb -s $DeviceIP shell pm enable $pkg 2>$null
    }
    Write-Host "Pacotes de sistema restaurados." -ForegroundColor Green
} else {
    Write-Host "AVISO: Arquivo de backup não encontrado em $backupFile" -ForegroundColor Red
}

# 3. Desinstalar Amaro TV (opcional)
Write-Host "Desinstalando Amaro TV..." -ForegroundColor Cyan
adb -s $DeviceIP uninstall com.amarotv.tvlivre

Write-Host "`n=== Restauração concluída. Reinicie o aparelho. ===" -ForegroundColor Green
