# M03 — Present designs, then pause

**Current disposition: DONE — owner selected A from the M02 delivery.** See `design-review.md` for exact approved assets and scope. The instructions below preserve the original review plan; do not reopen its approval gate. Extra mock-state/multisize review work moves to M05/M07 and is not claimed as performed here.

Depends on M02. Build a review board in `art/world-map/review/` showing all candidates, their clean art, and deterministic nine-node route overlays. Show layouts at 1280×720 and 1920×1080; include one smaller-window preview. Use compact mock markers for locked, available, completed, selected, conquered well and terminal boss. Mark these explicitly as mock data, not functioning campaign UI.

Compare perceived regional scale, theme coherence, landmark readability, boss destination, route legibility, nine-node density and room for a compact selected-level panel. Include a short recommendation and specific tradeoffs, not a declaration that one is approved. Review backgrounds with all nodes visible; do not hide a poor layout behind zoom requirements.

Create `work/world-map/design-review.md` recording candidate IDs, image hashes, matching layout revision, feedback and `Design approval: PENDING`. Provide direct file links and ask the owner to choose/revise theme, composition and route. Feedback is authorization for the requested art iteration only. Preserve prior versions and update the board after changes.

**Mandatory stop:** do not start M04–M07, import maps into the live game, or implement campaign state before the owner explicitly approves a specific design. Record the owner's approval faithfully with the chosen candidate/hash/layout when received. Do not infer approval from silence or from completion of this card. This gate comes directly from the user's request to pause and iterate on designs.

Acceptance: review board and reproducible overlays delivered, open decisions identified, approval status accurate. A completed review-delivery card can still have pending design approval.

Completion note: Owner explicitly approved A (“lets go with A”) after receiving the three candidates. Recorded verified master/layout hashes and `A_valley-landmarks-02` in `design-review.md`. M04 may proceed with the approved candidate-specific layout. Additional mock-state board and multisize previews were not performed; M05/M07 retain those presentation checks. No runtime work was done to close this checkpoint.
