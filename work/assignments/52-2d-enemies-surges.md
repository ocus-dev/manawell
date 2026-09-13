# 52 — Enemy pursuit, machine defense, and surges

Status: tracked in work/2d/README.md. Dependency: 51.

## Read

Queue and predecessor; archived melee/ranged actors and director logic; active balance/catalog definitions; melee and surge tests.

## Implement

Reuse the promoted side-view actors rather than rebuilding 3D actors. Replace the finite experiment schedule with the existing catalog's continuing surge intervals/compositions mapped deterministically to left/right entries. Preserve well-two and Overdrive timing/damage modifiers, cap, and increasing pressure. All roles must remain introduced clearly; the exact experimental introduction timestamps are a reference, not a second director to run in parallel. Expose one director state with spawn timer, composition index, side sequence, and pending entry warnings for later snapshots. Keep warning timing and next-threat HUD derived from that same owner.

Integrate pursuer, breaker, and ranged movement/attack states with canonical models. Pursuers threaten the hero; breakers threaten the machine. Retain cooldowns, ranged stop distance/windup, modifiers, and sealing pressure. Convert distance/speed once using the shared scale. Preserve nonblocking lane actors and service walkway; attack ranges use ground coordinates. Spawn at visible left/right entries with warnings, never the former arena-corner positions.

Keep existing ranged windup/fire connected to the promoted projectile owner; card 53 repairs and hardens hit behavior. Keep enemies scheduled only by the controller and clear them on retry/results.

## Acceptance

- Pursuer/breaker target behavior, damage intervals, death, cap, and authored surge timing match existing rules.
- Pause freezes movement and windups; sealing continues pressure; retry clears actors.
- Arena spawning stays within the intended bounds and machine targeting is reachable.
- Run beyond 82 seconds and multiple later surge boundaries: pressure never silently ends, both sides remain active, and cap/warning behavior remains deterministic. Verify well-two and Overdrive timing against catalog values without a second spawn clock.
- Port melee/surge tests; explicitly assign remaining ranged-projectile checks to 53.

## Stop

No navigation framework, new enemy types, or balance tuning.

## Completion note

Completed 2026-09-07.

- Replaced the finite S01-S03 schedule with one catalog-driven continuing surge director in `prototype/scripts/game/encounter_controller.gd`. It exposes `spawn_timer`, `spawn_index`, `side_sequence`, pending entry warnings, composition selection, and current interval through `get_director_state()`.
- Preserved canonical role stats and behavior while adding catalog surge composition, deterministic alternating visible left/right entries, increasing pressure after later surge boundaries, Well 2 timing/damage modifiers, Overdrive interval reduction, ranged windup support, machine-targeting breakers, pause freeze, and live-cap pruning.
- Removed the unused active finite schedule file. The promoted 2D enemy and projectile actors now read `RunState.paused`, apply controller-selected damage modifiers, and remain owned by the single controller scheduler.
- Added `prototype/tests/surge_2d_test.gd` covering continuing pressure beyond 82 seconds, all role introduction, deterministic side state, multiple surge intervals, Well 2/Overdrive timing, pause freeze, breaker machine damage, and the 60-enemy cap. Archived 3D melee/ranged fixtures remain deferred; ranged projectile repair is owned by card 53.

Actual checks:

- `prototype/run_tests.ps1 -GodotPath .\\Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe`: all 14 active tests passed, including `surge_2d_test.gd` and the 13 card 51 tests.
- Direct `surge_2d_test.gd`: passed `2D surge checks passed`.
- Active project import and headless boot exited 0 with no authored script diagnostics.
- Authored active-file scan found no 3D runtime classes, camera/orbit handlers, archived asset preloads, or finite schedule preload.
- Frozen archive manifest remains unchanged at 222 files; the accepted experiment remains unchanged.

Remaining archived 3D fixtures are not reported as passing. Card 53 owns ranged projectile hardening and related spatial conversions. No navigation, new enemy types, or balance tuning was added.
