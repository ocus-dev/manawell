# E02 — Collection and equipment ownership

Depends on E01 and research save changes being complete. Extend account state with unique owned item IDs, three equipped IDs (empty allowed), and persisted inspected/new status. Do not duplicate equipped items into a separate bag or mark research IDs as items. Expose semantic equip(slot,item), unequip(slot), inspect(item) commands through the current controller boundary.

Validate known ID, ownership, slot compatibility and no active/suspended run before mutation. Use expected current slot value for stale UI equip/unequip commands so an old click cannot undo a newer selection. Equipping a replacement atomically swaps references; old item stays owned. Kits follow the selected active hero; guard equipment remains unchanged.

Persist through the existing save envelope/dirty retry flow, preserving bank/research/campaign. Old valid profiles lacking inventory default to an empty collection before E03 reconciliation. Reject invalid types, duplicate serialized ownership, unknown definitions, unowned equipment or wrong slots under existing corruption/recovery policy. No automatic destructive reset.

Acceptance: round-trip, legacy missing fields, invalid equipment/ownership, replacement, repeated/stale commands, active/suspended restriction and failed-save retry. Empty kit preserves existing behavior. Completion note: pending.
