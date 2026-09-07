# 04 — Encounter wiring and HUD

Dependencies: 02, 03. Status is tracked in ../README.md.

## Read first

Run-state public methods and handoff; main scene and player. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Connect the extraction model to a playable start/harvest/retry flow.

## Implement

Add a small encounter controller and in-memory account bank. Wire E and a button to start/harvest. Display phase, bank, tank payout, both health bars, completed tier, next surge countdown, sealing countdown, and terminal reason. Add retry, abandon, and Escape pause. A developer-only damage control may stand in for enemies. Route result credit through one idempotent account method.

## Acceptance checks

Complete a harvest and confirm bank rises once. Repeat button presses and terminal ticks do not duplicate it. Force hero and machine death separately; bank stays intact. Pause freezes extraction and sealing; retry resets state. Check death versus seal completion with an integration fixture.

## Stop boundary

No enemy AI or durable saves. Clearly identify developer controls.

## Completion note

Done. Added the in-memory `AccountState`, `EncounterController`, HUD, start/harvest flow, pause, retry, abandon, and clearly labeled developer damage controls. Changed `prototype/scripts/model/account_state.gd`, `prototype/scripts/game/encounter_controller.gd`, `prototype/scenes/main.tscn`, `prototype/tests/encounter_test.gd`, and `prototype/README.md`. The encounter integration test exited `0`; it covers one-time credit, duplicate terminal ticks, pause, retry, separate hero/machine death, and death-before-seal ordering. Existing bootstrap, movement, extraction, and main-scene checks remain passing. No enemy AI or durable save was added. Next card can use `EncounterController.run_state`, `account_state`, and `tick(delta)`.

