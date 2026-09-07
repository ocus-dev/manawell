# 11 — Extraction playtest checkpoint

Dependencies: 10. Status is tracked in ../README.md.

## Read first

Completed A-card handoffs; relevant test commands. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Verify milestone A and record whether its central decisions are promising.

## Implement

Run the existing targeted checks and a compact manual sequence: fresh run, success, hero failure, machine failure, pause during sealing, retry, and each upgrade. Compare instant and delayed sealing. Write work/playtests/extraction.md with actual observations, mode, basic run duration/payout, issues, and suggested tuning. Fix only small directly observed milestone defects; record larger fixes as separate follow-up cards.

## Acceptance checks

All executable checks pass or are explicitly reported blocked. Report actual manual evidence, not assumed enjoyment. Include whether extraction timing changed across runs and whether upgrades were perceptible. State human feedback pending if no human tested it.

## Stop boundary

No network, save system, second well, or broad redesign. The next milestone follows this checkpoint; unresolved runtime defects must be addressed first.

## Completion note

Completed the milestone A extraction checkpoint. Added `prototype/tests/extraction_checkpoint_test.gd` for fresh run, success, hero failure, machine failure, pause during sealing, retry, instant/delayed sealing, and next-run upgrade evidence. Added `work/playtests/extraction.md` with measured headless observations, timing/payout results, tuning questions, and explicit human-feedback limitations. Fixed directly observed generic failure feedback by distinguishing `hero_destroyed` and `machine_destroyed` in `prototype/scripts/model/run_state.gd` and the HUD.

Checks run with `Godot_v4.8-dev4_win64_console.exe --headless`: all 11 prototype test scripts and main-scene startup exited 0 with no reported errors. Human playtesting and target-resolution readability remain pending; no network, save, second-well, or broad redesign work was added.

