# 12 — Persistent account saves

Dependencies: 11. Status is tracked in ../README.md.

## Read first

Account model, shared save contract, test runner. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Persist bank and purchased progress safely.

## Implement

Implement versioned SaveStore and account serialization under user://. Persist on bank/purchase changes using temporary replace and last-good backup. Validate types, finite nonnegative amounts, known IDs and schema version before loading. Preserve incompatible or corrupt originals and display a recovery message. Use injected paths for tests. Active run recovery remains explicitly unavailable until card 19.

## Acceptance checks

Round-trip account and purchases; restart keeps bank. Test malformed JSON, invalid values, unsupported future version, interrupted/temp write, and backup recovery with fixtures. Failed saves produce a visible error and cannot replay payout. Tests never touch real user saves.

## Stop boundary

Do not serialize enemies or grant offline income yet. State the interim active-run limitation in prototype README.

## Completion note

Completed persistent account saves. Added `prototype/scripts/model/save_store.gd` with schema version validation, injected paths, temporary replacement, last-good backup recovery, and visible error state. Added account serialization/validation in `prototype/scripts/model/account_state.gd`; the controller loads at startup and saves successful payouts and purchases in `prototype/scripts/game/encounter_controller.gd`. Added `prototype/tests/account_saves_test.gd` covering round-trip, restart retention, malformed JSON, invalid values, future versions, backup recovery, and orphaned temp files.

Checks run: account-save fixture test, all existing prototype tests, extraction checkpoint test, and main-scene startup. Tests use injected `user://test_account_save.*` fixtures and headless runtime persistence is disabled, so the real player save is untouched. Active run recovery remains unavailable until card 19; passive/offline production remains deferred to cards 15-17.

