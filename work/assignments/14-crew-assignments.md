# 14 — Second hero and assignment rules

Dependencies: 13. Status is tracked in ../README.md.

## Read first

Account roster, well selector, assignment contract. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Implement a small exclusive-assignment model.

## Implement

Support hero_1 and unlocked hero_2 as active selection/reserve/guard records. Hero 2 shares combat stats but has a different primitive color/shape and the specified guard trait. Add minimal preparation controls to assign/recall a guard at a commissioned well. Enforce one role per hero and one guard per site. Starting a guarded well releases that guard with clear pre-start text.

## Acceptance checks

Model checks cover locked hero/site, double assignment, recall, active availability, and starting a guarded site. Recall always provides a route back into play. Round-trip assignments through saves. No passive mana is credited yet.

## Stop boundary

No roster expansion, recruitment, equipment, or production timers.

## Completion note

Completed the exclusive crew-assignment model. Extended `prototype/scripts/model/account_state.gd` and versioned saves with `hero_assignments`, active/reserve/guard roles, one-hero-per-role enforcement, one-guard-per-site enforcement, active hero selection, guard assignment, recall, and guarded-site release. Added preparation controls and assignment feedback in `prototype/scripts/game/encounter_controller.gd`; Hero 2 uses a blue box primitive while Hero 1 retains the red capsule. The HUD now groups preparation, run status, encounter actions, upgrades, and developer controls into collapsible sections with scrolling fallback so the preparation controls remain reachable on smaller windows.

The qualifying-success credit path now calls the commission-aware account operation, and the collapsed Account section provides a guarded clear-save action for playtest resets.

Added `prototype/tests/crew_assignments_test.gd` covering locked hero/site, double assignment, recall, active availability, save round-trip, and starting a guarded site. Focused UI integration checks and main-scene startup exited 0 after the collapsible-menu refactor. No passive mana, production timers, recruitment, equipment, or roster expansion were added; assignment UI remains intentionally minimal.

