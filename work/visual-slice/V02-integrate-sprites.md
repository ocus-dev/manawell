# V02 — Integrate sprites into gameplay and a comparison scene

Read the queue and V01 handoff; active `scripts/game/player.gd`, `melee_enemy.gd`, `projectile.gd`, `encounter_controller.gd`, main scene, and relevant presentation/combat tests. Confirm actual current paths; the single enemy implementation currently draws all roles.

## Implement

Add small reusable visual scenes/scripts with Sprite2D children, driven by the prepared asset manifest or one central visual configuration. Use actor-local foot/base anchors and the suggested display heights. Keep simulation roots and their state unchanged. Map the current enemy kind enum to the correct sprite IDs. Mirror character visuals horizontally for left/right facing, keeping health/labels upright. Give idle facing a stable value. Sharing one hero image across both hero IDs is intentional for this slice.

Replace hero/enemy procedural body drawings, and replace only the harvester body/mechanism art inside the controller's drawing code. Keep the environment, walkway, extraction/sealing feedback, hit flashes, warnings and HUD. Use explicit draw order: environment, harvester, lane actors, combat warnings/feedback, HUD. Verify the hero remains visible while crossing the machine and that enemy bars follow each displayed silhouette instead of old hard-coded heights.

Define reviewed presentation-only muzzle/emitter anchors for the hero and ranged creature. Render projectiles/attack flashes from those anchors while retaining the existing authoritative horizontal swept-hit behavior. Do not shift actor positions or broaden attack ranges to make a decorative gun line up. Avoid visual shot teleportation at launch. Minimal recoil/hit tint is allowed; locomotion sheets, skeletal rigs, and animation generation are outside scope. Respect pause and reduced-motion settings and keep visual offsets out of saves.

Create `prototype/scenes/previews/side_view_visual_slice.tscn` with the same visual components/config as gameplay, a common baseline, role labels, left/right comparison, and controls for selecting assets and adjusting visual scale for review. Do not save changes automatically or introduce a second balance model. Include a debug overlay toggle for ground anchors/current gameplay footprints, and allow comparison at 1280×720 and 1920×1080. The preview must start without account loading, production settlement, or combat spawning.

## Acceptance

- Real encounters show all five assets, correct facing and stable grounding, with no duplicate procedural bodies.
- Hero crosses the machine visibly; windups, health, shots, dash/pulse, sealing and damage feedback remain readable.
- Preview and gameplay use the same textures, anchors, and initial size settings.
- Focused tests verify role mapping, facing without actor-root transform changes, and visual scale/anchor behavior. Existing movement, weapon, surge and presentation checks pass.
- No numerical gameplay/collision/save schema changes. Document exact launch commands and any visual compromises.

Stop before tuning collision sizes or producing replacement art/animation.

## Completion note

DONE. Added the shared presentation layer in `prototype/scripts/game/side_view_visual_config.gd` and `side_view_actor_visual.gd`, with role mappings, V01-derived anchors/heights, linear filtering, child-only facing mirrors, emitter anchors, and scale behavior. `player.gd` and `melee_enemy.gd` now use Sprite2D children; their simulation roots, health, warnings, damage feedback, movement, and collision behavior remain unchanged. The controller uses the harvester sprite behind actors, retains environment/feedback drawing, and launches projectile visuals from reviewed muzzle/emitter heights without changing horizontal swept-hit logic. Added `prototype/scenes/previews/side_view_visual_slice.tscn`, a persistence-free comparison scene with all five roles, common baselines, left/right comparison, scale control, anchor/footprint debug toggle, and 1280x720 / 1920x1080 selector. Launch preview with `Godot_v4.8-dev4_win64_console.exe --path prototype --scene res://scenes/previews/side_view_visual_slice.tscn`; launch gameplay with `--path prototype`. Focused visual, preview, presentation, encounter, and full prototype tests pass (23 tests). Manual interactive visual playthrough and screenshot evidence remain for V03; breaker angled pose and ranged lifted leg remain known art limitations. No collision, balance, save schema, or animation changes were made.
