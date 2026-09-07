# 26 — One gameplay scheduler

Status: tracked in work/architecture/README.md. Dependencies: 25.
Review coverage: Finding 3 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: controller tick/process; player.gd; both enemies; auto_weapon; projectiles. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Create one fixed-physics-step orchestration path used by the running scene and integration tests. Queue input commands, update movement/ability state and combat in a documented order, apply damage, then advance sealing/extraction and resolve terminal state. Remove independent actor scheduling of those same updates. Keep rendering and passive real-time accounting separate. Preserve existing movement APIs and actual physics collision behavior; do not simulate a large interval as one move_and_slide call.

## Acceptance checks

Drive the real scheduler at fixed steps: lethal melee and hostile projectile damage beat seal completion on the same step; dash expiry has a documented tested order; pause freezes combat; no actor advances twice. Compare identical fixed-step input sequences with different numbers of render refreshes. Existing focused combat tests still pass.

## Stop boundary

No balance tuning, deterministic networking, replay engine, or new abilities. A thin compatibility wrapper for old tests is temporary and must delegate to the real scheduler.

## Completion note

Completed. `EncounterController` now owns a 60 Hz fixed-step scheduler. `_process` queues input and settles passive production; `_physics_process` consumes fixed steps in the order input, player movement/abilities, weapon and hostile actors/projectiles, damage, then sealing/extraction and terminal credit. Player, melee enemy, and ranged enemy no longer self-schedule physics; their `simulate_tick` methods are called only by the controller. `tick(delta)` remains a thin compatibility wrapper over the same scheduler. Added `single_scheduler_test.gd` covering lethal melee/projectile ordering, dash expiry before movement, pause freeze, and render-refresh invariance. Existing detached fixtures retain collision behavior in real scenes while avoiding physics calls off-tree. The complete 24-test suite passes, including the new scheduler test. Remaining limitation: this is fixed-step orchestration, not deterministic networking or replay infrastructure.

