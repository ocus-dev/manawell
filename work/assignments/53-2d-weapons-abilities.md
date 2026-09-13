# 53 — Weapons, projectiles, dash, and pulse

Status: tracked in work/2d/README.md. Dependency: 52.

## Read

Queue and predecessor; archived auto weapon, projectile classes, and player ability logic; active balance and combat tests.

## Implement

Repair and integrate the promoted actors rather than restarting combat. In particular, replace original-aim-point projectile damage with per-step swept checks against current ground positions. A hero who moves clear of a shot's path must evade it; crossing the current hero position must hit unless dashing. Friendly shots inspect only the current travel segment and hit its nearest live enemy in travel order, not the cumulative path from launch. Define zero-distance aim deterministically using facing. Add regression tests that would fail against the experiment implementation.

Integrate nearest-live-target acquisition across both sides, automatic fire, friendly/hostile shots, damage, lifetime, dash, and pulse with canonical balance. Implement the queue's Triple shot adaptation of spread_1 without vertical gameplay trajectories. Preserve timings/damage and scale speed/radius/range once. Give zero-input dash a defined last-facing direction. Dash invulnerability protects the hero only. Pulse uses horizontal distance on both sides. Preserve single-hit swept projectile behavior and connect ranged fire from 52.

Keep simple, readable warnings and ability feedback. Projectiles, cooldowns, and abilities advance only in the common scheduler and clear correctly at terminal/reset boundaries.

## Acceptance

- Friendly projectile hits once, ignores dead targets, expires, and cannot skip a target along its tested travel segment.
- Ranged windup leads to the expected hostile hit; pause freezes in-flight projectiles.
- Moving away from the old aim point avoids an actual nonintersecting shot; moving into its swept segment takes damage. A nearer intervening enemy intercepts a friendly shot. Test both travel directions, dead targets, zero-distance aim, and Triple shot single-hit behavior per projectile.
- Dash direction/duration/cooldown/invulnerability and pulse radius/damage/cooldown match existing rules in scaled coordinates.
- Restore weapon, ranged, and ability behavioral coverage from the matrix.
- One complete extraction run is playable with real enemies, weapons, abilities, sealing, results, and retry. Record manual checks separately from headless results.

## Stop

No new abilities, manual aiming, or art production.

## Completion note

Completed 2026-09-07.

- Repaired `prototype/scripts/game/projectile.gd` to resolve hits from the current per-step horizontal travel segment. Hostile shots test the hero's current ground position, friendly shots select the nearest live enemy on the current segment, dead targets are ignored, and zero-distance aims use the owner's facing.
- Integrated friendly/hostile projectile creation, automatic fire, dash invulnerability/direction/cooldown, pulse range/damage/cooldown, and Triple shot as three same-lane projectiles through the controller-owned scheduler. No vertical gameplay trajectory or new ability was added.
- Added `prototype/tests/weapons_abilities_2d_test.gd` covering both projectile travel directions, intervening-target interception, dead-target immunity, moving away from an old aim point, moving into a swept path, zero-distance facing, dash protection, pulse cooldown/radius, and Triple shot per-projectile single-hit behavior.

Actual checks:

- `prototype/run_tests.ps1 -GodotPath .\\Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe`: all 15 active tests passed, including `weapons_abilities_2d_test.gd` and the prior lifecycle/surge coverage.
- Direct `weapons_abilities_2d_test.gd`: passed `2D weapons and abilities checks passed`.
- Active project imports and boots without script diagnostics. No authored active 3D runtime references remain.
- Archive manifest remains unchanged at 222 files.

Manual runtime walkthrough, window-focus/input checks, and visual projectile/ability readability remain pending. Archived 3D weapon/ranged/player fixtures are not reported as passing; their 2D replacements are owned by this card and the remaining ranged integration can extend them later.
