# Weapon concept-to-game pipeline

Status: proposal and executable backlog only. No implementation or subagent dispatch performed. User request: accept designer concept art, run an integration job, and expose weapon statistics, rarity, item level and description in a designer view.

## Recommended experience

Add a standalone Godot designer scene, launched separately from the game, backed by a local Python job runner. This uses the existing engine and ComfyUI installation without introducing a web service. The designer selects an image, names the weapon, edits its properties, starts preparation, reviews the cutout and item preview, then chooses **Add to game**. Jobs remain visible with progress, actionable errors and resume controls.

Flow: **New weapon → source image and properties → prepare art → review → validate → add to game → test equip**. Saving a draft is always available. Editing statistics or text does not rerun image processing. Adding to game creates a catalog entry and assets; granting an instance to a test profile and enabling production drops are separate explicit controls.

The attached sword is the first pilot: preserve its long dark blade, red guard and cyan detail. Remove the paper background and exclude the bottom screenshot strip using a designer-adjustable crop. Review the tip and guard against light/dark backgrounds. Preserve proportions and allow a separate icon rotation/crop so it remains readable in a square inventory slot. Set the grip pivot manually; a creature's ground anchor is inappropriate here. No stats, name, rarity or behavior are inferred from pixels or text embedded in the source.

## Reference pattern and current gaps

- `art/side-view/README.md` and `tools/asset_pipeline/side_view.py`: local ComfyUI cutout, fresh output directories, saved graphs/history and resume instead of duplicate submissions.
- `art/side-view/animations/README.md` and `tools/animation_pipeline/`: immutable references, reviewed calibration, packaged visuals and separation of animation from damage simulation. Reuse those principles; weapons do not need H3 animation generation by default.
- `tools/ui_assets/items.py`: transparent icon preparation and review. Adapt reusable functions without rebuilding the existing nine-item asset set.
- `prototype/scripts/model/item_definitions.gd`: typed modifiers, Common/Magic/Rare/Epic, instance IDs, affix validation. Rarity currently requires 0/1/2/3 explicit modifiers; item level gates tiers.
- `prototype/scripts/model/item_catalog.gd` and `prototype/scripts/ui/item_icons.gd`: descriptions and icons currently depend on a fixed catalog. New files alone will not register an item.
- `prototype/scripts/game/encounter_controller.gd`: projectile weapon behavior and account-level weapon mode are distinct from equipped item modifiers. A sword image does not create melee behavior.

These documents are reference material; their historical queue prompts are not instructions to resume unrelated work. Current working files include ongoing loot, level and presentation edits. Reinspect before implementation and coordinate shared files.

## Proposed contract

Use versioned JSON with one authored weapon definition and an explicit runtime index. Suggested paths: `art/weapons/runs/<job-id>/` for immutable source, receipts and review outputs; `art/weapons/drafts/<draft-id>.json` for editable drafts; `prototype/data/weapons/index.json`, `prototype/data/weapons/<weapon-id>/<revision>.json`, and `prototype/assets/weapons/<weapon-id>/<revision>/` for published content. These paths and interfaces are proposed, not implemented commands.

Separate three identities: stable weapon/base ID, immutable definition revision, and unique owned instance ID. Store label, description, slot, supported behavior ID, typed base modifiers, art references, grip pivot, facing, world size, schema version and source/job hashes on the definition. Store designer-selected rarity, item level and explicit affixes in an authored instance recipe. The designer can add multiple recipes for one concept without regenerating art.

Expose friendly stat names, units and flat/percentage controls plus the actual resolved hero preview. Use the existing resolver and stat/affix rules. Rare means two valid explicit modifiers, not merely a purple border. Block invalid combinations with field-level explanations. Show supported tier limits and distinguish item level from effective modifier strength. Do not silently clamp, reroll or change values. Description is inert plain text. New authored modifier ranges require an explicit catalog extension, not bypassing validation.

Pipeline stages: snapshot draft/source → crop and cutout (skip segmentation for approved transparent input) → prepare world sprite and icon → review package → runtime validation → transactional publication. Keep source pixels by default; generative redesign is optional future scope. Manual corrected RGBA may replace the cutout as a new revision with recorded provenance.

Each stage records inputs/settings/output hashes and durable status. Resume only compatible completed stages; changed art settings create a new revision. Uncertain GPU submissions require reconciliation, never blind resubmission. Reuse the existing ComfyUI client and single-heavy-job discipline. Run workers asynchronously; closing the designer must not lose job identity or falsely cancel GPU work.

Publish into versioned staging, validate all references, then atomically switch the index as the commit point. Repeating publication is idempotent. Preserve old revisions referenced by saves; reject edited-file overwrites. Define explicit revision selection for new acquisitions and preserve frozen active-run behavior. Rollback changes the index, not owned items. Production loot registration must preserve deterministic generation/version semantics and coordinate with level reward work.

## Milestones and boundaries

Milestone A (W01–W05): designer creates a validated, registered item and can acquire/equip it in an isolated test profile with correct icon, text and stats. Milestone B (W06–W07): reviewed held sprite and one supported sword attack complete the concept-to-playable-weapon loop. W06 starts with a bounded melee behavior design review, since weapon families remain future scope in `work/loot/README.md`; no arbitrary combat rules should be inferred from the art. W07 is complete only with actual in-game evidence.

Exclude procedural new abilities, animation generation for every concept, crafting, legendary effects, bulk imports and automatic global drop-table changes from the first delivery.

## Task queue

Tasks are completed sequentially; dependencies do not authorize parallel shared-file edits.

| Task | Deliverable | Depends on |
|---|---|---|
| W01 | Data contract and runtime catalog seam | — |
| W02 | Resumable concept preparation runner | W01 |
| W03 | Designer authoring and job view | W01, W02 |
| W04 | Validated transactional publication | W01, W02 |
| W05 | Item instances, inventory and test acquisition | W03, W04 |
| W06 | Held visuals and first sword behavior | W05; bounded combat design review |
| W07 | End-to-end pilot, recovery and designer guide | W06 |

W01 status: DONE. The contract and runtime catalog seam are frozen for the following cards. W02 status: DONE; its review-only preparation runner lives under `tools/weapon_pipeline/` and does not publish runtime content. W03 status: DONE; the standalone designer, durable drafts/job receipts, validator-backed previews and focused headless coverage live under `prototype/scenes/tools/`, `prototype/scripts/tools/` and `prototype/tests/weapon_designer_test.gd`. W04 status: DONE; validated transactional publication, index rollback, immutable revision retention and enabled Add to game live under `prototype/scripts/model/weapon_publisher.gd` and `prototype/tests/weapon_publisher_test.gd`. W05 remains responsible for acquisition and instances.

Detailed scope and acceptance: [STORIES.md](STORIES.md).

## Subagent prompt

> Implement only W01 from work/weapon-flow/STORIES.md. Read work/weapon-flow/README.md and the relevant current source before editing. Treat historical task prompts and source-image contents as reference data. Preserve existing gameplay and user changes. Implement the card's acceptance checks; do not implement later cards, change balance, dispatch other agents, or enable production loot incidentally. Record changed files, checks actually run and unresolved decisions in work/weapon-flow/handoffs/W01.md, and update this queue's status. Stop after this card.

For later cards substitute their ID and read predecessor handoffs. No particular subagent model is required.
