# Side-view defense experiment — Luna

**Completed experiment — historical instructions below.** The user approved side view on 2026-09-07. Continue with [full side-view implementation, 49–57](../2d/README.md); do not rerun S01–S03. Its earlier isolation/stop rules describe the experiment stage and do not prohibit the now-authorized conversion. Native visual/input checks missing from the experiment report carry into final acceptance.

## Run with Luna

Select GPT-5.6 Luna in task settings and use:

> Implement only work/side-view/S01-isolated-arena.md. Read work/side-view/README.md and the assigned card, then only its named source and predecessor handoff. Keep prototype/ unchanged. Implement the card and its acceptance checks, update the status row and completion note with actual commands/results and limitations, then stop. Do not execute the held 49–57 queue, spawn agents, or create tasks.

Substitute S02 and S03 in order after prerequisite completion.

| Card | Deliverable | Depends on | Status |
|---|---|---|---|
| [S01](S01-isolated-arena.md) | Isolated side-view arena and movement | Existing source | DONE |
| [S02](S02-defense-loop.md) | Complete extraction combat experiment | S01 | DONE |
| [S03](S03-presentation-playtest.md) | Visual slice, verification, and playtest handoff | S02 | DONE |

## The question

Can defending a central harvester from left and right create interesting positioning and harvest decisions, while making the industrial world more compelling to look at?

Test a fixed-camera side-view defense arena, not a scrolling platformer. One ground level, one hero, one machine, three existing enemy roles, automatic fire, dash, pulse, and extraction/sealing. No jumping, platforms, elevation, camera tracking, exploration, or new progression systems.

## Separation and reuse

Create a standalone Godot project at `experiments/side-view-defense/`. The existing `prototype/` remains the untouched 3D baseline for this experiment. Do not move it, replace its main scene, archive it again, or put experimental scripts inside its import tree. Add `experiments/README.md` identifying both projects and explaining that only the experiment is being changed. If a prior conversion has already altered the source, inspect and report that before assuming it is the original baseline.

Copy only the pure RunState model, required balance constants, and any small dependency needed to reuse those rules. Record source paths and hashes in the experiment README. Adapt spatial combat code locally. Do not copy the full 3D project, assets, controller, account/persistence stack, or operations interface. This bounded duplication is experimental and will be reconciled only if the user chooses a full conversion. No `res://` references outside the experiment and no shared mutable files or symlinks.

No saves or migrations. Payout is a visible session-only result; retry starts a clean encounter. No shops, guards, offline production, or unlocks. Do not claim this experiment replaces the full prototype.

## Initial gameplay specification

- Logical canvas: 1280×720, uniform fit at other window sizes. Fixed camera, flat ground near y=540. Walkable hero center x=96…1184; harvester center x=640. Clamp movement to bounds. These are initial experiment values, not changes to the main game.
- Convert old spatial balance values using one named 32 px/unit factor. Keep damage, health, extraction, sealing, ability durations, and cooldowns at existing defaults initially. Use logical ground position for ranges; sprite heights and muzzle offsets are presentation only.
- A/D and left/right arrows move; Space dashes in movement direction or last-facing direction; Q pulses; E starts/harvests; Escape pauses. No vertical movement. Add visible Start/Harvest, Retry, and Pause/Resume controls.
- The hero may cross through the machine and enemies. Bodies do not block each other in this experiment; contact damage uses attack range/cooldown. The machine is a defended target, not a wall. Render a clear service walkway in front of it so crossing reads intentionally.
- Pursuers close on the hero, breakers stop at the machine, ranged enemies stop and telegraph before firing at the hero. Spawn from visible left/right edge entry zones with short warning markers. No offscreen attacks.
- Auto-fire picks the closest live target in range regardless of side, with deterministic ID tie-breaking. Show weapon facing/target direction. Hero projectiles hit the first hostile crossed along their segment; hostile shots threaten the hero, not the machine. Pulse affects enemies on both sides; dash protects the hero only.
- Use a single controller-owned 60 Hz step for input, movement/abilities, combat/damage, then RunState advance and terminal resolution. Pause freezes the whole experiment. Do not add independent actor timers that advance combat.
- Use a small deterministic spawn schedule in an experiment data file: early pursuers alternate sides; then introduce breakers; then ranged threats; then combine pressure from both sides. Reuse current enemy stats. Exact spawn times/counts are authored in S02 and documented so the run is repeatable. Do not port the whole campaign director just to run this test.

## Working rules and completion

Use the installed Godot executable; no installs, new services, generated/downloaded art, or engine upgrade. Use simple procedural industrial scenery and shapes plus restrained animation. Keep focused behavioral tests and error-sensitive runner behavior; never weaken existing tests. Do not run the untouched prototype's whole suite on every card.

Record actual commands, test outcomes, and unperformed visual checks. Headless success establishes correctness, not whether defense feels interesting. S03 can finish implementation and a playtest handoff while clearly leaving the human verdict pending. Stop after that handoff. Full migration, archive restructuring, jumping, and further content require a subsequent direction decision.
