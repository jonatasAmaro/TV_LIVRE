# Debloat MIRAGE TV Box - Remove apps desnecessários para otimizar RAM/ROM
# AVISO: Desabilita (não deleta) - pode ser revertido com enable
param(
    [string]$DeviceIP = "192.168.18.16:5555"
)

Write-Host "=== MIRAGE Debloat - Otimização de Performance ===" -ForegroundColor Cyan
Write-Host "Apenas desabilita (pm disable-user). Para reverter: pm enable <pacote>" -ForegroundColor DarkGray

adb connect $DeviceIP
Start-Sleep -Seconds 2

# SOMENTE pacotes 100% seguros — NÃO desabilitar providers nem softwinner
$bloatware = @(
    "com.android.egg"                      # Easter egg
    "com.android.htmlviewer"               # Visualizador HTML
    "com.android.companiondevicemanager"   # Companion devices
    "com.android.wallpapercropper"        # Wallpaper cropper
    "com.google.android.soundpicker"      # Sound picker
    "com.example.a"                       # App de teste
)

$disabled = 0
foreach ($pkg in $bloatware) {
    $result = adb -s $DeviceIP shell pm disable-user --user 0 $pkg 2>&1
    if ($result -match "disabled") {
        Write-Host "  [OK] $pkg" -ForegroundColor Green
        $disabled++
    } else {
        Write-Host "  [--] $pkg (já desabilitado ou não existe)" -ForegroundColor DarkGray
    }
}

Write-Host "`n=== $disabled pacotes desabilitados ===" -ForegroundColor Cyan

# Limpar cache do sistema
Write-Host "Limpando caches..." -ForegroundColor Yellow
adb -s $DeviceIP shell pm trim-caches 500M

# Mostrar RAM liberada
$memInfo = adb -s $DeviceIP shell cat /proc/meminfo | Select-String "MemAvailable"
Write-Host "RAM disponível: $memInfo" -ForegroundColor Green

Write-Host "`nPara reverter TUDO:" -ForegroundColor Yellow
Write-Host '  $bloatware | ForEach-Object { adb shell pm enable $_ }' -ForegroundColor DarkGray
