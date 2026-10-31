param([string]$Out)
# Cards for the app shortcuts in TV AO VIVO (reuses New-Card from make_images.ps1).
. (Join-Path $PSScriptRoot "card_lib.ps1")
New-Card (Join-Path $Out "app_maiscanais.png") 1120 630 "+Canais" "OK abre o app" "#6C1D9E" "#1B0A33"
New-Card (Join-Path $Out "app_plutotv.png")    1120 630 "Pluto TV" "OK abre o app" "#2B2B2B" "#F5C400"
New-Card (Join-Path $Out "app_runtime.png")    1120 630 "Runtime" "OK abre o app" "#0D3B66" "#E4572E"
New-Card (Join-Path $Out "app_soplay.png")     1120 630 "SoPlay" "OK abre o app" "#004D40" "#26A69A"
Write-Output "app cards ok"
