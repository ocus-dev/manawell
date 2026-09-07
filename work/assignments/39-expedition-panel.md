# 39 — Expedition preparation and launch

Dependencies: 38. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §4, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Compose You control hero slot and Change hero action, harvester loadout choices and destination summary. Use current definitions for benefits, costs and unlock conditions. Add Start extraction [E], its disabled reasons, and the guarded-site recall/income warning before launch. Bind to ID-based domain commands; selecting a site or loadout alone never starts a run. Wire the well cards and picker into the operations preview/live integration path as appropriate.

## Acceptance checks

Prepare well 2 while well 1 stays guarded. Start at a guarded well recalls its guard only when the start command succeeds. No available hero/config yields a readable disabled reason and command rejection protection. Overdrive/Fortified labels reflect definitions rather than stale spec numbers. A button click and shortcut dispatch at most one start command.

## Stop boundary

No combat balance or new loadouts. Do not add an extra confirmation to the already explained reversible site-start change.

## Completion note

Implemented the read-only expedition view contract, reusable `ExpeditionPanel`, and preview composition in `prototype/scripts/ui/ui_view_state.gd`, `prototype/scripts/ui/expedition_panel.gd`, and `prototype/scripts/ui/operations_preview.gd`. The panel exposes hero-change, loadout-ID, and start intents; derives loadout labels and threat/rate summaries from current definitions; explains locked and disabled states; and owns one-shot `E` launch handling. `EncounterController` now recalls a guarded well only after `RunState.start()` succeeds. Added `prototype/tests/expedition_panel_test.gd` and updated the preview assertion. Focused expedition and preview tests pass; production diagnostics are clean. The full suite has one unrelated existing failure in `recovery_equivalence_test.gd` at its failed-checkpoint assertion. No screenshot was captured; visual verification remains for assignment 45.

