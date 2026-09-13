# Animation grounding repair — 2026-09-08

Runtime fix in `prototype/scripts/game/side_view_actor_visual.gd` and actor calibration in `side_view_visual_config.gd`:

- Removed per-frame alpha-box grounding, including the incorrect top+bottom interpretation of LTRB bounds. Natural authored pose movement stays intact.
- One source-reference height/ground anchor per actor across idle/walk/attack, independent of each clip's union crop. Hero reference scale is 80/416; first-frame height differs by at most one source pixel across clips instead of shrinking to 75 pixels on attack.
- Immutable transforms: every facing/multiplier update recalculates scale and position around the shared pivot, including x offsets for asymmetric crops. Repeated updates cannot accumulate scale.
- Static sprites use the same pivot math. Reconfiguration clears old clip state without duplicate signals; missing walk/idle clips fall back to the available animation/static sprite.
- Harvester calibrated from its actual source reference (557 high, pivot 384,638), replacing the erroneous inherited 288,495 pivot.

Exporter accepts `package --reference-height` to share calibration across future standalone clip exports. Runtime deliberately ignores old clip-fitting recommended scales. No atlas/source images, movement/collision code, research or UI implementation was changed.

Verification: `prototype/run_tests.ps1` with `-TestFilter animation_anchor` and `-TestFilter side_view_visual` passed. New regression covers all imported actors and clips, every frame, both facings, multipliers 1/1.25/0.75, thirty repeated facing updates, reference feet/heights, pivot invariance and repeated reconfiguration. Six Python animation pipeline tests passed, including an attack with a taller silhouette retaining reference scale.

Broader `jump_controller` test failed from a parse error in `prototype/scripts/ui/ui_view_state.gd:122` (cannot infer `available`), followed by dependent UI initialization errors. Movement checks themselves printed their pass message; the suite is not reported as passing. This unrelated shared UI work was not edited. No full live-game visual playtest was completed in this repair.

Residual source motion: hero idle/attack bottoms vary by one source pixel; walk varies by nine (about 1.7 screen pixels at base scale), consistent with authored foot motion. This is preserved rather than erased through per-frame snapping. Re-render/review clips if that motion is artistically undesirable.
