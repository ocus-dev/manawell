param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\..\art\world-map\act-1-draft.json')
)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
$nodes = @($manifest.nodes)
$errors = [System.Collections.Generic.List[string]]::new()

function Fail([string]$Message) { $errors.Add($Message) }

if ($manifest.schema_version -ne 1) { Fail 'schema_version must be 1' }
if ($manifest.master.width -ne 2048 -or $manifest.master.height -ne 1152) { Fail 'master must target 2048x1152' }
if ($nodes.Count -ne 9) { Fail "expected 9 nodes, got $($nodes.Count)" }

$ids = @{}
$wellIds = @{}
$nodeById = @{}
foreach ($node in $nodes) {
    $id = [string]$node.id
    if ([string]::IsNullOrWhiteSpace($id)) { Fail 'node ID must be non-empty' }
    elseif ($ids.ContainsKey($id)) { Fail "duplicate node ID: $id" }
    else { $ids[$id] = $true; $nodeById[$id] = $node }

    if (@('monster', 'well', 'boss') -notcontains [string]$node.type) { Fail "invalid node type: $id" }
    if ($null -eq $node.position -or $node.position.x -lt 0 -or $node.position.x -gt 1 -or $node.position.y -lt 0 -or $node.position.y -gt 1) { Fail "position outside [0,1]: $id" }
    if ([string]::IsNullOrWhiteSpace([string]$node.encounter_key)) { Fail "missing encounter_key: $id" }
    if ($node.type -eq 'well') {
        $wellId = [string]$node.well_id
        if ([string]::IsNullOrWhiteSpace($wellId)) { Fail "well node missing well_id: $id" }
        elseif ($wellIds.ContainsKey($wellId)) { Fail "duplicate well_id: $wellId" }
        else { $wellIds[$wellId] = $true }
    } elseif ($null -ne $node.well_id) { Fail "non-well node has well_id: $id" }
}

if ((@($nodes | Where-Object type -eq 'monster')).Count -ne 5) { Fail 'expected exactly 5 monster nodes' }
if ((@($nodes | Where-Object type -eq 'well')).Count -ne 3) { Fail 'expected exactly 3 well nodes' }
if ((@($nodes | Where-Object type -eq 'boss')).Count -ne 1) { Fail 'expected exactly 1 boss node' }
if ($wellIds.Count -ne 3) { Fail 'expected exactly 3 unique well IDs' }

$incoming = @{}
foreach ($node in $nodes) {
    $incoming[[string]$node.id] = 0
    foreach ($prerequisite in @($node.prerequisite_ids)) {
        $prerequisiteId = [string]$prerequisite
        if (-not $nodeById.ContainsKey($prerequisiteId)) { Fail "unknown prerequisite $prerequisiteId on $($node.id)" }
        else { $incoming[[string]$node.id]++ }
    }
}

$queue = [System.Collections.Generic.Queue[string]]::new()
foreach ($id in $incoming.Keys) { if ($incoming[$id] -eq 0) { $queue.Enqueue($id) } }
$visited = 0
while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    $visited++
    foreach ($node in $nodes) {
        if (@($node.prerequisite_ids | ForEach-Object { [string]$_ }) -contains $current) {
            $incoming[[string]$node.id]--
            if ($incoming[[string]$node.id] -eq 0) { $queue.Enqueue([string]$node.id) }
        }
    }
}
if ($visited -ne $nodes.Count) { Fail 'prerequisite graph must be acyclic and connected to a root' }

$bosses = @($nodes | Where-Object type -eq 'boss')
if ($bosses.Count -ne 1) { Fail 'terminal boss is missing' }
elseif (@($bosses[0].prerequisite_ids).Count -ne 8) { Fail 'boss must require all eight preceding nodes' }

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "VALID: $ManifestPath"
Write-Output '9 nodes, 3 wells, 5 monsters, 1 terminal boss; positions and prerequisite graph passed.'