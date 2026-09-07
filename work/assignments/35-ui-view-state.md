# 35 — UI view state and preview fixtures

Dependencies: 34. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §§1, 9–10, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Inspect the actual HUD, domain command API, definitions and session view data after assignment 34. Create a small presentation contract for operations, combat, results and notices. Include stable IDs, availability reasons, authoritative bank/rates, actual run reward, guard-versus-active labels, and selected destination. Add isolated fixtures for fresh account, one well commissioned, both commissioned, no reserve hero, extracting, sealing, failure, paused recovery and save failure. Put proposed new UI scripts under scripts/ui/ and reusable scenes under scenes/ui/ unless the architecture pass established another convention.

## Acceptance checks

Rendering view state is read-only; no writes, rate settlement, or duplicated economic formulas. Fixtures never load a real player save. Two different guard/active assignments generate unambiguous labels. Snapshot-restored and normal runs expose the same display fields. Document API gaps for downstream cards; add only necessary read-only selectors now.

## Stop boundary

No layout replacement or new game rules. Do not recreate domain models in the presenter.

## Completion note

Completed. Added `UiViewState.build(account, run_state, selected_well_id, notices)` under `prototype/scripts/ui/ui_view_state.gd`. It exposes operations, combat, results and notices with stable IDs, selected destination, role-specific labels, availability reasons, authoritative passive rates, and terminal run reward. Added nine isolated in-memory fixtures in `ui_preview_fixtures.gd` for account, assignment, encounter, recovery and save-notice states, plus `ui_view_state_test.gd`. Rendering performs no writes or settlement and uses `ProductionAccounting.calculate_rates()` and `RunState.get_terminal_result()`. Downstream cards still need command-result/save-status selectors and threat/ability presentation fields; those remain controller-owned until their assigned cards. No layout or gameplay rules changed. Targeted check: `run_tests.ps1 -TestFilter ui_view_state`; manual screenshots and keyboard/focus checks remain pending. Queue row 35 is DONE.

