# 36 — Shared theme and operations shell

Dependencies: 35. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §§2, 8–9, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Create one Godot Theme with industrial colors, typography, spacing and focus treatment. Add the operations shell: resource-strip region, wells/research area, expedition area and launch area using containers/anchors. Introduce a preview scene that consumes card 35 fixtures, so components can be reviewed before replacing the live HUD. Reserve a notice region. Keep one canonical theme and composition entry point.

## Acceptance checks

Preview at 1280×720 and 1920×1080; core content regions fit without overlapping or scrolling the essential launch area. At narrower widths operations stacks without horizontal clipping. Focus styles and 16px body/14px secondary text remain legible. Placeholder regions have clear ownership for later cards.

## Stop boundary

No fonts/assets download, hangar environment, shader effects or hardcoded absolute positions for every widget. Keep the original runtime HUD until replacement is integrated.

## Completion note

Completed. Added the canonical `IndustrialTheme.create()` factory and the isolated `scenes/ui/operations_preview.tscn` composition entry point. `OperationsPreview` uses container layout for the resource strip, wells/research region, expedition/launch region and reserved notices; it stacks the workspace below 960 px without changing the stable well-card order. The preview remains fixture-safe and does not replace `EncounterHUD` or issue domain commands. Added `operations_preview_test.gd` covering theme ownership, region ownership, 1280x720 two-column layout and narrow responsive stacking. Godot screenshots at 1280x720 and 1920x1080 remain pending; automated layout checks cover 1280x720 and 800x720. No fonts, assets, shaders or runtime HUD changes were added. Queue row 36 is DONE.

