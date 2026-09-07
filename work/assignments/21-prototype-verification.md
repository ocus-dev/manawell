# 21 — Final prototype verification

Dependencies: 20. Status is tracked in ../README.md.

## Read first

Backlog handoffs, prototype README and prior playtest report. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Deliver a reproducible, honest prototype handoff.

## Implement

Run the established tests and a fresh-profile end-to-end session: commission well 1, buy upgrades, unlock crew/site, assign guard, run well 2, observe income, reload, resume sealing, commission well 2 and select modules. Use separate test saves. Write work/playtests/prototype.md and update prototype README with launch, controls, save location, recovery limits, and known issues. Fix small directly observed integration defects only.

## Acceptance checks

Document actual automated and manual results, bank consistency, displayed versus credited rates, and unresolved balance questions. Confirm all completed cards have handoffs. If export tooling is already available, an optional local build may be made; otherwise the editor-run prototype is the deliverable.

## Stop boundary

No public distribution, services, new content, extensive performance overhaul, or claims of human fun validation without feedback.

## Completion note

Completed the reproducible handoff. Added `prototype/tests/prototype_verification_test.gd` with isolated save fixtures for fresh progression, upgrades, Hero 2 guard assignment, Well 2 passive income, paused sealing reload/resume, Well 2 commissioning, and loadout selection. Added `work/playtests/prototype.md` with actual results, bank/rate evidence, manual steps, known issues, and unresolved balance questions. Updated `prototype/README.md` with launch, controls, save paths, recovery limits, and known issues. Verification: all 21 test scripts and main-scene startup exited 0. Fixed post-reload run-ID collisions and restored snapshot selection-ID mapping found by the end-to-end check. No human visual or fun validation was performed; no export was available or required.

