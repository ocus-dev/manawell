# Compact combat UI and platforming — Luna queue

Current next work, following the completed visual slice and the owner's feedback. This queue supersedes the earlier no-platforming constraints for this milestone. The existing sprites/environment remain the visual baseline. Planning only: no implementation tasks dispatched.

## Run with Luna

Select GPT-5.6 Luna and paste:

> Implement only work/platforming/P01-compact-combat-hud.md. Read work/platforming/README.md, the assigned card and its predecessor handoff, then only the relevant current source. Complete its checks, update the status row and a concise completion note with changed paths, commands/results and remaining limitations, then stop. Do not execute later cards, spawn agents, create tasks, regenerate art or change unrelated systems.

Substitute each next card in order. Preserve completed visual-slice history and the original 3D archive. Card 57's open historical acceptance is not a prerequisite; carry relevant unresolved checks into P08. Status values: TODO, IN PROGRESS, DONE, BLOCKED. Keep notes around 150 words per card.

## Two milestones

1. P01–P03: a compact combat HUD with thin HP/pressure indicators and icon-only skill bar.
2. P04–P08: jumping and two platforms, height-aware combat and reliable save/resume.

## Product decisions

- Each persistent HUD element must communicate a current action or risk. Keep hero health, machine health, pressure/next surge, unbanked tank, harvesting/sealing and pause; remove duplicate explanations, huge frames and passive-income detail from combat. Operations/results retain their established layout.
- At 1280×720 logical resolution, target a top reserved band no taller than 56 px and a bottom band no taller than 64 px, with small edge margins. Individual panels hug content; do not fill these bands with opaque backing. Keep the central play area y=64…648 free of persistent HUD. Temporary world-space hit/telegraph effects and modals are exceptions. Static visible panel/control bounding areas should total no more than 15% of the viewport; exclude transparent full-screen roots and count overlapping rectangles only once.
- Health bars roughly 140–180 px wide and 6–8 px thick; surge cluster roughly 220–260 px wide. Skill targets 40–44 px square plus small badges, with a strip no taller than 56 px. Main text stays at least 14 logical px, key/cooldown micro-labels at least 12. These are implementation targets to validate in screenshots, not permission to clip critical information. Default UI scale must work without adjustment.
- Skill bar: dash/pulse icons, key badges, cooldown overlays, tooltip/focus explanations. No permanent skill-name/ready text. Click access remains. Jump is movement rather than a skill slot.
- Platforming mapping: Space jump; Shift dash; Q pulse; E start/harvest; A/D or arrows move; Down/S+Space drops through a platform; Escape pauses. Change bindings and all visible labels together in P04. Before P04 badges show current bindings. No new rebinding UI.
- Fixed camera and continuous safe floor remain. Two reachable one-way platforms are the first platforming scope, with coyote time, jump buffering and variable jump height. No double/wall jump, moving platforms, ladders, pits, scrolling or new art pipeline.
- Enemy platform navigation is deferred: ground enemies remain grounded, ranged enemies can aim up, breakers threaten the machine. All combat must become height-aware so vertical movement works honestly. Platforms do not block shots in this milestone.
- Preserve account/economy, damage, cooldowns, art and run lifecycle. New movement/geometry constants are explicit and centralized. Preserve one controller-owned 60 Hz scheduler; no independent physics timers. Never fake jumping as sprite-only bobbing over horizontal-only combat.
- Every intermediate card boots with its stated limitations. P04–P06 temporarily disable only active-run snapshots until P07 implements valid vertical state; account saves remain. Final delivery must restore recovery. Old active runs need no migration, but valid account progress remains.
- Use installed tools and actual runtime capture; no downloads, engine upgrades or new services. Tests use isolated fixtures. Check current source and predecessor changes rather than assuming historical file paths remain exact.

## Ordered assignments

| Card | Deliverable | Depends on | Status |
|---|---|---|---|
| [P01](P01-compact-combat-hud.md) | Compact health, pressure, and extraction HUD | Visual slice | DONE |
| [P02](P02-icon-hotbar.md) | Icon-only skill hotbar | P01 | DONE |
| [P03](P03-hud-acceptance.md) | Verify the compact HUD in the visual slice | P02 | DONE |
| [P04](P04-jump-controller.md) | Jumping, gravity, and control mapping | P03 | DONE |
| [P05](P05-platform-arena.md) | Two playable platforms in the foundry | P04 | DONE |
| [P06](P06-height-aware-combat.md) | Height-aware targeting, hits, and enemy pressure | P05 | DONE |
| [P07](P07-platform-recovery.md) | Restore exact platforming save and resume | P06 | DONE |
| [P08](P08-platform-acceptance.md) | Full platforming playtest and handoff | P07 | TODO |

## Owner review

After P03, inspect the HUD at normal viewing size: essential information must be obvious without covering the world. After P08, play both platforms and judge jump timing, drop-through, air dash, shot evasion and machine defense. Report specific friction before broad tuning. These reviews do not create an extra approval gate between already-authorized implementation cards; Luna stops after each assigned card as usual.
