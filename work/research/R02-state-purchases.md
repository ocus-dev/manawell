# R02 — Persistent ranks, legal purchases and specialization selection

Depends on R01. Extend current account/save ownership, using research ranks and equipped harvester/weapon mode IDs. Keep unlocked research separate from equipped choices. Always permit free selection of Standard outside an active/suspended run. Unlocked Fan uses the current Splitter rank; Lance and Fan never combine.

Controller purchase commands carry research ID and expected current rank. Revalidate cost, balance, prerequisites, cap and session phase atomically, then increment one rank and debit once. Stale/double-click commands must not accidentally buy the next rank. Persist using existing dirty/retry semantics without replaying spending. Do not mutate state from UI widgets.

Map legacy boolean purchases according to the index, preserving bank/campaign/wells. Remove double-application of old checks as later behavior cards integrate; provide a narrow compatibility adapter if necessary to keep the project runnable between cards. Validate rank integer types, finite bounds, known IDs, legal prerequisites and equipped unlocks on load. Document schema version behavior and handling of incompatible active snapshots; never silently reset the real profile.

Acceptance tests: valid purchase, insufficient funds, prerequisite/cap failures, stale expected rank, repeated command, save-write retry, save/reload, legacy mapping, corrupt rank/equipment data, free mode switch and active/suspended restrictions. Completion note: account ranks, atomic purchases, equipment, persistence, and legacy migration implemented; focused purchase command passes.
