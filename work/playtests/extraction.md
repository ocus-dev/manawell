# Extraction checkpoint

Date: 2026-09-05
Mode: deterministic headless Godot checkpoint (`extraction_checkpoint_test.gd`), plus the existing executable test suite. No human playtest or interactive target-resolution pass was performed; human feedback is pending.

## Evidence

- Fresh run: started in `EXTRACTING`; after 1.0 simulation seconds, tank was 2 mana at the base 2 mana/sec rate.
- Harvest: entered `SEALING` with a locked payout of 2 and 2.0 seconds remaining.
- Pause during sealing: after a simulated 1.0 second while paused, sealing remained at 2.0 seconds.
- Delayed success: completed after the remaining 2.0 simulation seconds and banked 2 mana.
- Hero failure: terminal reason was `hero_destroyed`; existing bank remained 2.
- Machine failure: terminal reason was `machine_destroyed`; existing bank remained 2.
- Retry: returned to `EXTRACTING` with no upgrades accidentally added or removed.
- Instant sealing: developer 0-second mode entered success on the next tick with a 2 mana payout.
- Upgrades: next run reported extraction rate 2.5, weapon damage 15, and spread enabled. This confirms pump, damage, and spread effects apply at run start.

## Timing and perception

Delayed sealing adds 2 simulation seconds after harvest; instant sealing removes that delay. Extraction accumulation itself did not change between the baseline and instant-sealing runs. The pump upgrade changes output from 2.0 to 2.5 mana/sec, while damage and spread changes were verified by runtime values and the prior upgrade fixture, not by human visual play.

## Issues and tuning

Fixed during this checkpoint: hero and machine destruction previously shared one generic terminal reason. The HUD now reports `hero_destroyed` and `machine_destroyed` distinctly.

Suggested tuning question: a 2 mana payout after a 1-second sample is mechanically clear but too small to judge long-run upgrade motivation. A human session should compare a longer tank, repeated harvest decisions, and the readability of the 2-second sealing danger under enemy pressure.

No unresolved executable runtime defects remain. Audio, target-resolution readability, and enjoyment are unvalidated. Human feedback is pending.
