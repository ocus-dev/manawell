# Inventory collection and drop handoff

Implemented September 9, 2026. This delivery covers item collection and acquisition. The broader E01–E06 equipment assignments remain open where they require stat modifiers, equip legality, comparisons or equipment testing. Extend the existing catalog and ownership model rather than creating parallel systems.

## Available in the game

- Operations has a persistent Inventory tab with All, Weapon, Hero and Harvester filters, selection details, acquisition locations and new-item counts.
- Each Act 1 node awards its scheduled item on its first qualifying successful completion. Results name the recovered item. Wells must qualify for commissioning.
- Rewards are granted with campaign completion, never by opening a screen. Replays, failures and repeated result delivery do not duplicate items.
- Ownership and new-item state are saved with the account. Inspecting an owned item clears its new marker. Items are not consumed or lost on failure.
- Existing profiles receive missing rewards from saved campaign completion flags. Reconciliation is idempotent and preserves bank and research progress.
- Buttons remain alive across HUD refreshes, preserving press/release input and selection.

## Boundaries and next work

Items currently form a collection; there are no equip actions or stat bonuses yet. There are no random enemy drops, world pickups, duplicate conversions or item quantities. The nine authored items use readable monogram placeholders pending final icon art.

Next implement the active expedition kit and shared stat resolution described in E02/E04, followed by equip comparisons in E05. Add modifiers to `item_catalog.gd`; retain its stable IDs and reward schedule. Preserve account validation, legacy defaults, acquisition transaction and persistent UI controls.

## Verification

`inventory_drops_test.gd` covers all nine rewards, failure and commissioning gates, repeat commits and replay, inspection, invalid IDs/duplicates, legacy reconciliation, a disk save/reload, and failed-save retry. Its disk files are isolated under `work/reviews` and removed afterward.

`inventory_ui_test.gd` verifies empty/populated states, real mouse press/release across a HUD refresh, category filters, new markers and persistent controls. It uses an injected account with saving disabled. A rendered 1280×720 capture is at `work/reviews/inventory-screen.png`; the entire collection and details fit in view.

Both inventory tests, both campaign regression tests and all five research regression tests passed. The campaign disk-save check required a rerun outside the filesystem sandbox to access its isolated `user://campaign-state-test` files.
