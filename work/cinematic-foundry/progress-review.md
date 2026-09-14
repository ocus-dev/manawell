# Cinematic foundry progress review — 2026-09-12

Assessment: useful scaffold, not yet ready for a reliable visual comparison. Review only; foundry implementation was not changed.

## Findings / next work for Luna

1. **High: C02 still uses the old rendering language.** The copied backdrop API retains OVA cel shading, overcast lighting, no perspective floor and a machine clearing at x=640. Lane/dressing copies also retain OVA prompts. Apply the assignment's cinematic style, composition and warm/cool lighting blocks to BOTH UI and API workflows, with left-side drill framing. Verify pairs agree. The current copies will continue steering toward the old look.
2. **High: the comparison does not compare baseline against cinematic art.** cinematic_foundry.gd:_refresh_presentation switches use_prepared_layers. The shared environment draws the existing prepared background when true and debug geometry when false. Preserve today's prepared scene as baseline, then connect the approved cinematic candidate as the alternative. Until art is approved, label the alternative as a placeholder. Existing candidate images in art/side-view/cinematic-foundry/assets are not wired into this scene.
3. **Medium: shadow toggle is overridden every frame.** The harness sets shadow.visible from shadows_enabled, then contact_shadow.gd:_process sets visible=true again. Reproduced: disabled shadows still report visible=true. Give the shadow an enabled property and gate its processing/visibility; test after several frames.
4. **Medium: freeze does not freeze animation.** It only skips controller processing. AnimatedSprite2D children continue playing. Reproduced drill animation advancing from frame 2 to frame 5 while frozen. Pause actor animation and eventual particles without disabling experiment controls; resume their prior state.
5. **Medium: repeat seed is not repeatable.** scene_seed is assigned before start_run, which replaces the loot seed. Observed configured 20260912 versus runtime 701699755. F3 calls retry(), which returns immediately during an active run. Implement an explicit experiment reset from any phase and seed after runtime initialization; check repeated actor/loot state after a fixed simulation duration.
6. **Medium: shadows are hard-edged polygons.** Support placement is useful, but the assignment requested soft contact shadows. Use a feathered texture/shader or layered falloff and compare against the current ellipse at actual game size. Avoid allocating/recreating shadows repeatedly for dead actors still in the enemy list.
7. **Documentation/evidence:** C02 is workflow preparation, not complete. Reconcile candidate images now present with the README's generated-art-pending claim; add the candidate manifest and actor-scale composites. Add captures and performance results before C06 signoff. The current test does not cover presentation correctness, toggle persistence, freezing or deterministic reset.

## What works
- Isolated scene reuses the encounter controller and disables persistence.
- Existing platform-support shadow test passes, including platform/floor selection and enemy cleanup.
- Separate copied workflow files exist; the active renderer need not change.
- Current code retains the enlarged left-side drill and right-side arrivals.

## Status
- C01: partial; fix comparison, freeze and repeat controls.
- C02: partial; correct prompt variants and prepare traceable candidates for REVIEW A.
- C03: partial; support placement works, toggle and soft edges remain.
- C04/C05: not implemented in the inspected scene; appropriate to defer final assembly until REVIEW A.
- C06: not ready; reliable A/B and evidence are prerequisites.

Recommended order: correct workflow prompts; repair comparison controls/toggle/reset; produce two traceable composites for REVIEW A; then proceed to lighting and activity effects.

Verification: cinematic_foundry_test.gd passed. Additional runtime probe reproduced the toggle, freeze and seed defects. This review did not visually grade the candidate image files or run a performance benchmark.

## Correction follow-up
Prompt pairs, baseline selection/placeholder labeling, persistent shadow toggle, child-animation freeze and seeded scene reset have been corrected and regression checked. Dead actors are excluded before creating shadow nodes. Shadows now use feathered layered opacity; visual approval is still pending. Candidate inventory now explicitly records unknown provenance. Original findings above describe the reviewed pre-fix state. No cinematic candidate is approved or integrated, and C04-C06 remain future work.
