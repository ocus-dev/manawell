# Telos item-art pipeline

Current batch: all nine existing equipment bases. Art is shared by every instance of the same base; rarity, selection, lock state and rolled stats remain dynamic UI layers.

## Files

- `prompts.json`: shared style, exact subject and full generation prompt for every stable item ID.
- `sources/<base_id>.png`: untouched selected generation outputs with alpha.
- `generation-receipts.json`: original generator paths and method for this batch.
- `workflows/`: nine editable ComfyUI UI graphs, matching API graphs and a background-cutout pair.
- `gallery.png`: contact sheet with large icons and 32/48/64-pixel checks.
- `../../prototype/assets/ui-icons/items/`: prepared 256×256 RGBA runtime PNGs and hash/provenance manifest.
- `../../tools/ui_assets/items.py`: deterministic workflow construction and runtime preparation.

The first batch was generated with the built-in image-generation tool, one image per item, using the exact prompts in prompts.json. ComfyUI presets are supplied for subsequent local generation; they did not generate this batch. Built-in generation has no exposed reproducible seed. The local presets have fixed seeds, but model/runtime changes can still affect reproducibility.

## Generate or revise an item

1. Add its stable ID, label, subject and full prompt to prompts.json. Keep one distinctive silhouette per item. Use the shared soft upper-left lighting, worn steel/brass/ochre palette and quiet surface detail. Never bake labels, rarity colors, borders, selection or cooldown into the image.
2. For built-in generation, request one 1024-class square transparent image with that full prompt. Review subject, silhouette and alpha. For future revisions retain original sources with a version suffix and update the selected source intentionally.
3. For local ComfyUI, run `python tools/ui_assets/items.py workflows`, open the relevant plain `.json` in ComfyUI and edit subject node 3/seed 16. These inherit the project's Krea2 concept model stack. The `.api.json` companion is for API clients, not the UI Load command. No model downloads or server writes occur when building presets.
4. Local concept output has a plain background, not guaranteed alpha. Open `cutout.json`, choose the approved output and generate a cutout with the existing Trellis2RemoveBackground node. Inspect edges and preserve alpha. Do not remove background based only on brightness: metallic highlights and holes must survive.
5. Copy the chosen genuinely transparent PNG into `sources/<base_id>.png`. Record source/provider/job details in generation-receipts.json. The preparation tool rejects opaque and empty inputs instead of quietly shipping a square background.
6. Run `python tools/ui_assets/items.py prepare`. It bounds by meaningful alpha, fits the object inside 194×194 pixels on a 256×256 transparent canvas, retains soft edges, emits hashes and rebuilds the gallery. This is deterministic asset preparation, not an art-generation step.
7. Review gallery.png at actual icon sizes on dark and light backgrounds. Open Godot to import PNGs and run `res://tests/item_icon_assets_test.gd`. Review inventory and loot-drop animations before accepting a revision.

The available project Python is `D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe` and already includes Pillow. From the project root in PowerShell, prefix commands with `&` and quote that executable path.

## Runtime binding

`prototype/scripts/ui/item_icons.gd` resolves known base IDs to cached textures. Inventory buttons use a 48-pixel icon, retaining text and accessible rarity labels. World drop animations use the same artwork within their existing rarity ring. Unknown/missing art retains the existing monogram/silhouette fallback. No equipment statistics, drop rates or save fields depend on art files.

Final sprite art replaces placeholder silhouettes only when a valid texture exists. Whole item IDs, not rarity or instance IDs, are the mapping key. Keep all generation masters outside the runtime asset directory.

## Validation — September 10, 2026

All nine images passed alpha/preparation checks and were inspected together at large and 32/48/64-pixel sizes. The ten ComfyUI API graphs (nine concepts plus cutout) validated against the running local server's node/model schemas; no local generation jobs were submitted. Godot imported the PNGs. `item_icon_assets_test.gd` and `loot_visual_feedback_test.gd` passed. Inventory rendering was checked with an injected account at 1280×720 in `inventory-preview.png`; its grid now uses available width so labels do not squeeze icons away. Existing inventory content below the collection remains vertically scrollable. Saved player data was not used or modified.
