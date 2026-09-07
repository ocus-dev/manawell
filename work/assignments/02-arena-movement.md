# 02 — Arena and movement

Dependencies: 01. Status is tracked in ../README.md.

## Read first

Compact spec; main scene; bootstrap handoff. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Make a controllable hero in a readable arena.

## Implement

Build the 28 × 28 floor, boundary collision, central machine placeholder, lighting, and fixed elevated camera. Use CharacterBody3D for the hero. Add WASD movement in camera-relative ground directions with normalized diagonal speed. Define the future Q/Space/E/Escape input actions without implementing their gameplay.

## Acceptance checks

Move in all directions; diagonal speed matches straight speed. Hero cannot pass through machine or boundaries. Whole playable area and hero remain readable at 1280 × 720 and 1920 × 1080.

## Stop boundary

No enemies, extraction, asset downloads, or camera cinematics.

## Completion note

Done. Added arena floor and collision, four boundary bodies, central machine placeholder, fixed elevated camera composition, red `CharacterBody3D` hero, camera-relative normalized WASD movement, and reserved `pulse`, `dash`, `harvest`, and `pause_game` actions. Changed `prototype/project.godot`, `prototype/scenes/main.tscn`, `prototype/scripts/game/player.gd`, `prototype/tests/arena_movement_test.gd`, and `prototype/README.md`. The main scene loaded headlessly with exit `0`, and the focused movement test exited `0`. Manual control and readability checks at 1280x720 and 1920x1080 remain outstanding; no enemies or extraction behavior was added. Card 03 can use `Hero`, `Machine`, and the arena boundaries already present in `res://scenes/main.tscn`.

