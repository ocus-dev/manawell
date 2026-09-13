# Primary-assistant work assignments

## D02 — Architecture and balance contract

After L01, before persistence or combat integration. Review its schemas and produce `work/loot/approved-tables.md` plus `work/loot/persistence-contract.md`.

1. Author exact base implicits and affix eligibility, IDs, modifier families, integer/float precision, weights, level thresholds and min/max tier rolls. Include worked fixtures for each slot and rarity. Decide which stats are live versus reserved; no useless resistance or vision rolls.
2. Audit current ResearchResolver → encounter controller → projectile damage path. The current source appears to apply fan damage scaling in both `resolve_weapon` and `spawn_friendly_volley`; reproduce and decide the intended baseline before equipment stacks on top. Audit snapshot weapon interval/max-health handling too; current capture paths reference constants in places. Do not carry accidental double multipliers into item tuning.
3. Specify one damage/stat routing contract for direct hits, projectiles, pulse, boss attacks and future elemental sources. Author monster-family tags and actual elemental threats if enabling resistance loot. Define each hero baseline and all cap behavior exactly.
4. Specify save/snapshot version changes, legacy migration, terminal kill ordering, run IDs/enemy IDs, dedicated loot RNG representation, processed-kill pruning and failed-save retry. No-drop outcomes need the same replay protection as drops. Explain crash windows and avoid a ledger that grows forever across runs.
5. Choose checkpoint cadence and inventory-cap behavior in actual controller code. Define save failure behavior without blocking simulation every frame. Specify which older suspended runs are discarded and preserve the account.
6. Approve tables and contracts for L02–L05 by recording the review result. If a mechanic cannot support an affix yet, defer that affix explicitly instead of leaving Luna to guess.

## D03 — Loot and build balance

After L04/L05, before live drops. Review deterministic evidence, not just formulas.

- Simulate at least 100,000 ordinary kills and report drop count, rarity counts, affix/tier distributions, streak percentiles, duplicate-base frequency and storage growth. Compare observed frequencies with binomial sampling bounds, not exact counts.
- Enumerate legal three-slot combinations at baseline and researched progression; include minimum/maximum rolls, farming gear, tank, attack-rate and mining builds. Measure single-target damage, actual multishot hit assumptions, effective HP, time to kill, healing per encounter and active output. Do not equate theoretical spread DPS with all projectiles landing.
- Collect actual eligible kills/minute at early, middle and boss nodes. Compute expected items/session and useful upgrades/session under an explicit comparison rule, separately from raw drops.
- Review safe regeneration camping, farming/drop bonus feedback, easy-node farming versus level tiers, paused-time rewards, and boss summon farming. Set tuning changes in data with rationale. Verify at least two viable build directions; do not claim fun from simulation.
- Publish `work/loot/balance-review.md`, with exact approved numbers and any unresolved playtest questions. Unresolved critical interactions block L06; harmless feel questions go to D04.

## D04 — Playable review and next design

After L08, review an actual playable loop with the user. Tune comparison clarity, pickup cadence, near-upgrades and first-run readability. Record measured results and distinguish user feedback from automated checks.

Then design `work/loot/hero-loadouts-contract.md`: individual hero strengths/tradeoffs, two or three weapon families, active spell slots/unlock source, spell damage/cooldown rules, existing dash/pulse compatibility, weapon research interactions and monster counterplay. Add explicit acceptance fixtures and balance budgets for L09. Legendary powers, critical hits, penetration, crafting and additional armor slots remain separate proposals, not implied L09 scope.
