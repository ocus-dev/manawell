# P03 — Verify the compact HUD in the visual slice

Dependency: P02. Status tracked in work/platforming/README.md.

## Implement

Use real runtime fixture captures and the existing render-capture approach. Capture both supported resolutions with the environment and all actor roles during combat, low HP, ranged windup, dash/pulse cooldown, sealing, and pause. Add focused layout assertions measuring rendered widget rectangles and checking reserved-band boundaries rather than checking implementation names.
Inspect every persistent element against the owner's instruction that each pixel must justify itself. Remove redundant labels/large panel padding in scope. Keep small text readable rather than meeting area budgets by shrinking fonts beyond the queue minimum. Run applicable UI, click routing, presentation, operations layout and combat tests.
Write work/playtests/compact-combat-hud.md with before/after screenshots, widget bounds, checks and any unresolved readability/input observations.

## Acceptance

Health, pressure, skill icons, harvest risk and pause remain readable at both resolutions; no static widget enters the platforming play area. Actual screenshots are inspected, not inferred from headless passes. No unrelated UI or gameplay regression.

## Stop boundary

Deliver this compact UI milestone, then the next assigned card may begin. No new user-approval gate is required for already-authorized platforming.

## Completion note

DONE. Added the native `prototype/tests/compact_combat_hud_acceptance_test.gd` fixture and `work/playtests/compact-combat-hud.md`. It captures the prepared foundry with hero, harvester, pursuer, breaker, ranged windup/projectile, low hero/machine health, dash/pulse cooldowns, sealing, and pause at 1280x720 and 1920x1080. Captures were inspected directly; both resolutions contain the rendered environment and HUD. Logical bounds are Survival (24,8) 293x56, Pressure (500,6) 250x58, Pause (1168,8) 102x51, AbilityBar (24,660) 104x52, and Extraction (490,656) 300x60. The acceptance fixture verifies every rectangle remains in the viewport, top widgets stay within y=0...64, and bottom widgets stay within y=656...720 without entering the play area. Passed native acceptance, combat widgets, weapons/abilities, presentation, operations layout, pause/results, and view-state tests; headless acceptance assertions and editor diagnostics are clean. No unrelated UI/gameplay changes were made. Remaining limitation: keyboard feel and tooltip focus were not human-playtested; the known unrelated progression test timeout remains.

