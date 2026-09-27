# Telos prototype 2D

Active Godot project for the Windows desktop side-view prototype. The fixed 1280x720 logical canvas uses a single horizontal ground lane, a central harvester, procedural industrial presentation, continuing surge pressure, and the full two-well progression, loadout, production, and recovery loop. The accepted experiment at `../experiments/side-view-defense/` is frozen historical evidence; the original 3D runtime is independently preserved at `../archive/prototype-3d/`. Neither is an active dependency.

## Verified toolchain

- Godot: `4.8.dev4.official.b56a91878`
- Editor: `C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64.exe`
- Console runner: `C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe`
- Active project: `prototype/`, using the isolated 2D profile `user://telos_side_view_defense_experiment`.

The executable directory is kept outside the project. This is a development build; use a stable Godot 4 release before shipping.

## Run the project

From the repository root in PowerShell:

```powershell
$godot = 'C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64.exe'
& $godot --editor --path '.\prototype'
```

To run the main scene without opening the editor:

```powershell
& $godot --path '.\prototype'
```

For the static-art comparison scene, open the project in the editor and run `scenes/previews/side_view_visual_slice.tscn`. The five trial sprites are in `assets/side-view/`; their source/cutout provenance, alpha bounds, visible heights, and ground anchors are recorded in `assets/side-view/side-view-assets.json`. Native screenshot evidence and the owner review checklist are in `../work/playtests/static-sprite-slice.md`.

The game uses keyboard controls: `A/D` or arrows move, `Space` jumps, `S/Down + Space` drops through a platform, `Shift` dashes, `Q` uses the defensive pulse, `E` starts extraction or harvests, and `Escape` pauses or resumes. The HUD exposes the same actions plus preparation, assignment, upgrade, network, retry, abandon, and save-reset controls. Active encounter checkpoints restore the validated platforming state paused; incompatible active snapshots are rejected while account progress remains saved.

Combat geometry is authored independently from sprite alpha in `data/combat_geometry.gd`: hero, pursuer, breaker, ranged, and machine hurtboxes use feet-relative rectangles, with explicit body-center and muzzle calculations. Projectiles use swept 2D segments and platforms remain open/slatted visual supports that do not block shots in this milestone.

The active project has no runtime resource loads from the archive or experiment. Its accepted scope is the existing 2D prototype with retained procedural visuals, not a new platformer, final art release, or campaign expansion.
The focused behavior checks are `movement_test.gd`, `run_state_test.gd`, `encounter_test.gd`, `surge_2d_test.gd`, `weapons_abilities_2d_test.gd`, `progression_2d_test.gd`, `persistence_2d_test.gd`, `presentation_2d_test.gd`, and the remaining model/UI tests discovered by the runner. Legacy 3D fixture names are not active paths; their disposition is recorded in `work/2d/test-matrix.md`.

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/player_abilities_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Player abilities test failed with exit code $LASTEXITCODE" }
```

The hero exposes `setup_abilities`, `try_dash`, `try_pulse`, `receive_damage`, `simulate_ability_tick`, and `reset_abilities`. Dash lasts 0.2 seconds at speed 15 with a 4-second cooldown and blocks hero damage only. Pulse deals 15 damage within radius 4 with an 8-second cooldown.

## Monster Encyclopedia (dev tool)

Tune monster stats while the game is running. Available in debug builds only (running from the editor or a debug export); release exports don't include it.

- **During an encounter:** press `F9`. The run pauses while the panel is open and resumes when you close it (`F9`, `Esc`, or **Close**).
- **From the title screen:** choose **DEV ENCYCLOPEDIA**.

The list shows the pursuer, breaker, and ranged monsters using their in-game side-view sprites, with idle/walk/attack previews from `assets/side-view/animations/`. Each stat has a slider, a number field, and a **Default** button. The amber tick on each slider marks the default from `data/balance.gd`. Derived numbers (damage per second, time to kill the hero or break the harvester, hits to kill with the current weapon, arena crossing time) update as you edit.

Edits apply immediately: monsters already in the arena pick up the new stats (keeping their current health percentage), and every later spawn uses them. They last until you quit unless you save.

- **Save to game data** writes `data/monster_stats.json`. Commit that file to share the tuning. In an exported debug build `res://` is read-only, so the save goes to `user://monster_stats.json` and is loaded from there instead.
- **Export JSON / Import JSON** copy stats as text (same format as the data file). Unknown monsters and stats are ignored; values are clamped to the slider ranges.
- **Reset monster / Reset all** return to the `data/balance.gd` defaults. Nothing on disk changes until you save.

How it fits together:

- `scripts/model/monster_stats.gd` (`MonsterStats`) owns the stats: defaults from `Balance`, overridden by `data/monster_stats.json`. `DefenseEnemy._apply_stats()` and the hostile projectile speed read from it.
- `scripts/tools/monster_encyclopedia.gd` is the panel. The encounter controller attaches it in `_attach_monster_encyclopedia()`, and `apply_monster_stats()` pushes edits onto live enemies.
- Ranged enemies now wait out `attack_interval` between shots (the wind-up counts toward it). Before this change `RANGED_ATTACK_INTERVAL` wasn't used, so ranged enemies fired again as soon as each wind-up finished.
- To add a monster, add it to `MONSTERS` and `DEFAULTS` in `monster_stats.gd`, and add its sprite to `SideViewVisualConfig.ASSETS`.

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/monster_encyclopedia_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Monster encyclopedia test failed with exit code $LASTEXITCODE" }
```

## Monster Test Arena (dev tool)

A sandbox for checking Monster Encyclopedia changes against real monster behavior. Debug builds only: choose **MONSTER ARENA** on the title screen.

- An invincible test dummy stands in the middle of the arena. It never loses health. Every hit shows a floating damage number, colored by the monster that landed it (pursuer red, breaker amber, ranged blue).
- Monsters use their real AI and their current `MonsterStats` values. Pursuers and ranged monsters target the dummy as the hero; breakers target it in place of the harvester.
- **Add / remove:** the `+` and `-` buttons on each row (Shift-click `+` adds five), number keys `1` `2` `3` (Shift + number removes the newest of that type), right-click a monster to remove it, or **Clear all** (`Delete`). **Spawn from** picks the right side, left side, or alternating. **Click to place** drops the chosen monster wherever you left-click.
- **Surge level** applies the same damage multiplier the encounter uses after each completed surge.
- The **Damage taken** panel shows total damage, DPS over the last 5 seconds, hit count, largest hit, and a per-monster breakdown. `R` resets it.
- `F9` (or **Open encyclopedia**) opens the Monster Encyclopedia over the arena. The arena pauses while it's open, and edits apply to the monsters already fighting. `Space` pauses, `Esc` returns to the title screen.

Files: `scenes/tools/monster_test_arena.tscn`, `scripts/tools/monster_test_arena.gd` (implements the slice of the encounter controller API that `DefenseEnemy`, `DefenseProjectile`, and the encyclopedia call), and `scripts/tools/monster_test_dummy.gd`.

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/monster_test_arena_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Monster test arena test failed with exit code $LASTEXITCODE" }
```

## Weapon Lab (dev tool)

Brings weapon art made in ComfyUI or ChatGPT into the game and lets you test it in the Monster Test Arena. Debug builds only: choose **WEAPON LAB** on the title screen. It replaces the AUTHOR/PUBLISHED tabs of `scenes/tools/weapon_designer.tscn` for day-to-day work; the old designer still opens and reads the same drafts, runs, and catalog.

One page per weapon, like the Monster Encyclopedia. The list on the left holds every weapon in the game plus lab drafts; **+ New weapon** starts a new one.

1. **Art.** Pick an image from `art/ui-items/Weapons/`, or **Import image...** to copy one in from anywhere (PNG, JPG, WebP). Choose a cutout and press **Cut out & prepare**:
   - **Auto** keeps a PNG's own transparency, otherwise uses Trellis 2.
   - **ComfyUI Trellis 2** uploads the image to your local ComfyUI and runs `art/side-view/workflows/06_cutout.api.json` (`Trellis2RemoveBackground`). The URL comes from `tools/asset_pipeline/config.json` (`concept_url`) or defaults to `http://127.0.0.1:8188`; edit it in the lab and press **Check**.
   - **Solid background** removes a flat backdrop locally, no ComfyUI needed. Raise **Tolerance** if a halo is left.
   - **Already transparent** uses the PNG's alpha as is.
   The lab trims the cutout and writes the world sprite (256 px tall), the 256 px icon, and review images to `art/weapons/runs/<job_id>/` in the same format as `tools/weapon_pipeline/pipeline.py`, so no Python or PowerShell is needed. Click the world sprite to set the grip.
2. **Details & stats.** Name (the id is made from it and locks once the weapon is in the game), description, behavior, **base damage** and **base attacks per second** (the weapon's own baseline, saved as `base_stats` on the revision), plus bonus damage, attack speed, and projectile speed. Research ranks add on top of a weapon's base, and item bonus caps are relative to it. Weapons without `base_stats` keep the global `Balance.WEAPON_DAMAGE` / `WEAPON_INTERVAL` baseline (10 damage, 1.67 attacks per second). The line under the stats shows the resolved in-game numbers and warns when an item cap applies (+50% damage, +30% attack speed).
3. **Placement.** Grip, scale, rotation, hand offset, and facing.

4. **Swing.** How the weapon moves when the hero attacks. Pick a preset (Default swing, Slash, Overhead smash, Thrust / stab, Spin, Gun recoil, No motion) or tune the values: duration, wind-up / strike / settle angles, when the wind-up and strike end (fractions of the swing), wind-up and strike push (pixels along the facing direction), strike lift, and snap (how hard the strike starts and eases out). Editing a value switches the preset to Custom. The preview animates the weapon around the hand with faint ghost poses, and the graph shows the angle over time; for melee weapons a red line marks when damage lands (40% of the attack interval), and a note warns if the swing is longer than the time between attacks. Swings are saved on the revision as `swing` (`scripts/model/weapon_swing.gd`); weapons left on Default swing store nothing and move exactly as before. In the arena the right panel has **Placement** and **Swing** tabs, so you can tune the swing live with **Loop attack animation** and slow motion; changes come back to the lab.

   **Research presets.** **Test swing sword** and **Test swing ax** are based on how real cuts move, fitted to the game's rule that melee damage lands at 40% of the attack interval. Pick one and the value grid fills in, and a "Why these numbers" note explains each value; hover any value for what it does.
   - *Sword* (made for the default 1.67 attacks/s, so the hit lands 0.24 s in). A short 0.12 s chamber to -50°, then a 175° cut in 0.18 s. The hit lands two-thirds of the way through the cut (about +67°), where real cuts are at top speed. It follows through about 58° past the hit (real blades carry 30–60° past contact). The weapon moves back 4 px on the chamber and forward 8 px on the cut, as the body steps in. Snap is 0 (steady speed), and it recovers by 0.5 s.
   - *Ax* (made for a heavy 1.0 attacks/s, so the hit lands 0.4 s in). A 0.28 s raise straight overhead to -150°, then a 245° chop in 0.12 s that ends exactly on the hit. Snap is -0.6, so the head accelerates into the target: the weight does the work. It drops 8 px on the chop, has no follow-through (it bites and stops), and takes a slow 0.4 s to recover. At the default 1.67/s the hit would land during the raise, so the lab warns you and offers a button to set the base attack speed to 1.0.

   `snap` now goes from -1 to 1. Positive starts the strike fast and eases out (a whip). Negative starts slow and accelerates into the hit (a heavy chop).

5. **Effects.** Flipbooks that play during the attack: slash trails, sparks, impact rings, glows, muzzle flashes. Up to 4 per weapon.
   - **Get a sheet.** **Generate** makes a built-in one (Slash arc, Spark burst, Impact ring, Glow pulse, Muzzle flash) in the color you pick, so you can try effects before making art. **Import sprite sheet...** takes a ready-made sheet (set Frames and Columns first; columns = frames for a single strip). **Import frames...** takes separate PNGs (for example frames exported from a ComfyUI video), sorts them by file name and packs them into one strip. Sheets are saved under `art/weapons/effects/<weapon id>/`.
   - **When it fires.** *Wind-up starts*, *Strike starts*, *Hit lands* (melee: the damage moment at 40% of the attack interval; ranged: the moment the shot fires), *Strike ends*, or *Custom* (a fraction of the swing). Teal triangles on the swing graph show each trigger, and the swing preview plays the effects in place.
   - **Where it appears.** Anchor is a point on the weapon image: type it or press **Pick anchor on sprite** and click the world sprite. **Follow weapon** rides along with the blade (trails, glows); off, it stays where it spawned (sparks, impacts). **Turn with weapon**, size, extra rotation, offset, FPS, opacity, and additive (glowing) blend.
   - Publishing copies each sheet into `assets/weapons/<id>/<n>/effects/` and saves the list on the revision as `effects` (`scripts/model/weapon_effects.gd`). The hero plays them in the encounter and in the arena (`scripts/game/weapon_effect.gd`). Slow motion in the arena is the easiest way to check timing.

6. **Attack clip.** A drawn attack animation for the weapon: a pose sheet (like a ChatGPT animation sheet), separate frame images, or a video. **Import clip...** opens the clip importer:
   - **Source.** *Pose sheet...* takes one image with every pose in a row; you don't need to cut it into single frames. Captions, borders (even a screenshot's dark edge), and the ground line are ignored. *Frames...* takes one image per frame, played in file-name order. *Video...* (MP4, WebM, MOV, GIF) needs ffmpeg: on PATH, or point the ffmpeg box at `ffmpeg.exe` (ComfyUI often has one under `python_embeded\Lib\site-packages\imageio_ffmpeg\binaries`). Set the fps (10-15 is plenty), start time, and max frames.
   - **Slice** (sheets). The importer finds the pose row and cuts between poses at the emptiest columns. If poses touch, set **Frames** to the number of poses. Drag the magenta cuts and green top/bottom lines, or give the selected box its own left/right edge (boxes may overlap when a weapon reaches into the next pose).
   - **Cut out.** *Solid background* works offline for flat backdrops. *ComfyUI Trellis 2* runs one cutout job per frame. *Drop bits of neighbouring poses* removes loose pieces touching a box's side; *Min piece* removes dust and motion arrows; *Clear background in gaps* empties holes between arms and handle.
   - **Line up & clean.** Sheets line up each pose on its feet; videos keep their positions. The green mark is the ground point (weapon mode: the grip), the blue ghost is the previous frame. Drag a frame to move it, click to put a point on the mark, arrow keys nudge (Shift = 10 px), Q/E step frames, Space plays. The **Eraser** paints away stray bits; **Re-cut frame** undoes it.
   - **Timing & attacks.** Hold time per frame. Tick **Hit frame** where the weapon connects. For a combo, tick **Starts a new attack** on the first frame of each later attack: the hero alternates between the attacks and starts over after a pause. For melee weapons the frames before the hit are sped up or slowed so the hit frame shows exactly when damage lands (40% of the attack interval); the hit and follow-through keep their own pace. The summary warns when an attack runs longer than the time between attacks.
   - **Use as.** *Hero attack*: the frames show the whole hero; while the weapon is equipped they replace the hero's attack animation and the held weapon hides (effects still show). *Weapon frames*: the frames show only the weapon and replace its picture during the swing. **Hero height** (measured from frame 1) scales the clip to the hero's in-game height; **Scale** fine-tunes it.
   Work is saved under `art/weapons/clips/<weapon id>/<clip>/` (source, cut frames, `project.json`, packed sheet), so **Edit clip...** reopens it. Publishing copies the sheet to `assets/weapons/<id>/<n>/clip.png` and saves the clip on the revision as `attack_clip` (`scripts/model/weapon_clip.gd`).

   Tips for ChatGPT sheets: ask for "a single row of N poses, evenly spaced with clear gaps between them, plain flat light background, no text, no labels, no arrows, same scale in every pose, character facing right, feet on the same ground line". Gaps mean no manual cleanup; effects like slash trails are fine as long as they stay inside a pose's slot.

**Test in arena** opens the Monster Test Arena with the hero holding the weapon. The hero is invincible and attacks with the game's rules (ranged shots at the nearest monster within 12 units, or melee strikes in reach in the facing direction). Weapon hits show as white damage numbers, with a dealt/DPS/hits/kills meter. Monsters can't die unless you untick **Monsters can't die**. For animation work: **Swing** (`E`), **Loop attack animation**, and slow motion (`T` or the speed menu, down to 0.1x). Edit placement on the right or drag the weapon with the mouse; `A`/`D` move, `F` flips. `Esc` returns to the lab with the placement carried over.

**Add to game** publishes through `WeaponPublisher` (immutable revision under `data/weapons/<id>/<n>/`, assets under `assets/weapons/<id>/<n>/`, `data/weapons/index.json` updated, previous index kept in `history/`). For a weapon already in the game the button reads **Publish update (rN)** and publishes the next revision; it refuses when nothing changed. **Drops as loot** registers the weapon in the `foundry_physical_v1` table, and publishing an update re-registers it so drops follow the new revision. **Save draft** keeps work in progress in `data/designer/drafts/lab.<id>.json`.

**Remove** (bottom left) takes the selected weapon out of the game after a confirmation. Its index entry moves to a `retired` list in `data/weapons/index.json`, its loot drops are turned off, and its lab draft is deleted. Nothing else is deleted: revision folders and assets stay on disk, and players who already own one keep it (retired weapons are still registered so saves load, but they can't drop or be granted). Tick **Show removed** in the list and press **Restore to game** to bring one back at the revision it had. A removed weapon's id can't be reused by a new weapon. For a weapon with unpublished edits, the dialog also offers **Discard draft only**. For a weapon that was never added to the game the button reads **Delete draft** and just deletes the draft (the source image and prepared art stay).

Notes:

- Behavior only switches between ranged and melee in the encounter today. Fan and lance spreads come from research, not the weapon.
- The encounter fires every shot at the base projectile speed, so the projectile speed bonus is saved on the weapon but has no effect yet.

Files: `scenes/tools/weapon_lab.tscn`, `scripts/tools/weapon_lab.gd` (UI and publishing), `scripts/tools/weapon_lab_art.gd` (cutouts and run folders), `scripts/tools/weapon_lab_effects.gd` and `scripts/tools/weapon_effect_art.gd` (effects panel and sheets), `scripts/tools/weapon_clip_importer.gd` and `scripts/tools/weapon_clip_import.gd` (clip importer UI and engine), `scripts/tools/comfy_cutout.gd` (ComfyUI client), `scripts/tools/weapon_test_arena.gd` (the arena's weapon mode, extends `monster_test_arena.gd`). `WeaponDesignerStore.revision_for()`/`recipe_for()` now honor a draft's `revision`, which is how updates publish as revision N+1.

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/weapon_lab_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Weapon lab test failed with exit code $LASTEXITCODE" }
```

## Run the upgrade purchases test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/upgrade_purchases_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Upgrade purchases test failed with exit code $LASTEXITCODE" }
```

The account exposes `purchase_upgrade` and `has_upgrade`. `damage_1` costs 40 and adds 5 weapon damage, `pump_1` costs 60 and adds 25% extraction output, and `spread_1` costs 100 and fires three projectiles at -12, 0, and +12 degrees. Purchases are one-time, outside active runs, and apply at the next run start.

## Run the feedback and onboarding test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/feedback_onboarding_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Feedback and onboarding test failed with exit code $LASTEXITCODE" }
```

The HUD explains movement, starting, tank risk, sealing danger, failure, and retry. Success is shown as banked mana; sealing explicitly remains unsafe until its timer reaches zero. Developer-only damage controls are hidden unless `EncounterController.developer_mode` is enabled. The exported `sealing_duration_setting` supports the authored 2-second seal or a 0-second developer test seal.

## Run the extraction checkpoint

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/extraction_checkpoint_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Extraction checkpoint failed with exit code $LASTEXITCODE" }
```

The checkpoint records fresh-run timing, delayed and instant sealing, pause during sealing, hero and machine failure, retry, and next-run upgrade effects. The evidence report is `work/playtests/extraction.md`.

## Persistent account saves

The runtime stores versioned account progress and an optional active encounter snapshot under `user://account_save.json`. `SessionPersistence` owns the injected store and monotonic/UTC clocks, builds one envelope, and routes controller saves through `SaveStore.save_envelope()`. `SaveStore` reports `fresh`, `loaded`, `recovered`, `unsupported`, or `corrupt` through `get_load_result()`, with write eligibility. Writes go through a temporary file and committed backup; a rejected live save is preserved at `user://account_save.json.recovery`, and unsupported or unrecoverable saves block automatic writes until explicit reset. Tests configure persistence before startup and use injected fixture paths, so they never touch the player save.

Fractional production remains in memory between explicit transitions and five-second checkpoints. Failed saves retain the dirty account and latest snapshot for retry without replaying rewards or purchases; an uncommitted crash can still roll back to the last successful checkpoint.

Combat runs through one controller-owned 60 Hz scheduler. Each fixed step consumes queued input, updates player movement and abilities, advances the weapon and hostile actors/projectiles, applies damage, then advances sealing/extraction and resolves terminal state. Rendering and passive production remain outside that loop. Actor `simulate_tick()` methods no longer run from independent physics callbacks; `EncounterController.tick()` is a compatibility wrapper over the same fixed-step path for integration tests.

Active encounter snapshots use the current schema and validated component records. `RunSnapshot` rejects malformed sections, unknown kinds, invalid references, duplicate IDs, nonfinite values, and unsupported versions before scene mutation. Stateful components expose `capture_snapshot_state()` and `restore_snapshot_state()`; actor and projectile IDs come from the persisted monotonic `spawner.next_id`. Safe legacy IDs can migrate into a separate namespace; unsafe identity or incomplete component state rejects only the active snapshot and preserves banked progress. Restored encounters are paused until explicit resume.

The account owns commissioned wells, hero assignments, upgrades, per-well loadouts, and run identity. `ContentCatalog` supplies the known well, hero, upgrade, and surge definitions. `AccountState.complete_run()` is the single successful-run command: it validates the active run ID and applies payout and commissioning once. `select_well_by_id`, `select_loadout_by_id`, `select_active_hero_by_id`, `assign_guard_by_id`, and `recall_guard_by_well_id` are the controller's UI-independent command boundary. The HUD emits these semantic IDs and does not save or mutate account state.

Passive production uses commissioned, guarded, non-active wells and the injected monotonic/UTC clocks. Offline catch-up is capped at 24 hours, backward clocks grant zero while preserving the later watermark, and failed writes remain pending for retry. Loadouts affect active runs only: Overdrive changes active extraction and pressure timing, while Fortified raises machine integrity to 225 without changing output or pressure.

The collapsed **ACCOUNT** section can clear the live save, temporary file, backup, and recovery copy outside an active extraction or sealing phase. The **NETWORK** section shows guarded production and exposes offline-settlement retry. These controls are adapters over the command and persistence boundaries, not the enforcement layer.

Architecture verification is recorded in `work/reviews/architecture-follow-up.md`. The complete strengthened runner currently discovers 31 tests. A fresh fixture journey progresses, assigns a guard, accrues production, saves, restores paused, resumes, commissions the next well, and completes without touching the player profile.

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/account_saves_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Account save test failed with exit code $LASTEXITCODE" }
```

Verify the production model with:

```powershell
& $godot_console --headless --path '.\\prototype' --script 'res://tests/production_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Production model test failed with exit code $LASTEXITCODE" }
```

Offline catch-up is capped at 24 hours and is not applied to active encounter recovery.

Verify online production manually by unlocking Hero 2, assigning a guard, expanding **NETWORK**, and starting an expedition at the other well. Confirm the guarded site's displayed rate and bank increase while the expedition site shows no passive rate. Pause combat for several seconds and confirm income continues; collapse and reopen **NETWORK** and confirm the bank does not jump. Buy **Pump +25% output** between checks and confirm only future accrual uses the higher rate.

Verify offline production by assigning Hero 2 as a guard, closing the game, advancing the saved test clock or waiting briefly, and restarting. Expand NETWORK and confirm the welcome-back amount matches the displayed rate and elapsed time. Restart again at the same timestamp and confirm no second credit. For a backward clock, confirm zero credit and a preserved watermark. To exercise recovery, make the save location unavailable, restart, restore it, and press **Retry offline settlement** once; confirm the summary clears without awarding twice.

Verify loadouts manually by commissioning Well 2, selecting each site in PREPARATION, and confirming Standard, Overdrive, and Fortified are available. Start an Overdrive run and compare its tank and next-surge timing with Standard; confirm the selector is disabled after starting. Start Fortified and confirm the machine bar maximum increases to 225 while output and pressure timing remain at baseline. Expand NETWORK before and during each run to confirm passive rates are unchanged.

Known limitations remain: checkpoint recovery can roll back to the latest committed save after a crash; local wall-clock time is user-editable; the project uses a Godot 4.8 development build; and manual visual, input, collision, window-focus, and readability checks have not been performed in this environment.
