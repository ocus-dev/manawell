# L05 — Deterministic drop generator and evidence
Owner: Luna. Depends on D02; execute after L04 to keep the queue sequential.

Implement a pure generator with explicit dedicated RNG input/state, approved tables/version, encounter item level, eligibility and frozen drop bonus. Separate occurrence, rarity, base selection, affix-family selection, eligible tier and numeric roll. Return exact instance data plus updated RNG state; no account mutation inside the generator.

Honor Common implicits, 0/1/2/3 explicit modifiers, slot restrictions, no repeated family, level thresholds and stable precision. Reject invalid or unsatisfiable tables instead of silently creating fewer affixes. Do not use global randomness or depend on iteration order of unordered data. At inventory capacity, return a full result without consuming RNG.

Acceptance: same state/input reproduces outputs, save/reload continues a sequence, independent AI randomness cannot change loot, boundary probabilities, no-roll for ineligible kills, each rarity and roll bound, no invalid affixes. Produce reproducible 100,000-kill simulation outputs and build-combination inputs for D03, with seeds and commands. Report measured counts, not a claim that the game is balanced. No kill hook until D03. Stop.
