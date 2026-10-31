param([string]$Out)
Add-Type -AssemblyName System.Drawing

function New-Card([string]$path, [int]$w, [int]$h, [string]$title, [string]$sub, [string]$c1, [string]$c2) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.ColorTranslator]::FromHtml($c1)), ([System.Drawing.ColorTranslator]::FromHtml($c2)), 35
    $g.FillRectangle($brush, $rect)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'
    $fmt.LineAlignment = 'Center'
    $big = New-Object System.Drawing.Font 'Segoe UI', ([single]($h * 0.22)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $small = New-Object System.Drawing.Font 'Segoe UI', ([single]($h * 0.085)), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $white = [System.Drawing.Brushes]::White
    if ($sub) {
        $g.DrawString($title, $big, $white, (New-Object System.Drawing.RectangleF 0, 0, $w, ($h * 0.82)), $fmt)
        $g.DrawString($sub, $small, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 255, 255))), (New-Object System.Drawing.RectangleF 0, ($h * 0.52), $w, ($h * 0.4)), $fmt)
    } else {
        $g.DrawString($title, $big, $white, (New-Object System.Drawing.RectangleF 0, 0, $w, $h), $fmt)
    }
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# Roku 9-patch: 1px border, black pixels on top/left mark the stretchable band.
function New-Pill([string]$path, [bool]$ring) {
    $w = 66; $h = 58; $r = 27
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $x = 1.5; $y = 1.5; $iw = 63 - 1; $ih = 55 - 1
    $d = $r * 2
    $gp.AddArc($x, $y, $d, $ih, 90, 180)
    $gp.AddArc($x + $iw - $d, $y, $d, $ih, 270, 180)
    $gp.CloseFigure()
    if ($ring) {
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 3
        $g.DrawPath($pen, $gp)
    } else {
        $g.FillPath([System.Drawing.Brushes]::White, $gp)
    }
    $g.Dispose()
    $black = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
    for ($i = 0; $i -lt $w; $i++) { $bmp.SetPixel($i, 0, [System.Drawing.Color]::Transparent) }
    for ($i = 0; $i -lt $h; $i++) { $bmp.SetPixel(0, $i, [System.Drawing.Color]::Transparent) }
    for ($i = 31; $i -le 34; $i++) { $bmp.SetPixel($i, 0, $black) }
    for ($i = 27; $i -le 30; $i++) { $bmp.SetPixel(0, $i, $black) }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

New-Card "$Out\icon_hd.png"     290  218  "TV Livre" "" "#9B5DE5" "#E63946"
New-Card "$Out\icon_fhd.png"    540  405  "TV Livre" "" "#9B5DE5" "#E63946"
New-Card "$Out\splash_hd.png"   1280 720  "TV Livre" "filmes  •  séries  •  desenhos  •  ao vivo" "#0B0F1A" "#2B1B4A"
New-Card "$Out\splash_fhd.png"  1920 1080 "TV Livre" "filmes  •  séries  •  desenhos  •  ao vivo" "#0B0F1A" "#2B1B4A"
New-Card "$Out\placeholder.png" 400  225  "TV Livre" "" "#1C2333" "#262F45"
New-Card "$Out\live_camara.png" 400  225  "TV Câmara" "ao vivo" "#0F5132" "#198754"
New-Card "$Out\live_nasa.png"   400  225  "NASA TV" "ao vivo" "#0B3D91" "#FC3D21"
New-Card "$Out\live_tvbrasil.png"    400 225 "TV Brasil" "ao vivo" "#004A8F" "#00A859"
New-Card "$Out\live_tvbrasilint.png" 400 225 "TV Brasil" "internacional" "#00346A" "#0077C8"
New-Card "$Out\live_cultura.png"     400 225 "Cultura" "ao vivo" "#111111" "#E4002B"
New-Card "$Out\live_educacao.png"    400 225 "Educação" "ao vivo" "#5B2C83" "#F7A600"
New-Card "$Out\live_gov.png"         400 225 "Canal Gov" "ao vivo" "#1351B4" "#071D41"
New-Card "$Out\live_recordnews.png"  400 225 "Record News" "ao vivo" "#003C82" "#E30613"
New-Card "$Out\live_redebrasil.png"  400 225 "Rede Brasil" "ao vivo" "#009C3B" "#002776"
New-Card "$Out\live_combrasil.png"   400 225 "COM Brasil" "ao vivo" "#F28C00" "#7A1F00"
New-Card "$Out\live_istv.png"        400 225 "ISTV" "ao vivo" "#0A6EBD" "#06325A"
New-Card "$Out\live_tvcultura.png"   400 225 "TV Cultura" "ao vivo" "#222222" "#E4002B"
New-Card "$Out\live_tvers.png"       400 225 "TVE RS" "ao vivo" "#008542" "#C8102E"
New-Card "$Out\live_sic.png"         400 225 "SIC" "Portugal" "#E2001A" "#5A0008"
New-Card "$Out\live_portocanal.png"  400 225 "Porto Canal" "Portugal" "#0055A4" "#001F3F"
New-Card "$Out\live_adtv.png"        400 225 "ADtv" "Portugal" "#6A1B9A" "#1A0033"
New-Card "$Out\yt_estadio97.png"     400 225 "Estádio 97" "ao vivo no YouTube" "#CC0000" "#3A0000"
Write-Output "images ok"
