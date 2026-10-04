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
- To add a monster, add it to `MONSTERS` and `DEFAULTS` in `monster_stats.gd`, and add its sprite to `SideViewVisualConfig.ASSETS`. Creatures made in the **Creature Lab** (below) are added from `data/creatures/index.json` with no code changes.

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

The lab opens on a bigger 1600x900 canvas (and makes the window bigger if your screen has room), then puts the game's 1280x720 back when you leave or open the arena. Filter the list by weapon category with the dropdown; **Edit** next to it adds, renames and removes categories (the same list as the weapon types in section 4, saved in `data/weapons/type_clips.json`).

**Green check.** Every weapon tile has a round check on the right: click it to tick a weapon as done (animated and in the game), click again to clear it. The same check is **Mark done** in section 2. It's just your own note: saved right away in `data/weapons/lab_marks.json`, no publishing needed.

1. **Art.** Pick an image from `art/ui-items/Weapons/`, or **Import image...** to copy one in from anywhere (PNG, JPG, WebP). Choose a cutout and press **Cut out & prepare**:
   - **Auto** keeps a PNG's own transparency, otherwise uses Trellis 2.
   - **ComfyUI Trellis 2** uploads the image to your local ComfyUI and runs `art/side-view/workflows/06_cutout.api.json` (`Trellis2RemoveBackground`). The URL comes from `tools/asset_pipeline/config.json` (`concept_url`) or defaults to `http://127.0.0.1:8188`; edit it in the lab and press **Check**.
   - **Solid background** removes a flat backdrop locally, no ComfyUI needed. Raise **Tolerance** if a halo is left.
   - **Already transparent** uses the PNG's alpha as is.
   The lab trims the cutout and writes the world sprite (256 px tall), the 256 px icon, and review images to `art/weapons/runs/<job_id>/` in the same format as `tools/weapon_pipeline/pipeline.py`, so no Python or PowerShell is needed. Click the world sprite to set the grip.
2. **Details & stats.** At the top, two live previews drawn by the game's own hero code: **Attack loop** (the hero attacking with this weapon, using the animation it actually plays) and **Holding** (a still of the hero holding it). Under them the readiness check says what the weapon still needs to look right in the game: art, a grip, a weapon type, an attack animation that shows this weapon (the hero's normal attack, a missing type default, or a type default with a different weapon painted into its frames all count as not animated yet), and whether it's in the game with these edits (`scripts/model/weapon_readiness.gd`). Below that: name (the id is made from it and locks once the weapon is in the game), description, behavior, **base damage** and **base attacks per second** (the weapon's own baseline, saved as `base_stats` on the revision), plus bonus damage, attack speed, and projectile speed. Research ranks add on top of a weapon's base, and item bonus caps are relative to it. Weapons without `base_stats` keep the global `Balance.WEAPON_DAMAGE` / `WEAPON_INTERVAL` baseline (10 damage, 1.67 attacks per second). The line under the stats shows the resolved in-game numbers and warns when an item cap applies (+50% damage, +30% attack speed).
3. **Placement.** Grip, scale, rotation, hand offset, and facing.

4. **Attack animation.** How the hero attacks with the weapon.
   - **Weapon type.** Pick Axe, Sword, Hammer, Spear, Dagger, Club, Staff, Gun, Bow, or add your own (e.g. "great sword"). New weapons guess their type from the name.
   - **Where the animation comes from:** *Use the Axe default* (every weapon of the type shares one animation; new weapons start here), *Own animation* (this weapon only), or *Hero's normal attack*.
   - **Make animation...** opens the clip importer (below). When you save, choose **Save as the Axe default (all axe weapons)** or **Save for this weapon only**. A weapon with its own animation also gets **Make this the Axe default**. **Edit...** reopens whichever animation is in use (editing a default saves back to the default); **Remove** removes the weapon's own animation, or the type's default.
   - Type defaults are saved in `data/weapons/type_clips.json`, with each default's sheet in `assets/weapons/_types/<type>/<n>/clip.png` (a new folder each time it changes; the previous file is kept in `data/weapons/history/`). Weapons that use their type's default pick up a new default immediately, without republishing. Revisions store `weapon_type` and `clip_source` (`type` / `own` / `none`); `scripts/model/weapon_types.gd` resolves which animation plays.
   - The old swing editor is gone. Weapons that already have a `swing` keep it, and weapons without an animation use the built-in swing.

   - **Your weapon in the hero's hands.** For an animation where each weapon shows its own art (one animation for every axe, for example): make a weapon-free version of the pose sheet (in ChatGPT, edit the sheet: "remove the weapon from every pose, keep everything else the same, hands closed as if gripping a handle"). In the importer, cut out the weapon-free sheet, tick **This sheet has no weapon: draw each weapon's own art in the hands**, and load **Sheet with weapon...** (the original) as a faint ghost. Then with **Place weapon**, click the hand gripping the weapon, then the far end of the ghost's weapon (the tip of the head or blade); it moves on to the next frame by itself. Drag the green (grip) and amber (far end) dots to adjust, **Move ghost** lines up the ghost (Shift for every frame), **Behind the body** draws the weapon behind the hero on that frame, and **Same as previous** copies the last frame's placement. The weapon you're editing is drawn in the hands as you go.
     In the game each weapon's own picture is placed with its grip (Placement section) in the hand and its far end (the point of the picture farthest from the grip) along the line you clicked, sized to that line's length. **Auto-place all frames** (after loading the sheet with the weapon) does this for you: it compares the two sheets, lines the ghost up, puts the green dot in the fist and the orange dot at the weapon's far end, ticks Behind the body where the weapon is hidden, and lists frames worth a look; **This frame** redoes just one. **Front hand over the weapon** (on by default) draws the gripping fist on top of the weapon so the fingers wrap the handle; it's made automatically around the grip, **Hand brush** paints it (Shift erases), **Auto hand** redoes it. It's saved as a second sheet (`hand.png` next to `clip.png`) and shown only on frames where the weapon is in front. Each weapon can fine-tune this in section 4: **Angle**, **Size**, **Flip** (blade on the other side of the handle), and **Set far end...** (click the head or blade tip on the world sprite if the automatic far end is wrong; right-click the button to go back to automatic). In the importer's line-up view the mouse wheel zooms, right-drag moves the view, and **Fit** (F) shows the whole frame again. Stored as `attack_clip.mode = "hero_weapon"` with a per-frame `track` ({grip, angle, length, behind} in cell pixels) and `hand_fit` on the weapon's revision.

   **Clip importer.** A drawn attack animation for the weapon: a pose sheet (like a ChatGPT animation sheet), separate frame images, or a video. the importer:
   - **Source.** *Pose sheet...* takes one image with every pose in a row; you don't need to cut it into single frames. Captions, borders (even a screenshot's dark edge), and the ground line are ignored. *Frames...* takes one image per frame, played in file-name order. *Video...* (MP4, WebM, MOV, GIF) needs ffmpeg: on PATH, or point the ffmpeg box at `ffmpeg.exe` (ComfyUI often has one under `python_embeded\Lib\site-packages\imageio_ffmpeg\binaries`). Set the fps (10-15 is plenty), start time, and max frames.
   - **Slice** (sheets). The importer finds the pose row and cuts between poses at the emptiest columns. If poses touch, set **Frames** to the number of poses. Drag the magenta cuts and green top/bottom lines, or give the selected box its own left/right edge (boxes may overlap when a weapon reaches into the next pose).
   - **Cut out.** *Solid background* works offline for flat backdrops. *ComfyUI Trellis 2* runs one cutout job per frame. *Drop bits of neighbouring poses* removes loose pieces touching a box's side; *Min piece* removes dust and motion arrows; *Clear background in gaps* empties holes between arms and handle.
   - **Line up & clean.** Sheets line up each pose on its feet; videos keep their positions. The green mark is the ground point (weapon mode: the grip), the blue ghost is the previous frame. Drag a frame to move it, click to put a point on the mark, arrow keys nudge (Shift = 10 px), Q/E step frames, Space plays. The **Eraser** paints away stray bits; **Re-cut frame** undoes it.
   - **Timing & attacks.** Hold time per frame. Tick **Hit frame** where the weapon connects. For a combo, tick **Starts a new attack** on the first frame of each later attack: the hero alternates between the attacks and starts over after a pause. For melee weapons the frames before the hit are sped up or slowed so the hit frame shows exactly when damage lands (40% of the attack interval); the hit and follow-through keep their own pace. The summary warns when an attack runs longer than the time between attacks.
   - **Use as.** *Hero attack*: the frames show the whole hero; while the weapon is equipped they replace the hero's attack animation and the held weapon hides (effects still show). *Weapon frames*: the frames show only the weapon and replace its picture during the swing. **Hero height** (measured from frame 1) scales the clip to the hero's in-game height; **Scale** fine-tunes it.
   Work is saved under `art/weapons/clips/<weapon id>/<clip>/` (source, cut frames, `project.json`, packed sheet), so **Edit clip...** reopens it. Publishing copies the sheet to `assets/weapons/<id>/<n>/clip.png` and saves the clip on the revision as `attack_clip` (`scripts/model/weapon_clip.gd`).

   Tips for ChatGPT sheets: ask for "a single row of N poses, evenly spaced with clear gaps between them, plain flat light background, no text, no labels, no arrows, same scale in every pose, character facing right, feet on the same ground line". Gaps mean no manual cleanup; effects like slash trails are fine as long as they stay inside a pose's slot.

5. **Effects.** Flipbooks that play during the attack: slash trails, sparks, impact rings, glows, muzzle flashes. Up to 4 per weapon.
   - **Get a sheet.** **Generate** makes a built-in one (Slash arc, Spark burst, Impact ring, Glow pulse, Muzzle flash) in the color you pick, so you can try effects before making art. **Import sprite sheet...** takes a ready-made sheet (set Frames and Columns first; columns = frames for a single strip). **Import frames...** takes separate PNGs (for example frames exported from a ComfyUI video), sorts them by file name and packs them into one strip. Sheets are saved under `art/weapons/effects/<weapon id>/`.
   - **When it fires.** *Wind-up starts*, *Strike starts*, *Hit lands* (melee: the damage moment at 40% of the attack interval; ranged: the moment the shot fires), *Strike ends*, or *Custom* (a fraction of the swing). Wind-up and strike times come from the weapon's swing (the built-in one unless it has its own). Check timing in the arena with slow motion.
   - **Where it appears.** Anchor is a point on the weapon image: type it or press **Pick anchor on sprite** and click the world sprite. **Follow weapon** rides along with the blade (trails, glows); off, it stays where it spawned (sparks, impacts). **Turn with weapon**, size, extra rotation, offset, FPS, opacity, and additive (glowing) blend.
   - Publishing copies each sheet into `assets/weapons/<id>/<n>/effects/` and saves the list on the revision as `effects` (`scripts/model/weapon_effects.gd`). The hero plays them in the encounter and in the arena (`scripts/game/weapon_effect.gd`). Slow motion in the arena is the easiest way to check timing.

**Hero animations...** (top right) replaces the hero's own art for any animation state (**idle**, **walk**, **attack**, **dash**, **hurt**, **death**, **jump**, **fall**, **spawn**, **wind-up**; see *Animation states* below). It opens the clip importer in hero mode: open a pose sheet (side view, facing right, **no weapon**: empty hands closed as if gripping, since weapons are drawn into them), frames or a video, cut out, check the line-up (walk and idle default to *Line up the body*, which keeps the torso still while the legs swing), set the frame timing, pick **Hero's: Idle / Walk / Attack** and save. *Only the selected frame* makes a still pose (the idle from a walk frame, for example). `scripts/model/hero_animations.gd` scales the frames to the hero's reference height, puts the feet on its shared anchor, and writes `assets/side-view/animations/hero_<name>/atlas.png`, `animation.tres` and `manifest.json` in the existing layout (the previous files are copied to `art/side-view/backups/` first). The lab previews and the arena use the new art straight away; click back into the Godot editor before the next run so it imports the new atlas. The Holding preview has a **Walk** box to check a weapon while walking. The weapon socket (`WEAPON_SOCKET_LOCAL` in `player.gd`) sits on the new art's front fist.

**Animation states.** `SideViewActorVisual` (`scripts/game/side_view_actor_visual.gd`) plays every actor's states from `SideViewVisualConfig.STATES`. Locomotion (idle, walk, dash, jump, fall) is picked each tick from what the owner reports (`set_locomotion`, `set_dashing`, `set_airborne`); actions (attack, windup, hurt, spawn, death) play once over it, by priority death > spawn > attack/windup > hurt, then hand back. A state uses the clip in `assets/side-view/animations/<folder>_<state>/` (`animation.tres`, `atlas.png`, `manifest.json`, the layout the importer and `tools/animation_pipeline` already write) when it exists, found on first use, so adding e.g. `pursuer_hurt/` needs no code. Without one it falls back: dash plays the walk 1.8x faster with afterimages, windup plays the attack (ranged monsters' old behaviour), jump/fall use idle, hurt is a short red tint, spawn a fade-in, death a fade-and-sink. Wiring: monsters fade in when spawned, flash on hits, telegraph with `play_windup()` (with their own wind-up clip, the attack clip plays when the shot fires), and leave their body behind to play death (`release_death_visual`); the hero flashes on hits, plays death at 0 health, shows dash while dashing and jump/fall in the air, and `reset_motion()` revives it on retry. All of it is presentation only: hit tests, timings and saves are unchanged. `tests/animation_states_test.gd` covers it.

**Test in arena** opens the Monster Test Arena with the hero holding the weapon. The hero is invincible and attacks with the game's rules (ranged shots at the nearest monster within 12 units, or melee strikes in reach in the facing direction). Weapon hits show as white damage numbers, with a dealt/DPS/hits/kills meter. Monsters can't die unless you untick **Monsters can't die**. For animation work: **Swing** (`E`), **Loop attack animation**, and slow motion (`T` or the speed menu, down to 0.1x). Edit placement on the right or drag the weapon with the mouse; `A`/`D` move, `F` flips. `Esc` returns to the lab with the placement carried over.

**Add to game** publishes through `WeaponPublisher` (immutable revision under `data/weapons/<id>/<n>/`, assets under `assets/weapons/<id>/<n>/`, `data/weapons/index.json` updated, previous index kept in `history/`). For a weapon already in the game the button reads **Publish update (rN)** and publishes the next revision; it refuses when nothing changed. **Drops as loot** registers the weapon in the `foundry_physical_v1` table, and publishing an update re-registers it so drops follow the new revision. **Save draft** keeps work in progress in `data/designer/drafts/lab.<id>.json`.

**Remove** (bottom left) takes the selected weapon out of the game after a confirmation. Its index entry moves to a `retired` list in `data/weapons/index.json`, its loot drops are turned off, and its lab draft is deleted. Nothing else is deleted: revision folders and assets stay on disk, and players who already own one keep it (retired weapons are still registered so saves load, but they can't drop or be granted). Tick **Show removed** in the list and press **Restore to game** to bring one back at the revision it had. A removed weapon's id can't be reused by a new weapon. For a weapon with unpublished edits, the dialog also offers **Discard draft only**. For a weapon that was never added to the game the button reads **Delete draft** and just deletes the draft (the source image and prepared art stay).

Notes:

- Behavior only switches between ranged and melee in the encounter today. Fan and lance spreads come from research, not the weapon.
- The encounter fires every shot at the base projectile speed, so the projectile speed bonus is saved on the weapon but has no effect yet.

Files: `scenes/tools/weapon_lab.tscn`, `scripts/tools/weapon_lab.gd` (UI and publishing), `scripts/tools/weapon_lab_showcase.gd` (section 2 previews), `scripts/tools/weapon_lab_check.gd` (the green check), `scripts/tools/weapon_lab_art.gd` (cutouts and run folders), `scripts/tools/weapon_lab_effects.gd` and `scripts/tools/weapon_effect_art.gd` (effects panel and sheets), `scripts/tools/weapon_clip_importer.gd` and `scripts/tools/weapon_clip_import.gd` (clip importer UI and engine), `scripts/tools/comfy_cutout.gd` (ComfyUI client), `scripts/tools/weapon_test_arena.gd` (the arena's weapon mode, extends `monster_test_arena.gd`). `WeaponDesignerStore.revision_for()`/`recipe_for()` now honor a draft's `revision`, which is how updates publish as revision N+1.

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/weapon_lab_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Weapon lab test failed with exit code $LASTEXITCODE" }
```

## Creature Lab (dev tool)

Turns creature concept art into animated monsters in the Monster Encyclopedia, using the MiniMax H3 ComfyUI workflow (the same graph as `tools/animation_pipeline/workflows.py`). Debug builds only: choose **CREATURE LAB** on the title screen. No Python or PowerShell is needed.

**Concept art** is read from `art/creatures/enemies/<family>/`, one folder per creature family, one image per evolution stage named `<name>_stage_<n>.png` (images without a stage number are listed as *Base*). The list on the left groups them by family and sorts by stage; **Rescan** picks up new files. Each image becomes its own creature (id from the file name, e.g. `shell_walker_stage_2`).

**ComfyUI** defaults to `http://192.168.1.102:8188` (the GPU machine; start ComfyUI there with `--listen`). Edit the URL in the header and press **Check**: it confirms the `MiniMaxH3ImageToVideo` node, the H3 model files and Trellis 2. The URL is remembered in `user://creature_lab_settings.json`.

1. **Creature.** Name, **Behaves as** (Hunter = pursuer, Breaker, Ranged: which built-in monster's AI and starting stats it uses), which way the concept faces (game art faces right, so left-facing concepts are mirrored), in-game height and the encyclopedia description.
2. **Reference.** Cuts the concept out (**Auto**/**Flat background** work offline and cope with a thin frame line or screenshot bars; **ComfyUI Trellis 2** for busy backgrounds; **PNG transparency**) and places it on the 576 px H3 canvas exactly like `prepare.py reference()` (70% width / 72% height, feet at y 495, flat grey). Click the picture to move the feet line. Writes `art/creatures/references/<id>/reference.png`, `reference.json`, `cutout.png`, and the in-game still `assets/side-view/creatures/<id>.png`.
3. **Animations.** Pick a state (idle, walk, attack, wind-up, hurt, death, spawn). The prompt box starts from a template for that state; edit it freely. **Generate take** uploads the reference, queues the H3 graph with your prompt, seed, length and steps, waits (status shows the queue), and downloads every decoded frame. **End on the reference pose** gives H3 the reference as the last frame as well (on for loops, attack and hurt; off for death, wind-up and spawn, when the installed node allows an empty last frame). Takes are listed on the right with a 12 fps preview; **Use its prompt & seed** loads a take's settings to tweak or recreate it, and **Stop waiting** / **Collect frames** let a long render finish in the background. **Install as <state>** samples the frames (FPS, From/To trim), cuts each one out (grey background locally, or Trellis 2 per frame), puts them all in one union crop around the shared feet line and writes `assets/side-view/animations/<id>_<state>/` (`atlas.png`, `animation.tres`, `manifest.json`, the layout every actor uses, previous files backed up to `art/side-view/backups/`). It plays straight away; click back into the editor so Godot imports the atlas.
4. **Encyclopedia.** **Add to encyclopedia** lists the creature next to the built-in monsters, with stats starting from its behavior's monster. Tune them in the encyclopedia (**Encyclopedia** in the header opens it over the lab) and **Save to game data** as usual; they go into `data/monster_stats.json` under the creature's id.

**The database.** Everything needed to recreate a clip is kept under `data/creatures/` (commit it with the art):
- `index.json`: every creature in development (name, family, stage, concept and its hash, behavior, facing, height, reference calibration, installed take per state, whether it's in the encyclopedia).
- `<id>/prompts.json`: per state, every prompt version ever used (text, hash, date) and which one is current. Saving identical wording reuses its version number.
- `<id>/takes/<take>.json`: one per generation: state, prompt and its version, seed, seconds, steps, size, model files, sampler, reference path + hash, ComfyUI server, upload name and prompt id, the exact API graph submitted, every downloaded frame with its hash, status/errors, and each install (fps, trim, cutout). The graph is also saved as `art/creatures/animations/<id>/<take>/api.json` (load or queue it in ComfyUI directly), next to the `masters/` frames and the cut frames.

**In the game.** `scripts/model/creature_registry.gd` (`CreatureRegistry`) reads `data/creatures/index.json`. `MonsterStats.monsters()` returns the built-ins plus encyclopedia creatures (`MONSTERS` is still the built-in list), `MonsterStats.archetype(id)` names the behavior, and `SideViewVisualConfig.asset_for(id)` builds a creature's art from its reference and clips, so new creatures need no code. A `DefenseEnemy` with `monster_override = "<id>"` (set before `setup()`) fights with its archetype's AI but the creature's art and stats; spawning creatures in levels and the Monster Test Arena is the next step.

Files: `scenes/tools/creature_lab.tscn`, `scripts/tools/creature_lab.gd` (UI), `scripts/tools/creature_lab_art.gd` (cutouts, reference, frame sampling, clip install), `scripts/tools/comfy_animation_client.gd` (ComfyUI client that accepts LAN servers), `scripts/model/creature_animation.gd` (H3 graph and prompt templates), `scripts/model/creature_registry.gd` (database).

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/creature_lab_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Creature lab test failed with exit code $LASTEXITCODE" }
```

The test runs the whole flow (reference, prompt versions, generate, install, encyclopedia) against a stand-in ComfyUI, writing only under `user://creature_lab_test/`.

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
