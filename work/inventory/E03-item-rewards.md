# E03 — Reliable first-clear item rewards

Depends on E02 and current real campaign completion routing. Attach the nine-item schedule to authored encounter/campaign rewards. Grant inside the validated terminal account transaction with completion and currency; persist that combined state through current retry semantics. Results UI reads a committed reward summary rather than granting anything itself.

A new clear grants the mapped item and marks it New. Replay retains existing repeatable currency rewards but no duplicate item/conversion. Failure and incomplete well commissioning grant no item. Reward methods validate run/node identity, not client-provided item IDs. Returning to/reopening results never repeats the grant; do not auto-equip.

Reconcile already-cleared nodes from persisted authoritative progress on load or a single explicit initialization path, adding only missing mapped collection IDs. Mark this reconciliation consistently so New status is not reset on every load. Preserve completed profiles and all current resources. Document behavior if a reward mapping changes in a future catalog version.

Acceptance: all nine mappings, successful combat/well/boss grants, failed seal/non-qualifying extraction, stale/wrong run IDs, double terminal events, repeated results view, replay, save failure/retry and completed-profile reconciliation twice. Completion note: pending.
