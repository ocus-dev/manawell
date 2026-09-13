# Side-view defense experiment playtest handoff

Date: 2026-09-07

## Implemented scope

S03 completes one fixed-camera procedural side-view encounter on the existing isolated project at `experiments/side-view-defense/`. The scene has a central industrial harvester, animated extraction ring and moving mechanism, service walkway, distant gantries and stacks, sparse foreground structure, bounded horizontal movement, role-specific enemy silhouettes, entry warnings, ranged windup warnings, friendly and hostile projectile colors, dash and pulse feedback, machine damage flashes, health, machine integrity, tank, sealing, payout, pause, and clean retry.

The camera remains fixed. There is no scrolling, parallax system, jumping, persistence, progression, external art, or dependency on the 3D prototype. The preserved baseline is `prototype/` and its source inventory remained unchanged at 101 files with aggregate SHA-256 `cb9302330a55a5a4b740c305a3cb04e057048d1e9cac2e10d2ec3e1f11384f1a`.

## Launch and controls

From the repository root:

```powershell
& '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe' --path '.\experiments\side-view-defense'
```

A/D or left/right arrows move. Space dashes in the last movement direction. Q pulses. E starts extraction or begins harvest/sealing. Escape pauses. The visible buttons provide Start/Harvest, Retry, and Pause/Resume.

## Authored schedule

The deterministic schedule in `experiments/side-view-defense/data/schedule.gd` introduces pursuers at 5s left and 10s right, a breaker at 18s left, a ranged threat at 26s right, a breaker at 36s right, a ranged threat at 46s left, mixed pursuer/breaker pressure at 58s, mixed ranged/pursuer pressure at 70s, and mixed breaker/ranged pressure at 82s. The live-enemy cap remains the copied default of 60. No balance values were tuned for S03.

## Actual checks and evidence

```powershell
& '.\experiments\side-view-defense\run_tests.ps1' -GodotPath '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
```

Passed `movement_test.gd` and `defense_test.gd`. The test runner reports known headless CanvasItem/ObjectDB leak warnings after the movement process, but exits successfully. `get_errors` reported no errors for the experiment.

The actual main scene also booted and exited successfully headlessly with:

```powershell
& '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe' --headless --path '.\experiments\side-view-defense' --resolution 1280x720 --quit-after 2
& '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe' --headless --path '.\experiments\side-view-defense' --resolution 1920x1080 --quit-after 2
```

Native Godot window screenshots were not captured: the available capture tooling only controls browser pages, and no native-window capture tool was available. Therefore there is no screenshot evidence claimed for either resolution. Interactive input focus behavior and a human walkthrough remain pending.

## Observation table

| Question | Observed evidence | Verdict |
|---|---|---|
| Does holding one side trivially dominate? | No human run performed. | Pending human playtest |
| Is crossing through the machine readable? | Procedural service walkway is present; no human observation performed. | Pending human playtest |
| Does automatic targeting help interception? | Deterministic nearest-target behavior passes focused tests; feel is untested. | Pending human playtest |
| Do dash and pulse offer choices beyond cooldown use? | Dash protection and pulse range/cooldown pass focused tests; decision quality is untested. | Pending human playtest |
| Does the fixed side view make the industrial world more compelling? | Procedural machinery, gantries, stacks, role silhouettes, and restrained motion are implemented; visual inspection was not captured. | Pending visual and human review |
| Are attacks, machine damage, and harvest risk clear? | Functional states and color/feedback paths are implemented; interactive readability is untested. | Pending human playtest |

## Human playtest protocol

1. Play a fresh run and harvest early to learn the controls and sealing.
2. Retry and stay until all three enemy roles and mixed-side pressure appear.
3. Try holding one side, then actively intercepting threats on both sides. Note whether either strategy trivially dominates.
4. Judge whether crossing through the machine feels readable, whether automatic targeting helps or frustrates interception, and whether dash/pulse offer choices beyond cooldown use.
5. Judge whether the fixed side view makes the machinery/world more appealing and whether attacks, machine damage, and harvest risk remain clear.

## Outcome

**Direction update — 2026-09-07:** The user reviewed the result, said they liked it, and requested the full implementation queue. Side view is approved; continue with `work/2d/README.md` cards 49–57. The original observations and pending technical checks below remain historical evidence; approval does not claim that native screenshots or focus tests were performed.

Implementation is complete, but the experiment does not select a fun verdict from automated checks. The current handoff recommendation is **pending human playtest**, with the next decision constrained to: pursue side view, revise one specific arena/combat issue and retest, or return to top-down. A jump/platform experiment is a separate possible follow-up and is not part of this deliverable. Cards 49-57 are not resumed automatically.

## Known limitations

- Native screenshots at 1280x720 and 1920x1080 were unavailable in the current tooling environment.
- Interactive runtime walkthrough, UI focus/modal input isolation, and human experience fields remain pending.
- The scene uses procedural primitives rather than production assets.
