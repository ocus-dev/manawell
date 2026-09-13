# P05 — Two playable platforms in the foundry

Dependency: P04. Status tracked in work/platforming/README.md.

## Implement

Create one authored arena layout resource shared by gameplay, preview, movement and later save validation. Keep the continuous floor at y=540 and bounds x=96…1184. Start with two horizontal one-way supports: x=260…470 and x=810…1020 at y=430. Assign stable platform IDs. No pits or lethal falls.
Extend the motor to land only while descending and crossing a platform top within its horizontal extent. Allow ascent through the underside and walking/falling off edges. Add S/Down+Space to intentionally drop through the current one-way platform, ignoring only that support until safely below or a short bounded timer expires. Ground cannot be dropped through. Support bounds/edge rules use explicit collider dimensions rather than transparent image bounds.
Give platforms visible industrial deck edges/brackets consistent with the environment, using existing materials/procedural shapes. No new ComfyUI generation required. Keep the central machine crossing clear and fixed camera; do not reshape the full environment around a new biome. Add support/hero-collider debug overlays to the existing preview, with physics and visual geometry using the same definitions.

## Acceptance

Both platforms are reachable with the default jump, can be stood on, walked off, and dropped through reliably. No underside sticking, repeated drop cancellation, phantom ground/coyote resets or tunneling. Foot placement matches deck tops. Preview and runtime platform rectangles match, and HUD does not obscure jumping paths.

## Stop boundary

No moving platforms, ladders, slopes, wall jumps, double jumps, scrolling or enemy platform navigation.

## Completion note

DONE. Added the shared authored geometry source at `prototype/data/arena_layout.gd` with stable `platform_left` and `platform_right` IDs, explicit collider rectangles `(260,430,210,16)` and `(810,430,210,16)`, floor/bounds constants, hero collider width, and bounded drop-through values. `prototype/scripts/game/player.gd` now lands only on descending support crossings, passes through undersides, walks off edges, and handles `S/Down + Space` drop-through without disabling the floor. Runtime decks/brackets and the existing visual preview both consume the same definitions; the preview debug toggle shows support rectangles, IDs, and hero collider overlays. Updated visible controls and added `prototype/tests/platform_arena_test.gd` for reachability, ascent, edge walk-off, drop-through, tunneling, and runtime/preview geometry identity. Checks passed: P05 platform fixture, P04 jump, movement, environment, persistence, diagnostics, and 1280x720 headless boot. Remaining limitations: no moving platforms, slopes, ladders, wall/double jumps, platform-aware combat, or active-run recovery; those remain later cards.

