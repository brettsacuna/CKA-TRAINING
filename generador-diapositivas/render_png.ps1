param([string]$Pptx, [string]$OutDir)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$pp = New-Object -ComObject PowerPoint.Application
$deck = $pp.Presentations.Open($Pptx, $true, $false, $false)
$w = 1600; $h = 900
for ($i = 1; $i -le $deck.Slides.Count; $i++) {
    $f = Join-Path $OutDir ("slide{0:D2}.png" -f $i)
    $deck.Slides.Item($i).Export($f, "PNG", $w, $h)
}
$deck.Close()
$pp.Quit()
Write-Output "exported $($deck.Slides.Count) slides"
