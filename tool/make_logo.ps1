# Draws the Basirah logo from its geometry (the same numbers as
# BrandMarkPainter in lib/shared/brand.dart) and writes every icon:
#   assets/brand/logo.png          the flat gold mark, transparent
#   web/logo.png                   app-icon tile, web loading screen
#   web/favicon.png                app-icon tile
#   web/icons/Icon-*.png           installable web app (tile; maskable = full bleed)
#   android/.../mipmap-*/ic_launcher.png
#
#   powershell -ExecutionPolicy Bypass -File tool/make_logo.ps1
Add-Type -AssemblyName System.Drawing

$gold = [System.Drawing.Color]::FromArgb(255, 0xC9, 0x93, 0x2C)       # BrandColors.gold
$goldOnInk = [System.Drawing.Color]::FromArgb(255, 0xE2, 0xB0, 0x4E)  # BrandColors.goldOnInk
$ink = [System.Drawing.Color]::FromArgb(255, 0x18, 0x17, 0x1C)        # BrandColors.ink

# (centre x, centre y, radius, exponent) as fractions of the side — BrandMarkPainter.stars
$stars = @(@(0.50, 0.50, 0.47, 4.6), @(0.295, 0.265, 0.095, 3.4), @(0.715, 0.725, 0.082, 3.4))

function Get-Star([double]$cx, [double]$cy, [double]$r, [double]$n) {
  $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
  for ($i = 0; $i -lt 1440; $i++) {
    $t = 2 * [Math]::PI * $i / 1440
    $c = [Math]::Cos($t); $s = [Math]::Sin($t)
    $x = $r * [Math]::Sign($c) * [Math]::Pow([Math]::Abs($c), $n)
    $y = $r * [Math]::Sign($s) * [Math]::Pow([Math]::Abs($s), $n)
    $pts.Add((New-Object System.Drawing.PointF ([float]($cx + $x)), ([float]($cy + $y))))
  }
  return ,$pts.ToArray()
}

function Draw-Mark($g, [double]$x0, [double]$y0, [double]$side, [System.Drawing.Color]$color) {
  $brush = New-Object System.Drawing.SolidBrush $color
  foreach ($s in $stars) {
    $g.FillPolygon($brush, (Get-Star ($x0 + $s[0] * $side) ($y0 + $s[1] * $side) ($s[2] * $side) $s[3]))
  }
  $brush.Dispose()
}

function Fill-RoundRect($g, [System.Drawing.Color]$color, [double]$x, [double]$y, [double]$w, [double]$rad) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2 * $rad
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $w - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $w - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  $b = New-Object System.Drawing.SolidBrush $color
  $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
}

# Renders at 4x and scales down for clean edges at small sizes.
function Save-Icon([int]$size, [string]$path, [string]$kind) {
  $k = 4; $big = $size * $k
  $bmp = New-Object System.Drawing.Bitmap $big, $big, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  switch ($kind) {
    'mark' { Draw-Mark $g 0 0 $big $gold }
    'tile' {
      Fill-RoundRect $g $ink 0 0 $big ($big * 0.23)
      $m = $big * 0.70; Draw-Mark $g (($big - $m) / 2) (($big - $m) / 2) $m $goldOnInk
    }
    'bleed' {
      $g.Clear($ink)
      $m = $big * 0.58; Draw-Mark $g (($big - $m) / 2) (($big - $m) / 2) $m $goldOnInk
    }
  }
  $g.Dispose()
  $out = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g2 = [System.Drawing.Graphics]::FromImage($out)
  $g2.InterpolationMode = 'HighQualityBicubic'; $g2.PixelOffsetMode = 'HighQuality'
  $g2.DrawImage($bmp, 0, 0, $size, $size)
  $g2.Dispose(); $bmp.Dispose()
  New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
  $out.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $out.Dispose()
}

$root = Split-Path -Parent $PSScriptRoot
Save-Icon 512 "$root\assets\brand\logo.png" 'mark'
Save-Icon 256 "$root\web\logo.png" 'tile'
Save-Icon 48  "$root\web\favicon.png" 'tile'
Save-Icon 192 "$root\web\icons\Icon-192.png" 'tile'
Save-Icon 512 "$root\web\icons\Icon-512.png" 'tile'
Save-Icon 192 "$root\web\icons\Icon-maskable-192.png" 'bleed'
Save-Icon 512 "$root\web\icons\Icon-maskable-512.png" 'bleed'
$android = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($d in $android.Keys) {
  Save-Icon $android[$d] "$root\android\app\src\main\res\mipmap-$d\ic_launcher.png" 'tile'
}
"icons written"
