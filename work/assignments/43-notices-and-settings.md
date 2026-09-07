# 43 — Recovery notices and safe settings

Dependencies: 42. Status: work/interface/README.md.

## Read first

Read work/interface/README.md, design/Interface.md §7 notices/settings, and only the predecessor handoff and relevant current UI/domain source. Files may have moved in the architecture pass; follow the completed handoff rather than recreating old paths.

## Implement

Build NoticeHost for actual offline settlement, rejected commands and persistent save/recovery problems. Keep action errors separate from gameplay instructions. Offer the session's retry-save/settlement action and distinguish saved versus pending in-memory state. Settings exposes only existing controls; isolate Clear saved progress behind a confirmation whose default is Cancel. Gate developer controls behind developer mode. Use the existing profile-reset command and surface its failures.

## Acceptance checks

Offline notice appears only for actual committed settlement; dismissing it never credits again. Save issue remains actionable and cannot be disguised as success by closing a modal. Cancel reset makes no changes. Confirm reset uses injected fixtures in tests and returns UI to correct fresh state. Developer controls absent in normal mode. Notices do not cover health/Harvest.

## Stop boundary

No new settings persistence, audio sliders, key remapping or changes to protected-save policy. Never reset the real player profile for verification.

## Completion note

Implemented `NoticeHost` and `SettingsPanel` in `prototype/scripts/ui/`, with actionable save and offline-settlement retry intents, pending in-memory state, dismiss-only behavior, developer-mode gating, and cancel-default clear-progress confirmation. Extended `UiViewState` notices and added `EncounterController.notice_state()` as a read-only presentation snapshot; existing session retry and protected-save policies remain authoritative. Added `prototype/tests/notices_settings_test.gd`, including an injected reset-store fixture and fresh-account verification. Focused and full-suite checks pass except the existing unrelated `recovery_equivalence_test.gd` failure. These surfaces remain preview-only until assignment 44 integrates the live HUD; no screenshot was captured.

