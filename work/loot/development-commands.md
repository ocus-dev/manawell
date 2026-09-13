# Development loot commands

Press F8 in a Godot development build to open the loot console. The game pauses while it is open; F8 or Escape closes it and restores the previous pause state.

- `drop_rate 100`: every eligible monster/boss drops an item while storage has room.
- `drop_rate 10`: flat 10% chance per eligible kill.
- `drop_rate 0`: no items.
- `drop_rate reset`: restore normal rates and equipment bonuses.

Override applies immediately to subsequent kills, replacing the occurrence chance for both ordinary enemies and bosses. Rarity/affix rolls, eligibility, uniqueness and the 100-item capacity remain unchanged. An on-screen DEV LOOT indicator remains visible while overridden. The override is session-only and is not restored after restarting. Items collected during testing save normally. Commands and overrides are disabled in release builds.

Normal base rates: ordinary 2%, boss 25%. Ordinary average is one item per 50 kills, not a guaranteed interval. At an assumed 20 kills/minute this is 2.5 minutes/item on average. Equipment bonuses multiply occurrence chance, with a 30% final cap. Conditional rarity weights: Common 60%, Magic 30%, Rare 9%, Epic 1%.

Validation: loot_dev_command_test.gd checks 100%/0%, invalid input, reset, capacity and F8 pause behavior. Existing generator and kill-reward checks cover unchanged normal behavior.
