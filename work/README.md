# Prototype work assignments

> **Planned after architecture:** [interface revamp assignments 35–45](interface/README.md), based on [the interface design](../design/Interface.md). Finish 22–34 before starting this queue.

> **Next queue:** prototype assignments 01–21 are complete. Continue with [architecture repair assignments 22–34](architecture/README.md). That index contains the current Luna prompt, dependencies, scope, and status tracking. The completed queue below is retained as history.

These assignments implement the first prototype from `design/Concept.md`. They are written for **GPT-5.6 Luna**, one assignment per task. No implementation has been performed by creating this backlog.

## Start here

Use `work/PROTOTYPE.md` as the compact specification and `work/CONTRACTS.md` for shared behavior. Do not load the entire design document, visual bible, or concept-art directory for every assignment. Read extra material only when the assigned work needs it.

Provisional technical choice: **Godot 4, GDScript, desktop Windows, keyboard and mouse, primitive 3D art**. Assignment 01 verifies available tooling and records an exact version. This is a practical default for this backlog, not an engine decision previously made in the concept. If the user selects another engine, revise the contracts and paths once before implementing downstream cards.

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
