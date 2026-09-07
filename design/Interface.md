# Mana Well — Interface revamp

> Proposed UI direction, September 5, 2026. Implement after architecture assignments 22–34. This design changes presentation and interaction flow, not combat balance or economic rules. The clickable conversation mockup illustrates selected states; this document is the implementation specification.

## 1. Organize around the player's task

Replace the tall expandable control panel with three clear views:

1. **Operations:** choose a well, see its guard, prepare the expedition hero and machine, and buy upgrades.
2. **Extraction:** keep the arena visible; show survival, the at-risk tank, the next threat, and the harvest action.
3. **Result:** explain what happened, distinguish the run's reward from background income, and offer preparation or an explicit retry.

The important relationship is spatial: a guard belongs inside the card for the well they operate. The hero the player controls belongs in a separate expedition card. Do not use a single unlabeled hero selector for both roles.

Use ordinary player language. “Banked mana,” “Guard,” “Ready to operate,” “Unstaffed,” “Extracting,” and “Prepare expedition” are clearer than raw phase names, assignment dictionaries, or technical recovery states.

## 2. Operations layout

At 1280 × 720, place the operations content inside a centered area with 24 px outer margins. Use a compact header, a two-column workspace, and a footer action area. Start with roughly 60% width for wells and 40% for expedition preparation; allow the exact split to follow readable content. Two wells appear side by side in the left area. Upgrade cards occupy the row below them. Expedition hero and loadout occupy the right column. Essential preparation and launch controls must fit without scrolling at the baseline size.

The arena may be dimmed behind this view; a fully opaque operations surface is also acceptable. Do not spend this pass on a separate hangar scene.

### Persistent resource strip

- Title: Mana Well / Operations.
- Banked mana, with a consistent mana symbol and label.
- Total passive income in mana/minute; zero is shown plainly rather than hidden.
- Settings button in the header. Save problems appear as a separate persistent notice, not as replacement text for the primary instruction.

Show two decimals for banked totals where space permits; use compact large-number formatting when needed, with the full value on focus/hover. The wallet and its rates use the same model values as the economy. Do not manufacture projected income in UI code.

### Well card

One reusable component represents each well. Its stable order is:

1. Well name and state label.
2. Small schematic well/machine illustration or placeholder; no image-generation dependency.
3. Current passive mana/minute. For an unstaffed well, show `0 mana/min · Add a guard`.
4. **Guard slot:** the assigned hero portrait/initials and name, or a bordered square with **+** and the visible label **Assign guard**.
5. A **Prepare here** button, with a clearly selected state when this is the current expedition destination.

Selecting a destination does not start a run or alter guard duty. Clicking the + opens the hero picker for that specific well. Clicking an occupied slot opens the same picker with the current guard and a **Recall to reserve** action. A persistent small Recall action may sit beside the occupied slot; it must not be an unlabeled destructive-looking X.

### Well states

| State | Guard slot | Main action and detail |
|---|---|---|
| Locked | Lock symbol, not + | Disabled; visible explanation of the existing unlock condition |
| Available, not commissioned | `Complete a qualifying harvest first` | Prepare here; show actual qualifying requirement |
| Commissioned, no guard | + Assign guard | Prepare here; passive rate is zero |
| Commissioned, guarded | Hero portrait/name | Prepare here; current passive rate and Recall |
| Active expedition | `You are here · [hero]` in the activity label | Read-only during combat; passive production at this site is zero |

Active operator and assigned guard are distinct meanings. Never show the active operator in a slot labeled Guard. If a well is guarded when the player prepares there, keep its guard visible until launch actually succeeds.

## 3. Assignment picker

Use a small modal titled **Assign a guard to [well name]**, anchored visually to the operations view. Show available heroes as rows with portrait/initials, name, current assignment, and guard trait. Do not require a global roster screen for two heroes.

- Reserve heroes have an **Assign** action and a model-supplied resulting passive rate for the target well, if a preview API is available.
- The active hero is visibly unavailable: **Expedition hero**.
- A hero guarding another well is visibly unavailable: **Guarding [well] — recall there first**.
- The current guard is labeled **Assigned here**, with Recall available.
- If no reserve hero exists, show **No reserve heroes available. Change your expedition hero or recall a guard first.** Keep unavailable heroes visible so the reason is understandable.
- Cancel and Escape close without changing assignments. Restore keyboard focus to the opener.

No implicit reassignment, no drag-and-drop, no automatic recall from a different site. For the initial two-hero roster, replacing a guard can be done through explicit Recall then Assign. This avoids introducing a new multi-assignment economic transaction just for the UI. After recall, update the picker in place; do not close and reopen it unnecessarily.

On a successful action, update the affected well and total rate immediately. On rejection or failed persistence, display the command result from the session layer; do not locally pretend a mutation succeeded. Preserve the existing dirty-save retry semantics and distinguish applied-in-memory progress from saved progress.

## 4. Expedition preparation

### Expedition hero card

Show **You control**, portrait/initials, hero name, a concise capability summary and **Change hero**. This opens a picker with reserve/current heroes; guarded heroes are disabled with their location. Selecting a reserve hero uses the existing active-hero command, returning the previous active hero to reserve.

This makes the common swap understandable: Change hero first, then assign the now-reserve hero to the desired well. Do not require the player to understand internal role names to discover this path.

### Harvester card

Show the selected well name and one-of-three loadout choices as compact radio-style cards: Standard, Overdrive, Fortified. Each has a concise model-derived benefit/tradeoff. Locked choices show the unlock requirement. Selected state uses a border/check and text, not color alone.

Keep current numerical definitions, including whatever values the architecture pass preserves. No hardcoded percentages in UI copy. If a well cannot yet change loadout, show Standard and explain availability rather than presenting an unusable blank selector.

### Launch summary

Show destination, active hero, and loadout above **Start extraction [E]**. Include the well's base extraction rate and threat summary as preparation information, clearly distinguished from passive income.

If launching at a guarded site, display **Starting here recalls [hero] and stops this well's passive income.** The normal Start action is sufficient; no extra confirmation is necessary for this reversible, already explained change. Other guarded wells remain producing.

Launch is disabled with an explanation when the selected configuration is invalid. Domain commands remain authoritative if availability changes after rendering.

## 5. Upgrades

Show the three existing upgrades as small purchase cards under **Research**: title, exact effect, cost, and Buy button. Show Owned instead of leaving a dead Buy button. For insufficient funds, show **Need [difference] more**. Compute affordability and effects from domain definitions/state.

Keep machine research together visually; do not add a new research tree. Use one purchase command per click. Update the wallet and card after the result. Avoid a success modal for routine purchases. Upgrades remain unavailable during active combat, including while paused.

## 6. Combat layout

Remove the operations workspace during extraction. Use compact widgets anchored to viewport edges:

- **Top left — survival:** two labeled horizontal bars with current/max values: Hero and Harvester. Distinguishable symbols and shapes accompany color. Low values get a restrained warning, not flashing wallpaper.
- **Top center — pressure:** completed surge/multiplier, time to the next surge, and the upcoming threat summary. Labels must distinguish “next surge” from “next enemy spawn.” Use the domain's time-scale-aware display values for Overdrive.
- **Top right — wallet and pause:** compact banked mana and passive rate, plus Pause. Detailed network management is absent.
- **Bottom center — extraction:** prominently show **At risk: [payout] mana** and **Harvest [E]**. Helper text: **Defend for [seal duration]s to bank it**. During sealing, replace the action with **Sealing… [remaining]s · Keep defending**; disable repeat harvesting and freeze the displayed locked payout.
- **Bottom left — abilities:** Dash [Space] and Pulse [Q] with ready/cooldown state. Represent readiness with text and fill, not only color.

Preserve a large unobstructed arena center. No scrolling for combat-critical information. No dismissible notification should cover health, the next threat, or Harvest.

## 7. Pause, results, and return

Pause displays a small centered overlay with Resume, Settings, and **Abandon current tank**. Show the lost amount before abandon, with a confirmation because it forfeits the tank. Escape resumes only when the pause overlay itself is the topmost view; inside Settings, Escape closes Settings and leaves the run paused. Management actions remain unavailable while paused.

Results show **Harvest secured** or **Extraction lost**, the run's banked/lost amount, completed surge, and an understandable cause. Keep passive income separate: never derive the run reward by subtracting wallet totals.

Primary action: **Return to operations**. Secondary: **Retry same expedition**, explicitly starting a fresh run with the same valid configuration. Retain a clear banked-progress reassurance after failure. Returning to operations clears terminal presentation without starting another run. Reuse an existing reset/preparation command, or add a narrow one if the architecture layer does not expose it.

Offline return: a single dismissible **While away: +[amount] mana** notice, only after actual settlement. Failed settlement stays actionable through the session's retry action. Recovered encounter: **Recovered at your last checkpoint** and **Resume**, initially paused as already specified by recovery rules.

Settings contains only existing settings/actions. Move **Clear saved progress** into a separate danger area with confirmation; Cancel is the default. Do not add audio sliders, remapping, or new saved preferences that have no existing backing system. Developer controls remain available only in developer mode and separate from normal play.

## 8. Input and accessibility contract

- Each input event dispatches at most one command. GUI-handled keys cannot fall through to gameplay polling.
- Modals own keyboard focus. Enter activates the focused control; Space on a focused button must not also dash. E in an assignment/settings modal must not launch or harvest.
- Escape closes the topmost modal before changing encounter pause state. Restore the opener's focus after closing.
- Mouse clicks inside UI do not pass into the arena. No drag-only interactions or essential hover-only explanations.
- Use at least 16 px body text at 1280 × 720, 14 px for secondary labels, and approximately 40 px minimum actionable target height. Focus rings are visible on the industrial palette.
- Use 8 px spacing increments, clear labels, stable card order and stable selection through refreshes. Avoid animated layout shifts as mana numbers change.
- Verify 1280 × 720 and 1920 × 1080. At narrower windows, stack operations columns and allow its content to scroll; keep the launch area accessible. Combat widgets reflow without clipping and never require scrolling. Below the tested minimum, document the minimum rather than shrinking labels into illegibility.

## 9. Appearance and component ownership

Use the established industrial language: charcoal surfaces, off-white text, restrained cyan for mana, yellow for machine/action emphasis and red for actual danger. Small stenciled headings can add character; body labels must remain easy to read. Square/slightly rounded panels and clear separators suit the machinery theme. Avoid elaborate texture, scanlines, noise or decorative gauges in this pass.

Suggested reusable Godot components:

| Component | Owns | Emits |
|---|---|---|
| ResourceStrip | Wallet/rate display | Open settings |
| WellCard | Site state and guard slot | Prepare site, open guard picker |
| HeroSlot / HeroPicker | Portrait, availability and choice | Select hero ID, recall well ID |
| ExpeditionPanel | Active hero, loadout, launch summary | Change hero, select loadout ID, start |
| UpgradeCard | Effect, cost, availability | Purchase upgrade ID |
| SurvivalWidget / PressureWidget | Combat readouts | No model mutations |
| ExtractionWidget / AbilityBar | Actions and their current state | Harvest / ability intent |
| ResultPanel / PausePanel | End/pause choices | Prepare, retry, resume, abandon intent |
| NoticeHost / SettingsPanel | Recovery messages and existing settings | Dismiss, retry-save, confirmed reset |

These are composition boundaries, not a requirement for a generic UI framework. Reuse controls/themes rather than subclassing every label. A single presenter assembles view data from domain state; widgets consume it and emit IDs. No widget reads save files, recalculates production formulas, or manipulates raw account dictionaries. Rendering creates no model changes.

## 10. Acceptance journey

Use isolated profiles/fixtures representing fresh, first well commissioned, both wells commissioned, and resumed combat. A player should be able to:

1. Identify where to start a fresh expedition without opening settings.
2. Commission well 1, see its + slot, assign the reserve hero there, and see its income on that same card.
3. Prepare well 2 while well 1 visibly stays staffed.
4. Understand why an active/guarded hero is unavailable in the picker and recover through explicit actions.
5. Change hero, recall, and reassign without inconsistent UI or duplicate income settlement.
6. See both health pools and the at-risk payout throughout extraction and sealing.
7. Pause, navigate a modal, and resume without stray gameplay commands.
8. Understand success/failure, return to operations, buy one upgrade, and intentionally retry.
9. See genuine save/recovery issues without having them replace gameplay instructions or be dismissed as a successful save.

Automated tests cover intent routing and state presentation. Manual screenshots at both target resolutions and a keyboard/mouse walkthrough establish layout and usability. Neither replaces the other; document any unperformed checks.
