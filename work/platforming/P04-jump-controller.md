# P04 — Jumping, gravity, and control mapping

Dependency: P03. Status tracked in work/platforming/README.md.

## Implement

Read player.gd, controller scheduler/input handling, project.godot, visual anchors, snapshot ownership and motion tests.
Implement the queue's fixed-step hero motion with vertical velocity, grounded state, jump press buffer, coyote timer and variable jump height. Keep the controller's sole 60 Hz scheduler and use the supplied delta. Use a small explicit kinematic motor on the current Node2D, with swept ground/support crossing so it remains deterministic in fixture tests; do not add an independently ticking physics actor. Add jump=Space (W/Up optional aliases), change dash to Shift, keep Q pulse and E harvest. Update all help, hotbar labels and tests together.
Add 0.10 s coyote time and 0.10 s jump buffer as initial configurable values. Start with 192 px/s horizontal speed, 1200 px/s² gravity, -600 px/s jump impulse and 900 px/s terminal fall speed; releasing jump clamps upward speed to -240 px/s. Preserve existing dash speed/duration/cooldown and hero-only invulnerability. Dash may start grounded or airborne; it changes horizontal motion while gravity continues, and never refreshes jump eligibility. Keep x bounds and continuous ground at y=540.
Do not scale/rotate simulation roots to animate. Keep feet anchored to the collision support surface with existing sprites; no new animation generation. Read input edges once, queue them, consume at most once; modals and focus loss cannot leave held movement/jump stuck.
Until P07 finishes the new snapshot contract, explicitly disable active encounter resume/checkpoint snapshots in this intermediate build while retaining account saves, with a short documented notice. Do not serialize incomplete airborne state or silently erase account progress.

## Acceptance

Press/release produces a readable variable-height jump; no auto-bunny-hop from holding jump. Coyote/buffer expire correctly, landing resets eligibility, pause freezes timers, retry resets motion. Air dash does not grant extra jumps or cancel gravity. Space no longer triggers dash, Shift does, and UI/gameplay input isolation passes. Ground collision cannot tunnel under large test steps.

## Stop boundary

No platforms or height-aware combat claims yet. Mark jumping as an intermediate motion milestone; P06 repairs combat.

## Completion note

DONE. Implemented deterministic controller-owned fixed-step hero motion in `prototype/scripts/game/player.gd` and `prototype/scripts/game/encounter_controller.gd`: horizontal speed 192 px/s, gravity 1200 px/s2, jump impulse -600 px/s, release clamp -240 px/s, terminal fall 900 px/s, 0.10 s coyote time and 0.10 s jump buffer. Ground support remains continuous at y=540 with swept crossing; retry resets motion, air dash preserves gravity, and queued jump/action edges are cleared on pause/focus loss. Added Space jump with W/Up aliases, Shift dash, and updated `prototype/project.godot`, help text, README controls, dynamic hotbar badges, and persistence fixture expectations. Active encounter snapshots/checkpoints are explicitly disabled until P07 while account saves remain. Added `prototype/tests/jump_controller_test.gd` covering variable height, coyote/buffer expiry, no auto-bunny-hop, pause, air dash, retry, floor tunneling, and mappings. Checks passed: jump controller, movement, weapons/abilities, and persistence Godot headless tests. Remaining limitations: no platforms or height-aware combat yet; active airborne recovery waits for P07.

