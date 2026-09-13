# Telos experiments

This folder contains isolated experiments that do not replace the preserved 3D baseline in `../prototype/`.

- Baseline: `../prototype/project.godot`
- Current experiment: `side-view-defense/project.godot`

Only `experiments/` is changed by the side-view work. The experiment has its own Godot project, scripts, tests, and user-data identity. It does not reference `prototype/` resources at runtime and does not share mutable files with it.
