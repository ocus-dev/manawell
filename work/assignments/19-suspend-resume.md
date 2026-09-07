# 19 — Suspend and resume integration

Dependencies: 18. Status is tracked in ../README.md.

## Read first

Snapshot codec, encounter controller, SaveStore and reward transaction. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Restore interrupted solo encounters without duplication or rerolls.

## Implement

Save combined account + snapshot on orderly quit, focus loss, and periodic checkpoints (starting interval 5 seconds). Focus loss checkpoints without pausing active gameplay; restore actors and timers from snapshot initially paused. Reinitialize online monotonic timing after offline settlement; exclude the snapshot's active well from offline production. Commit successful reward/unlocks and clearing snapshot atomically. Make retry/abandon clear the snapshot. Explain crash rollback to last checkpoint.

## Acceptance checks

Close/reopen during extraction, ranged windup and sealing; resume preserves relevant state. Pause never accrues tank. Successful payout followed by reload pays once. A malformed active snapshot preserves bank and emits a recovery message. Save failures and backup recovery do not duplicate rewards.

## Stop boundary

No perfect recovery between checkpoints or online disconnect rules. Remove the interim README limitation from card 12 and document actual recovery guarantees.

## Completion note

Implemented suspend/resume integration across `prototype/scripts/game/encounter_controller.gd` and `prototype/scripts/model/save_store.gd`. Active encounters checkpoint every 5 seconds, on window focus loss, and on orderly close. Account saves can now carry an optional validated snapshot; startup preserves the snapshot while settling offline production, excludes its active well, restores the encounter paused, and requires explicit Resume. Actor health/positions, ranged windups/projectiles, abilities, sealing state, and spawner progress are restored. Retry, abandon, and successful payout save without a snapshot so recovery cannot duplicate rewards. Malformed snapshots preserve banked account progress and show a recovery message.

Added `prototype/tests/suspend_resume_test.gd` covering ranged snapshot capture, focus-loss checkpointing without pausing, partial sealing restore, paused behavior, resume-to-success, one-time reward with snapshot clearing, and malformed snapshot recovery. Run `& $godot_console --headless --path '.\prototype' --script 'res://tests/suspend_resume_test.gd'`; it exited 0. Manual verification: begin an extraction, wait for a ranged windup or sealing, unfocus and confirm the encounter continues, then close and reopen, confirm the NETWORK/status recovery message and paused phase, and press Resume. Repeat after a checkpoint interval and verify payout occurs once. Crash recovery is bounded by the last committed checkpoint; disconnect handling and perfect frame recovery remain out of scope.

