# R07 research acceptance

## Automated evidence

Commands run against `Godot_v4.8-dev4_win64_console.exe`:

```powershell
--headless --path .\prototype --script res://tests/research_resolver_test.gd
--headless --path .\prototype --script res://tests/research_purchases_test.gd
--headless --path .\prototype --script res://tests/research_tuning_test.gd
--headless --path .\prototype --script res://tests/production_test.gd
--headless --path .\prototype --script res://tests/snapshot_codec_test.gd
```

Resolver, purchase/migration, tuning, production, and snapshot checks pass. The tuning scene is isolated and only reads authored presets; it does not load or mutate the player profile.

The existing `progression_2d_test.gd` remains profile-dependent: its fresh-world assertion can fail when the local `user://` save already has Well 2 unlocked. That is recorded as an environment/test-isolation issue, not treated as campaign evidence. A clean user-data directory is required for that suite and for human route measurements.

## Final authored balance

The initial costs and formulas are in [balance-sheet.md](balance-sheet.md). Early Act 1 rewards are 3/4/5/6/7 mana, the boss reward is 12, and Well 1's base output is 2 mana/sec. The first-rank anchors remain damage 40, amount 60, and Splitter 100. Fan is 3 or 5 separate projectiles at the documented per-pellet multipliers; Lance pierces one distinct enemy at 85% attack rate. Passive production applies amount ranks only and never applies active specializations.

## Outstanding human checks

Normal-size visual inspection of the compact tree, left/right airborne fan aim, close-range boss Fan performance, sealing survival, and equal-budget Act 1 routes still require a clean profile and a human capture. No claim of fun or final balance is made from numerical tests alone.