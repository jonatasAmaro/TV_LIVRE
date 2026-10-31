param([string]$Out)
# White gear icon (tinted in the app with Poster.blendColor).
Add-Type -AssemblyName System.Drawing
$size = 96
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$c = $size / 2
$teeth = 8
$outer = 44; $inner = 34; $hole = 14
$pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
for ($i = 0; $i -lt $teeth * 4; $i++) {
    $ang = [Math]::PI * 2 * $i / ($teeth * 4)
    $r = if (($i % 4) -lt 2) { $outer } else { $inner }
    $pts.Add((New-Object System.Drawing.PointF ([single]($c + $r * [Math]::Cos($ang))), ([single]($c + $r * [Math]::Sin($ang)))))
}
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddPolygon($pts.ToArray())
$path.AddEllipse([single]($c - $hole), [single]($c - $hole), [single]($hole * 2), [single]($hole * 2))
$path.FillMode = 'Alternate'
$g.FillPath([System.Drawing.Brushes]::White, $path)
$g.Dispose()
$bmp.Save((Join-Path $Out "gear.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "gear ok"
