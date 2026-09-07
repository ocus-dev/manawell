# 46 — Repair widget lifecycle and operations layout

Depends on 45's implementation. Current acceptance is reopened by work/reviews/ui-implementation-gap.md. Track status in work/interface/README.md.

## Read

Read the gap report and design/Interface.md sections 2, 4–5, 8–9. Inspect operations_preview.gd, well_card.gd, hero_slot.gd, expedition_panel.gd, upgrade_card.gd and the theme. Reuse the current widgets; do not rebuild the game UI from scratch.

## Work, in order

1. Make widget construction idempotent regardless of configure-before-ready or ready-before-configure. WellCard and HeroSlot currently build twice. Guard construction and keep exactly one content subtree. Check the same lifecycle convention in the other UI components you touch.
2. Update loadout buttons in place by stable ID; only change the list when definitions actually change. Identical refresh must preserve button identity, focus and signal connection count. Remove obsolete children immediately from layout before queuing deletion when structure changes.
3. Make the baseline operations layout fit 1280×720 with 24px margins and an approximate 60/40 workspace. Constrain long summaries with wrapped Label content instead of long minimum-width button text. Use a compact label/action row for research if three full purchase cards cannot fit; this matches the approved mockup's research treatment. Allow well cards to fill their grid cells. Remove redundant nested panel padding where appropriate rather than shrinking text.
4. Keep Start visible, labels readable at 16px/14px, and actionable controls at least 40px high. Keep the selected well/loadout visually identifiable without relying solely on text prefixes. Remove raw destination IDs and bracketed placeholder copy from player-facing labels; simple initials/primitive well visuals are sufficient.
5. Implement actual inner reflow and operations scrolling below the baseline width. Do not merely flip the outer box while fixed-width children overflow. Combat layout is not redesigned by this card.

## Checks

Use work/reviews/ui-layout-audit.gd as the reproduction, then add reliable assertions to the UI suite:

- Configure before and after scene entry: one content root, one guard action and one prepare action per well.
- Repeated identical refreshes: same loadout instances and focused control; a press emits once.
- After deferred layout settles at 1280×720 and 1920×1080, Settings, both wells, all research actions and Start lie within the intended viewport margins with no sibling overlap. Include fresh/commissioned and long-copy/large-wallet fixtures.
- At 800×720, operations content is accessible through intentional scrolling/reflow, with no horizontal clipping. Do not assert that the cards must remain two columns at narrow widths.

Run targeted tests through the existing reliable runner and record actual results. Do not use node-existence tests as proof of fit. Capture preview screenshots if available; final live verification belongs to 48.

## Stop

No economy, hero stats, input-router rewrite, save system changes or new art dependencies. Leave command-result/picker semantics to 47. Do not change unrelated recovery tests to make the suite green.

## Completion note

Updated `well_card.gd` and `hero_slot.gd` for idempotent construction; `expedition_panel.gd` reconciles loadouts by stable ID, removes obsolete children immediately, preserves identity/focus when available, wraps summaries, and hides raw destination IDs. Reduced research/card minimums, added compact affordability actions, inner well/research reflow, a real vertical operations `ScrollContainer`, and the operations Settings signal. After settling, Settings, wells, research actions, and Start fit 24px margins at 1280x720 and 1920x1080. At 800x720, wells reflow to one column, vertical scrolling is enabled, and the horizontal scrollbar remains hidden. Direct Godot checks pass: operations preview, expedition panel, well cards, and runtime click routing. No screenshots or manual visual checks were available; those remain stage 48 work.
