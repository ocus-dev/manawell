# I04 — Isolated Godot icon gallery and review

Dependency: I03. Stay within the parallel-owned paths.

## Implement

Create prototype/scenes/previews/ui_icon_gallery.tscn and its controller under scripts/ui_assets/. Use the actual lookup/runtime textures, not copied preview PNGs. Show skill glyphs at 24/32/40/44 px and item icons at 32/48/64 px against light/dark gameplay-like surfaces. Include separate example overlays for normal, hover/focus, selected, disabled and cooldown plus a key badge. These are gallery demonstrations only; do not create a second skill controller or require the live hotbar to adopt gallery interaction code.

Build the gallery independently of project.godot and the live UI; it must load without account saves, gameplay or production settlement. Include clear asset-key labels outside icon canvases and a way to inspect one enlarged asset without replacing the actual-size comparisons. Use a neutral fallback case.

Capture actual rendered Godot views at 1280×720 and 1920×1080 with installed tooling and inspect icon clipping, optical size, contrast, false text detail and overlay obstruction. Add prototype/tests/ui_icon_assets_test.gd for resource lookup/gallery boot/bounds behavior. Run the focused checks; do not rerun another task's entire changing suite during parallel asset-only work.

Write art/ui-assets/review.md with images, tested sizes, candidate choices, unresolved issues and the I05 file-change plan. The owner may request revisions by asset key; absence of feedback is not final artistic approval, but a documented provisional choice is enough for the dependency handoff.

## Acceptance

Gallery uses production assets, not mock substitutes, and displays distinct icons with clear dynamic state examples. Runtime captures and checks recorded honestly. All live UI/controller files remain untouched. Integration dependencies are listed explicitly.

## Stop

Deliver the library and gallery. Do not start I05 while P03/P04 or another widget-editing task remains active.

## Completion note

Pending.
