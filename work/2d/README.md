# 2D transition — Luna execution queue

> **CURRENT QUEUE — side view approved 2026-09-07.** Implement 49–57 using the completed [side-view experiment](../playtests/side-view-experiment.md). The user approved this direction after the experiment; do not rebuild a top-down arena or rerun S01–S03. This queue replaces the earlier overhead proposal.

These are planned work orders, not implemented changes or dispatched Codex tasks. Run serially with GPT-5.6 Luna, one card per task. Full implementation means restoring the existing prototype feature set in the approved side view, not adding the entire future campaign or final production art. Existing 01–48 statuses remain historical; card 48's pending visual acceptance is carried into card 57 and is not a prerequisite.

## Execution prompt

> Implement only work/assignments/49-archive-3d-baseline.md. Read work/2d/README.md, the assigned card, and its predecessor's completion note, then only the source needed for that card. Follow the acceptance checks, update this queue's status row and add a short completion note to the card with changed paths, actual commands/results, and remaining limitations. Stop after this card. Do not implement later cards, spawn agents, or create additional tasks.

Substitute the next card's path after its predecessor is complete. Select GPT-5.6 Luna in the task settings. Do not automatically dispatch this queue.

## Product and technical decisions

- Native Godot 2D, fixed side view, one horizontal ground lane, A/D or arrow movement, Space dash, Q pulse, E start/harvest, Escape pause. Preserve the experiment's machine-crossing service walkway and nonblocking actors. No camera orbit, scrolling, jumping, platforms, or elevation. Horizontal ground coordinates determine hits/ranges; decorative sprite heights do not.
- Keep the extraction/defense loop, two wells, two heroes, upgrades, loadouts, assignments, and production. Preserve health, damage, timings, rewards, and relative movement/range balance. No new content or economy redesign.
- Keep and integrate the experiment's existing procedural industrial scene, machinery animation, silhouettes, and warnings. Do not restart from blank shapes or commission new assets. Final asset generation, sprite sheets, and broad art polish are a later queue.
- Preserve current 3D work as a frozen, independent project in `archive/prototype-3d/`, outside active `prototype/`. Include its local resource dependencies and tests. No runtime references, symlinks, or shared mutable code between archive and active project.
- The active project remains `prototype/`; retain `scripts/model/`, `scripts/ui/`, and `data/` where appropriate. New combat lives in `scripts/game/` and `scenes/main.tscn`. No permanent parallel `game2d`/`game3d` implementations in the active project.
- Old player saves and 3D snapshots need no migration. Use a distinct 2D user-data directory and fresh 2D snapshot/config identity. Do not spend effort converting old coordinates or deleting old user files. New 2D saves, suspend/resume, and save-retry behavior remain supported.
- Preserve the single 60 Hz scheduler, semantic UI commands, model ownership, and damage-before-sealing order. Adapt existing logic; do not build an engine abstraction or general framework.
- Preserve the experiment's 32 pixels per former world unit and 1280×720 logical canvas, ground y=540, hero center x=96…1184, machine x=640. Scale presentation uniformly at other resolutions; HUD must leave the lane visible. Do not use the earlier 24 px/unit square-arena specification.
- Freeze `experiments/side-view-defense/` as the accepted experiment reference after promoting its useful code into `prototype/`. The active project must have one RunState, balance source, simulation owner, command boundary, and HUD; reconcile copies rather than keeping experiment and production implementations side by side.
- Preserve nearest-target auto-fire across both sides with deterministic ID ties, dash facing, and pulse on both sides. Hostile shots hit the hero's current ground position when crossed, not an old aim point; friendly shots hit the first current hostile crossed during each step. Dead actors cannot absorb hits.
- Keep upgrade ID/cost `spread_1`; adapt its three shots to a horizontal lane as three simultaneous same-direction projectiles with decorative separated trails, each applying the normal single-hit rule. No vertical gameplay trajectory. Label it "Triple shot" in active UI/catalog and document this dimensional adaptation. It may concentrate three hits on one surviving target; do not silently invent penetration or area damage.

## Experiment evidence and integration gaps

The playtest report records two passing focused tests and headless boots at two sizes, plus unresolved headless resource-leak warnings. It does not record native screenshots or interactive focus checks. User approval selects the direction but is not evidence that those technical checks passed. Carry them forward to 56–57.

Source inspection shows `data/schedule.gd` ends at 82 seconds; card 52 must provide ongoing catalog-driven pressure. `scripts/projectile.gd` applies hostile damage at the original aim point; card 53 must make dodging work against current positions. The experiment controller polls input inside its simulation loop and owns a separate HUD/RunState copy: card 51 restores queued input, the existing scheduler, and production UI/model ownership. Do not treat the two experiment tests as full regression coverage.

## Execution rules

1. Read applicable repository instructions and predecessor handoffs. Follow actual current paths if a predecessor moved them. Keep notes under roughly 150 words per card.
2. Card 49 preserves the baseline before any active code is removed. Verify resolved source/destination paths before recursive file operations on Windows. Never overwrite a pre-existing archive without investigating it.
3. Each card leaves its declared milestone runnable and parsing. Preserve the experiment's playable encounter during promotion; progression/persistence integration follows in later cards. Label temporary limitations honestly. Do not retain inert 3D implementations merely to satisfy old tests.
4. Reuse model/UI code and behavioral tests. Classify affected tests explicitly in `work/2d/test-matrix.md`; every archived fixture must have an explicit 2D replacement or obsolete rationale. Do not silently weaken the runner, suppress errors, or present a partial suite as complete.
5. Use the installed Godot executable and existing PowerShell runner. No engine upgrade, downloads, plugins, asset purchases, external services, or deployment in this queue.
6. Tests use isolated stores/profiles. Old saves are disposable for compatibility purposes, but resetting the real user profile is unnecessary. Never claim visual or manual checks from headless results.
7. Update the current card only after actual work. Values: TODO, IN PROGRESS, DONE, BLOCKED. Record a concrete blocker rather than inventing success.

## Ordered work

| ID | Card | Depends on | Status |
|---|---|---|---|
| 49 | [Archive the 3D baseline](../assignments/49-archive-3d-baseline.md) | Current working project | DONE |
| 50 | [Promote the approved side-view arena](../assignments/50-2d-shell-movement.md) | 49 | DONE |
| 51 | [Encounter lifecycle and existing interface](../assignments/51-2d-encounter-ui.md) | 50 | DONE |
| 52 | [Enemy pursuit, machine defense, and surges](../assignments/52-2d-enemies-surges.md) | 51 | DONE |
| 53 | [Weapons, projectiles, dash, and pulse](../assignments/53-2d-weapons-abilities.md) | 52 | DONE |
| 54 | [Progression and production integration](../assignments/54-2d-progression.md) | 53 | DONE |
| 55 | [Fresh 2D persistence and recovery](../assignments/55-2d-persistence.md) | 54 | DONE |
| 56 | [Readable 2D presentation](../assignments/56-2d-presentation.md) | 55 | DONE |
| 57 | [Full acceptance and documentation](../assignments/57-2d-acceptance.md) | 56 | BLOCKED |

After 53: one complete playable extraction encounter with the existing interface and placeholder graphics. After 55: the current progression loop and 2D recovery work. After 57: one clearly identified active 2D prototype, one preserved 3D archive, and an evidence-backed handoff for future art production.
