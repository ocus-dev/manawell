# Architecture repair assignments — Luna

This is the next queue after completed prototype assignments 01–21. It converts the findings in [the architecture review](../reviews/architecture-review.md) into bounded work. All cards start TODO; creating the queue has not implemented or dispatched any changes.

## Run one card at a time

Use a task configured for GPT-5.6 Luna and this prompt:

> Implement only work/assignments/22-reliable-test-runner.md. Read work/architecture/README.md, the relevant review finding, and the assigned source files. Check predecessor completion notes before proceeding. Preserve gameplay and balance; implement only this card and its regression checks. Run the targeted checks using the common runner, record actual results and changed interfaces in the card's completion note, update its row in work/architecture/README.md, and stop. Do not implement later cards or spawn extra agents.

Replace the path for each next card. Start at 22; do not rerun the original implementation backlog. No model tasks have been created automatically.

## Scope and working rules

- Execute serially in listed order. Each card depends on the immediately preceding card to keep handoffs simple and avoid overlapping refactors.
- Read the compact materials named by the card. Do not reload the entire concept, visual bible, all assignment histories or all source files on every task.
- This queue clarifies architecture and fixes the review's correctness problems. It does not authorize new content, balance tuning, art work, engine upgrades, installs, multiplayer, publishing or asset downloads.
- Preserve current intended behavior where the review identifies no defect. In particular, keep current numerical balance; the implemented Fortified maximum of 225 is not being changed to the earlier proposal's +50 absolute integrity in this pass.
- Keep the model separation already present. Add small owners for session persistence, scheduling, snapshots and HUD; do not replace one large controller with another large service or a general-purpose framework.
- Existing work/CONTRACTS.md expresses the original intended invariants. Use it for context, but follow this queue's explicit repairs where implementation detail differs. Record interface changes in each handoff; card 34 reconciles final documentation. Unspecified product choices remain deferred.
- Establish new tests through the strengthened runner from card 22. Use injected clocks/stores and separate fixture paths. Never edit, delete or reset the real player save to test recovery.
- For a reported defect, add a focused regression case that fails before the fix when practical. Check the result, not implementation spelling. Preserve original coverage while moving tests off private controller internals when required by the card.
- During intermediate refactors, narrow compatibility adapters are acceptable. Identify their callers and remove superseded adapters when the dependent card migrates them; do not accumulate permanent duplicate code paths.
- Runtime changes and schema changes require targeted checks. Run the complete suite at cards 22, 29 and 34, or when integration changes justify it; avoid repeatedly running unrelated expensive checks after documentation-only edits.
- Card 23 defines protected save outcomes; cards 24–25 must honor them. Unsupported/corrupt source preservation takes precedence over automatic checkpointing. Card 33 must use the same schema migration mechanism rather than inventing a second one.
- Snapshot migration must be honest. If missing old fields prevent faithful recovery, retain banked progress, preserve the source and explain why only the active snapshot cannot resume. Never silently treat invented defaults as an exact recovery.
- Keep tests operational after each card. If a prerequisite is incomplete or tooling prevents verification, mark BLOCKED with the concrete reason. Do not count an exit-zero result with script errors as a pass.
- Keep each completion note under about 150 words with paths, actual commands/results, and the API names the next task needs. Report remaining manual checks explicitly.

## Queue

| ID | Assignment | Depends on | Status |
|---|---|---|---|
| 22 | [Reliable test runner](../assignments/22-reliable-test-runner.md) | 21 | DONE |
| 23 | [Save recovery and protected writes](../assignments/23-save-recovery-policy.md) | 22 | DONE |
| 24 | [One session save boundary](../assignments/24-session-save-boundary.md) | 23 | DONE |
| 25 | [Bounded checkpoints and failed-save retry](../assignments/25-checkpoints-and-save-retry.md) | 24 | DONE |
| 26 | [One gameplay scheduler](../assignments/26-single-simulation-scheduler.md) | 25 | DONE |
| 27 | [Snapshot validation and stable IDs](../assignments/27-snapshot-validation-and-identity.md) | 26 | DONE |
| 28 | [Component-owned snapshot state](../assignments/28-component-snapshot-state.md) | 27 | DONE |
| 29 | [Recovery equivalence checkpoint](../assignments/29-recovery-equivalence-tests.md) | 28 | DONE |
| 30 | [UI-independent commands](../assignments/30-domain-commands.md) | 29 | DONE |
| 31 | [Extract HUD and preserve selection](../assignments/31-extract-hud.md) | 30 | DONE |
| 32 | [Consolidate content definitions](../assignments/32-content-definitions.md) | 31 | DONE |
| 33 | [Bounded run identity and one completion command](../assignments/33-run-identity-and-credit.md) | 32 | DONE |
| 34 | [Architecture verification and final documentation](../assignments/34-architecture-handoff.md) | 33 | DONE |

## Checkpoints

After **25**, save recovery and transaction boundaries should be safe enough to protect subsequent refactors, with bounded write frequency.

After **29**, one scheduler and complete component snapshots should make uninterrupted versus resumed encounters comparable through a trustworthy test harness.

After **34**, review the architecture follow-up report before beginning gameplay changes. Completion means evidence for the findings, not a target file count or an arbitrary maximum number of lines.

## Coverage map

| Review finding | Assignments |
|---|---|
| 1: save transaction/cadence/clock inconsistencies | 24–25 |
| 2: protected save recovery | 23, integration in 24–25 |
| 3: simulation ownership/order | 26, 29 |
| 4: incomplete snapshots and unstable identity | 27–29 |
| 5: misleading test success and bypassed runtime paths | 22, 24, 26, 29 |
| 6: controller/HUD coupling and selection resets | 30–31 |
| 7: definitions, duplicate credit, unbounded IDs, stale docs | 32–34 |

