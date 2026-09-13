# I05 — Bind the library to live skills and item-like UI

Dependencies: I04, P03 and P04 complete, and live widget files unowned by an active task. Read current handoffs and current source; do not assume P02 still uses its original file structure.

## Implement

Replace only the hotbar's visual icon resources with skill.dash and skill.pulse through the new lookup. Preserve actual action IDs, click/hotkey handling, current Shift/Q badges, tooltip/focus labels, cooldown overlays, disabled states and compact size limits. Do not copy gallery state behavior into the gameplay widget. Jump remains a movement action with no skill slot.

Add the prepared small icons beside existing upgrade and loadout labels, and resource.mana beside the existing wallet/tank text where useful. This is icon binding, not a new inventory UI. Preserve semantic labels, IDs, purchase/loadout legality, affordability states, focus and accessible descriptions. Do not increase card or hotbar minimum size just to accommodate art; use fixed bounded icon dimensions and remove redundant decoration if needed. No game-rule/catalog-ID edits.

Unknown resource keys render the fallback cleanly. Add/update focused integration checks for correct skill/upgrade/loadout mapping, click behavior, disabled/cooldown/selected states, and no size growth during refresh. Run existing operations layout, compact combat HUD and interaction tests plus the full active suite after the narrow integration is complete.

Capture actual runtime hotbar during cooldown and ready states, and operations with upgrades/loadouts at both supported resolutions. Verify tinting does not obscure item identities or make skill keys unreadable. Update art/ui-assets/README.md and review.md with consumers, actual checks, screenshots, extension steps for future IDs, and remaining visual revisions.

## Acceptance

Existing live controls use the shared icon library, fit the compact HUD/layout budgets, and retain all actions/labels/state behavior. No new inventory/skills/items or overwritten concurrent changes. Both runtime captures and automated outcomes recorded; no implied owner art approval.

## Stop

Hand off for owner review. Do not add rarity variants, new item mechanics, hotbar slots or automated art rerolls.

## Completion note

Pending.
