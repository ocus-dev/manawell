# UI icon asset pipeline — parallel Luna queue

> Current item-art delivery: [Nine equipment icons and reusable pipeline](../../art/ui-items/README.md) are implemented for the live loot inventory and world-drop visuals. This supersedes the old item batch below for current equipment. Skill glyph work and the remaining older queue are not marked complete by that delivery.

This queue builds reusable item/equipment art and skill glyphs while the P01–P08 HUD/platforming queue proceeds. Planning only; no tasks are dispatched. Do not change P-queue status or stop its work. Cards I01–I04 can run alongside it in separate owned files; I05 is serialized after the integration dependencies below.

## Luna prompt

Select GPT-5.6 Luna and paste:

> Implement only work/ui-assets/I01-icon-contract.md. Read work/ui-assets/README.md, the assigned card, and predecessor notes, then only relevant existing source. Respect the parallel-work file boundaries. Complete its acceptance checks, update only this queue's status and the card's completion note with actual files/checks/limitations, then stop. Do not modify the platforming queue or live HUD, spawn agents, create tasks, introduce gameplay items, or implement later cards.

Replace the path with the next I-card after its dependency completes. Status values: TODO, IN PROGRESS, DONE, BLOCKED. Notes should stay near 150 words.

| Card | Deliverable | Depends on | Status |
|---|---|---|---|
| [I01](I01-icon-contract.md) | Asset manifest, style rules and integration contract | Existing catalog and P02 specification | TODO |
| [I02](I02-item-workflows.md) | ComfyUI item presets and initial generated set | I01 | TODO |
| [I03](I03-prepare-icons.md) | Prepared item PNGs and skill SVGs | I02 | TODO |
| [I04](I04-icon-gallery.md) | Isolated Godot gallery and visual checks | I03 | TODO |
| [I05](I05-integrate-icons.md) | Hook approved provisional assets into the live UI | I04 plus P03 and P04 complete, HUD files idle | TODO |

## One reusable asset workflow

Item/equipment: authored subject definition → local ComfyUI concept → cutout → deterministic crop/padding → native-size review → runtime PNG + manifest.
Skills: semantic action definition → hand-authored SVG glyph → native-size review → runtime SVG + manifest.
Both: isolated Godot gallery → live widget binding by ID → state/interaction checks.

Use the existing painted retro-industrial OVA language for item materials: chunky engineered forms, quiet surfaces, selective lines, three broad value groups and small functional accents. Skills use the same silhouette language simplified into one-color/off-white glyphs suitable for theme tinting. Do not attempt to derive a tiny readable skill symbol by shrinking a detailed generated scene.

## First batch and stable IDs

These are presentation mappings for existing concepts, not authorization for new gameplay:

| Manifest key | Existing concept | Visual direction |
|---|---|---|
| skill.dash | dash action | Forward chevrons / short acceleration streak |
| skill.pulse | pulse action | Central emitter and expanding rings |
| resource.mana | existing currency | Contained cyan energy capsule |
| upgrade.damage_1 | damage upgrade | Reinforced gun barrel module |
| upgrade.pump_1 | pump upgrade | Compact pump/tank module |
| upgrade.spread_1 | existing three-shot upgrade | Three parallel projectile outlets |
| loadout.standard | standard loadout | Plain industrial cartridge |
| loadout.overdrive | overdrive loadout | Vented powered cartridge |
| loadout.fortified | fortified loadout | Braced armored cartridge |
| fallback.unknown | missing icon | Neutral crate/question glyph |

No jump skill slot: jumping remains movement. Do not hard-code Space/Shift into art; P04 changes controls. Preserve current IDs even if UI wording is later renamed. Read current catalog labels at integration time rather than using this table to change balance or invent content. Future item IDs can extend the manifest without adding another pipeline.

## Pixel and file contract

- Skill masters: simple SVG viewBox 0 0 64 64, roughly 8 px safe padding; principal strokes about 4 px at master size; no external fonts, embedded bitmap, scripts or external links. Test at 24, 32, 40 and 44 px.
- Item concepts: one object per 1024×1024 generation, fixed lighting and framing, isolated on a plain background. Prepare a 256×256 transparent runtime canvas with consistent optical size and at least 12% safety padding. Review at 32, 48 and 64 px; tiny detail must not carry meaning.
- Preserve straight RGBA transparency and soft edges. No painted checkerboard, ground shadow, card frame, rarity border, item name, keycap, text, cooldown wedge or selected glow inside the asset.
- Keep cooldown, disabled tint, focus/hover, key label and selected-state layers dynamic in the widget. Essential state cannot rely on color alone.
- Similar silhouettes need distinct structural differences (for example plain/vented/braced cartridges), not merely recoloring the same image.
- Record source/hash, output/hash, generation graph/seed/job ID where applicable, asset kind, transparent/visible bounds and intended display sizes. No atlases needed for this small batch.
- Missing keys resolve to fallback.unknown with a diagnostic; never a broken texture or silent unrelated icon.

## Parallel work ownership

I01–I04 may create/edit only:
- work/ui-assets/
- art/ui-assets/
- tools/ui_assets/
- prototype/assets/ui-icons/
- prototype/scripts/ui_assets/
- prototype/scenes/previews/ui_icon_gallery.tscn
- prototype/tests/ui_icon_assets_test.gd

Read other files as necessary. Reuse existing helpers by import/copy with attribution, but do not edit tools/asset_pipeline/side_view.py or its generated workflows while other tasks may use them. Create a separate Telos_UI_Icons ComfyUI folder; do not replace Telos_SideView. External installation permissions still apply.

Do not edit ability_bar.gd, combat_preview.gd, encounter_hud.gd, ui_view_state.gd, player/controller/input code, project.godot, live operations widgets, shared themes, or P-queue documentation during I01–I04. P02 retains its own working glyphs until I05 swaps their visual resources. Do not require P02 to wait for this asset queue.

I05 begins only after P03/P04 are complete and the owner/coordinating task confirms no active task owns the live widget files. Inspect actual latest changes and integrate narrowly; if the same task serially performs both queues, its completed handoffs establish this. Do not resolve concurrency by overwriting another task's files.

## Owner steps

1. Start I01 with the prompt above. No additional item list is required for the first batch.
2. Keep ComfyUI available during I02; avoid simultaneous heavy GPU work. Existing installed local models only.
3. Review I04's gallery at normal game size, not just enlarged concept art. Look for instant recognition, consistent optical size, transparent edges, and distinguishable skill/loadout silhouettes.
4. Give feedback by key: “skill.pulse too similar to target reticle,” “loadout.fortified needs stronger braces,” etc. Optional feedback does not block a provisional gallery.
5. Run I05 after the HUD/control work is complete and idle. Review the actual hotbar and operations widgets in context.

No new skills, loot system, rarity mechanics, inventory screen, tool install, paid service, new model download, or final animation work in this queue.
