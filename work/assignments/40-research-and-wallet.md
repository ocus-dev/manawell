# 40 — Research cards and wallet feedback

Dependencies: 39. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §2 resource strip; §5, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Implement ResourceStrip and reusable UpgradeCard using the three existing research items. Show effect, cost, Buy/Owned and amount still needed when unaffordable. Bind purchases through session commands; refresh from returned state. Show wallet and passive income consistently across operations and combat. Reserve stable width/number formatting so updates do not shift controls.

## Acceptance checks

Exact funds purchase succeeds once; insufficient funds shows correct deficit; repeat click cannot purchase twice. Wallet, owned state and model-provided rates agree after pump research. Purchases unavailable in active/paused combat. A persistence failure is not presented as a successful durable save. Large values do not overlap buttons.

## Stop boundary

No full research tree, currency changes, purchase animations requiring assets, or per-card economic calculations.

## Completion note

Implemented definition-backed research state in `prototype/scripts/ui/ui_view_state.gd`, reusable `ResourceStrip` and `UpgradeCard` components, and Operations preview wiring in `prototype/scripts/ui/operations_preview.gd`. Upgrade cards expose `purchase_requested(upgrade_id)` only; controller/session purchase authority remains unchanged, including active-combat rejection and save-failure handling. Cards show exact effects, costs, Owned state, and readable mana deficits with stable button widths. Added `prototype/tests/research_wallet_test.gd` covering exact funds, deficits, owned refresh state, combat lockout, wallet formatting, and one ID intent per click. Focused tests and all other suite tests pass. The full suite retains the unrelated existing `recovery_equivalence_test.gd` failure. No screenshot was captured; visual verification remains for assignment 45.

