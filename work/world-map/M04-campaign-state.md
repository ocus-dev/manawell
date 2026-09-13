# M04 — Add campaign state and progression

**Ready after shared-file coordination.** Design approval is recorded in `work/world-map/design-review.md`. Use `art/world-map/candidates/A_valley/layout.json` (`A_valley-landmarks-02`), not the initial generic draft coordinates. No art generation or renewed approval is needed.

Requires explicit M03 design approval and idle shared model/persistence files. Read current ownership contracts and actual catalog, account, save and terminal-result implementation. Update relevant contracts after implementation; do not create competing sources of truth.

Implement authored act/level definitions separately from mutable progress. Promote the approved Act 1 manifest: exactly nine nodes, three wells, five combat nodes, one terminal boss, stable IDs, explicit prerequisites, normalized positions and encounter keys. Support additional authored acts by data; do not invent or expose playable placeholder acts. Validate missing/duplicate references, cycles, counts, disconnected nodes and boss position.

Define clear rules: first node available on a fresh campaign; successful level completion unlocks its successor; all eight previous nodes gate the boss; failure/abandonment never grants completion; completed nodes always revisitable; completed boss unlocks the next authored act. Distinguish locked/available/completed progress from transient hover/focus/selection. Show lock reasons derived from prerequisite definitions.

For wells, conquest means successful commissioning under the current extraction rules. Completing an extraction without meeting commissioning requirements does not advance the route. Derive commissioned/guarded/producing/active/idle status from the existing well/account/production systems. Map completion is not another income ledger. Add the third real well through the catalog and existing ownership mechanisms; avoid well_1/well_2-only assumptions.

Persist progress and act/node identity through the existing save envelope. Route rewards and progression through one idempotent validated terminal commit. Replays may receive normal repeatable encounter rewards once per run; never regrant one-time conquest/boss unlock rewards. On reload, restore a valid active node or reject an invalid snapshot without granting completion. Apply the queue's prototype migration policy explicitly.

Acceptance: targeted tests cover new game, nine-node counts, well commission gating, failure, replay, duplicate result delivery, boss/next-act unlock, third-well independence, invalid definitions, and save/reload. No clickable map or fake encounter completion shortcuts yet. Document the semantic command/view-state interface for M05/M06.

Completion note: implemented. Added validated authored campaign definitions for approved Act 1 layout `A_valley-landmarks-02`, mutable progression and idempotent terminal commits, catalog-driven third-well commissioning, version-5 save-envelope campaign persistence with legacy-save defaults, and derived well status. Acceptance coverage is in `prototype/tests/campaign_state_test.gd`; it passed alongside the existing catalog check. No map UI or encounter shortcut was added.
