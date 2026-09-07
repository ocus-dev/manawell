# 22 — Reliable test runner

Status: tracked in work/architecture/README.md. Dependencies: 21.
Review coverage: Finding 5 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: prototype/tests/*_test.gd; prototype/README.md. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Add one PowerShell entry command with an optional test filter and explicit Godot path. Capture per-test output, enforce a timeout, and fail on nonzero exit, assertion failure, parse error, or SCRIPT ERROR even if Godot returns zero. Use a small reusable check helper for new tests; retain existing assertions initially. Narrowly allow only the known malformed-JSON diagnostic in the fixture that expects it. Add isolated intentional-failure and timeout fixtures excluded from ordinary test discovery.

## Acceptance checks

Prove the wrapper returns nonzero for a nested failed assertion followed by quit(0), a script error, and a timeout. Run all 21 existing tests and report their actual results. A missing executable or unwritable fixture location must fail clearly. Test fixtures must never target the player profile.

## Stop boundary

No gameplay or persistence refactor. Do not convert all tests just for stylistic uniformity.

## Completion note

Completed. Added `prototype/run_tests.ps1` with required `-GodotPath`, optional `-TestFilter`, per-test logs, 30-second timeout, exit/diagnostic checks, and the account-save malformed-JSON exemption. Added `prototype/tests/test_check.gd` and isolated assertion, script-error, and timeout fixtures under `prototype/tests/fixtures/`. Updated the prototype README and architecture queue. The full 21-test suite passed with exit 0. The assertion, script-error, and timeout fixtures each returned exit 1. Missing executable and invalid log-directory checks failed clearly; timeout cleanup left no Godot process. Tests use only `user://test_*` fixtures or project-local logs and never target the player profile. Remaining limitation: the runner uses PowerShell 5.1 and the documented Godot console executable.

