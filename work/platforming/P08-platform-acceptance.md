# P08 — Full platforming playtest and handoff

Dependency: P07. Status tracked in work/platforming/README.md.

## Implement

Run the full active suite and fix in-scope regressions. Capture actual runtime at 1280×720 and 1920×1080 showing compact HUD, both platforms, jump apex, air dash, upward ranged shot, hero crossing machine, sealing and pause. Reuse current Godot capture tooling; inspect runtime output rather than treating tests as visual acceptance.
Provide a repeatable fixture/preview mode to exercise movement safely, plus a real encounter walkthrough: jump to both decks, drop through, dash in air, evade a shot, take an aimed airborne hit, pulse from different elevations, defend the machine, seal, retry and save/resume airborne. Record manual checks separately from automated/captured evidence.
Update active README, control help, work/CONTRACTS.md and the current movement/presentation sections of design/Concept.md. Historical flat-lane/visual-slice assignments stay unchanged. Write work/playtests/platforming-milestone.md with actual checks, initial motion/hurtbox/platform parameters, screenshots and a short owner feedback form covering jump responsiveness, landing readability, HUD footprint, machine defense and whether platforms offer meaningful choices.
Do not claim the inherited card 57 acceptance complete unless its remaining checks are actually covered; link new evidence instead.

## Acceptance

A coherent playable platforming encounter has compact HUD and icon skills, no old Space-dash labels, no disabled recovery, and a passing active regression suite or clearly unresolved blockers. Owner can launch both preview and game and assess the new movement without replaying the whole campaign.

## Stop boundary

Stop for owner playtest feedback. No automatic next biome, animation generation, new skills or expansion of traversal mechanics.

## Completion note

Pending.

