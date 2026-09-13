# M01 handoff

Status: DONE for the design contract. Owner design approval is still PENDING; M04 and later remain gated.

## Delivered

- `art/world-map/brief.md` — Act 1 Broken Foundry theme, three districts, destination landmark, 16:9 composition contract, reusable prompt blocks, source audit and art/runtime separation.
- `art/world-map/act-1-draft.json` — draft act manifest with nine stable node IDs in the required order, five monster nodes, three unique well IDs, one terminal boss, normalized positions, placeholders and prerequisite IDs.
- `art/world-map/act-1-overlay.svg` — deterministic nine-node review sketch with distinct well, monster and boss markers.
- `tools/world_map/validate_act_manifest.ps1` — checks node/type/well counts, unique IDs, normalized positions, terminal boss prerequisites and acyclic prerequisite graph.

## Checks

`tools/world_map/validate_act_manifest.ps1` passes: 9 nodes, 3 wells, 5 monsters, 1 terminal boss; positions and prerequisite graph passed.

## Limitations

No ComfyUI generation, model download, workflow installation, live catalog change, persistence change, map scene or routing implementation was performed. Names, encounter keys, positions, districts and prompt blocks are provisional. The owner must approve a named candidate/revision and route overlay, with the exact image hash recorded during M03, before M04 begins.