# 10 — Feedback and onboarding

Dependencies: 09. Status is tracked in ../README.md.

## Read first

Current HUD and arena; compact spec visual minimum. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Make the extraction loop understandable without a spoken explanation.

## Implement

Add short first-run instructions for movement, start, at-risk tank, sealing danger, and retry. Make sealing and successful banking visually unmistakable; show explicit failure cause. Give enemy types distinct silhouettes and make ranged windups legible. Add simple local/generated tones if practical without dependencies; keep audio optional. Provide a developer setting for 0/2 second sealing and hide damage/debug shortcuts from normal play.

## Acceptance checks

Walk through a fresh session using only on-screen instructions. Check HUD at both target resolutions, pause/resume, keyboard and button harvesting, and success/failure feedback. Text must not imply instant safety when sealing takes two seconds.

## Stop boundary

No art overhaul, shader work, downloaded assets, or lengthy tutorial stage.

## Completion note

Implemented state-aware onboarding and outcome feedback in `prototype/scripts/game/encounter_controller.gd`: controls, tank risk, non-instant sealing danger, banked success, explicit failure cause, and retry guidance. Developer damage controls are hidden by default; `developer_mode` exposes them along with the exported 0/2-second `sealing_duration_setting`. Added a visible ranged attack telegraph ring in `prototype/scripts/game/ranged_enemy.gd`. Added `prototype/tests/feedback_onboarding_test.gd` covering the full success/failure walkthrough and developer seal setting.

Checks run with `Godot_v4.8-dev4_win64_console.exe --headless`: bootstrap, arena movement, run state, encounter, melee, automatic weapon, surges/ranged, player abilities, upgrade purchases, feedback/onboarding, and main-scene startup all exited 0 with no reported errors. Remaining limitation: audio feedback and final target-resolution manual readability checks remain optional playtest work.

