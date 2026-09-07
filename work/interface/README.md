# Interface revamp — Luna assignments 35–45

> **Current repair queue:** [48 — live visual acceptance](../assignments/48-ui-visual-acceptance.md). See [the measured gap report](../reviews/ui-implementation-gap.md). Original DONE rows are historical implementation status; visual acceptance remains open.

| Repair | Depends on | Status |
|---|---|---|
| 46 — UI layout repair | 45 implementation | DONE |
| 47 — UI interaction repair | 46 | DONE |
| 48 — UI visual acceptance | 47 | BLOCKED |

Luna prompt: **Implement only work/assignments/46-ui-layout-repair.md. Read the gap report and named design sections, reproduce the layout measurements, fix only this card, run its focused checks, update its completion note and status here, then stop.** Substitute the next path after verified completion.

Implement [the interface design](../../design/Interface.md) after architecture assignments 22–34. At planning time only 22–23 were marked DONE; this UI queue does not imply the other architecture work is complete. Do not implement against the old monolithic controller while that refactor is in flight.

## Start

Use a task configured for GPT-5.6 Luna:

> Implement only work/assignments/35-ui-view-state.md. Read work/interface/README.md, the named sections of design/Interface.md, and the prerequisite handoff. Reuse the completed architecture's HUD, ID-based commands, definitions and session persistence. Implement this card and focused checks only, update its completion note and row in work/interface/README.md, and stop. Do not implement later cards, change balance, or spawn extra agents.

Replace the path for each subsequent assignment. These are work orders only; no game implementation or task dispatch was performed in creating them.

## Design direction

- Operations groups well cards, guard slots, research and expedition preparation.
- Every commissioned empty well has a visible **+ Assign guard** slot; an occupied slot shows that well's actual guard.
- The expedition hero has a separate **You control** card.
- During combat, compact health, pressure, abilities and harvest widgets replace management controls.
- Results, pause, settings and recovery each get a small focused surface.

The full specification defines state variants, empty/locked reasons, confirmation behavior, input routing and dimensions. The conversation mockup is illustrative, uses example data and a subset of interactions; it is not an alternative set of game rules or the runtime implementation.

## Working rules

1. Work serially. Start 35 only after 34 is complete and its unresolved issues are understood. Preserve all existing assignment statuses.
2. Reuse the architecture pass's presenter/view state and command boundaries where they exist; extend them rather than create competing owners. Widget rendering never settles production, saves or mutates account dictionaries.
3. Build real Godot components. The mockup's browser markup is a design reference, not a request to embed a browser in the game.
4. Read only assigned sections and relevant source. Use fixture previews to avoid replaying the whole campaign for every UI change.
5. Keep economy, hero stats, unlocks, timing and loadout values unchanged. Derive labels from current definitions. Only narrow command adapters/navigation commands required by the specified UI flow are in scope.
6. Preserve the existing explicit assignment rules. No implicit guard transfers or role swaps. Empty/unavailable states explain the correct next action.
7. All game mutations use ID-based domain commands and real results. A rejected command or failed save must never be rendered as durable success.
8. Use the strengthened runner from assignment 22 and isolated fixture paths. UI tests check emitted intent/state/interaction behavior, not private node names wherever avoidable. Never reset or modify the real player save for tests.
9. Test small cards with targeted checks. Run the complete suite at 44 and 45, and when concrete integration concerns justify it. Do not claim visual usability based only on headless assertions.
10. Keep intermediate preview widgets separate from the current live HUD until integration is ready. Card 44 removes superseded UI code and duplicate event handlers. Do not leave two runtime implementations enabled.
11. Preserve focus and selection through refresh. Modals consume input before gameplay, including the existing E and Space shortcuts. Card 44 verifies the real event path, not just direct method calls.
12. Keep handoff notes concise, with actual source paths, interfaces, checks and screenshots when available. Mark runtime blockers honestly; report missing manual verification explicitly. Avoid extra frameworks, asset downloads, engine changes or unrelated refactors.

## Queue

| ID | Assignment | Depends on | Status |
|---|---|---|---|
| 35 | [UI view state and preview fixtures](../assignments/35-ui-view-state.md) | 34 | DONE |
| 36 | [Shared theme and operations shell](../assignments/36-ui-theme-and-shell.md) | 35 | DONE |
| 37 | [Well cards and guard slots](../assignments/37-well-cards.md) | 36 | DONE |
| 38 | [Guard and expedition hero pickers](../assignments/38-hero-picker.md) | 37 | DONE |
| 39 | [Expedition preparation and launch](../assignments/39-expedition-panel.md) | 38 | DONE |
| 40 | [Research cards and wallet feedback](../assignments/40-research-and-wallet.md) | 39 | DONE |
| 41 | [Compact combat HUD](../assignments/41-combat-widgets.md) | 40 | DONE |
| 42 | [Pause, results and return flow](../assignments/42-pause-and-results.md) | 41 | DONE |
| 43 | [Recovery notices and safe settings](../assignments/43-notices-and-settings.md) | 42 | DONE |
| 44 | [Input routing and final HUD integration](../assignments/44-input-and-runtime-integration.md) | 43 | DONE |
| 45 | [UI walkthrough and handoff](../assignments/45-ui-verification.md) | 44 | DONE |

## Completion target

A player can see both wells and their guards, assign a reserve hero by clicking a well's +, choose an expedition destination and hero, purchase existing upgrades, and launch. During extraction, all survival/harvest information is visible without scrolling. Pause, result and recovery flows cannot accidentally send gameplay input or misrepresent saved progress.

After 45, review work/reviews/interface-review.md for evidence and unresolved visual checks before further gameplay changes.
