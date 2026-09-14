$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools/asset_pipeline/config.json') -Raw | ConvertFrom-Json
Push-Location $PSScriptRoot
try {
    & $config.python (Join-Path $PSScriptRoot 'tools/weapon_pipeline/pipeline.py') @args
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
