# P06 — Height-aware targeting, hits, and enemy pressure

Dependency: P05. Status tracked in work/platforming/README.md.

## Implement

Replace horizontal-only range and projectile hit helpers with explicit 2D combat geometry. Separate foot anchors, hurtboxes, muzzle positions, and movement support surfaces; do not derive gameplay hitboxes from sprite alpha. Document initial hurtboxes centrally, basing horizontal reach on current behavior and vertical extent on visible body mass.
Friendly auto-fire chooses the nearest live enemy in 2D range with stable tie-breaking and aims at its body center. Hostile ranged attacks lock a visible 2D aim direction at the end of their existing windup and fire straight; do not track the hero after launch. Projectiles use velocity Vector2 and swept segment-versus-hurtbox tests with travel-order first hits and current target positions. Visual muzzle and authoritative shot trajectory must agree; no decorative launch path detached from collision. Retain damage, rate, lifetime, and three-shot upgrade semantics (three shots sharing aim, each single-hit).
Pulse uses a true 2D radius. Pursuer contact damage requires vertical and horizontal proximity/shape overlap; jumping clear avoids it. Breakers continue targeting the grounded machine. In this first milestone all enemies stay on the ground: pursuers move toward the hero's horizontal location without attacking through platforms, ranged enemies can aim upward, and breakers preserve pressure on the machine. Do not add a platform pathfinding system or flying enemies.
Platforms are one-way movement supports and do not block projectiles in this version; document this deliberate rule and use visually open/slatted decks. Verify sustained two-sided threats while the hero is elevated. Fix defects, but record balance observations instead of silently changing wave timings or damage.

## Acceptance

Jumping over a ground projectile actually avoids damage; airborne hero can be hit by an intersecting aimed shot; projectiles below a platform cannot hit a nonintersecting elevated hurtbox. Melee cannot damage solely because x aligns. Friendly aim, pulse, dash invulnerability, first-hit ordering and triple shots work from ground/platform/air. Machine still takes damage while hero is elevated. Update the former horizontal-only regression expectations with actual 2D behavioral cases.

## Stop boundary

No new enemy roles/navigation, platforms blocking shots, broad damage tuning or permanent invulnerable camping verdict based solely on tests.

## Completion note

DONE. Added centralized 2D combat geometry in `prototype/data/combat_geometry.gd` with explicit feet-relative hurtboxes for hero, pursuer, breaker, ranged, and machine actors plus body-center, muzzle, circle/AABB, melee-overlap, and swept segment helpers. `prototype/scripts/game/projectile.gd` now uses Vector2 velocity and travel-order segment hits; projectile visuals follow the same aim vector. Controller auto-fire selects nearest 2D target with stable IDs, aims at body centers, pulse uses a true 2D radius, and hostile ranged shots lock the visible target point at windup completion. Pursuer contact requires 2D overlap while breakers still damage the machine; open one-way platforms do not block shots. Updated the former horizontal-facing regression and added `prototype/tests/height_aware_combat_test.gd` covering ground-projectile evasion, airborne aimed hits, vertical melee/pulse separation, locked aim, machine pressure, and 2D target selection. Checks passed: P06 fixture, weapons/abilities, diagnostics, and runtime compatibility checks. Remaining limitations: no platform-aware enemy navigation, projectile-blocking platforms, broad balance tuning, or active-run recovery; P07 owns recovery.

