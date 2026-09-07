# 30 — UI-independent commands

Status: tracked in work/architecture/README.md. Dependencies: 29.
Review coverage: Finding 6 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: controller selection/purchase/assignment handlers; session coordinator; tests. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Provide explicit commands accepting well, hero, upgrade and loadout IDs rather than widget indices. Enforce phase, unlock, affordability and assignment legality at this boundary. Route all mutations through the existing session transaction path. Keep thin UI adapters temporarily. Use concrete model types where possible without unrelated typing churn.

## Acceptance checks

Call commands directly without creating HUD widgets. Invalid IDs/phases cause no mutation or writes. Valid commands update the correct selection/assignment and settle old rates. Disabled buttons are no longer the only protection against illegal actions.

## Stop boundary

Do not extract or redesign the HUD yet. Avoid duplicating account rules in both UI adapters and commands.

## Completion note

Added ID-based controller commands: `select_well_by_id`, `select_loadout_by_id`, `select_active_hero_by_id`, `assign_guard_by_id`, and `recall_guard_by_well_id`. Existing widget-index handlers are thin adapters, while account legality, phase checks, production settlement, and session saves remain at the command boundary. Added `domain_commands_test.gd`, which calls commands on an unattached controller without HUD widgets and verifies valid mutations plus invalid IDs/phases. Focused command, upgrade, loadout, assignment, and full-suite checks passed. Remaining limitation: keyboard encounter actions still use the existing controller command methods directly because they already carry semantic intent rather than widget indices.

