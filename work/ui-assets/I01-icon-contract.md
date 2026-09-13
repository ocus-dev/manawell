# I01 — Define the UI icon library contract

Read this queue, the current ContentCatalog/Loadout definitions, P02's icon-hotbar specification, current visual bible, and existing asset manifests. Keep the live UI untouched.

## Implement

Create art/ui-assets/README.md and a machine-readable source manifest defining exactly the first batch in the queue, their semantic keys, visual descriptions, display targets and expected pipeline. Distinguish asset identity from localized labels and current keyboard bindings.

Create a concise consumer contract for a future read-only icon lookup under prototype/scripts/ui_assets/: namespaced key → texture path, kind and display metadata; missing keys → fallback.unknown. No account mutation, input handling, control sizing, cooldown logic or gameplay rules in this lookup. I03 fills prepared paths; don't invent existing outputs.

Specify prompt blocks for item world/material/render/composition/subject and the simpler skill SVG geometry rules. Set review criteria: silhouette readable at minimum size, enough negative space, no text/frame, distinguishable without color, consistent lighting/optical mass. Record file ownership and the I05 integration prerequisites in the handoff.

## Acceptance

All current first-batch concepts have stable mappings and no new gameplay IDs. Source references exist. The contract can be consumed by P02's finished hotbar without changing its input/cooldown ownership. No live runtime or shared-pipeline files edited.

## Stop

No generation or UI integration yet.

## Completion note

Pending.
