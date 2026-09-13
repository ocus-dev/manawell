$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools/asset_pipeline/config.json') -Raw | ConvertFrom-Json
Push-Location $PSScriptRoot
try {
    & $config.python (Join-Path $PSScriptRoot 'tools/animation_pipeline/pipeline.py') @args
    if ($LASTEXITCODE -ne 0) { throw "Animation pipeline exited with code $LASTEXITCODE" }
} finally {
    Pop-Location
}
