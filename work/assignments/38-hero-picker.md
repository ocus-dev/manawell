# 38 — Guard and expedition hero pickers

Dependencies: 37. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §§3–4; §8 modal rules, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Create a reusable HeroPicker with guard and expedition modes. Show availability reasons, current assignments and guard traits. Guard mode offers reserve heroes, current guard plus Recall, and visible disabled active/other-site heroes. Expedition mode allows current/reserve selection and disables guarded heroes. Emit ID-based commands through the established adapter. Recall updates the open picker; replacing a guard is explicit Recall then Assign. Add empty/no-reserve states, cancel, focus ownership and opener focus restoration.

## Acceptance checks

Assign reserve hero to the requested well; active hero cannot become guard through this picker. Change expedition hero returns old hero to reserve using existing command semantics. Guarding another well remains unavailable until explicitly recalled. Cancel has no effect; repeated activation cannot double-assign or double-settle. Command rejection and failed-save state are displayed honestly. Enter/E/Space cannot fall through from the modal into gameplay.

## Stop boundary

No implicit transfer, drag-and-drop, recruitment or atomic multi-site swap. Do not calculate projected income locally; use a domain selector or omit the optional preview.

## Completion note

Completed. Added reusable `HeroPicker` under `prototype/scripts/ui/` with explicit guard and expedition modes. It renders initials, current assignment, availability reasons, disabled active/other-site heroes, current-guard Recall, reserve selection, no-reserve messaging, Cancel, Escape, opener focus restoration and ID-based `hero_selected(hero_id, mode, well_id)` / `guard_recall_requested(well_id)` signals. `OperationsPreview` opens guard mode from each well card and forwards intents without mutating account state or calculating rates. Recall updates the open list in place; selection does not emit cancellation. Added `hero_picker_test.gd`; full suite: 35 tests passed. Domain command result/save-failure presentation remains with the downstream session adapter because this preview has no mutation boundary yet. Manual keyboard/mouse walkthrough and screenshots remain pending. Queue row 38 is DONE.

