[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $GodotPath,

    [string] $TestFilter,

    [int] $TimeoutSeconds = 30,

    [string] $LogDirectory = (Join-Path $PSScriptRoot '..\work\reviews\logs')
)

$ErrorActionPreference = 'Stop'

function Fail([string] $Message) {
    throw "Test runner: $Message"
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Fail "Godot executable was not found: $GodotPath"
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
if ($TimeoutSeconds -lt 1) {
    Fail "TimeoutSeconds must be at least 1."
}
if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
    if (Test-Path -LiteralPath $LogDirectory) {
        Fail "log directory is not a directory: $LogDirectory"
    }
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}
$LogDirectory = (Resolve-Path -LiteralPath $LogDirectory).Path
$probePath = Join-Path $LogDirectory '.runner-write-probe'
try {
    [System.IO.File]::WriteAllText($probePath, '')
    Remove-Item -LiteralPath $probePath -Force
} catch {
    Fail "log directory is not writable: $LogDirectory"
}

$testRoot = (Resolve-Path (Join-Path $PSScriptRoot 'tests')).Path
$tests = @(Get-ChildItem -LiteralPath $testRoot -Filter '*_test.gd' -File | Sort-Object Name)
if ($TestFilter) {
    $tests = @(
        Get-ChildItem -LiteralPath $testRoot -Filter '*_test.gd' -File -Recurse |
            Where-Object { $_.Name -like "*$TestFilter*" -or $_.FullName -like "*$TestFilter*" } |
            Sort-Object FullName
    )
}
if ($tests.Count -eq 0) {
    Fail "no tests matched filter '$TestFilter'."
}

$failed = 0
foreach ($test in $tests) {
    $logPath = Join-Path $LogDirectory $test.BaseName
    $capturePath = "$logPath.capture.tmp"
    $exitPath = "$logPath.exit.tmp"
    $relativeTestPath = $test.FullName.Substring($testRoot.Length + 1).Replace('\', '/')
    $scriptPath = "res://tests/$relativeTestPath"
    $job = $null
    try {
        $job = Start-Job -ScriptBlock {
            param($executable, $projectPath, $testScript, $outputPath, $statusPath)
            & $executable --headless --path $projectPath --script $testScript *> $outputPath
            Set-Content -LiteralPath $statusPath -Value ([string]$LASTEXITCODE)
        } -ArgumentList $GodotPath, $PSScriptRoot, $scriptPath, $capturePath, $exitPath
        if ($null -eq (Wait-Job -Job $job -Timeout ($TimeoutSeconds))) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Get-CimInstance Win32_Process |
                Where-Object { $_.CommandLine -like "*$scriptPath*" } |
                ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $capturePath) {
                Get-Content -LiteralPath $capturePath | Set-Content -LiteralPath "$logPath.log"
            }
            $failed++
            Write-Host "FAIL $($test.Name): timed out after ${TimeoutSeconds}s"
            continue
        }
        $output = @(Get-Content -LiteralPath $capturePath)
        $output | Set-Content -LiteralPath "$logPath.log"
        $exitCode = [int](Get-Content -LiteralPath $exitPath)
        $malformedJsonAllowed = $test.Name -eq 'account_saves_test.gd'
        $unexpectedScriptError = @($output | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Assertion failed|TEST CHECK FAILED' })
        if ($malformedJsonAllowed) {
            $unexpectedScriptError = @($unexpectedScriptError | Where-Object { $_ -notmatch 'JSON.*parse|parse.*JSON|Malformed JSON' })
        }
        if ($exitCode -ne 0) {
            $failed++
            Write-Host "FAIL $($test.Name): exit code $exitCode"
        } elseif ($unexpectedScriptError.Count -gt 0) {
            $failed++
            Write-Host "FAIL $($test.Name): diagnostic indicates failure"
        } else {
            Write-Host "PASS $($test.Name)"
        }
    } finally {
        if ($null -ne $job) {
            Remove-Job -Job $job -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $capturePath, $exitPath -Force -ErrorAction SilentlyContinue
    }
}

if ($failed -gt 0) {
    exit 1
}
exit 0