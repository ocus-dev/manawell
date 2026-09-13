# M07 — Verify the complete act journey

Depends on M06. Use an isolated test profile; never clear the owner's real save. Run relevant state, persistence, production, controller and UI regression checks using the repository's current runner. Test fixtures may accelerate encounters, but a scripted fixture is not evidence of a manual gameplay pass.

Verify a fresh Act 1 has exactly nine nodes (3 well / 5 monster / 1 boss) and the intended first availability. Traverse the complete route, commission all three wells, clear five combat-only levels and defeat the boss. Confirm meaningful lock reasons, immediate unlock indicators, and completed-act behavior with and without a next authored act. Revisit an early combat level and conquered well after reaching the boss; progression must remain intact.

Check guarded/unguarded/active wells, real rates, assignment changes, failure, abandonment, duplicate completion delivery, save/reload, supported suspend/resume and failed-save retry. No duplicate first-clear rewards or passive-income double counting. Verify monster-only levels require no machine or sealing interaction.

Manually check startup navigation, return from every encounter type, mouse/focus hit regions, keyboard use, tooltips, compact selection panel, runtime resize, UI scaling and readable status without color. Capture normal-size screenshots showing fresh, partial and completed progress at baseline and larger/minimum supported sizes. Inspect that art still conveys regional scale rather than being hidden under controls.

Write `work/world-map/acceptance.md` with exact commands, screenshots, approved art identity, actual passes/failures and unperformed checks. Document how to add another themed act through the generation workflow and manifest. Update current work/spec/contracts narrowly to reflect implemented behavior and the new nine-node structure; preserve historical completion notes. Stop when verified or report the exact unresolved blocker without claiming completion.

Completion note: pending.
