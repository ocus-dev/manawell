# Prototype work assignments

> **Required for all agents:** Read [the agent working agreement](agents.md) before starting. Every task prompt must explicitly reference it. Its ownership, Git and integration rules apply to every queue below; historical completion notes do not establish a current integrated baseline.

> **Current loot queue:** [Monster loot and hero builds](loot/README.md). Low-probability monster drops, rarity, individual item rolls, per-hero equipment and deeper stats. L01 and primary-assistant D02 review are complete; start Luna at L02 using the updated prompt and approved contracts. This supersedes unimplemented E01–E06 assumptions. Existing fixed collection behavior remains live until migration/cutover. No new tasks dispatched by this handoff.

> **New planned queue:** [Research trees — Luna R01–R07](research/README.md). Two trees cover harvesting amount/cadence and weapon damage/rate/multishot/projectile speed, with selectable Rapid Seal, Deep Draw and Lance specializations. Begin with catalog/balance, then state, mechanics, compact UI and measured campaign acceptance. Coordinate shared files with remaining map/animation work; no tasks dispatched.

> **New staged queue:** [Act campaign maps — Luna M01–M07](world-map/README.md). Generate themed map candidates first, then stop at M03 for explicit owner design approval. Only afterward implement campaign progression, compact interactive markers and real level routing. Each act has nine nodes: three wells, five monster-only levels and one terminal boss. This queue does not cancel current platforming or icon work.

> **Parallel asset queue:** [UI item and skill icons — Luna I01–I05](ui-assets/README.md). I01–I04 build workflows, assets and an isolated gallery without editing live HUD/platforming files. I05 integrates only after P03/P04 are complete and the relevant widget files are idle. This does not replace or pause P01–P08.

> **Current next queue:** [Compact combat UI and platforming — Luna P01–P08](platforming/README.md). Following the completed visual slice, compact health/pressure and icon skills first, then implement jumping, platforms, height-aware combat and recovery. Card 57's historical acceptance remains explicitly open. Earlier next-queue directions below are historical.

> **Planned after architecture:** [interface revamp assignments 35–45](interface/README.md), based on [the interface design](../design/Interface.md). Finish 22–34 before starting this queue.

> **Next queue:** prototype assignments 01–21 are complete. Continue with [architecture repair assignments 22–34](architecture/README.md). That index contains the current Luna prompt, dependencies, scope, and status tracking. The completed queue below is retained as history.

These assignments implement the first prototype from `design/Concept.md`. The active result is the approved 2D side-view project in `prototype/`; the earlier 3D specification below is retained as historical assignment context. They are written for **GPT-5.6 Luna**, one assignment per task. No implementation has been performed by creating this backlog.

## Start here

Use `work/PROTOTYPE.md` as the compact specification and `work/CONTRACTS.md` for shared behavior. Do not load the entire design document, visual bible, or concept-art directory for every assignment. Read extra material only when the assigned work needs it.

Historical technical choice for assignments 01-21: **Godot 4, GDScript, desktop Windows, keyboard and mouse, primitive 3D art**. The current active implementation is the approved native 2D side view documented in `work/2d/README.md`.

## How to run a card

Use this prompt in a task configured to use GPT-5.6 Luna:

> Implement only work/assignments/01-project-bootstrap.md. Read work/PROTOTYPE.md and work/CONTRACTS.md first, then only the source files and predecessor handoff needed for this assignment. Follow its acceptance checks. Do not implement later cards or perform unrelated refactoring. Update its row in work/README.md and add a short completion note to that assignment with changed files, checks actually run, and anything still blocked. Stop when the card is complete.

Replace the assignment path for subsequent cards. The model is selected in the task settings; naming it in a prompt alone does not switch the model. These are repository work orders, not already dispatched tasks.

## Execution rules

- Work in the listed order. Dependencies are minimum prerequisites, not a request for parallel agents.
- Before starting, check prerequisite rows and their completion notes. Do not rebuild completed features.
- Keep the project runnable after every card. Use temporary test fixtures where later systems are missing; do not ship a second implementation of their rules.
- Match the existing code style and shared contracts. Avoid new frameworks, dependency packages, asset searches, and broad architecture rewrites.
- Use targeted tests for state, money, persistence, and timing. Use short manual checks for appearance and controls. Never report an unperformed check as passing.
- If a card grows beyond its stated boundary, document the smallest follow-up instead of quietly absorbing neighboring work.
- If tooling is unavailable, record the exact blocker and leave the card blocked. Do not mark it complete based solely on code generation.
- On completion, add at most about 150 words of handoff notes to the card. Include real paths and commands so the next task can continue cheaply.
- Do not spawn extra agents or create additional tasks automatically. Do not install tools, publish builds, or enable online services as an incidental step.

Status values: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`. Change status only when work actually occurs.

## Ordered queue

| ID | Assignment | Depends on | Status |
|---|---|---|---|
| 01 | [Project bootstrap](assignments/01-project-bootstrap.md) | — | DONE |
| 02 | [Arena and player movement](assignments/02-arena-movement.md) | 01 | DONE |
| 03 | [Extraction state and payout](assignments/03-extraction-state.md) | 01 | DONE |
| 04 | [Encounter wiring and basic HUD](assignments/04-encounter-hud.md) | 02, 03 | DONE |
| 05 | [Melee enemies and damage](assignments/05-melee-enemies.md) | 04 | DONE |
| 06 | [Automatic weapon](assignments/06-auto-weapon.md) | 05 | DONE |
| 07 | [Surges and ranged enemy](assignments/07-surges-ranged.md) | 06 | DONE |
| 08 | [Player abilities](assignments/08-player-abilities.md) | 07 | DONE |
| 09 | [Upgrade purchases](assignments/09-upgrade-purchases.md) | 08 | DONE |
| 10 | [Readable feedback and onboarding](assignments/10-feedback-onboarding.md) | 09 | DONE |
| 11 | [Extraction playtest checkpoint](assignments/11-extraction-checkpoint.md) | 10 | DONE |
| 12 | [Persistent account saves](assignments/12-account-saves.md) | 11 | DONE |
| 13 | [Well commissioning and second site](assignments/13-two-wells.md) | 12 | DONE |
| 14 | [Second hero and assignments](assignments/14-crew-assignments.md) | 13 | DONE |
| 15 | [Production accounting model](assignments/15-production-model.md) | 14 | DONE |
| 16 | [Network UI and online production](assignments/16-network-ui.md) | 15 | DONE |
| 17 | [Offline production settlement](assignments/17-offline-production.md) | 16 | DONE |
| 18 | [Encounter snapshot codec](assignments/18-snapshot-codec.md) | 17 | DONE |
| 19 | [Suspend and resume integration](assignments/19-suspend-resume.md) | 18 | DONE |
| 20 | [Two harvester loadouts](assignments/20-harvester-loadouts.md) | 19 | DONE |
| 21 | [Final prototype verification](assignments/21-prototype-verification.md) | 20 | DONE |

**Checkpoint A, after 11:** a one-well extraction game with combat and upgrades. Fix concrete failures before adding the network. If human playtesting is unavailable, record that limitation; do not invent a fun verdict. The owner can still choose to proceed with the second milestone.

**Checkpoint B, after 21:** two wells, two heroes, visible upgrades, crew assignment, reliable production, and local recovery. Recruitment randomness, multiple acts, online play, and polished assets remain outside this backlog.
