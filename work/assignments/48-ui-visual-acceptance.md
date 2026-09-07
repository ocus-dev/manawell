# 48 — Verify the live interface against the design

Depends on 47. Track status in work/interface/README.md.

## Goal

Close the missing visual acceptance gate from 45. Read design/Interface.md and work/reviews/ui-implementation-gap.md. Do not declare the interface successful solely because headless tests pass.

## Verify

1. Run the repaired UI/layout/input tests and the reliable full suite. Record unrelated pre-existing failures explicitly; never describe a suite with a failing test as entirely passing.
2. Run the actual main scene using an isolated fixture profile. Capture operations at 1280×720 and 1920×1080, guard picker, extracting, sealing and result states. Also capture a persistent save-error notice using a fixture. Use real Godot renders, not the HTML mockup or a reconstructed image.
3. Walk through: click + on commissioned well 1, assign reserve hero, prepare well 2, change active hero where legal, purchase an upgrade, open/close Settings, start, pause/resume, harvest, return and retry. Check keyboard and pointer paths. Verify no duplicate rows, off-screen controls, overlapping hit areas, lost focus, or stale guard/payout text.
4. Compare against the design's hierarchy: wells and guard slots together; separate You control card; compact research; clear primary Start; unobstructed combat center; separate pause/result surfaces. Preserve the intended design rather than accepting whatever the current containers happen to produce.
5. Fix only small defects directly observed here. If a larger issue remains, write an exact follow-up and leave visual acceptance incomplete.

## Deliver

Append a dated follow-up to work/reviews/interface-review.md with screenshot paths, tested dimensions, real commands/results, actual input walkthrough evidence and remaining issues. Update the queue. Preserve prior records as history. If graphical capture or manual interaction is unavailable, state the limitation and leave this acceptance card BLOCKED; do not repeat assignment 45's DONE-without-visual-verification outcome.

No gameplay tuning, unrelated recovery repair, publishing, new asset dependencies or changes to the player's real save.

## Completion

BLOCKED 2026-09-06. The reliable Godot suite was run with `prototype/run_tests.ps1` against `Godot_v4.8-dev4_win64.exe`; all discovered tests passed, including operations, picker, routing, settings, combat, pause/results, and recovery checks. Automated layout fixtures cover 1280x720, 1920x1080, and narrow responsive composition, but they are not graphical acceptance. This environment exposes browser-page screenshots only; it has no native Godot-window capture or manual pointer/keyboard walkthrough harness. No real profile was opened or changed, and no screenshots can be honestly recorded. Operations, picker, extracting, sealing, result, save-error rendering, and the requested input journey remain unverified. Resume with a desktop capture/manual-input environment and append the native screenshot paths and walkthrough evidence before marking this card DONE.
