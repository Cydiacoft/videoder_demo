# Generates the native icon from the same vector geometry as assets/branding/app_icon.svg.
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
function New-RoundPath([single]$x,[single]$y,[single]$w,[single]$h,[single]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x,$y,$d,$d,180,90)
    $path.AddArc(($x+$w-$d),$y,$d,$d,270,90)
    $path.AddArc(($x+$w-$d),($y+$h-$d),$d,$d,0,90)
    $path.AddArc($x,($y+$h-$d),$d,$d,90,90)
    $path.CloseFigure()
    return $path
}
function New-IconPng([int]$size) {
    $bitmap = New-Object System.Drawing.Bitmap ($size*4),($size*4)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = 'AntiAlias'
    $g.ScaleTransform(($size*4/1024.0),($size*4/1024.0))
    $path = New-RoundPath 64 64 896 896 208
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush ([System.Drawing.Point]::new(64,64)),([System.Drawing.Point]::new(960,960)),([System.Drawing.ColorTranslator]::FromHtml('#8795F2')),([System.Drawing.ColorTranslator]::FromHtml('#45448E'))
    $g.FillPath($brush,$path)
    foreach ($bar in @(@(248,424,56,176),@(336,336,56,352),@(424,248,56,528),@(512,352,56,320),@(600,432,56,160))) {
        $wave = New-RoundPath $bar[0] $bar[1] $bar[2] $bar[3] 28
        $g.FillPath([System.Drawing.Brushes]::White,$wave)
        $wave.Dispose()
    }
    $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#8EF0DA'))
    $g.FillPolygon($accent,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(704,408),[System.Drawing.PointF]::new(844,512),[System.Drawing.PointF]::new(704,616)))
    $small = New-Object System.Drawing.Bitmap $size,$size
    $sg = [System.Drawing.Graphics]::FromImage($small)
    $sg.InterpolationMode = 'HighQualityBicubic'
    $sg.DrawImage($bitmap,0,0,$size,$size)
    $stream = New-Object System.IO.MemoryStream
    $small.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $stream.ToArray()
    $stream.Dispose(); $sg.Dispose(); $small.Dispose(); $g.Dispose(); $bitmap.Dispose(); $path.Dispose(); $brush.Dispose(); $accent.Dispose()
    return ,$bytes
}
[System.IO.File]::WriteAllBytes((Join-Path $root 'assets/branding/app_icon.png'),(New-IconPng 1024))
$sizes = @(16,24,32,48,64,128,256)
$images = @($sizes | ForEach-Object { ,(New-IconPng $_) })
$ico = [System.IO.File]::Create((Join-Path $root 'windows/runner/resources/app_icon.ico'))
$writer = New-Object System.IO.BinaryWriter $ico
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
$offset = 6 + 16*$sizes.Count
for ($i=0;$i -lt $sizes.Count;$i++) {
    $dimension = if ($sizes[$i] -eq 256) {0} else {$sizes[$i]}
    $writer.Write([byte]$dimension); $writer.Write([byte]$dimension); $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$images[$i].Length); $writer.Write([uint32]$offset)
    $offset += $images[$i].Length
}
foreach ($bytes in $images) { $writer.Write([byte[]]$bytes) }
$writer.Dispose()
foreach ($size in @(16,32,64,128,256,512,1024)) {
    [System.IO.File]::WriteAllBytes((Join-Path $root "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png"),(New-IconPng $size))
}
foreach ($entry in @{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}.GetEnumerator()) {
    [System.IO.File]::WriteAllBytes((Join-Path $root "android/app/src/main/res/mipmap-$($entry.Key)/ic_launcher.png"),(New-IconPng $entry.Value))
}
