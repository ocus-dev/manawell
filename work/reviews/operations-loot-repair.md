# Operations loot repair

Reproduced with the real Operations `start_run()` entry point and `drop_rate 100`: loot_enabled was false and a killed enemy awarded zero items. The original development-command test covered generator overrides, while the kill test explicitly set loot_enabled=true, hiding the encounter-start bug.

Operations wells now resolve their authored campaign source node for item level/provenance and enable loot without selecting or completing a campaign node. Existing suspended Operations runs repair the disabled flag and derive the proper well item level without resetting RNG or retired enemy IDs. This intentionally treats authored Operations wells as normal grinding encounters; unknown/non-authored test sites remain disabled. Applying a development override also repairs an already-active disabled authored well.

The command reports when inventory is full. Generator validation failures produce a diagnostic instead of silently returning.

Verification: new loot_operations_drop_test.gd reproduced zero items before the fix and exactly one item plus a visible drop effect afterward, without campaign completion. Development-command and existing kill-reward regression tests passed. Tests used injected accounts with saving disabled.
