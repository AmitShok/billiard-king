# Runs the project's Godot 4.7 with arguments and prints its output.
# Usage: powershell -File tools/godot.ps1 --headless --script tools/build_tower.gd
# Never stops other Godot processes (the editor may be open).
$ErrorActionPreference = 'Stop'
$godot = 'C:\Users\Amit Shok\Desktop\Godot_v4.7-stable_win64.exe'
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $env:TEMP ('bk_godot_' + [guid]::NewGuid().ToString('N') + '.txt')
$err = $out + '.err'
$quoted = @('--path', ('"' + $root + '"')) + ($args | ForEach-Object { if ("$_" -match '\s') { '"' + $_ + '"' } else { "$_" } })
$p = Start-Process -FilePath $godot -ArgumentList $quoted -Wait -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
Get-Content $out
Get-Content $err
Remove-Item $out, $err -ErrorAction SilentlyContinue
exit $p.ExitCode
