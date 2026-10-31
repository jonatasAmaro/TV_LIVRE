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
