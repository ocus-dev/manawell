# P01 — Compact health, pressure, and extraction HUD

Dependency: Current completed visual slice. Status tracked in work/platforming/README.md.

## Implement

Read combat_preview.gd, survival_widget.gd, pressure_widget.gd, extraction_widget.gd, ui_view_state.gd, the startup-layout repair and current presentation tests.
Replace large combat panels with the queue's compact layout. Keep hero HP and machine integrity distinct with small identifying glyphs and thin bars. Use short current/max values or hover details; no repeated headings or explanatory paragraphs. Show surge tier, a thin pressure/progress strip and one next-surge countdown. Extracted tank value, harvest action, and unsafe sealing countdown must remain unmistakable. Move wallet/passive-production detail to pause/operations, keeping the existing account model untouched.
Use combat-local styles so shrinking combat does not accidentally shrink operations, settings, modals or results. Use anchored/container sizing in logical pixels, not whole-HUD scale reduction. Keep command/view-state ownership and pause control. Record before/after widget bounds and screenshots.

## Acceptance

At 1280×720 and 1920×1080, static combat widgets fit the queue's reserved bands and do not cover the playable area. Long values, low HP, high surge number, sealing, pause and results do not overflow. Health and machine integrity remain distinguishable without color alone. Existing start/harvest/phase semantics and startup layout tests pass.

## Stop boundary

No ability redesign yet, platforming, balance changes or operations-screen redesign.

## Completion note

DONE. Compact combat-local survival, pressure, extraction, and pause controls in `prototype/scripts/ui/{survival_widget.gd,pressure_widget.gd,extraction_widget.gd,combat_preview.gd}`. Wallet and passive-rate labels no longer render during combat; account and view-state data remain unchanged. Before bounds were Survival 250x132, Pressure 280x110, Extraction 300x126, Wallet 276x68 minimums. Measured after bounds at 1280x720 were Survival 293x56, Pressure 250x58, Extraction 300x60, Pause 102x51; all stayed inside the reserved bands. The focused test now records bounds and native screenshots at `work/reviews/combat-hud-1280.png` and `work/reviews/combat-hud-1920.png`. Passed `combat_widgets_test.gd`, `presentation_2d_test.gd`, and `operations_layout_test.gd`; the full runner passed 24 tests except the pre-existing `progression_2d_test.gd` timeout, which also timed out at 90 seconds in isolation. No ability, platforming, balance, operations, or results redesign was performed.

