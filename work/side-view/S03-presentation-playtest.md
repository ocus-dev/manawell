# S03 — Visual slice and playtest handoff

Read the queue and S02 handoff; only relevant industrial palette, silhouette, atmosphere, and readability sections of `design/visual-style-bible.md`.

## Implement

Build one coherent procedural industrial scene: large central harvester with restrained moving mechanism/extraction feedback, service walkway, distant structural silhouettes/stacks, and sparse foreground framing that does not hide threats. Distinguish enemy roles through silhouettes and motion, not just color. Show target/facing direction, entry warnings, windup, hostile versus friendly fire, dash, pulse, and machine damage clearly. Keep the camera fixed and all attacks visible; do not introduce actual scrolling/parallax camera systems.

Keep essential HUD and controls readable without covering the ground lane at 1280×720 and 1920×1080. Use short hit flashes and restrained machine motion; no screen shake required. No external art or complex animation pipeline.

Run the complete experiment suite and an actual runtime walkthrough where tooling permits. Capture and inspect runtime screenshots at both resolutions. Record unperformed checks explicitly if unavailable; never claim screenshot evidence from generated mockups. Confirm baseline source remains unchanged and document exact launch commands.

Create `work/playtests/side-view-experiment.md` with implemented scope, controls, authored wave schedule, config/tuning changes, actual checks/screenshots, known issues, and the following short human playtest protocol:

1. Play a fresh run and harvest early to learn the controls and sealing.
2. Retry and stay until all three enemy roles and mixed-side pressure appear.
3. Try holding one side, then actively intercepting threats on both sides. Note whether either strategy trivially dominates.
4. Judge whether crossing through the machine feels readable, whether automatic targeting helps or frustrates interception, and whether dash/pulse offer choices beyond cooldown use.
5. Judge whether the fixed side view makes the machinery/world more appealing and whether attacks, machine damage, and harvest risk remain clear.

Provide a brief observation table with question, observed evidence, and verdict; leave human experience fields pending if no human played. Frame the outcome as one of: pursue side view, revise one specific arena/combat issue and retest, or return to top-down. Do not choose a fun verdict solely from automated tests. Note that a jump/platform experiment is a separate possible follow-up, not part of this deliverable.

## Acceptance

- One locally runnable, visually coherent side-view encounter with real combat and results; tests and runtime evidence clearly distinguished.
- No main-project changes, old-save handling, full migration, or dependency on archived/3D assets.
- A user can launch and evaluate the experiment from the written instructions without reconstructing task history.
- Implementation completion and pending human evaluation are explicitly separate. Stop for the user's direction after the handoff; do not resume cards 49–57 automatically.

## Completion note

Completed 2026-09-07.

- Built the coherent procedural industrial scene in `experiments/side-view-defense/`: central harvester with animated mechanism and extraction feedback, service walkway, distant gantries/stacks, restrained foreground framing, role-specific enemy silhouettes, entry warnings, windup warnings, projectile colors, dash/pulse feedback, and machine damage flash.
- Kept the camera fixed and the ground lane clear of scrolling/parallax systems. No external art, persistence, progression, jumping, or prototype/3D asset dependency was added.
- Updated the HUD and visible controls for S03, fixed the Retry button to perform the complete encounter cleanup, and retained the deterministic S02 wave schedule and copied balance defaults without tuning changes.
- Created `work/playtests/side-view-experiment.md` with launch commands, controls, schedule, implementation/runtime evidence, observation table, human protocol, known limitations, and pending outcome choices.

Actual checks:

- `experiments/side-view-defense/run_tests.ps1 -GodotPath Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe`: passed `movement_test.gd` and `defense_test.gd`.
- Headless main-scene boot passed at both `1280x720` and `1920x1080` using `--quit-after 2`.
- `get_errors` reported no errors for the experiment.
- Prototype source inventory remained unchanged: 101 files, aggregate SHA-256 `cb9302330a55a5a4b740c305a3cb04e057048d1e9cac2e10d2ec3e1f11384f1a`.

Native runtime screenshots were not captured because the available capture tooling controls browser pages, not native Godot windows. Interactive runtime walkthrough, input-focus behavior, visual inspection at both resolutions, and human playtest verdict remain pending. Automated checks do not select pursue/revise/return; stop here for the user's direction. Cards 49-57 are not resumed automatically.
