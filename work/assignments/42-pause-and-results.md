# 42 — Pause, results and return flow

Dependencies: 41. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §7 results/pause; §8, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Implement PausePanel and ResultPanel with a small explicit presentation state router. Pause offers Resume, Settings and Abandon current tank with amount and confirmation. Results show actual run reward/loss, cause and completed surge; Return to operations is primary and Retry same expedition secondary. Use existing commands; add only a narrow terminal-to-preparation command if missing, preserving account and not starting a run. Keep management actions unavailable while paused.

## Acceptance checks

Success/failure displays run outcome independently of passive income. Return does not retry; Retry deliberately starts a valid same configuration. Escape closes a child modal before resuming pause. Cancel abandon preserves tank; confirm forfeits once. Recovered run begins paused and resumes explicitly. No two terminal overlays coexist.

## Stop boundary

Do not redesign combat failure penalties or reset persistence. Avoid a general-purpose navigation framework.

## Completion note

Implemented `PausePanel`, `ResultPanel`, and an exclusive `PresentationRouter` in `prototype/scripts/ui/`. Pause owns Resume, Settings, and abandon confirmation; Escape closes the child confirmation before resuming. Results use actual run reward/loss, terminal cause, and completed surges, with distinct Return and Retry intents. Added `EncounterController.return_to_operations()` as a terminal-only reset that clears the encounter without starting a run. Extended `UiViewState` result fields and added `prototype/tests/pause_results_test.gd`, including the real controller return path. Focused and full-suite checks pass except the existing unrelated `recovery_equivalence_test.gd` failure. These panels remain preview-only until assignment 44 integrates the live HUD; no screenshot was captured.

