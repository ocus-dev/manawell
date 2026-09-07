# 31 — Extract HUD and preserve selection

Status: tracked in work/architecture/README.md. Dependencies: 30.
Review coverage: Finding 6 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: controller HUD build/refresh and adapters; main.tscn. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Move HUD construction and update code into scripts/ui/encounter_hud.gd and an appropriate scene if useful. Emit typed command signals carrying IDs. Feed a compact view state to the HUD; it must not save, award mana, or mutate account models. Separate dynamic labels from structural list refreshes. Rebuild lists only when their contents change, preserving selected IDs; handle a selected item becoming unavailable explicitly.

## Acceptance checks

Selection survives many idle/render frames; changed roster/availability updates once and chooses a valid fallback. Each signal maps to the right command ID. Run headless UI checks plus a manual dropdown/open-popup check when available; report manual checks honestly. Health/timers remain responsive and save calls do not originate from HUD code.

## Stop boundary

Preserve current layout, labels and controls unless a correctness fix requires a small adjustment. No menu redesign or art work.

## Completion note

Moved HUD construction and structural controls into `scripts/ui/encounter_hud.gd`. `EncounterHUD` emits typed ID signals for wells, loadouts, heroes, guard assignment, recall, and upgrades, and receives a compact read-only view state. The controller remains the sole owner of account mutation, saving, simulation, and payout. Selector signatures prevent unchanged lists from rebuilding each render while preserving selected IDs and refreshing availability changes. Added `encounter_hud_test.gd` for 120 refresh cycles and exact signal payloads. Focused onboarding, encounter, assignment, command, and full-suite checks passed. Manual dropdown/open-popup inspection was not performed in the headless environment.

