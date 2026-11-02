# Runs every Billiard King check. Test saves are isolated (--save-profile).
#   powershell -File tools/run_tests.ps1 [-SkipSolver]
param([switch]$SkipSolver)
$ErrorActionPreference = 'Continue'
$g = Join-Path $PSScriptRoot 'godot.ps1'
$failed = 0
function Run($label, [string[]]$argv) {
    Write-Output "== $label"
    $out = & powershell -ExecutionPolicy Bypass -File $g @argv 2>&1 | Out-String
    $out -split "`n" | Where-Object { $_ -match 'ok  |FAIL|passed|PASS|Explored|Lost balls|Most forgiving|Hardest|SCRIPT ERROR' } | ForEach-Object { $_.TrimEnd() }
    if ($LASTEXITCODE -ne 0) { $script:failed++ }
}
Run 'Gameplay' @('--headless', '--quit-after', '20000', 'res://tests/gameplay_test.tscn', '--', '--save-profile=test')
Run 'Menus and ending' @('--headless', '--quit-after', '20000', 'res://tests/menu_test.tscn', '--', '--save-profile=menu')
Run 'Reactive props and controls hint' @('--headless', '--quit-after', '20000', 'res://tests/props_test.tscn', '--', '--save-profile=props')
if (-not $SkipSolver) { Run 'Route solver (about 3 minutes)' @('--headless', '--script', 'tests/route_solver.gd') }
if ($failed -gt 0) { Write-Output "$failed suite(s) FAILED"; exit 1 }
Write-Output 'All suites passed.'
