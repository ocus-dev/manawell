# E05 — Compact inventory and item comparison

Depends on E03/E04 and current research UI. Add Inventory to existing operations navigation, not as another permanent combat panel. Show a compact icon grid with All/Weapon/Hero/Harvester filters, three equipment slots and one shared details panel. The first slice has no capacity/weight counters, sell buttons or crafting tabs.

Selecting shows name, slot, benefit/tradeoff and current-kit → replacement final-stat comparison from the same resolver/runtime context. Distinguish inventory ownership, equipped state and New with icons/text as well as color. Inspecting clears New once. Equip and Unequip are explicit actions; selecting/double-clicking should not accidentally sell, consume or equip. Empty slots have a clear baseline label. Active/suspended restrictions show a reason.

Show newly earned items in existing results presentation with View Inventory navigation when session flow permits; opening results never grants items. Existing profiles see their reconciled items. Reuse existing icon manifest or add semantic `item.*` entries with functional SVG/placeholder fallback; polished bitmap generation is a later art pass, not a blocker.

Keep research modes and well policies visibly separate from item slots. Explain that the kit follows the active hero and harvester items do not affect passive wells. Compare actual context-specific stats rather than green/red arrows based on stat names alone; lower interval is better, faster pressure is a cost. Label theoretical DPS honestly.

Acceptance: 1280×720, 1920×1080 and supported minimum window; keyboard focus/activation, mouse selection/equip, filter retention, empty/fully-owned collections, long labels, no overlap and live result/purchase state refresh. No giant cards covering the map or combat. Completion note: pending.
