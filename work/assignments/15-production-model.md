# 15 — Production accounting model

Dependencies: 14. Status is tracked in ../README.md.

## Read first

Assignment model and production contract. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Implement rates and elapsed-time settlement as pure model logic.

## Implement

Create production.gd with rate calculation and an injected clock/explicit timestamps. Return total fractional mana and per-site rates. Enforce commissioned + guarded + non-active eligibility. Settle at old rate before mutations. Include monotonic in-process cursor and offline calculation helpers, but no load-time offline credit yet. Account for pump research and hero 2 guard trait.

## Acceptance checks

Use fake clocks: one well for 60 sec gives 24 mana at base rate; hero 2 gives 30. Two sequential half-intervals equal one interval. Paused simulation does not change wall-time totals. Assignment/research changes split intervals correctly. Same timestamp repeated gives zero; negative elapsed gives zero; active site gives zero.

## Stop boundary

No frame-loop wiring, network panel, file I/O, or actual offline load settlement.

## Completion note

Implemented `prototype/scripts/model/production.gd` with `ProductionAccounting.calculate_rates`, `settle`, `total_for_elapsed`, `offline_elapsed`, and `offline_settlement`. Rates require a commissioned, guarded, non-active well; pump research and Hero 2's 25% guard factor are applied. Settlement uses a monotonic in-process cursor, returns fractional totals and per-site rates, and preserves the later watermark when time moves backward. Added `prototype/tests/production_test.gd` with fake timestamps covering baseline 24 mana/60 seconds, Hero 2's 30 mana/60 seconds, split intervals, paused timestamps, mutation ordering, active-site exclusion, repeated timestamps, backward time, and offline caps.

Verification: run `& $godot_console --headless --path '.\prototype' --script 'res://tests/production_test.gd'`; it exited 0. This card has no in-game passive-income UI yet, so visual/manual verification is intentionally deferred to card 16. The next card can call `settle` before assignment/research changes and persist the returned cursor/total through its own runtime integration.

