[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $GodotPath,
    [int] $TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$godot = (Resolve-Path -LiteralPath $GodotPath).Path
$tests = @('res://tests/movement_test.gd', 'res://tests/defense_test.gd')
$logDirectory = Join-Path $projectRoot 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$outputPath = Join-Path $logDirectory 'movement_test.log'
$exitPath = Join-Path $logDirectory 'movement_test.exit'
$failed = 0
foreach ($test in $tests) {
    $name = [System.IO.Path]::GetFileName($test)
    $job = Start-Job -ScriptBlock {
        param($executable, $path, $script, $output, $exit)
        & $executable --headless --path $path --script $script *> $output
        Set-Content -LiteralPath $exit -Value ([string]$LASTEXITCODE)
    } -ArgumentList $godot, $projectRoot, $test, $outputPath, $exitPath
    if ($null -eq (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        $failed++
        Write-Host "FAIL $name`: timed out after ${TimeoutSeconds}s"
    } else {
        $output = Get-Content -LiteralPath $outputPath -ErrorAction Stop
        $exit_code = [int](Get-Content -LiteralPath $exitPath -ErrorAction Stop)
        $output | ForEach-Object { Write-Host $_ }
        if ($exit_code -ne 0) {
            $failed++
            Write-Host "FAIL $name`: exit code $exit_code"
        } else {
            Write-Host "PASS $name"
        }
    }
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $outputPath, $exitPath -Force -ErrorAction SilentlyContinue
}
if ($failed -gt 0) { exit 1 }
