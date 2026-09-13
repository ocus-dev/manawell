# 2D conversion test matrix

Reconciled 2026-09-07. The frozen archive contains the complete 43-test pre-conversion suite. The active runner discovers 22 current 2D tests; all pass. The temporary copies formerly staged under `work/2d/deferred-tests/` were removed after this reconciliation. Their originals remain unchanged at `archive/prototype-3d/tests/`.

| Category | Existing tests | Responsible card |
|---|---|---|
| Reusable model/UI | `run_state_test`, `production_test`, `progression_2d_test`, `content_catalog_test`, `research_wallet_test`, `run_identity_credit_test`, `account_saves_test`, `session_persistence_test`, `persistence_2d_test`, `snapshot_codec_test`, `ui_view_state_test`, `combat_widgets_test`, `bootstrap_test` | 50-55, only where retained by the active 2D product scope |
| Spatial conversion | `movement_test`, `surge_2d_test`, `arena_movement_test`, `melee_enemy_test`, `auto_weapon_test`, `player_abilities_test`, `surges_ranged_test`, `single_scheduler_test` | 50-53 |
| Integration conversion | `checkpoint_retry_test`, `prototype_verification_test`, `guard_pointer_test`, `recovery_equivalence_test`, `suspend_resume_test` | 54-56 |
| Obsolete 3D-only | 30 archived fixtures listed below; each depends on removed 3D actors, transforms, or the pre-conversion controller surface. | 50-57 decision record |

## Reconciled legacy paths

The following original tests were staged temporarily at `work/2d/deferred-tests/`. They are now classified as obsolete 3D-only fixtures, not unresolved active tests. Each original remains preserved in `archive/prototype-3d/tests/`:

| Archived 3D fixture | 2D disposition | Owning card |
|---|---|---|
| `crew_assignments_test.gd`, `harvester_loadouts_test.gd`, `network_production_test.gd`, `offline_production_test.gd`, `two_wells_test.gd` | Replaced by `progression_2d_test.gd`, `production_test.gd`, and `persistence_2d_test.gd` | 54-55 |
| `checkpoint_retry_test.gd`, `domain_commands_test.gd`, `extraction_checkpoint_test.gd`, `feedback_onboarding_test.gd`, `guard_interaction_test.gd`, `notices_settings_test.gd`, `operations_preview_test.gd`, `settings_interaction_test.gd` | Replaced by `encounter_test.gd`, `persistence_2d_test.gd`, `operations_layout_test.gd`, `runtime_click_routing_test.gd`, and `presentation_2d_test.gd` | 51-56 |
| `component_snapshot_test.gd`, `recovery_equivalence_test.gd`, `snapshot_validation_identity_test.gd`, `suspend_resume_test.gd` | Replaced by `snapshot_codec_test.gd`, `persistence_2d_test.gd`, and `session_persistence_test.gd`; the archived recovery test's known baseline failure is not an active 2D failure | 53-55 |
| `upgrade_purchases_test.gd` | Replaced by `progression_2d_test.gd` and `weapons_abilities_2d_test.gd` | 52-54 |
| `encounter_hud_test.gd`, `expedition_panel_test.gd`, `hero_picker_test.gd`, `well_cards_test.gd` | Replaced by `operations_layout_test.gd`, `ui_view_state_test.gd`, and `presentation_2d_test.gd` | 51, 54-56 |
| `arena_movement_test.gd`, `melee_enemy_test.gd`, `auto_weapon_test.gd`, `player_abilities_test.gd`, `surges_ranged_test.gd`, `single_scheduler_test.gd`, `prototype_verification_test.gd`, `guard_pointer_test.gd` | Replaced by `movement_test.gd`, `surge_2d_test.gd`, `weapons_abilities_2d_test.gd`, and `runtime_click_routing_test.gd` | 50-53 |

Card 51 restored `encounter_test.gd`, `pause_results_test.gd`, and `runtime_click_routing_test.gd` to active discovery. All three pass against the 2D controller/HUD boundary.

Card 52 added `prototype/tests/surge_2d_test.gd` to active discovery. It replaces the 3D melee/ranged fixtures with continuing side-view pressure and late-tier coverage.

Card 53 added `prototype/tests/weapons_abilities_2d_test.gd` to active discovery. It replaces the archived 3D automatic-weapon and player-ability fixtures and owns current-position projectile dodging and Triple shot.

Card 54 added `prototype/tests/progression_2d_test.gd` to active discovery. It covers the in-memory two-well/two-hero journey, upgrades, guard assignment/recall, loadout modifiers, real damage configuration, active-well production exclusion, and HUD refresh purity. Persistence and offline settlement were subsequently covered by card 55.

Card 55 restored `account_saves_test.gd`, `session_persistence_test.gd`, and `snapshot_codec_test.gd`, and added `persistence_2d_test.gd`. The 3D actor recovery fixtures are historical only; current recovery is covered by the active 2D persistence tests.

Card 56 added `prototype/tests/presentation_2d_test.gd` to active discovery. It verifies single-HUD CanvasLayer ownership, operations/combat visibility transitions, director-derived next-spawn presentation, and pause overlay routing.

## Rules for conversion

- Preserve the archived 3D suite and its baseline results; do not rewrite it in place.
- Port pure model/UI assertions first, then replace 3D vector/collision assumptions with 2D ground-position assertions under cards 50-53.
- Convert integration tests only after the new 2D controller, input routing, and persistence decision are explicit under cards 54-56.
- S01-S03 experiment tests are a separate accepted reference suite and are not substitutes for this matrix.
- Any test removed from the active 2D suite must be listed with its replacement, responsible card, and reason in this matrix.

The archived 3D suite's pre-copy result is documented in `archive/README.md`: 44 tests were attempted, with `recovery_equivalence_test` failing due to its old 3D fixture. That result is preserved as baseline evidence and is not silently reported as an active pass. Native screenshots and interactive focus/input walkthroughs remain unverified; they are acceptance evidence, not headless test rows.
