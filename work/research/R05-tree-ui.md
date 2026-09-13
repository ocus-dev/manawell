# R05 — Compact, readable research trees

Depends on R03/R04. Replace the flat upgrade list in existing operations/research navigation with two tabs, Harvester and Weapons. Compact icon nodes show rank/cap and branch connections; one shared details panel shows selected node, exact cost, prerequisites, current → next values and purchase action. No giant card for every node. Reuse icon pipeline keys or clear SVG/procedural placeholders; labels and states remain dynamic.

Differentiate locked, affordable, unaffordable, partially ranked, maxed and selected without relying solely on color. Show why a node is unavailable. Add a small equipment selector for unlocked harvester specialization and weapon mode, with active-run lock explanation. Selecting a research node does not equip it or buy it. Buying does not launch combat.

Resolver-backed previews show mana/cycle, cycles/sec, average mana/sec, seal duration and pressure tradeoff; weapons show damage/projectile, projectiles/attack, attacks/sec, speed and mode. Label full-connect volley DPS as theoretical, not guaranteed damage. Distinguish passive rate from active Deep Draw rate. Display actual well/loadout context for harvest previews.

Respect current viewport/UI-scale settings and supported minimum size. Check 1280×720, 1920×1080 and minimum size, keyboard traversal, focused tooltips, mouse hit targets and live bank/rank updates. No campaign HUD enlargement. Tests cover semantic command IDs/expected-rank handling and preview parity; manual screenshots establish readability. Completion note: compact track summaries and resolver-backed details implemented; research wallet passes, while operations layout retains an unrelated stale page-count assertion.
