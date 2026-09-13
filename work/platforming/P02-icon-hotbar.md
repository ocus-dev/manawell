# P02 — Icon-only skill hotbar

Dependency: P01. Status tracked in work/platforming/README.md.

## Implement

Read ability_bar.gd, UI view-state, input routing, settings, and ability tests.
Replace skill text buttons with locally authored SVG or procedural icons: a dash chevron and pulse ring. Use 40–44 px square targets, a small key badge and a cooldown sweep/dim overlay; show compact remaining seconds only while cooling down. No permanent skill name, ready text or descriptions. Hover and keyboard focus reveal name, current key and description. Keep focus outlines, click activation, disabled states and existing command IDs. Do not fetch/generated-download icon packs or call ComfyUI for these simple symbols.
Bind badges to a shared action-label source rather than hard-coded strings. Until P04 changes controls, show the actual current dash binding (Space). Do not silently relabel it Shift before the input mapping changes. Jump will be movement, not an extra skill slot.

## Acceptance

Icons and key badges remain legible at actual game scale. Ready/cooldown/paused/unavailable states are distinct and consistent with the controller. Click and hotkey each produce one command; tooltips/focus do not leak inputs into gameplay. No words expand slots during cooldown or state refresh.

## Stop boundary

No new skills, input rebinding screen, cooldown changes or platforming.

## Completion note

DONE. Replaced text ability buttons in `prototype/scripts/ui/ability_bar.gd` with fixed 44 px procedural `AbilitySlot` controls in `prototype/scripts/ui/ability_slot.gd`. Dash uses a chevron and pulse uses a ring; slots keep stable dimensions, focus outlines, click signals, disabled states, cooldown dim/sweep overlays, and remaining seconds only while cooling down. `prototype/scripts/ui/action_labels.gd` derives badges and tooltip bindings from `InputMap`, so current pre-P04 bindings display as Space and Q without relabeling controls. Tooltips expose each name, binding, and description. Expanded `prototype/tests/combat_widgets_test.gd` verifies icon-only text, target size, badges, tooltip metadata, cooldown labels, and click IDs. Native captures were refreshed at `work/reviews/combat-hud-1280.png` and `work/reviews/combat-hud-1920.png`. Passed combat, weapons/abilities, presentation, operations layout, pause/results, and view-state tests; diagnostics are clean. The known unrelated `progression_2d_test.gd` full-suite timeout remains. No new skills, rebinding UI, cooldown values, platforming, or balance changes.

