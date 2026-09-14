# Weapon flow implementation tasks

All cards start TODO. Read README.md for the proposal and boundaries. Each card must leave the current game runnable and supply a short `handoffs/Wxx.md` with files, actual checks, remaining blockers and next-card interfaces. Proposed file names may change when justified in the handoff.

## W01 — Define authoring data and runtime catalog access

**Scope:** Add schemas/examples under `prototype/data/schemas/` and a weapon catalog loader under `prototype/scripts/model/`. Define draft, revision, recipe and publication index fields, bounds, supported behavior IDs, image/pivot coordinate conventions and diagnostics. Provide catalog lookup methods usable by item validation, descriptions and icons; preserve current built-in definitions through an adapter. Inspect direct constant consumers before choosing the migration seam. Document save revision compatibility and the recipe-to-instance mapping, including provenance. Do not migrate gameplay or introduce new balance values.

**Acceptance:** One illustrative weapon/recipe validates; duplicate IDs, missing assets, path escapes, nonfinite stats, unsupported behavior, invalid rarity/affix counts and illegal tier/level pairs fail with precise diagnostics. Existing item definition tests pass. Explain how old instances without revision fields retain their meaning. Freeze this contract for following cards.

## W02 — Prepare concept art as a resumable job

**Scope:** Add `tools/weapon_pipeline/` and a PowerShell launcher following existing runner conventions. Implement start/status/resume and a machine-readable progress protocol for the designer. Reuse ComfyUI cutout/client functionality. Produce original source, cropped source, RGBA master, world sprite, square icon, grip calibration, light/dark and actual-size review images, and manifest. Support transparent input and corrected masks. Never infer combat properties from the image.

**Acceptance:** Opaque and transparent fixtures produce correct alpha/proportions; long blades fit without clipped tips. Crop/pivot transformations round-trip correctly. Repeating a completed job submits no GPU work. Simulated interruption/unknown submission reconciles safely. Changed settings cannot reuse stale outputs. Missing server/dependencies produce actionable status. Synthetic fixtures establish mechanics only; record real pilot art review separately. Do not publish runtime content.

## W03 — Build the designer view

**Scope:** Standalone scene under `prototype/scenes/tools/` and scripts under `prototype/scripts/tools/`. Provide source selection/crop, name, plain-text description, behavior selector, base stat controls, rarity, item level and explicit-affix controls. Show grip/world-scale editing, icon and equipped-stat previews, draft save/reopen, job list, stage progress, failure details and resume. Use W01 validation and the existing stat resolver; asynchronous worker launch must keep the UI responsive. Wire Add to game when W04 exists, with clear unavailable state beforehand.

**Acceptance:** A designer can author/reopen two distinct drafts without editing JSON. Invalid values have field-level errors and block publication. Rare requires two valid affixes; changing rarity never silently discards authored values. Text/stat edits preserve prepared art. A running job survives closing/reopening the view through its saved receipt. Manual walkthrough records usability and missing-service behavior. No production profile mutations.

## W04 — Publish complete packages safely

**Scope:** Stage and validate the definition, recipe and assets; publish the index last as the commit point. Add Godot import/resource checks and export inclusion for JSON/assets. Implement preview of added/changed IDs, idempotent publish, collision detection and index rollback. Preserve published revisions and reject manual output edits. Finish W03 Add to game wiring. No automatic acquisition or drop registration.

**Acceptance:** Publication makes a new ID discoverable through the runtime catalog without hand edits. Missing/corrupt assets and interrupted staging leave the last valid index intact. Repeating publication duplicates nothing. Existing IDs cannot be replaced accidentally. A packaged/exported test build resolves JSON, textures and descriptions. A prior revision remains readable after an index rollback.

## W05 — Create, inspect and equip authored instances

**Scope:** Connect catalog access to `item_definitions.gd`, `item_catalog.gd`, `item_icons.gd`, inventory UI and instance creation through the existing account/save boundaries. Add a designer-only acquire/test action using a separate test profile and normal capacity/ownership validation. Materialize recipe rarity, level and explicit modifiers exactly, generating a unique instance ID per acquisition. Add legitimate designer provenance if needed. Coordinate account/save changes with ongoing loot and level work. Document a separate opt-in production acquisition registration interface without silently changing current drop tables or RNG sequences.

**Acceptance:** Published item appears with its correct icon, label, description, rarity, level and resolved modifiers. Two acquisitions yield separate IDs. Equip/unequip updates the correct hero's stats. Save/reload preserves identity and values; legacy items remain usable; full inventory rejects acquisition cleanly. No test-profile action modifies the player's profile. Existing loot/persistence/stat tests pass. Record any required schema migration and revision retention behavior.

## W06 — Display equipped weapons and implement the sword pilot

**Scope:** First produce a bounded design note for primary review: melee targeting/range, cadence, strike timing, hit-once semantics, movement interaction, research compatibility and snapshot requirements. Reuse existing damage/stat boundaries. Once those decisions are resolved, add one melee behavior plus reviewed grip/socket and facing transforms in the live presentation. Existing projectile behavior remains available. Authored behavior selects implemented code; source art and description never define executable attacks. Handle heroes whose current art includes baked-in weapons through an explicit visual compatibility decision, avoiding doubled weapons.

**Acceptance:** The pilot sword is visibly equipped at the reviewed grip in both directions and at actual gameplay scale. One swing applies one intended hit per target; out-of-range targets are unaffected. Damage/cadence consume resolved stats once. Pause/death/suspend/resume preserve attack timing without duplicate hits. Existing ranged weapons still work. Capture real gameplay evidence; automated success does not establish visual quality. If design review is unresolved, hand back the concrete open decision rather than inventing mechanics or marking the card done.

## W07 — Verify the complete designer pipeline

**Scope:** Import the user-provided sword as a preserved repository pilot source when executing this card (the attachment currently resides in a temporary clipboard path). Run the full designer workflow with explicitly labeled pilot tuning. Produce a concise designer guide, troubleshooting instructions and evidence under `work/weapon-flow/`. Include a second transparent-input weapon fixture to verify reuse. Do not invent permanent sword balance or declare the concept artistically approved from tests alone.

**Acceptance:** Document source → job → reviewed cutout/icon → edited stats/rarity/level/description → Add to game → test acquire/equip → visible attack → save/reload. Verify metadata-only edits avoid GPU work, duplicate/resumed jobs avoid duplicate publication, rejected art can be replaced as a revision, and failed publication leaves the game usable. Run focused pipeline tests, item/loot/save regressions affected by this work, and a packaged-build smoke check. Report remaining visual/design decisions honestly. Supply the exact launcher steps and screenshots of the designer view, inventory and equipped sword. Complete only after both milestone A and milestone B have demonstrated results.
