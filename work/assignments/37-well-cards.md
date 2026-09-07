# 37 — Well cards and guard slots

Dependencies: 36. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §2, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Build reusable WellCard and HeroSlot components. Show both wells, their state, actual passive rate, assigned guard or + Assign guard, and Prepare here. Implement locked, available/uncommissioned, commissioned/empty, guarded and active-expedition variants. Emit destination/guard-picker intents with well IDs. Render the active operator as activity information rather than falsely labeling them Guard. Selected destination does not change assignments.

## Acceptance checks

Fixture checks cover all states. The + appears only where guard assignment is unlocked; disabled states explain why. Guard portrait/name and rate belong to the correct card. Prepare here emits one correct ID without starting a run. State refresh preserves selection/focus. Manual visual check confirms the two wells read as peers.

## Stop boundary

Do not implement the picker yet. Use initials/simple silhouettes as portraits; no art generation or new site unlocks.

## Completion note

Completed. Added reusable `WellCard` and `HeroSlot` controls under `prototype/scripts/ui/`. Cards render stable IDs, state labels, schematic placeholders, authoritative passive rates, guard initials/name, unstaffed assignment affordances, active-expedition activity text, availability reasons and selected destination state. `WellCard` emits `destination_requested(well_id)` and `guard_picker_requested(well_id)`; `OperationsPreview.refresh()` updates existing cards so controls and focus targets are preserved. The preview now consumes card 35 fixture view state; no picker or domain mutation was added. Added `well_cards_test.gd` covering locked, available, commissioned-empty, guarded and active variants, correct guard ownership, disabled states and one-ID intents. Full suite: 34 tests passed. Manual visual peer-card check remains pending. Queue row 37 is DONE.

