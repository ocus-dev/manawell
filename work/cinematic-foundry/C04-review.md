# C04 review and corrective path — 2026-09-12

C04 is an effects scaffold, not a completed lighting/visual slice. Review only: no runtime implementation changed in this review.

## Verified findings
- Both cinematic texture variables are null in the running scene. F1 uses the same prepared art in both modes. They are now ordinary variables, not exported inspector slots. No approved-art loading path is present.
- There are zero Light2D nodes. The reported light_count() counts configuration flags, not actual lights. Lamp and drill effects draw ordinary alpha-blended circles; they cannot illuminate sprite surfaces.
- Activity draws at z=0, drill at z=1, hero/enemies at z=2. Drill halo, steam and sparks are behind the drill. Hardcoded origins do not use the enlarged visual's exhaust/contact geometry. Steam rises only about 13-46 pixels over its lifetime and starts 148 pixels above ground, well within the 266-pixel-tall drill's vertical extent. This strongly limits visibility through the drill silhouette.
- Three lamp positions are fixed coordinates, unrelated to actual lamp fixtures. Yellow circles therefore look like arbitrary spots.
- Multi-projectile attacks bypass the overridden single-projectile method. Runtime probe: volley creates zero flashes; single shot creates one. Use a shared shot/volley event and emit one flash per firing action.
- Steam opacity is at most 0.12, dust is a 3-pixel circle, sparks are 2-pixel circles lasting 0.12-0.28 seconds. These settings compound the occlusion issue. Turning everything brighter will not solve incorrect placement.
- Shadows remain enabled in both presentations, so F1 is not an all-effects-off comparison. Document the comparison contract and separate environment-only / effects-only / full views.
- Particle randomness uses global randf(), not a seeded per-experiment generator. Restart also drops texture assignments and effect configuration. Repeatability remains incomplete for C04 despite the loot-seed checks.
- Tests count flags and injected particles; they do not establish light response or visible effect placement. New runtime probe is work/reviews/cinematic-c04-probe.gd.

## Animations
The animation itself is not the blocker. Its opaque pixels cover effects drawn behind it. Baked painted shading limits how convincingly a flat sprite can respond to dynamic illumination, but does not prevent visible steam, sparks, contact shadows or ordinary 2D lighting. Keep the current animation and ground calibration. Do not regenerate animation/normal-map libraries at this stage.

## Corrective sequence
1. Fix one drill close-up first. Hide experiment controls for evaluation. Add authored exhaust, drill contact and lamp/muzzle markers tied to the ground-anchored visual, with scale-aware positions. Debug markers may be shown only in the experiment.
2. Split effects into deliberate rear and front layers. Put visible steam at the exhaust, sparks at contact and dust along the deck; avoid a blanket foreground overlay. Use textured/feathered puffs and short spark streaks. Calibrate against idle, active and frozen frames.
3. Add one real, restrained drill PointLight2D with receiver masks excluding HUD. Compare off/on on a neutral static deck patch and existing drill animation. Keep soft additive halos as a separate visible glow effect. Place lamp halos only at authored fixtures; omit fixtures absent from the art.
4. Hook muzzle flashes into both single and multi-projectile firing, one flash per shot action. Preserve source facing and actual muzzle anchors.
5. Restore texture assignment/loading and preserve it, toggles and local particle RNG on restart. Clearly label unapproved artwork. Select/derive coherent background and deck layers at REVIEW A; do not expect particles to create the reference's monumental scale or material richness.
6. Capture matching baseline, environment-only, effects-only and combined views at actual game size. Verify per-effect screenshots, busy combat, loot readability, pause, restart and performance. Gate completion on a visible difference and correct attachment, not node/array counts.

Recommended next deliverable: one convincing drill with grounded contact shadow, attached exhaust steam, contact sparks/dust and a light that visibly affects nearby surfaces. Approve this before multiplying lamps or adding full-scene effects. Static normal/specular trials remain optional later work.
