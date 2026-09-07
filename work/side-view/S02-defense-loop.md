# S02 — Playable defense and extraction loop

Read the queue and S01 handoff; copied RunState/balance, original melee/ranged/weapon/projectile/player scripts for relevant behavior only. Adapt into small experiment-local scripts; do not copy the monolithic encounter controller.

## Implement

Implement READY → EXTRACTING → SEALING → SUCCESS/FAILED, plus pause, clean retry, visible session payout, health, machine integrity, tank, pressure/next threat, cooldowns, and sealing countdown. Use RunState as the rules owner; lethal damage precedes sealing completion. Do not persist anything.

Implement the three enemy roles, deterministic left/right wave schedule, live-enemy cap, nearest-target automatic fire, swept single-hit projectiles, ranged warnings, dash, and pulse from the queue. Treat ground position as authoritative for attack distances; draw muzzle/projectile heights for readability without allowing decorative vertical offsets to cause misses. Clear all transient actors, projectiles, queued inputs, spawn clocks, and cooldowns on retry. Ensure a fresh run is not damaged by stale projectiles.

Author a repeatable schedule that introduces all three enemy roles within the first 90 seconds, followed by repeating mixed pressure with a documented cap. Reuse base stats and timings first. If lane geometry makes a value clearly unworkable, keep adjustments in one experiment config and record original/new values and reason; never modify main-game balance or silently tune difficulty. No random spawns needed.

## Acceptance

- Full start/combat/harvest/result/retry journey works; successful payout locks on sealing and is shown once; failure pays zero.
- Breakers threaten the machine even while the hero is distant; pursuers and ranged attacks threaten the hero; left/right spawning and tie-breaking are deterministic.
- Projectile segment hits do not tunnel or double-hit; ranged windup pauses correctly.
- Dash invulnerability excludes machine damage; pulse reaches both sides; cooldowns and zero-input dash behave correctly.
- Pause freezes encounter and spawn time; UI focus/modal actions do not accidentally dash or harvest.
- Focused lifecycle and combat tests pass, including lethal-at-seal-boundary and retry cleanup. Record pending manual checks honestly.

Stop at a complete primitive-art experiment. No progression, persistence, jumping, or full production UI.

## Completion note

Completed 2026-09-07.

- Implemented the local READY -> EXTRACTING -> SEALING -> SUCCESS/FAILED loop with RunState as the rules owner, session-only payout, tank, health, machine integrity, pressure timing, sealing countdown, pause, and clean retry.
- Added controller-owned 60 Hz simulation, deterministic authored left/right schedule, 60 live-enemy cap, pursuers, breakers, ranged windups and warnings, nearest-target auto-fire with ID tie-breaking, swept single-hit projectiles, dash invulnerability, pulse damage on both sides, and hostile shots targeting only the hero.
- Reused copied balance defaults without tuning changes. The exact schedule and provenance are documented in `experiments/side-view-defense/README.md`.
- Expanded the project-local runner to execute both `movement_test.gd` and `defense_test.gd`. Focused tests cover lifecycle/result payout, lethal damage at the sealing boundary, all roles and schedule introduction, deterministic targeting, pause freeze, retry cleanup, dash protection, pulse cooldown, and projectile sweep/hit-once behavior.

Actual checks:

- `Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe --headless --path experiments/side-view-defense --script res://tests/defense_test.gd`: passed `S02 defense checks passed`.
- `experiments/side-view-defense/run_tests.ps1 -GodotPath Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe`: passed both `movement_test.gd` and `defense_test.gd`; Godot emitted only known headless CanvasItem/ObjectDB leak warnings on the movement test process exit.
- `get_errors` reported no errors for the experiment after implementation.

Pending manual checks: interactive runtime walkthrough, visual inspection at 1280x720 and 1920x1080, UI focus not triggering gameplay actions, and whether the defense loop feels interesting. No progression, persistence, jumping, or full production UI was added. S03 is the next card.
