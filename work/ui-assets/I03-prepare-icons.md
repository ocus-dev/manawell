# I03 — Prepare item PNGs and skill SVGs

Dependency: I02. Read the candidate decisions, I01 contract and existing deterministic sprite preparation utilities for useful patterns.

## Implement

Run the selected item images through local cutout one at a time, preserving source files. Prepare 256×256 transparent canvases with documented alpha bounds, safety padding and reviewed optical sizing. Preserve aspect ratio and soft alpha. Refuse empty/opaque failed cutouts; don't reduce alpha to a hard binary mask. Avoid an automatic tight crop that clips effects or makes one item much larger optically. Keep deterministic transforms/provenance and do not overwrite manually edited output silently.

Author skill.dash, skill.pulse and fallback.unknown SVGs directly with simple geometry. No raster generation needed for these glyphs. Inspect at every size in the contract; keep basic geometry and identity clear without relying on hue.

Write runtime-local files under prototype/assets/ui-icons/ and complete the asset manifest. Implement the narrow read-only lookup under prototype/scripts/ui_assets/, including texture caching and explicit fallback diagnostics without log spam. Do not bind it to live widgets yet.

Add focused preparation/lookup checks: valid RGBA, nonempty alpha and bounds, padding preservation, no missing manifest path/key, safe self-contained SVG, correct fallback, and no baked text/hotkeys in skill artwork. Do not assert aesthetic quality from these tests.

## Acceptance

Seven item/resource/loadout PNGs, two skill SVGs and one fallback asset are ready with complete source/output mapping. Light/dark/checkerboard review images show clean edges and consistent scale. At 24–44 px skill glyphs remain distinct; at 32–64 px item silhouettes remain recognizable.

## Stop

No live hotbar/operations integration or changes to P02's current assets.

## Completion note

Pending.
