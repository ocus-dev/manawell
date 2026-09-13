# Act campaign maps — Luna assignments

M01/M02 are complete and the owner has **approved A — inland valley**. [Approved asset/layout handoff](design-review.md) records the exact files and hashes. M03's art-choice gate is closed. **Next: M04**, then M05–M07 in order. These remaining cards have not been dispatched; do not repeat map generation or ask for the same design approval again.

## Scope and decisions

Each act contains exactly **9 level nodes: 3 wells, 5 monster-only levels, 1 terminal act boss**. This supersedes the earlier two-wells-per-act example in `design/Concept.md`; it does not imply a fixed total number of acts. Start with one complete Act 1 map and reusable act definitions. Do not fabricate playable later acts.

Proposed first route (reviewable during design): **monster → well → monster → monster → well → monster → monster → well → boss**. Use one winding, sequential path initially, with explicit prerequisite IDs so a future branch does not require a rewrite. All eight preceding nodes must be cleared before the boss becomes available. Defeating a boss unlocks the next authored act; if none exists, display act completion without a dead launch button. Completed levels remain revisitable. Neither failure nor replay removes existing completion.

The map is an illustrated regional overview, not a literal platforming collision layout. Establish scale through tiny infrastructure, terrain expanses, distant landmarks, a route across distinct districts and a dominant boss destination. Each act's brief establishes palette, materials, silhouettes, atmosphere, landmarks and links to its level-environment art. Use the existing retro-industrial OVA language. Act count, names and later themes remain authoring decisions, not required new content.

Keep generated scenery separate from deterministic route/node/UI layers. Never bake names, locks, completion ticks, well status or buttons into the background. Compact markers and a single selection panel preserve the map's visual area.

## Queue

| Card | Deliverable | Depends on | Status |
|---|---|---|---|
| [M01](M01-map-art-contract.md) | Act 1 brief, nine-node layout and asset contract | Existing art and campaign audit | DONE |
| [M02](M02-map-workflows.md) | Reusable ComfyUI map workflows and candidates | M01 | DONE |
| [M03](M03-design-review.md) | Owner design checkpoint — A approved from M02 delivery | M02 | DONE |
| [M04](M04-campaign-state.md) | Campaign definitions, progression and save state | Explicit M03 design approval | DONE |
| [M05](M05-interactive-map.md) | Responsive map screen and live indicators | M04 | DONE |
| [M06](M06-level-routing.md) | Launch/revisit routing and three encounter types | M05 | TODO |
| [M07](M07-campaign-acceptance.md) | End-to-end campaign and visual acceptance | M06 | TODO |

M01–M03 may run while other queues continue, within their owned directories. M04–M07 must be serialized with any active work touching account, persistence, catalog, controller or live UI files. Inspect current source and completed handoffs; historical contracts may lag platforming implementation. Do not overwrite another task's work or falsely claim prerequisites are complete.

## Luna prompt

Select Luna in task settings and paste:

> Implement only work/world-map/M04-campaign-state.md. Read work/world-map/README.md and work/world-map/design-review.md first, then the assigned card and relevant current source. Candidate A is approved; use its exact layout and preserve its IDs. M01–M03 are complete: do not regenerate art or request design approval again. Coordinate shared model/controller/persistence files with active work. Implement only this card, run its acceptance checks, update its status and completion note with actual results, then stop. Do not spawn agents, create tasks or implement later cards.

Replace the card path as predecessors complete. Status values: TODO, IN PROGRESS, DONE, BLOCKED. M03 may be DONE for delivering a review board while approval remains PENDING; M04 still cannot start. No live implementation occurs merely by creating these assignments.

## Owner steps

1. Give Luna the M04 prompt above after shared implementation files are available.
2. Run M05 for the compact interactive map, then M06 to connect Start/Revisit to real encounters.
3. Run M07 and playtest the full act journey. Art approval does not authorize unbounded later-act content or a boss system beyond the scoped prototype.

## Boundaries

Before design approval, write only `work/world-map/`, `art/world-map/`, `tools/world_map/` and an isolated `experiments/world-map-review/` if needed. Read existing assets/helpers, but do not modify them or live `prototype/` files. New ComfyUI files belong in `Telos_WorldMap`, preserving other workflows; external installation permissions still apply. Use existing installed models, serial GPU jobs and saved provenance. Do not download models or start cloud services as an incidental step.

Prototype save migration is not a priority, as previously agreed. New campaign progress must nevertheless save reliably, reject invalid identities and avoid duplicate rewards. Use explicit version/reset behavior for incompatible prototype saves; do not quietly erase a real profile or weaken corruption recovery.
