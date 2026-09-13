# Act 1 — Broken Foundry / map art contract

Status: provisional design, not approved or imported into the game. Implements M01. The owner's nine-node requirement supersedes the old two-well example in `design/Concept.md` section 7.

## Visual language and scale

Broken Foundry is a ruined heavy-industrial region whose raw mana is extracted beneath abandoned works. Preserve the established painted 1980s–1990s OVA rendering: broad engineered masses, three clear value groups, selective ink edges, tactile gouache surfaces, quiet platework, functional pipes and analog-era machinery. Muted ochre steel, rust-red terrain, charcoal concrete and cool blue-grey distance dominate; cyan mana remains a small accent. Avoid sleek neon, glossy CGI and decorative surface noise.

The map is a high aerial regional illustration, deliberately different from the level side-view camera. Tiny maintenance sheds, rail infrastructure and conveyors establish landscape scale. Extensive quiet terrain/water separates locations; the enormous Crown Furnace is a destination, not a close foreground prop. Distant geography continues past the map edge, implying a larger world. No literal kilometer distances or platform collision geometry are implied.

Three geographic candidates share this language:

- A / valley: salvage foothills → pumping basin → clinker mountains and furnace citadel. Closest to the original ruined-valley concept.
- B / coast: salvage port → tidal pumping marshes → fortified furnace headland. Explores negative space through water; could also inform a later Drowned Works theme, but remains an Act 1 alternative for this review.
- C / terraces: salvage quarry → pressure terraces → high furnace plateau. Explores vertical relief and an uphill journey.

No candidate is selected in advance. Later act themes in the concept are examples only; this work does not authorize their production.

## Nine-node route

| # | Draft name | Kind | Well identity |
|---|---|---|---|
| 1 | Scrap Approach | Monster-only | — |
| 2 | Intake Well | Well | well_1 |
| 3 | Broken Viaduct | Monster-only | — |
| 4 | Cinder Crossing | Monster-only | — |
| 5 | Pressure Well | Well | well_2 |
| 6 | Rail Graveyard | Monster-only | — |
| 7 | Furnace Rampart | Monster-only | — |
| 8 | Crown Well | Well | well_3 (draft, not yet runtime) |
| 9 | The Crown Furnace | Boss | — |

`act_01.draft.json` is the machine-readable contract. Each level has its own stable ID and draft encounter key, normalized position and prerequisite. The path is sequential and acyclic; the boss additionally lists all eight prior nodes as requirements. The draft does not implement unlock rules. Node names describe provisional gameplay locations; art generation is not expected to paint exactly nine identifiable facilities.

## Asset/display contract

Generate 1536×864 using the installed landscape baseline; preserve that source losslessly. Uniformly resample by 4/3 with Lanczos to a 2048×1152 review master. This is resampling, not newly generated detail. No stretching or cropping. Runtime should contain the full image in its available rectangle and transform normalized positions through that rectangle, including letterbox offsets.

Keep a minimum 6% geographic/marker margin. The boss sits near (0.87, 0.21); the route begins near (0.10, 0.77). Marker visuals are about 32 logical pixels at 1280×720 and future hit targets about 44 pixels. The draft validator checks spacing and margins. Candidates can carry separate reviewed coordinate/path revisions if the geography warrants them.

Clean generated art contains **no labels, route lines, pins, status, symbols, UI or characters**. Real railways and pipelines may be scenery. Route polylines, level markers, names and eventual lock/conquest/production states are deterministic separate layers. `layout-sketch.png` and candidate `overlay*.png` are disposable design previews, never runtime background textures. The current sketch deliberately uses no fake campaign-state progression. Dynamic status and panel behavior belong to M05 after approval.

`prompt-blocks.json` holds editable world, style, theme, composition, exclusions and alternative geography blocks. It is the reusable authoring source. Workflow nodes expose the same blocks. Preserve clean masters, graphs, seeds, model identifiers, job histories, hashes and candidate-specific layout files.

## Runtime audit and integration implications

Read on implementation: `prototype/scripts/model/content_catalog.gd` defines only `well_1` and `well_2`, heroes, upgrades and surge rules; no authored acts or monster-level catalog. `account_state.gd` owns well unlock/commission/guard/loadout state and validates known well IDs, including special well_2-based availability. `encounter_controller.gd` orchestrates the existing encounter and terminal flow around well identity. Existing UI exposes operations and combat, not a nine-node campaign map. Production/saves already have ownership contracts and must remain authoritative.

M04/M06 must therefore add campaign identities, a third real well, prerequisite progress and non-well/boss objectives; the map artwork cannot supply those rules. No changes to these runtime files are part of M01/M02. Save migration is not a design deliverable here.

Sources: `design/visual-style-bible.md` core identity/invariants; `design/Concept.md` sections 7 and regional variety; `tools/asset_pipeline/templates/concept.json`; `tools/asset_pipeline/side_view.py` Broken Foundry backdrop; `work/world-map/README.md`; current catalog/account/controller source. The earlier elevated courtyard art informs material language, not the geographic scale of this map.
