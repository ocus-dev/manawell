# 44 — Input routing and final HUD integration

Dependencies: 43. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §§8–9, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Finish replacing the legacy UI in the running scene with the new composed HUD. Use one input-routing path compatible with the architecture scheduler: top modal first, focused GUI controls next, gameplay only for unhandled intents. Ensure polling cannot re-detect a consumed E/Space key. Preserve selectors/modal selection across data refreshes. Remove superseded old UI adapters/builders after callers/tests are migrated; keep domain and persistence owners unchanged.

## Acceptance checks

Real input events: E starts or harvests once; Space on a button does not dash; E inside picker/settings does nothing to the encounter; Escape closes top modal and restores focus; pointer clicks never pass into arena. Repeated open/close/switch operations leave no duplicate signals or orphan overlays. Full existing and new headless suite passes; report any manual input checks not run.

## Stop boundary

No blanket domain API rewrite or simulation timing changes. Do not retain two live HUDs or two event consumers as a compatibility shortcut.

## Completion note

Replaced the live legacy HUD path with the composed `EncounterHUD` root in `prototype/scripts/ui/encounter_hud.gd`, assembling operations, combat widgets, pause/results routing, notices, and settings while preserving the existing ID-based controller signals. `EncounterController` now publishes `UiViewState` snapshots and consumes gameplay shortcuts only through `_unhandled_input`, preventing handled E/Space events from falling through to polling. Settings and picker modals consume their keys, restore opener focus, and pointer input is stopped at the HUD root. Removed the live duplicate path; domain, persistence, and scheduler owners remain unchanged. Focused HUD, lifecycle, notices, and full-suite checks pass except the existing unrelated `recovery_equivalence_test.gd` failure. No screenshots or manual keyboard/mouse walkthrough were run; visual/input verification remains for assignment 45.

