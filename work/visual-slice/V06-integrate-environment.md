# V06 — Integrate and verify the complete environment slice

Read the queue, V05 handoff, current controller environment drawing code, V02's shared visual configuration/components, preview scene, and V03's render-capture/testing approach.

## Implement

Add a small reusable environment visual component using the prepared layers/config. Use it in the actual encounter and `side_view_visual_slice.tscn`; the preview must not maintain a separate backdrop transform or fork the gameplay scene. Disable replaced procedural scenery by default while preserving service-walkway readability and all combat effects. Keep an explicit debug fallback toggle if helpful, with exactly one environment visible at a time.

Retain the fixed logical canvas, ground, bounds, machine position, actor scales and collision behavior. Keep backdrop/lane behind actors and warnings above dressing. Do not add physics bodies, camera scrolling/parallax, hazards, animation pipelines, or persistent environment state. One environment may serve both wells for this first slice; labels must still reflect the selected well.

Capture actual Godot viewport images at 1280×720 and 1920×1080 for: the full comparison scene, hero crossing the machine, mixed enemy combat including ranged warnings, and startup UI. Reuse existing capture tooling with isolated/no persistence. Inspect background contrast, floor contact, foreground obstruction, edge-entry visibility, projectile readability and HUD legibility. Where interactive checks are unavailable, state that separately from fixture screenshots.

Run focused environment/presentation and existing layout/combat tests, then the complete active suite once. Add only meaningful checks for shared placement, no duplicate environments, required resource loading and preserved gameplay coordinates. Fix integration regressions without changing numerical balance.

Update `work/playtests/static-sprite-slice.md` with an environment section: source choices, layer placements, runtime screenshots, launch commands, actual tests, known limitations and owner review prompts from the queue. Update the active README to identify the complete first environment slice. Preserve previous asset and test history rather than claiming old checks were performed again.

## Acceptance

- The same complete painted environment appears in preview and real encounters with all five actor assets.
- Grounding, overlap, warning visibility and both resolutions have rendered evidence; test results are recorded honestly.
- No game-rule, collision, save-schema, camera-mode, or actor-art changes.
- Owner can review scale and composition using the supplied launch commands and give a concrete revision list.

Stop for owner review. Do not start a second biome, animated weather, platforms, or combat tuning automatically.

## Completion note

DONE. Added `prototype/scripts/game/side_view_environment_visual.gd`, which loads the prepared V05 backdrop and lane at their fixed logical placements and retains the old procedural drawing only as an explicit fallback. Gameplay and `side_view_visual_slice.tscn` both instantiate this component; no duplicate preview transform, physics, camera, state, balance, collision, save, or actor-art changes were made. Added `prototype/tests/environment_visual_test.gd` for shared resource loading, dimensions, fixed coordinates, and duplicate checks. Extended the native OpenGL capture fixture with separate hero-crossing evidence. Captures were rendered at 1280x720 and 1920x1080 for comparison, startup, hero crossing, and mixed ranged-warning combat. Focused checks passed and all 25 complete active Godot tests passed with persistence isolated. Remaining limitations are manual input feel and owner judgement of final environment contrast/scale. Stop for owner review before any second biome, weather, platforms, animation, or combat tuning.
