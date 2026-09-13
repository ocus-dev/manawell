# Monster drop visual feedback — September 10, 2026

Review confirmed the live monster-death transaction already grants items during combat. Results summarize them later, but the transaction had no world visual, making collection appear to happen only after the level.

Added `prototype/scripts/game/loot_drop_visual.gd`: three code-drawn placeholder silhouettes (weapon, chassis, machine component), rarity-colored rings and explicit rarity/name labels. A drop rises from the monster's location, flies toward the hero and displays a collection checkmark/label. Pausing freezes it; returning/clearing the encounter removes it. It uses existing automatic collection: the animation is cosmetic and does not grant, delay or consume an item. Drop probability, inventory capacity and persistence are unchanged. There are no ground items requiring manual interaction in this version.

Hooked the effect only after `add_monster_instance` succeeds, so no-drop outcomes, full inventory and rejected duplicates have no false pickup cue. No texture imports or generated art are needed; final sprites can replace the three drawn silhouettes later.

Verification: existing `loot_kill_rewards_test.gd` passed. New `loot_visual_feedback_test.gd` verifies an ordinary monster grants before level completion, exactly one visual, pause behavior, rising/collection stages, no extra ownership from animation and cleanup. Rendered fixture uses an isolated account with saving disabled; `loot-placeholders.png` includes additional presentation-only examples to show the available shapes/rarities. No user's saved profile was modified.
