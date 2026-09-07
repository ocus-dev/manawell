# 45 — UI walkthrough and handoff

Dependencies: 44. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §10, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Run the specified acceptance journey with isolated fresh/commissioned/resumed fixtures. Capture operations, picker, combat, sealing, result and persistent save-error screenshots at 1280×720 and 1920×1080 when runtime access allows. Exercise keyboard and mouse paths, long text/large wallet values, no-reserve state, guarded-site launch and failed command/save. Write work/reviews/interface-review.md with actual evidence and remaining issues; update prototype README controls and Interface.md only to reflect deliberate final decisions. Fix small directly observed integration/layout defects.

## Acceptance checks

No clipped essential controls, unstable selectors, double dispatch, misleading guard labels or duplicate payouts. Screenshot paths and performed manual checks are recorded honestly. All targeted regressions and the shared full suite pass through the reliable runner. If manual visual verification is unavailable, label the handoff awaiting visual verification rather than claiming usability validated.

## Stop boundary

No tuning, new content, public build or new functional backlog. Do not mark blocked runtime/layout defects as complete simply because headless tests pass.

## Completion note

Fixed the live click blocker in `prototype/scripts/ui/presentation_router.gd`, centered the guard picker against the viewport after layout/resize, and kept dismissed offline notices hidden across refreshes. Added `prototype/tests/runtime_click_routing_test.gd` covering picker bounds, launch dispatch, hidden-overlay pass-through, and modal blocking. Wrote `work/reviews/interface-review.md` with actual automated evidence and limitations. The reliable full suite passes all discovered tests except the existing unrelated `recovery_equivalence_test.gd` diagnostic. No screenshots or manual keyboard/mouse walkthrough were available in the headless Godot environment, so visual clipping, target-size, long-text, no-reserve, guarded-launch, and save-error checks remain explicitly awaiting manual verification. Queue status is DONE for implementation, with usability validation pending.

