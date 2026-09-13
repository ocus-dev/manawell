# M05 — Build the responsive interactive act map

Approved background: `art/world-map/candidates/A_valley/master.png`; approved coordinates/paths: sibling `layout.json`. Verify against `work/world-map/design-review.md`. Never import `overlay.png` as scenery. The mock-state/multisize checks originally planned for M03 are now part of this card's UI review; art selection is already approved.

Depends on M04 and approved M03 assets. Import approved clean art plus its manifest/provenance into a dedicated runtime asset directory. Add a campaign map screen through the current presentation router. Map widgets read view state and emit node-ID commands; they never mutate saves or decide unlock rules.

Render paths and node markers separately over the image. Transform normalized coordinates using the actual contained-image rectangle, including letterboxing offsets; keep marker positions, path endpoints and hit regions aligned after resize. All nine nodes and the boss should fit the normal view. Optional zoom/pan must not be required for basic access. Do not scale entire controls with the source texture or use large cards over every location.

Use distinct well/combat/boss glyphs, a compact completion check, lock symbol, current selection outline, keyboard focus outline and restrained next-level emphasis. State must remain readable without color. Wells also show conquered/commissioned status and a compact producing/idle/active indicator sourced from production state; show exact rate/guard details in the single selected-level panel. Do not use zero income as evidence a well is unconquered.

Panel: level name/type, progress or lock reason, encounter objective, well details where relevant, and Start/Revisit action. Locked nodes can be inspected but cannot launch. Refresh indicators on terminal results, assignment changes, production changes and save load without rebuilding the entire screen each frame. Preserve selection by ID and choose a valid fallback after data changes.

Support mouse and keyboard navigation in route order, Enter/Space activation, clear focus, and tooltips/details on focus as well as hover. Use roughly 28–36 logical-pixel glyphs inside practical 44-pixel hit targets at baseline scale. Keep the existing compact UI philosophy; details should not cover the route. Adapt panel placement for smaller windows, respect current UI-scale/accessibility settings and existing minimum window limits.

Acceptance: screenshots at 1280×720, 1920×1080 and the supported minimum size show all nodes, readable statuses, no overlaps/clipping and correct hit testing. Tests verify resize transforms and command IDs; manually check keyboard traversal and live well-status refresh. Until M06 is complete, clearly disable unsupported launch actions rather than presenting fake gameplay.

Completion note: implemented. Added the approved clean map art to `prototype/assets/world_map/`, a responsive MAP page with separate route and node layers, contained-image coordinate transforms, semantic ID selection/focus commands, prerequisite/status details, derived well indicators, and explicitly disabled M06 routing. Acceptance coverage is in `prototype/tests/campaign_map_test.gd`; it passed at 1280x720, 1920x1080, and 720x540-style layouts. No overlay art or fake encounter launch was added.
