# Act 1 map — approved design handoff

Design approval: **APPROVED**.

Owner decision: “Okay looks great, - lets go with A”. This approves candidate A as the implementation baseline; no further art-selection confirmation is required.

- Candidate: `A_valley` / Broken Foundry inland valley.
- Clean runtime source: `art/world-map/candidates/A_valley/master.png` (2048×1152).
- Master SHA256: `5158e37c9649ef7cbadae12d25768ba348030dcdad5d0c113885398abdebfec2`.
- Authored layout: `art/world-map/candidates/A_valley/layout.json`.
- Layout revision: `A_valley-landmarks-02`.
- Layout SHA256: `5a480c2ed2607f8750a607cf80d873b59c9d986d79c0eaa531579542c31ed3b5`.
- Review evidence: `art/world-map/candidates/A_valley/overlay-1280.png`, full-size `overlay.png`, and `art/world-map/candidate-contact-sheet.png`.

Use this candidate's layout, **not** the original generic `act_01.draft.json` coordinates. Preserve all nine node IDs and the 3 well / 5 monster / 1 terminal boss sequence. Import clean art only; the overlay's lines, numbered shapes and labels are review aids, not a finished UI texture.

M01/M02 generated and inspected the three alternatives; the owner selected A from that delivery. Close M03's art-choice gate on this evidence. The originally planned extra mock-state board and smaller/larger-window previews were not performed; carry those UI checks into M05/M07 rather than claiming them complete or delaying the accepted art selection.

Historical generation receipts still say `design_approved: false` because they describe the pre-approval take. Preserve those receipts and asset hashes; this document is the current approval authority. B/C remain archived alternatives and must not be regenerated or substituted during Luna implementation.

Next: M04 campaign data/progression, then M05 map presentation, M06 real encounter routing, M07 acceptance. Shared-file coordination still applies. Routine marker placement, route rendering and compact UI refinements can proceed within the approved composition; major geography changes require a new design discussion. No new ComfyUI work is needed for M04–M07.
