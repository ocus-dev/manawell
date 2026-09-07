# 41 — Compact combat HUD

Dependencies: 40. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §6, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Implement SurvivalWidget, PressureWidget, ExtractionWidget and AbilityBar. Anchor health top-left, pressure top-center, compact wallet/pause top-right, abilities bottom-left and at-risk payout/Harvest bottom-center. Switch away from operations during extraction. Show locked payout and remaining defense time during sealing. Read time-scale-aware countdown and threat labels from authoritative state; if the current API only reports next-spawn type, label it truthfully and add a read-only next-surge selector rather than relabeling it incorrectly.

## Acceptance checks

Both health pools and Harvest remain visible at both target resolutions. At-risk amount never uses wallet delta. Sealing locks payout, disables repeat harvesting and explains continuing danger. Paused combat does not progress UI timers independently. Ability readiness/cooldown matches model. Center arena remains unobstructed; no combat-critical scrolling.

## Stop boundary

No new threat previews unsupported by the encounter data, no progress-bar timing simulation inside widgets, no ability or camera redesign.

## Completion note

Implemented `SurvivalWidget`, `PressureWidget`, `ExtractionWidget`, `AbilityBar`, and the edge-anchored `CombatPreview` in `prototype/scripts/ui/`. Extended `UiViewState` with time-scale-aware surge data, truthful pressure labeling, sealing duration, locked payout, and optional model-provided ability cooldowns. The preview keeps the arena center unobstructed, freezes presentation when paused, disables repeat harvest during sealing, and exposes ID-based harvest/ability/pause intents. Added `prototype/tests/combat_widgets_test.gd`; it passes at 1280x720 and 1920x1080. The full suite retains the unrelated existing `recovery_equivalence_test.gd` failure. These widgets remain preview-only until assignment 44 replaces the live HUD path; no screenshot was captured, so visual verification remains for assignment 45.

