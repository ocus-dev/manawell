# L04 — Connect resolved stats to gameplay
Owner: Luna. Depends on L03.

Follow D02 routing precisely. Freeze one resolved build at expedition start and restore it on resume. Route weapon hits, pulse, hostile projectiles, boss attacks and direct damage through the approved damage rules. Implement maximum HP, armor, approved elemental resistance, horizontal movement, vision/targeting, regeneration, family advantage and active mining consumers. Exclude unimplemented stats from live affix eligibility.

Fix only the demonstrated research/multishot and snapshot baseline problems identified in D02, with explicit regression tests. Preserve projectile count, spread, range, jump/dash physics and well policies unless the contract explicitly changes them. Do not apply hero equipment to guards or offline production.

Acceptance: actual damage for each source, single application of mode/family multipliers, positive-damage regen delay reset, zero regeneration while paused/dead/terminal, max-health restoration, unchanged mining cadence, no bonus in monster-only nodes or passive production, targeting limits, and suspend/resume equivalence. Test 30/60/120-step timing with equivalent simulated duration where relevant. No live monster loot yet. Record results and stop.
