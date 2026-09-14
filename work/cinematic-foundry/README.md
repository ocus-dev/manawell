# Cinematic foundry experiment — Luna assignments

Status: C04 drill-first lighting pass in progress; C02 art review still pending. Do not replace the active game's art or renderer.

Current checkpoint: `prototype/scenes/experiments/cinematic_foundry.tscn` attaches one restrained drill `PointLight2D`, authored exhaust/contact/lamp markers, front/rear steam and contact sparks, and a shared muzzle flash for single shots and volleys. F1 cycles baseline / environment-only / effects-only / full. C02 generated art remains unapproved, so environment comparison still uses the prepared baseline rather than substituting debug geometry.

## Objective
Build one isolated playable comparison scene that tests whether richer environments, grounded actors and restrained lighting deliver the reference's industrial scale while preserving combat readability. Keep the existing animated actors initially. Preserve the current left-edge drill (40% enlarged), right-only enemy arrivals, platforming, actor ground anchors and gameplay balance.

## Ownership and sequence
Luna owns scene assembly, configurable effects, workflow copies and technical verification. User/art operator runs generation if Luna lacks access to the existing ComfyUI service and chooses the preferred candidate. Lead review owns visual direction, tradeoffs and approval to integrate.

Graph: C01 -> C02 -> REVIEW A -> C03 -> C04 -> C06 -> REVIEW B.
C05 is optional after C04 and may be omitted if cost exceeds visible benefit. C02 workflow preparation and C03 reusable shadow implementation can proceed independently after C01, but final composition waits for REVIEW A.

Commit or checkpoint each assignment separately. Record changed files, how to launch, verification performed, screenshots and remaining limitations. Do not mark generated art complete if only prompts were prepared.

## C01 — Isolated comparison scene
Deliver prototype/scenes/experiments/cinematic_foundry.tscn and supporting scripts under prototype/scripts/experiments/cinematic_foundry/.
- Inspect the current encounter controller, side_view_environment_visual.gd, side_view_actor_visual.gd, side_view_visual_config.gd and data/arena_layout.gd first.
- Reuse existing actors and combat behavior through a small presentation hook or test harness; do not fork the entire encounter controller.
- Use a disposable account with persistence disabled. Do not change the default main scene.
- Include baseline/cinematic comparison, effects toggles and a repeatable scene seed. Switching presentation must preserve actor positions and combat state.
- Provide a freeze-frame control and representative idle, walking, jumping and combat moments. Keep experiment controls small and hideable for captures.
- Retain Compatibility rendering. Verify any chosen effect on the project's actual Godot version.
Acceptance: Both views run with identical gameplay, existing animations remain grounded, and no account save is written.

## C02 — Environment workflow variant and candidates
Read work/visual-slice/V04-environment-workflows.md and the existing 07_environment_backdrop, 08_environment_lane and 09_environment_dressing workflows under art/side-view/workflows/.
Copy the relevant workflows to art/side-view/cinematic-foundry/workflows/. Preserve originals and their API/UI pairs. Preserve compatible node wiring and model choices; change prompt blocks and output destinations first.

Shared style prompt:
Cinematic industrial science-fiction game artwork with tactile, realistically shaded materials and restrained painterly character. Weathered painted steel, brushed metal, heavy concrete, rubber seals and chipped maintenance markings. Clear large silhouettes, fine detail concentrated around functional mechanisms. Directional daylight, cool atmospheric fill, convincing material highlights and deep structural crevices. Preserve readability at gameplay scale.

Composition prompt:
Wide side-scrolling game environment viewed from a level camera. A narrow playable industrial service deck runs horizontally across the foreground, with a shallow visible top surface. Monumental refinery towers, interconnected pipes and elevated gantries occupy the middle distance; mountains and distant facilities recede through atmospheric haze. Strong separation between foreground, gameplay plane and background. Keep the character movement band uncluttered. No characters, HUD, labels or interface.

Lighting prompt:
Warm directional sunlight from the upper left, cool blue-grey skylight in shadow, restrained amber maintenance lights. Bright metallic edge highlights, soft atmospheric distance and dark contact crevices. Subtle damp patches and broken reflections on the deck. Preserve detail in shadows; avoid uniform darkness, excessive bloom and bright clutter behind characters.

Layer requirements:
- Distant sky/mountains; midground refinery; playable deck; sparse foreground dressing. Generate a coherent approved master first, then derive aligned layers; independent unreferenced generations are likely to disagree.
- Maintain the current ground/support coordinates. Shallow depicted perspective must not imply a different walkable surface.
- Deck and foreground need clean transparency where appropriate. No baked actor shadows, actors, lettering or HUD.
- Foreground must not cover enemies, pickups, ground edges or the left-side drill.
- Record source workflow, prompt, seed, dimensions, crop, ground line and source/output paths in a manifest.

Produce at most two initial candidates: A brighter daylight/readability-first; B slightly stronger atmosphere/material contrast. Make comparison composites with existing actors at actual gameplay size, including the enlarged drill. If generation is unavailable, deliver runnable workflow copies and exact operator instructions, then report that dependency rather than substituting unrelated artwork.

REVIEW A: User chooses the environment direction or requests revisions. Stop further art generation here. Technical shadow work can continue independently.

## C03 — Grounding and contact shadows
Add reusable soft shadow visuals beneath hero, enemies and drill in the experiment.
- Locate the actual support under each actor using arena/platform support data; never assume every actor stands on the main ground line.
- Grounded shadows meet the feet. Airborne shadows stay on the support below, becoming smaller and lighter with altitude; hide when no valid support exists.
- Follow dash/movement, sprite facing and scale without changing collision or animation pivots. Keep shadows below actors and above the supporting surface.
- Prefer a reusable soft texture or simple shader over extra full-screen effects. Expose opacity, width and height falloff in one visual configuration.
Acceptance: Check idle, run, jump apex, landing, platform edges, death/removal and the enlarged drill. No floating shadows or detached feet. No collision changes.

## C04 — Lighting and machine activity
Assemble the chosen layers and add effects incrementally with independent toggles.
- Small amber lamp halos, a restrained drill activity light and brief muzzle flashes.
- Light masks must exclude HUD and avoid washing out the entire background. Existing sprites already contain shading; compare gentle illumination against halos only.
- Steam near exhaust, dust at drill contact and sparse sparks tied to activity. Stop or reduce effects when the machine is inactive; respect pause and cleanup.
- Keep ground hazards, loot rarity cues, projectile silhouettes and health indicators readable during the busiest wave.
- Layer separation is required; parallax is optional and only meaningful if the camera moves. Do not introduce camera drift or change gameplay framing just to demonstrate it.
- Expose intensity, particle density and effect toggles in one configuration. Avoid renderer migration and full-screen bloom as prerequisites.
Acceptance: Screenshot each effect independently and combined. Pausing freezes activity; restarting does not accumulate particles, lights or nodes.

## C05 — Optional static material response
Only after C04, trial one deck or machine surface with a matching normal/specular resource using APIs supported by the installed engine.
- Keep it behind a toggle and compare at gameplay size under the same local light.
- Do not generate normal maps for the actor animation library.
- Do not interpret luminance-to-normal conversion as recovered geometry. Check bevels, seams and highlight direction for obvious errors.
Acceptance: Keep only if the improvement is visible and convincing. Document a rejected experiment rather than retaining it to satisfy the task.

## C06 — Evidence and recommendation
Deliver work/cinematic-foundry/review.md plus comparison captures under work/reviews/cinematic-foundry/.
- Same camera, actor positions and simulation moment for baseline, environment-only, shadows, full effects and optional materials.
- Inspect at 1024x576, 1280x720 and 1920x1080. Judge screenshots at native presentation size, not just zoomed detail.
- Include the drill at the left edge, hero airborne over a platform, a dense right-side attack, and item drops on the deck.
- Record hardware, renderer, resolution, frame time and node/particle/light counts for baseline and cinematic versions under the same repeatable load. Separate first-load warmup from steady-state cost; report unavailable measurements honestly.
- Check actor readability, apparent scale, grounding, motion consistency, effect clutter and material quality. Recommend which individual effects to keep.
- Verify the normal main scene, map, inventory, settings and save flow remain unaffected.

REVIEW B: Present the visual comparison and recommendation. Wait for user selection before integrating into the active game or regenerating actors.

## Deferred actor-style decision
Only if REVIEW B shows the existing actors are the remaining mismatch, propose a separate sprite/animation assignment. Retain strict framing and animation calibration; trial one hero idle/run pair before a library-wide change.
Suggested style addition: Preserve the reference design, proportions and side-facing silhouette. Realistically shaded painted metal or organic shell, restrained outlines, readable material highlights, soft upper-left key light and cool ambient fill. Neutral background for extraction. No ground shadow, scenery, particles or camera movement.
Keep baked actor lighting gentle because facing flips can reverse it.

## Corrective verification
The foundry regression now checks multi-frame shadow disabling, frozen animation frame/progress, prepared baseline preservation, and repeat reset seed/position/spawn-index behavior. The original support-placement checks remain. Soft edges use layered opacity, pending visual review at actual game size. Lighting, final material response, candidate selection, visual captures and performance acceptance remain outstanding; see the workflow handoff for the unreviewed candidate inventory.
