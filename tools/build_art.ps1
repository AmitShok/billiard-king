# Rebuilds all Vertical Billiard pixel art from the Aseprite Lua scripts in tools/.
# Usage: powershell -File tools/build_art.ps1 [-Only art_tiles] [-Preview]
#   -Preview also writes 4x nearest-neighbour previews to docs/art_preview/ (not shipped).
param(
    [string]$Only = '',
    [switch]$Preview,
    [string]$AsepritePath = 'C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $AsepritePath)) { throw 'Set -AsepritePath to the installed Aseprite executable.' }
$scripts = Get-ChildItem -LiteralPath (Join-Path $root 'tools') -Filter 'art_*.lua' | Where-Object { $_.Name -ne 'art_lib.lua' }
if ($Only) { $scripts = $scripts | Where-Object { $_.BaseName -eq $Only } }
foreach ($s in $scripts) {
    $out = Join-Path $env:TEMP 'bk_ase_out.txt'
    $err = Join-Path $env:TEMP 'bk_ase_err.txt'
    $p = Start-Process -FilePath $AsepritePath -ArgumentList @('-b', '--script-param', ('root="' + $root + '"'), '--script', ('"' + $s.FullName + '"')) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
    $log = (Get-Content $out -Raw) + (Get-Content $err -Raw)
    if ($p.ExitCode -ne 0 -or $log -match 'error') { throw "Aseprite failed on $($s.Name): $log" }
    Write-Output ("{0}: {1}" -f $s.BaseName, $log.Trim())
}
if ($Preview) {
    $dir = Join-Path $root 'docs/art_preview'
    New-Item -ItemType Directory -Force $dir | Out-Null
    foreach ($png in Get-ChildItem -LiteralPath (Join-Path $root 'assets/textures') -Filter '*.png') {
        $dst = Join-Path $dir $png.Name
        Start-Process -FilePath $AsepritePath -ArgumentList @('-b', ('"' + $png.FullName + '"'), '--scale', '4', '--save-as', ('"' + $dst + '"')) -Wait -NoNewWindow | Out-Null
    }
}
