# 47 — Repair assignment states and existing UI actions

Depends on 46. Track status in work/interface/README.md.

## Read

Read the gap report, design/Interface.md sections 2–3 and 7–8, and the current resource strip, EncounterHUD, WellCard, HeroSlot, HeroPicker and domain-command adapter.

## Implement

- Connect the operations Settings button through a typed signal to the existing settings flow. Restore opener focus on close. Do not duplicate settings controls.
- Render guard-slot states correctly: lock/explanation for locked wells; commissioning requirement for uncommissioned wells; an actual clickable + Assign guard slot only for commissioned empty wells; portrait/name for assigned guards. Label the active operator separately. Essential reasons must be visible, not only tooltips. Preserve an explicit Recall action.
- Make the slot's intended clickable surface, not just a small neighboring button, open the picker. No implicit transfer or swap between assignments.
- After Assign/Recall, refresh picker state from the authoritative command/view result. Do not mutate a copied hero dictionary to pretend success. Stay open with a clear reason on rejection; display pending-save semantics from the session layer. Recall updates the picker in place. Close after a successful assign if appropriate and restore focus safely.
- Verify existing modal routing prevents background clicks and E/Space from triggering gameplay. Make only targeted corrections if broken; do not add another parallel input consumer.

## Checks

Real button events open operations Settings. Cancel leaves state intact. Locked/uncommissioned slots cannot request assignment. A commissioned + opens the right well. Assign, recall, rejected action and save-pending responses reflect actual state; double click cannot emit duplicate mutations. While a picker is open, background Start cannot launch and E/Space do not leak into combat. Focus returns to a surviving opener after close. Repeated state refresh preserves relevant focus.

Test fresh, guarded, no-reserve and rejected-command fixtures through the reliable runner. Record actual manual interaction checks separately. No real profile reset.

## Stop

No changes to role eligibility, automatic reassignment, persistence policy, balance or recruitment. Do not hide unavailable heroes to bypass the empty-state requirement.

## Completion

Completed 2026-09-06. Updated `resource_strip.gd`, `operations_preview.gd`, `encounter_hud.gd`, `well_card.gd`, `hero_slot.gd`, `hero_picker.gd`, and focused UI tests. Settings now uses the existing modal flow; guard slots expose locked, uncommissioned, empty, assigned, and active states; whole-slot activation is gated by commissioning; picker assignment and recall reconcile from refreshed authoritative state and suppress duplicate pending actions. Picker, well-card, runtime-routing, settings, diagnostics, and whitespace checks passed. The existing operations bounds test still reports its pre-existing requirement that the complete scrollable workspace fit within 1280x720; the stage-46 audit records the workspace and Start button below that viewport by design. Manual visual and pointer verification remains for assignment 48.
