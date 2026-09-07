# 01 — Project bootstrap

Dependencies: None. Status is tracked in ../README.md.

## Read first

work/PROTOTYPE.md; work/CONTRACTS.md. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Create the minimal Godot project and repeatable launch/test instructions.

## Implement

Inspect available Godot tooling without installing anything. Record exact installed version and executable. If missing, document the required Godot 4 editor and mark runtime verification blocked. Create project.godot, main.tscn, an empty visible 3D floor, and a minimal headless test entry point. Add scoped ignore rules for generated Godot files; preserve existing repository content.

## Acceptance checks

Project opens and the main scene runs without parse errors. Headless runner exits 0 for a passing assertion and nonzero for an intentionally failing fixture (remove that fixture afterward). README includes exact commands for this machine.

## Stop boundary

Do not build movement, combat, engine abstractions, or export packaging.

## Completion note

Done. Created `prototype/project.godot`, `prototype/scenes/main.tscn`, `prototype/tests/bootstrap_test.gd`, `prototype/.gitignore`, and `prototype/README.md`. Verified Godot `4.8.dev4.official.b56a91878` using the local editor and console executables. The headless bootstrap test exited `0`; the main scene loaded headlessly and exited `0`; a temporary assertion fixture exited `1` and was removed. The next card can open `prototype/project.godot` and use `res://scenes/main.tscn` as the entry scene. Runtime visuals were not manually inspected in the editor, and the project remains limited to the camera, lights, and empty floor required by this card.

