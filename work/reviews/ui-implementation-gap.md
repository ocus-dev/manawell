# UI implementation gap — September 6, 2026

The current components approximate the requested grouping, but do not yet implement the approved interface reliably. This exceeds a small styling cleanup. No runtime UI code was changed in this review; assignments 46–48 scope the repair.

## Reproduced observations

The audit script `work/reviews/ui-layout-audit.gd` instantiates the real operations preview using its commissioned-well fixture, waits eight process frames for container layout, and records control bounds at both target resolutions. It also compares the standard loadout button before/after refreshing the same state. It does not load or change player progress.

At 1280×720:

- Workspace minimum width is 1,529 px; available content width is 1,232 px.
- Settings starts at x=1,427, outside the viewport.
- Expedition panel starts at x=772 with width 781; its right edge is x=1,553.
- Start extraction extends to x=1,537.
- Research purchase buttons extend below the viewport (y=664 plus height 75).
- Multiple GuardAction and PrepareButton controls appear for each well.

At 1920×1080 the measured principal controls fit, but duplicate controls remain. At both resolutions, refreshing identical view state replaces the standard loadout Button instance.

Detailed measurements: `work/reviews/ui-layout-audit.log`. This is actual Godot container-layout evidence, not a screenshot or a completed mouse walkthrough. No visual render was captured during this review.

## Causes

1. `well_card.gd` and `hero_slot.gd` can build from `configure()` before entering the scene tree, then build again unconditionally in `_ready()`. `_build()` has no guard. This produces duplicate visible content and stale component references. This is a lifecycle defect, not a theme issue.
2. `expedition_panel.gd` renders long unwrapped summaries inside buttons. They establish a large minimum width. Fixed-width research cards, nested panel padding, and non-wrapping hero rows further compete for space. Stretch ratios cannot shrink containers below their children's minimum sizes.
3. `ExpeditionPanel.configure()` queues every loadout button for deletion and recreates them even for an unchanged view. This disrupts focus and pointer interaction and temporarily keeps old and new controls in the container.
4. `operations_preview.gd` changes only the outer box orientation below 960 px. It never reflows the inner well/research rows or provides the specified narrow-window scrolling.
5. The resource-strip Settings button is constructed without a pressed connection or signal; EncounterHUD wires settings only from the pause router. The primary operations Settings action is not connected.
6. Empty and locked guard slots share the same +/Assign presentation. The picker also optimistically changes its own hero data on recall and closes on selection without waiting for an authoritative command result. These diverge from the specified availability/error behavior.

## Why prior checks missed this

`operations_preview_test.gd` checks region existence and the outer `vertical` flag. It does not wait for settled layout or assert control bounds, sibling overlaps, unique component construction, or focus retention. Assignment 45's handoff explicitly says no screenshots were captured. Its DONE status therefore does not establish that the visual acceptance criteria were met.

Keep the original records intact as history, but use 46–48 as the current UI acceptance gate. Do not claim the repair complete from the previous headless suite alone.

## Repair scope

46 fixes lifecycle and constrained layout; 47 fixes existing interaction/state presentation; 48 verifies the live UI against the design. Preserve combat, economy, persistence ownership and current balance. The unrelated recovery-equivalence diagnostic mentioned in the old handoff remains separately tracked; do not silently waive it or expand UI work to redesign recovery.

Reproduce from the repository root with the installed Godot console executable, `--headless --path prototype --script ../work/reviews/ui-layout-audit.gd --quit-after 120`, and an absolute writable `--log-file` path. The script prints evidence; it is not yet a pass/fail regression test. Card 46 converts the relevant observations into assertions under the reliable runner.
