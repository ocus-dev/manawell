# Architecture and maintainability review

Reviewed September 5, 2026. Scope: current prototype source, scene, tests, contracts, and handoff documents. Gameplay redesign and visual playtesting are deferred. No runtime implementation was changed during this review.

## Assessment

The prototype has useful foundations worth retaining: a scene-independent extraction model, a separate account model, pure production calculations, centralized core balance constants, and small combat scripts. It does not need a rewrite or a general-purpose entity framework.

However, the integration layer has become the main architectural weakness. `encounter_controller.gd` is 1,019 lines and owns input, simulation advancement, spawning, progression, production, persistence, snapshot reconstruction, character presentation, and all HUD construction/refresh. Changes across assignments have added alternate paths rather than consistently extending a single owner. Several correctness problems now demonstrate the cost of that structure.

Fix the test harness and persistence boundary before adding gameplay systems. Then unify simulation scheduling and snapshot ownership. Extract the UI in a separate behavior-preserving change.

## Findings, ordered by priority

### 1. P1 — Account mutations bypass a consistent save transaction

Evidence: `prototype/scripts/game/encounter_controller.gd:351`, `:537`, `:678`; `prototype/scripts/model/save_store.gd:49`.

Most saves pass through `_save_account`, but `purchase_upgrade` directly calls `save_store.save_account(account_state)` with its default production timestamp of zero. A purchase therefore writes a different save envelope from other account changes. If that save is the last one before exit/crash, the next load calculates absence from zero, potentially awarding the full capped offline interval to an eligible guard. Tests of purchases and production in isolation do not protect this boundary.

In addition, `_settle_production` calls `_save_account` whenever any fractional income is earned. It is called every render tick. With an eligible guard, this can serialize and replace the whole save every frame, and capture all encounter actors when another well is active. The separate five-second checkpoint timer does not limit this path. Actual performance impact was not profiled; the synchronous per-frame work is evident in the call chain.

Recommendation: introduce a small session/persistence coordinator with one save-envelope builder and explicit commands for purchases, assignments, and completed runs. Keep frequent income accrual in memory; checkpoint on a bounded cadence and on durable transitions. Store monotonic settlement state and UTC save watermark in distinctly named fields. Make save failure/retry behavior common to all transactions instead of special-casing offline income.

Regression requirements: purchase -> immediate reload with an eligible guard; bounded save count over simulated frames; failed save then retry without duplicate credit; clock reversal followed by an ordinary save. The current `_save_account` overwrites the UTC watermark with the current clock even after the offline path preserved a later watermark.

### 2. P1 — Save recovery is not a protected lifecycle

Evidence: `prototype/scripts/model/save_store.gd:25`, `:84`; controller startup at `prototype/scripts/game/encounter_controller.gd:88` and offline settlement at `:473`.

`load_account` returns a fresh account immediately when the live file is missing, without trying the backup. `_replace_live_with_temp` first moves the live file to the backup and then moves the temporary file into place. An interruption between those moves leaves exactly the missing-live/valid-backup condition that the loader does not recover.

Malformed and future-version files also do not put the store into a protected state. Loading may return a fresh account or fallback backup, after which startup offline settlement writes immediately. Backup rotation then replaces the recovery material. A later write can remove the original file entirely. Checking only that the original exists immediately after `load_account` does not establish preservation across startup.

Recommendation: return an explicit load result such as fresh, loaded, recovered, unsupported, or corrupt, with a clear write policy. Check recovery candidates when live is missing. Preserve rejected source bytes separately and never rotate an invalid live file over the last known-good backup. Handle schema migrations explicitly rather than accepting every older version through defaults alone.

Regression requirements: absent live plus valid backup; interruption after each replacement step; unsupported version through complete startup and a subsequent save; corrupt live with good backup followed by two saves. Use isolated fixtures.

### 3. P1 — There is no single authoritative simulation tick

Evidence: `prototype/scripts/game/encounter_controller.gd:115`, `:132`; `prototype/scripts/game/melee_enemy.gd:37`; `prototype/scripts/game/ranged_enemy.gd:31`; `prototype/scripts/game/player.gd:35`.

The controller advances the weapon, extraction, sealing, and spawning from `_process`, while enemies and player abilities advance independently from `_physics_process`. Thus `controller.tick(delta)` is not a complete gameplay step. It can finish sealing without advancing an enemy attack that is due in the corresponding interval. Rendering cadence and physics cadence determine their relative execution, rather than the documented input -> damage -> sealing ordering.

The tests explicitly apply lethal damage before calling `tick`; that confirms model behavior but not that the running scene enforces that order. A future ability or enemy can easily introduce another independently scheduled mutation.

Recommendation: one fixed-step encounter scheduler should orchestrate gameplay updates in an explicit order. Actors expose update methods but do not also schedule those same updates themselves. Input queues commands; rendering and HUD read the resulting state. Passive production keeps its separate real-time clock. Avoid a broader deterministic replay system unless actually needed.

Regression requirements: lethal contact/projectile hit at the seal boundary; pause/resume; dash expiry and incoming damage; equivalent outcomes with different render rates. Run at least one integration test through the actual scene scheduling path.

### 4. P1 — Recovery duplicates implementation knowledge and omits live state

Evidence: `prototype/scripts/game/encounter_controller.gd:366`, `:390`, `:400`, `:434`, `:442`; `prototype/scripts/game/auto_weapon.gd:12`; `prototype/scripts/model/run_snapshot.gd:39`.

Snapshot capture manually reads actor fields and restore manually assigns them in the central controller. The codec validates dictionaries but is not the owner of those fields. This already misses important state:

- Capture includes enemy projectiles but not `auto_weapon.projectiles` or its shot timer/configuration. Restore does not apply owned weapon upgrades to the new AutoWeapon, so a restored upgraded run resumes with the default weapon configuration.
- Restored enemies are spawned with damage multiplier `1.0`, losing the multiplier of enemies from Well 2 or later surges.
- Snapshot actor IDs are allocated from the current array index. After pruning an earlier actor, a newly appended actor can receive the same ID as a surviving actor whose old ID was retained. A later checkpoint can fail validation for duplicate IDs.
- `_with_defaults` uses a dictionary operation on `run_state` before validating its type. Some malformed payloads can raise a script error instead of returning an invalid-result object. Several identity/boolean fields are only checked for presence.

Recommendation: give each stateful component explicit capture/restore methods or a small typed state record, with one documented coordinate convention. Allocate actor IDs at spawn from a monotonic counter saved with the encounter. A snapshot assembler collects those component records without guessing their private fields. Validate external types before normalization and migrate snapshots explicitly.

Regression requirements: compare uninterrupted and restored encounters containing purchased spread/damage, in-flight friendly and hostile shots, scaled enemies, and a partly elapsed weapon cooldown. Kill/prune/spawn between checkpoints and assert identity uniqueness. Feed incorrect nested types to the decoder.

### 5. P1 — Test exit codes do not reliably indicate failure

Evidence: `prototype/tests/account_saves_test.gd:11`, `:18`; `prototype/tests/prototype_verification_test.gd:16`, `:25`; review logs in `work/reviews/logs/`.

Tests call GDScript `assert` inside helpers, then their outer entry points call `quit(0)`. During the first review run, the sandbox blocked fixture writes: account-save assertions failed repeatedly while the process still exited zero. This directly demonstrates that an exit-code-only runner can report success despite failing tests. Those sandbox-induced failures are not treated as product defects.

Some tests also instantiate the scene but manually advance only RunState or controller methods, disable persistence, and call private helpers. For example, the final progression fixture bypasses combat by directly advancing extraction time. It is useful model/integration coverage, but it is not a complete runtime journey.

Recommendation: add a single test entry command that counts failed checks, returns nonzero, imposes a timeout, and rejects unexpected script errors. Prove the runner with a deliberately failing fixture. Retain focused model tests, then add a few session-level tests that use production commands and an injected save store/clock. Configure headless persistence explicitly rather than hiding production behavior based on display type.

Verification performed: all 21 existing scripts were rerun with fixture-write access; all exited zero and had zero SCRIPT ERROR/assertion/parse-error matches. The account-save test emits the expected malformed-JSON diagnostic. This supports the existing covered cases, not the missing cases listed above. No interactive or human fun validation was performed.

### 6. P2 — HUD rendering owns and resets interaction state

Evidence: `prototype/scripts/game/encounter_controller.gd:285`, `:720`, `:868`.

Every controller tick refreshes the entire HUD. That refresh clears and rebuilds well, loadout, active-hero, and guard selectors; the guard selector is reselected to the last roster entry. Selection is therefore not stable user-owned UI state. Changing presentation also requires editing the same controller that handles money and saves. Command methods such as `select_loadout(index)` additionally depend on widget metadata instead of accepting a domain ID.

Recommendation: extract an `EncounterHUD` scene/script with typed command signals carrying IDs. Pass a small view state to it. Rebuild lists only when their data changes; update fast-changing health/timer labels separately. Move legality checks into the command boundary so disabled buttons are not the enforcement mechanism. Keep the encounter controller as wiring, not a new home for the extracted rules.

Regression requirements: selections persist across idle frames; each UI command maps to the expected ID; commands reject invalid phases without depending on widget state. This is a maintainability refactor, not a HUD redesign.

### 7. P2 — Definitions and interfaces are not centralized enough for the next content step

Evidence: `prototype/scripts/model/account_state.gd:64`, `:219`, `:248`; `prototype/scripts/model/production.gd:29`; controller well summaries, spawning helpers, and hero selectors.

Core constants are centralized, but known well/hero IDs, labels, output selection, wave timings, and role lists are repeated in model validation, production, spawning, and UI. Adding a third well or hero would require coordinated edits across those layers. The account also exposes two separate successful-run credit methods, only one of which performs commissioning. Both maintain an ever-growing list of credited run IDs; run startup searches past those IDs again after restarting the process.

Recommendation: use a small definition catalog for wells, heroes, and surge data; do not introduce a plugin/content framework. Consolidate successful-run application into one command. Prefer concrete model types to generic `RefCounted` where practical, and keep raw dictionaries at serialization boundaries. Use a persisted run sequence and bounded committed-run marker appropriate to the single-active-run model, with an explicit migration for existing saves.

The README should describe the final system rather than accumulating contradictory card-by-card history: several paragraphs still say production or recovery is deferred after later paragraphs document it as implemented. Keep historical notes in assignment handoffs.

## Suggested repair sequence

These are architectural work boundaries, not dispatched tasks or implemented changes:

1. Add a trustworthy test runner and failure fixture; preserve the existing suite.
2. Fix SaveStore recovery/write policy with injected filesystem-failure cases.
3. Introduce one session save transaction, separate clock fields, and bounded checkpoint cadence.
4. Move combat/extraction advancement under one scheduler and test terminal ordering.
5. Add component snapshot records and stable IDs; verify uninterrupted/resumed equivalence.
6. Extract HUD commands/view state and preserve selection across refreshes.
7. Consolidate content definitions and successful-run credit; refresh final-state documentation.

Keep these as small, independently checked changes for Luna. Do not combine them with balance, new hero mechanics, art changes, or multiplayer. After the first five items, the prototype will offer a much more dependable base for the functional review.

## Evidence limits

Concrete execution evidence in this review is the existing headless suite and its diagnostics. The code-path defects above were established by source inspection; their proposed regression cases have not been added or run. No rendering performance measurement, interactive control test, export verification, or destructive player-save experiment was performed. The repository currently lists the implementation directories as untracked, so this is a review of the present tree, not a commit-to-commit diff.
