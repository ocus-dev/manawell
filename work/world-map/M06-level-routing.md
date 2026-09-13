# M06 — Connect Start/Revisit to real encounter outcomes

Depends on M05; serialize with active controller/combat work. Inspect current side-view/platforming behavior before editing. Add a level-ID launch command which revalidates unlocks and current session phase even if called outside the map UI. Preserve selected act/node across return, restart and supported suspend/resume.

Dispatch by authored encounter type, not by invented well IDs:

- **Well:** existing extraction/commissioning flow for its unique real well; retain loadout, guard and active-production exclusion behavior.
- **Monster-only:** finite authored waves or enemies with an explicit clear objective. No harvester defense, extraction/sealing requirement, well commissioning or passive-income site. Reuse existing enemy/combat components and define five lightweight configurations with different compositions/layout choices; no new enemy families required.
- **Boss:** one named prototype act boss with visible boss health and a distinct telegraphed attack using existing systems/assets where possible. Completion requires actual boss defeat and player survival under the existing terminal ordering. No automatic win, normal-wave relabel or hidden developer completion button. A polished boss animation pack and later-act bosses are outside this card.

If current encounter architecture assumes every run is extraction, introduce the smallest encounter-objective adapter needed. Preserve common fixed-step combat and account terminal commits; do not fork the entire controller for every level. Author encounter durations/waves, boss parameters and first-clear/replay reward policy centrally and document provisional balance. All nine nodes must have working encounter definitions; repeated art is acceptable, dead-end placeholder nodes are not.

Success returns to the map with completion and next unlock immediately visible. Failure permits retry or map return without progression. Revisit runs preserve completed status, support normal valid rewards once, and cannot duplicate first-clear rewards. Block starting another node during a live/suspended run until existing resume/abandon flow resolves it. A monster/boss run must not suspend an unrelated well's passive income through a dummy active-well ID.

Acceptance: exercise all three encounter types and launch validation. Test duplicate terminal events, boss death/player-death tie, failed commission, replay reward rules, active-run blocking, and resume identity. Provide a brief playable first-act walkthrough with real results; do not label a mock route as implemented.

Completion note: implemented in the prototype controller.

Implementation notes:

- Campaign activation now validates the current run phase, campaign node status, authored node type and account prerequisites before launch.
- Well nodes use the existing extraction and commissioning path. Monster nodes use five authored finite-wave configurations. The boss node uses a named boss configuration with a dedicated health pool and timed warning attack.
- Monster and boss runs keep `selected_well_id` empty, so they do not exclude a commissioned well from passive production.
- Active snapshots carry act/node identity, objective configuration, wave progress and boss timing; mismatched or incomplete objective snapshots are rejected.
- Start/Revisit is enabled for available and completed nodes and remains disabled for locked nodes.

Verified with the headless Godot project boot, `campaign_state_test.gd`, and `campaign_map_test.gd`. The broader acceptance matrix listed above still needs dedicated M06 coverage before this card can be considered fully closed.
