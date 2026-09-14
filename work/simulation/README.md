# Simulator paused — September 13, 2026

User direction: pause simulator work, wrap up the current changes, and move on to fixing the game's pacing. No further cohort runs or simulator expansion are planned as part of this task.

## Current implementation

The main workspace now contains the three Luna contributions, with integration corrections:

- `prototype/simulation/experiments/combat_model.gd`: discrete weapon attacks, projectiles, enemy attack intervals, pulse cooldown, and seeded contact/coverage assumptions. An external-step interface lets the existing extraction/campaign director own spawning and run completion.
- `prototype/simulation/experiments/xp_model.gd`: optional persistent kill/completion XP, duplicate-event protection, levels, milestones, and stat bonuses.
- `prototype/simulation/player_model.gd`: integrates both modules; XP changes damage/health at the next encounter; failed extractions retain earned kill XP. Scenario overrides cover research costs, specialization charges, passive income, stage waves/health/damage, and post-surge-four payout growth.
- `prototype/simulation/run.gd`: five-experiment expansion, milestone/stage/XP summaries, HTML/JSON/CSV outputs and source hashes.
- `prototype/simulation/comparison.json`: concrete experiment settings. Longer-encounter overrides now target **monster stages and the boss**, correcting the earlier worktree settings that targeted wells and did not expand monster waves.
- The previous continuous combat model remains selectable with `combat_model: "legacy"`. The default integrated model is discrete.

These are simulator-only changes. Live combat, research prices, XP, campaign balance, and player saves were not changed.

## Verification completed

All four focused test scripts exited successfully:

| Test | Checks passed |
|---|---:|
| `pacing_simulation_test.gd` | 19 |
| `combat_model_experiments_test.gd` | 8 |
| `xp_model_test.gd` | 21 |
| `simulation_integration_test.gd` | 18 |
| Total | **66** |

Coverage includes payout boundaries, sealing losses, pressure/cycle separation, guard/offline income, seeded replay, discrete hit thresholds, pulse/boss attack timing, XP failure retention and duplicate awards, neutral-override/XP-disabled equivalence, applied XP health bonuses, specialization charging, wave scaling, and currency conservation. This is focused validation, not a full project regression or proof of combat fidelity.

## Reports and their limits

- [Integrated smoke report](integration-smoke/report.html): **3 players per profile per experiment**, 45 simulated players total. Five experiments and three personas completed. Suitable for checking integration and finding obvious failure modes, not estimating population pacing.
- [Original profile report](latest/report.html): 300 simulated players using the earlier continuous combat approximation. **Historical; not the integrated simulator's latest results.**
- [Original stay-duration sweep](risk-sweep/report.html): 600 players using the earlier approximation. Also historical.

The proposed larger run of 100 players per profile per experiment was **not started**, following the user's pause request. No simulator process remains running from this task.

The integrated smoke report shows incomplete boss completion in several scaled-encounter scenarios. Do not present the successful minority's longer times as proof of healthy 45–60-minute pacing. The experiment can produce difficulty walls and retries as well as longer encounters. No final balance candidate has been selected.

## Findings to carry into gameplay work

1. **Monster stages are tiny:** current authored stages contain only 3–5 enemies and do not introduce corresponding stage-specific HP growth; the boss has 240 HP. Improved player damage can shorten later encounters. The original model's single-digit-second combat estimates are optimistic, but the content budgets themselves are real.
2. **Extraction reprices the entire tank.** At base Intake output, 59 seconds locks 177 mana and 60 seconds locks 240. Extended survival increases both tank volume and multiplier. Long successful runs can rapidly consume the research progression.
3. **Research is finite and inexpensive relative to income.** Six core tracks cost 2,220 mana. Preserve early affordable choices while considering a larger investment curve for later ranks.
4. **Passive production can bypass that curve.** Hero 2 on base Intake generates 30 mana/minute. Costs and passive rates must be considered together.
5. **Runtime/documentation disagree:** cadence does not currently improve passive production. Specializations equip when prerequisites are met without charging the listed unlock price. Decide intended behavior explicitly before implementing gameplay changes.
6. **XP is optional, not the prerequisite fix.** Steady XP can preserve a sense of progress after failed extraction, but adding power also speeds combat. First address encounter budgets and economy; decide XP's role afterward.

## Recommended next gameplay work

Start with a bounded Act 1 encounter pass: expand meaningful waves, introduce authored per-stage HP/damage factors, and give the boss enough time to demonstrate its attacks. Preserve the easy introductory encounter and avoid extending play chiefly through repeated deaths. Test real encounter durations and mistake tolerance before multiplying costs globally.

Then tune late research/extraction/passive scaling together and resolve specialization purchasing. Proposed 45–60 attended minutes to first boss remains a design hypothesis, not an accepted result or measured average.

## If resumed later

Run the integration tests first, then:

```powershell
./tools/simulation/run.ps1 -Scenario prototype/simulation/comparison.json -OutputDirectory work/simulation/comparison -PlayersPerProfile 100
```

Remaining simulator limitations: no real movement/collisions, equipment or loot, dash AI, learning, or quitting behavior; contact chance, coverage and uptime remain assumptions. Level bonuses are applied between encounters. Stage durations and percentile times require playtest calibration. Optional override validation is not exhaustive; use the checked-in comparison settings until that is tightened. Legacy-path availability is not an end-to-end golden comparison against the old report. The old `grant_xp` helper is unused; actual XP flows through the XP module. Purchase trace rows still display authored rank cost rather than the scaled experimental cost; `research_spent`, `specialization_spent`, bank and currency-conservation checks reflect actual debits.

Do not spend more effort on these limitations before the next gameplay pass unless they block a concrete decision.
