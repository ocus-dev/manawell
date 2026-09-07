# Local asset pipeline. All arguments pass directly to Python, without shell evaluation.
$assetConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools/asset_pipeline/config.json') -Raw | ConvertFrom-Json
& $assetConfig.python (Join-Path $PSScriptRoot 'tools/asset_pipeline/pipeline.py') @args
exit $LASTEXITCODE
