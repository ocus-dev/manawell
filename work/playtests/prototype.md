# Prototype verification handoff

Date: 2026-09-05
Mode: Godot 4.8.dev4 headless regression plus a fixture-backed fresh-profile end-to-end session. No human interactive playtest, visual target-resolution pass, or fun judgment was performed.

## Automated result

All 21 test scripts exited 0, followed by main-scene startup with exit 0. The suite covers bootstrap, movement, extraction, combat, ranged threats, abilities, upgrades, feedback, commissioning, assignments, online and offline production, snapshots, suspend/resume, loadouts, and this end-to-end journey. `account_saves_test.gd` intentionally prints a JSON parser diagnostic while testing malformed-save recovery; its exit code is 0.

Command used from the repository root:

```powershell
$godot_console = 'C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
& $godot_console --headless --path '.\prototype' --script 'res://tests/prototype_verification_test.gd'
```

The complete regression uses the same command for every script in `prototype/tests/`, then:

```powershell
& $godot_console --headless --path '.\prototype' --quit-after 1
```

## Fresh-profile journey evidence

`prototype/tests/prototype_verification_test.gd` uses separate `user://test_prototype_verification.*` fixtures and cleans them up. It verifies:

- Fresh account -> qualifying Well 1 extraction -> Well 1 commission, Well 2 unlock, and Hero 2 unlock.
- Damage, pump, and spread purchases across subsequent successful runs.
- Hero 2 assigned as Well 1 guard.
- Well 2 expedition with Well 1 passive income continuing.
- Displayed Well 1 rate of `0.625 mana/sec` and `37.50` mana credited over 60 seconds; the values match the production formula `2 x 1.25 x 1.25 x 0.20`.
- Saved sealing snapshot reloads paused, resumes, completes once, commissions Well 2, and selects Overdrive.
- Separate card tests verify Standard/Overdrive/Fortified boundaries, no mid-run switching, and snapshot persistence.

## Manual handoff

Start the editor or game using the commands in `prototype/README.md`. For a clean manual run, use **ACCOUNT > Clear saved progress** before starting. Follow this sequence: qualify Well 1, purchase upgrades between runs, assign Hero 2 to guard Well 1, start Well 2, expand NETWORK, and compare the displayed passive rate with bank growth. Start an Overdrive or Fortified run, unfocus and confirm the encounter continues, then close during sealing and reopen. Confirm the paused recovery message, press Resume, and verify the selected module and one-time payout.

Manual visual, input, collision, window-focus, and readability checks remain unperformed in this environment. Human feedback about enjoyment remains pending.

## Known issues and tuning questions

- The project uses a Godot 4.8 development build; use a stable Godot 4 release before distribution.
- Recovery is checkpoint-based, so a crash can roll back to the latest committed checkpoint rather than the last simulation frame.
- Local wall-clock time is editable; server-grade anti-cheat is out of scope.
- Balance questions remain open: whether the 2-second sealing danger is readable under late-tier pressure, whether Overdrive's faster pressure is worth its risk, and whether Fortified's 225 integrity materially changes decisions. These require human playtesting.
- No export, public distribution, services, performance overhaul, or new content was added.

All completed cards have handoff notes in `work/assignments/01-project-bootstrap.md` through `work/assignments/20-harvester-loadouts.md`.
