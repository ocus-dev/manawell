class_name SideViewActorVisual
extends Node2D

## Draws one side-view actor (hero, monster, harvester) and plays its
## animation states. Presentation only: nothing here feeds back into the
## simulation, hit tests or saves.
##
## States (SideViewVisualConfig.STATES):
##   locomotion, picked every tick from the flags the owner sets:
##     idle, walk, dash, jump, fall
##   actions, one-shots that play over locomotion and then hand back:
##     attack, windup, hurt, spawn, death
## Each state plays the clip in assets/side-view/animations/<folder>_<state>/
## when the actor has one. Without it, the state falls back (FALLBACKS):
## dash runs the walk faster, windup plays the attack (the old behaviour),
## jump/fall use idle, and hurt / spawn / death use code-driven effects
## (red flash, fade in, fade and sink). New clips drop in with no code changes.

const ConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")

const LOCOMOTION_STATES := ["idle", "walk", "dash", "jump", "fall"]
const ACTION_STATES := ["attack", "windup", "hurt", "spawn", "death"]
## Which clip a state borrows when the actor has none of its own (first that
## exists wins). An empty list means the state is code-driven only.
const FALLBACKS := {
    "idle": ["walk"],
    "walk": ["idle"],
    "dash": ["walk", "idle"],
    "jump": ["fall", "idle"],
    "fall": ["jump", "idle"],
    "windup": ["attack"],
    "attack": [],
    "hurt": [],
    "spawn": [],
    "death": [],
}
## Higher wins: an action only replaces a running action of lower priority.
const ACTION_PRIORITY := {"hurt": 1, "attack": 2, "windup": 2, "spawn": 3, "death": 4}

## Held weapons tilt with the arm while standing and walking: the fist's
## swing around a shoulder this far above it (share of the reference height),
## times HAND_TILT_AMOUNT, at most HAND_TILT_MAX degrees.
const HAND_TILT_ARM := 0.3
const HAND_TILT_AMOUNT := 1.0
const HAND_TILT_MAX := 15.0

## Dash borrowing the walk clip plays it this much faster.
const DASH_FALLBACK_SPEED := 1.8
## Afterimages while dashing.
const AFTERIMAGE_INTERVAL := 0.035
const AFTERIMAGE_LIFETIME := 0.18
const AFTERIMAGE_COLOR := Color(0.55, 0.9, 1.0, 0.45)
## Hurt: a short tint over whatever is showing.
const HURT_FLASH_SECONDS := 0.14
const HURT_FLASH_COLOR := Color(1.0, 0.45, 0.4)
## Spawn without a clip: fade in.
const SPAWN_FADE_SECONDS := 0.25
## Death without a clip: fade out while sinking a little.
const DEATH_FADE_SECONDS := 0.5
const DEATH_SINK_PIXELS := 6.0
## A wind-up clip that finishes holds its last frame until the attack, but
## never longer than this.
const WINDUP_HOLD_LIMIT := 2.0

var asset_id := ""
var ground_local_y := 40.0
var facing := 1
var scale_multiplier := 1.0
var base_scale := 1.0
var sprite: Sprite2D
## One AnimatedSprite2D per state that has frames (made on demand).
## idle/walk/attack always exist so older callers and tests can reach them.
var state_sprites := {}
var idle_sprite: AnimatedSprite2D
var walk_sprite: AnimatedSprite2D
var attack_sprite: AnimatedSprite2D
var moving := false
var dashing := false
var airborne := false
var vertical_velocity := 0.0
var animation_offsets := {}
## Front fist per frame (relative to the feet, source canvas px) for clips
## whose manifests have one. Held weapons follow it.
var hand_tracks := {}
## Front fist cut out of each frame (hand_atlas.png), per state sprite. Drawn
## over a held weapon so the fingers close around the handle.
var hand_atlases := {}
var fist_sprite: Sprite2D
## The owner turns this on while a weapon is held (see set_fist_overlay).
var fist_overlay_enabled := false
var animation_scale := 1.0
var animation_source_anchor := Vector2.ZERO
var static_offset := Vector2.ZERO

## The state showing now, and the action (if any) holding it.
var current_state := "idle"
var action_state := ""
var _action_sprite: AnimatedSprite2D
var _action_elapsed := 0.0
var _hurt_flash := 0.0
var _spawn_fade := 0.0
var _death_elapsed := -1.0
var _free_after_death := false
var _death_base_position := Vector2.ZERO
var _afterimage_clock := 0.0
var _afterimages: Node2D

## Hero-mode weapon attack clip (WeaponClip). While set, play_attack() plays
## the clip's next combo attack instead of the baked attack animation.
var attack_clip: Dictionary = {}
var attack_clip_texture: Texture2D
var clip_sprite: Sprite2D
## hero_weapon clips: the gripping hand, drawn over the held weapon.
var hand_sprite: Sprite2D
var clip_hit_seconds := 0.0
var clip_combo_window := 1.0
var clip_attack_index := 0
var clip_line: Dictionary = {}
var clip_elapsed := 0.0
var clip_since_start := INF
var clip_playing := false
var clip_frame := -1
var clip_attacks_played := 0

## A weapon's own idle / walk (WeaponClip, looping), keyed by state. While
## the hero stands or walks, the clip shows instead of the hero's own art
## (dash borrows the walk, sped up). See set_pose_clip().
var pose_clips := {}
var pose_sprite: Sprite2D
var pose_hand_sprite: Sprite2D
## The pose state showing now ("" when none), its clip and frame.
var pose_state := ""
var pose_clip: Dictionary = {}
var pose_frame := -1
var pose_time := 0.0
var pose_speed := 1.0

signal attack_started
signal attack_finished
## Any change of the state showing (locomotion or action).
signal state_changed(state: String)
## The death animation (clip or fade) is over.
signal death_finished

func _ready() -> void:
    if sprite != null:
        return
    sprite = Sprite2D.new()
    sprite.name = "Sprite"
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(sprite)
    idle_sprite = _ensure_state_sprite("idle")
    walk_sprite = _ensure_state_sprite("walk")
    attack_sprite = _ensure_state_sprite("attack")
    clip_sprite = Sprite2D.new()
    clip_sprite.name = "ClipSprite"
    clip_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    clip_sprite.region_enabled = true
    clip_sprite.visible = false
    add_child(clip_sprite)
    hand_sprite = Sprite2D.new()
    hand_sprite.name = "HandSprite"
    hand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    hand_sprite.region_enabled = true
    hand_sprite.visible = false
    # Above the held weapon (weapon socket z 2 on the hero, this visual z 1).
    hand_sprite.z_index = 2
    add_child(hand_sprite)
    fist_sprite = Sprite2D.new()
    fist_sprite.name = "FistSprite"
    fist_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    fist_sprite.region_enabled = true
    fist_sprite.visible = false
    # Over the held weapon, like the attack clip's hand.
    fist_sprite.z_index = 2
    add_child(fist_sprite)
    pose_sprite = Sprite2D.new()
    pose_sprite.name = "PoseSprite"
    pose_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    pose_sprite.region_enabled = true
    pose_sprite.visible = false
    add_child(pose_sprite)
    move_child(pose_sprite, clip_sprite.get_index())
    pose_hand_sprite = Sprite2D.new()
    pose_hand_sprite.name = "PoseHandSprite"
    pose_hand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    pose_hand_sprite.region_enabled = true
    pose_hand_sprite.visible = false
    pose_hand_sprite.z_index = 2
    add_child(pose_hand_sprite)
    # A plain Node2D (no get_rect) so callers that look for the visible body
    # among this node's children never pick up an afterimage.
    _afterimages = Node2D.new()
    _afterimages.name = "Afterimages"
    add_child(_afterimages)

func _ensure_state_sprite(state: String) -> AnimatedSprite2D:
    if state_sprites.has(state):
        return state_sprites[state]
    var animated := AnimatedSprite2D.new()
    animated.name = state.capitalize().replace(" ", "") + "Sprite"
    animated.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    animated.visible = false
    animated.animation_finished.connect(_on_state_animation_finished.bind(state))
    animated.frame_changed.connect(_update_fist_overlay)
    add_child(animated)
    # Keep the clip/hand sprites drawn above the state sprites.
    if clip_sprite != null:
        move_child(animated, clip_sprite.get_index())
    state_sprites[state] = animated
    return animated

func configure(new_asset_id: String, local_ground_y: float = 40.0) -> bool:
    if sprite == null:
        _ready()
    var asset := ConfigScript.asset_for(new_asset_id)
    if asset.is_empty():
        return false
    asset_id = new_asset_id
    ground_local_y = local_ground_y
    var visible_bounds: Rect2 = asset["visible_bounds"]
    base_scale = float(asset["initial_visible_height"]) / visible_bounds.size.y
    sprite.texture = asset["texture"]
    static_offset = Vector2(sprite.texture.get_size()) * 0.5 - Vector2(asset["ground_anchor"])
    # All clips use the same prepared source canvas and reference-pose calibration.
    # Clip union bounds describe the space needed for motion, not the actor's size.
    animation_scale = float(asset["initial_visible_height"]) / float(asset["animation_reference_height"])
    animation_source_anchor = asset["animation_source_anchor"]
    animation_offsets.clear()
    hand_tracks.clear()
    hand_atlases.clear()
    var animation_folder: String = asset.get("animation_folder", "")
    for state in ConfigScript.STATES:
        var frames: SpriteFrames = ConfigScript.frames_for(asset, state)
        if frames == null and not state_sprites.has(state):
            continue
        _configure_animation_sprite(_ensure_state_sprite(state), frames, state, "%s_%s" % [animation_folder, state])
    _clear_action()
    revive()
    _apply_visual_transform()
    return true

func _configure_animation_sprite(animation_sprite: AnimatedSprite2D, frames: Variant, animation_name: String, manifest_folder: String) -> void:
    animation_sprite.stop()
    animation_sprite.sprite_frames = null
    animation_sprite.visible = false
    animation_sprite.speed_scale = 1.0
    if frames == null:
        return
    animation_sprite.sprite_frames = frames
    animation_sprite.animation = StringName(animation_name)
    var manifest: Dictionary = ConfigScript.manifest_for(manifest_folder)
    var cell: Array = manifest.get("cell_size", [0.0, 0.0])
    var crop: Array = manifest.get("union_crop", [0.0, 0.0, 0.0, 0.0])
    var anchor := animation_source_anchor - Vector2(float(crop[0]), float(crop[1]))
    animation_offsets[animation_sprite] = Vector2(float(cell[0]), float(cell[1])) * 0.5 - anchor
    var fists: Variant = manifest.get("hand_track", [])
    if fists is Array and not fists.is_empty():
        hand_tracks[animation_sprite] = fists
        var hand_atlas: Texture2D = ConfigScript.hand_atlas_for(manifest_folder)
        if hand_atlas != null:
            hand_atlases[animation_sprite] = hand_atlas

# ---------- what the owner tells the visual ----------

func set_locomotion(is_moving: bool) -> void:
    moving = is_moving
    _refresh_locomotion()

## Dash active (hero). Plays dash, or the walk sped up, with afterimages.
func set_dashing(is_dashing: bool) -> void:
    if dashing == is_dashing:
        return
    dashing = is_dashing
    _afterimage_clock = 0.0
    _refresh_locomotion()

## Off the ground (hero jumps). Negative velocity is rising (jump), positive falling.
func set_airborne(is_airborne: bool, new_vertical_velocity: float = 0.0) -> void:
    airborne = is_airborne
    vertical_velocity = new_vertical_velocity
    _refresh_locomotion()

## The attack: the weapon clip in hero mode, the baked attack clip otherwise.
func play_attack() -> void:
    if _death_elapsed >= 0.0:
        return
    if has_attack_clip():
        _play_clip_attack()
        return
    if attack_sprite == null or attack_sprite.sprite_frames == null:
        return
    if action_state == "attack" and attack_sprite.visible and attack_sprite.is_playing():
        return
    if not _start_action("attack", attack_sprite):
        return
    attack_started.emit()

## The telegraph before an attack. Returns true when the actor has a wind-up
## clip of its own; then the owner should call play_attack() when the attack
## lands. Without one this plays the attack instead (the old behaviour) and
## returns false.
func play_windup() -> bool:
    if _death_elapsed >= 0.0:
        return false
    if not has_state("windup"):
        play_attack()
        return false
    _start_action("windup", state_sprites["windup"])
    return true

## Took damage: a short tint, plus the hurt clip when there is one and
## nothing more important is playing.
func play_hurt() -> void:
    if _death_elapsed >= 0.0:
        return
    _hurt_flash = HURT_FLASH_SECONDS
    if has_state("hurt") and not clip_playing:
        _start_action("hurt", state_sprites["hurt"])
    _apply_modulate()

## Entering the arena: the spawn clip, or a fade in.
func play_spawn() -> void:
    if _death_elapsed >= 0.0:
        return
    if has_state("spawn"):
        _start_action("spawn", state_sprites["spawn"])
    else:
        _spawn_fade = SPAWN_FADE_SECONDS
    _apply_modulate()

## Dying: the death clip (held on its last frame), or a fade and sink.
## free_when_done: queue_free() this node afterwards (for corpses that have
## been detached from their actor).
func play_death(free_when_done: bool = false) -> void:
    if _death_elapsed >= 0.0:
        _free_after_death = _free_after_death or free_when_done
        return
    stop_attack_clip(false)
    _free_after_death = free_when_done
    _death_elapsed = 0.0
    _death_base_position = position
    _hurt_flash = 0.0
    _spawn_fade = 0.0
    dashing = false
    if has_state("death"):
        _start_action("death", state_sprites["death"], true)
    _apply_modulate()

## Back to normal after a death (a retried run reuses the hero): stops every
## effect and shows locomotion again.
func revive() -> void:
    if _death_elapsed >= 0.0:
        position = _death_base_position
    if action_state == "death":
        _clear_action()
    _death_elapsed = -1.0
    _free_after_death = false
    _hurt_flash = 0.0
    _spawn_fade = 0.0
    dashing = false
    if _afterimages != null:
        for ghost in _afterimages.get_children():
            ghost.queue_free()
    _refresh_locomotion(true)
    _apply_modulate()

func is_dying() -> bool:
    return _death_elapsed >= 0.0

## True when the actor has its own clip for `state` (not a fallback).
func has_state(state: String) -> bool:
    return state_sprites.has(state) and (state_sprites[state] as AnimatedSprite2D).sprite_frames != null

# ---------- state selection ----------

func _locomotion_state() -> String:
    if dashing:
        return "dash"
    if airborne:
        return "jump" if vertical_velocity < 0.0 else "fall"
    return "walk" if moving else "idle"

## The sprite that shows `state`: its own clip, else the first fallback that
## has one. null when nothing fits.
func _sprite_for_state(state: String) -> AnimatedSprite2D:
    if has_state(state):
        return state_sprites[state]
    for fallback in FALLBACKS.get(state, []):
        if has_state(fallback):
            return state_sprites[fallback]
    return null

func _refresh_locomotion(force: bool = false) -> void:
    if sprite == null:
        return
    if not action_state.is_empty() or clip_playing:
        return
    _show_locomotion_sprite(force)

func _show_locomotion_sprite(_force: bool = false) -> void:
    if clip_sprite != null:
        clip_sprite.visible = false
    var state := _locomotion_state()
    if _show_pose(state):
        _set_current_state(state)
        return
    var shown := _sprite_for_state(state)
    for animated in state_sprites.values():
        if animated != shown:
            animated.visible = false
    sprite.visible = shown == null
    if shown != null:
        shown.visible = true
        shown.speed_scale = DASH_FALLBACK_SPEED if state == "dash" and not has_state("dash") else 1.0
        if not shown.is_playing():
            shown.play()
    _set_current_state(state)

func _start_action(state: String, animated: AnimatedSprite2D, force: bool = false) -> bool:
    if animated == null or animated.sprite_frames == null:
        return false
    if not force and not action_state.is_empty() and action_state != state:
        if int(ACTION_PRIORITY.get(state, 0)) < int(ACTION_PRIORITY.get(action_state, 0)):
            return false
    if clip_playing and state != "death":
        return false
    # The action this one replaces must not finish later while hidden.
    if _action_sprite != null and _action_sprite != animated:
        _action_sprite.stop()
    action_state = state
    _action_sprite = animated
    _action_elapsed = 0.0
    sprite.visible = false
    _hide_pose()
    for other in state_sprites.values():
        if other != animated:
            other.visible = false
    animated.visible = true
    animated.speed_scale = 1.0
    animated.frame = 0
    animated.play(animated.animation)
    _set_current_state(state)
    return true

func _clear_action() -> void:
    action_state = ""
    _action_sprite = null
    _action_elapsed = 0.0

func _on_state_animation_finished(state: String) -> void:
    if state == "attack":
        _on_attack_animation_finished()
        return
    if state != action_state:
        return
    match state:
        "death":
            _finish_death()
        "windup":
            # Hold the last frame until play_attack() (or the hold limit).
            pass
        _:
            _clear_action()
            _show_locomotion_sprite()

func _on_attack_animation_finished() -> void:
    if action_state == "attack" or action_state.is_empty():
        _clear_action()
        _show_locomotion_sprite()
    attack_finished.emit()

func _finish_death() -> void:
    death_finished.emit()
    if _free_after_death:
        queue_free()

func _set_current_state(state: String) -> void:
    if current_state == state:
        return
    current_state = state
    state_changed.emit(state)

## How far the front fist is from where it is on the first idle frame, in the
## actor's local space (0 during attacks, or without a hand track).
func hand_follow_offset() -> Vector2:
    if clip_playing or not action_state.is_empty() or is_pose_showing():
        return Vector2.ZERO
    var shown: AnimatedSprite2D = null
    for animated in state_sprites.values():
        if animated.visible:
            shown = animated
            break
    if shown == null or not hand_tracks.has(shown):
        return Vector2.ZERO
    var track: Array = hand_tracks[shown]
    var reference: Array = hand_tracks.get(idle_sprite, track)
    var now: Array = track[clampi(shown.frame, 0, track.size() - 1)]
    var start: Array = reference[0]
    var s := animation_scale * scale_multiplier
    return Vector2((float(now[0]) - float(start[0])) * s * facing, (float(now[1]) - float(start[1])) * s)

## How much a held weapon tilts with the arm on the frame showing, in
## degrees (0 during attacks, idle/walk clips, or without a hand track): the
## fist's angle around a shoulder above it, compared with its average over
## the animation, so only the swing within the cycle tilts the weapon.
func hand_follow_tilt() -> float:
    if clip_playing or not action_state.is_empty() or is_pose_showing():
        return 0.0
    var shown := _shown_state_sprite()
    if shown == null or not hand_tracks.has(shown):
        return 0.0
    var track: Array = hand_tracks[shown]
    var mean := Vector2.ZERO
    for point in track:
        mean += Vector2(float(point[0]), float(point[1]))
    mean /= float(track.size())
    var now: Array = track[clampi(shown.frame, 0, track.size() - 1)]
    var asset := ConfigScript.asset_for(asset_id)
    var arm := float(asset.get("animation_reference_height", 416.0)) * HAND_TILT_ARM if not asset.is_empty() else 120.0
    var shoulder := mean - Vector2(0.0, arm)
    var swing := (Vector2(float(now[0]), float(now[1])) - shoulder).angle() - (mean - shoulder).angle()
    return clampf(rad_to_deg(swing) * HAND_TILT_AMOUNT, -HAND_TILT_MAX, HAND_TILT_MAX) * float(facing)

func _shown_state_sprite() -> AnimatedSprite2D:
    for animated in state_sprites.values():
        if animated.visible:
            return animated
    return null

## Shows the front fist over the held weapon on idle / walk frames that have
## one (hand_atlas.png). The owner says when a weapon is held.
func set_fist_overlay(on: bool) -> void:
    fist_overlay_enabled = on
    _update_fist_overlay()

func _update_fist_overlay() -> void:
    if fist_sprite == null:
        return
    var shown := _shown_state_sprite() if fist_overlay_enabled and not clip_playing and action_state.is_empty() and not is_pose_showing() else null
    if shown == null or not hand_atlases.has(shown) or shown.sprite_frames == null:
        fist_sprite.visible = false
        return
    var piece := shown.sprite_frames.get_frame_texture(shown.animation, shown.frame) as AtlasTexture
    if piece == null:
        fist_sprite.visible = false
        return
    fist_sprite.texture = hand_atlases[shown]
    fist_sprite.region_rect = piece.region
    fist_sprite.position = shown.position + shown.offset * shown.scale
    fist_sprite.scale = shown.scale
    fist_sprite.visible = true

# ---------- weapon attack clip (hero mode) ----------

## `hit_seconds`: when the game deals damage (0 for ranged). `combo_window`:
## an attack starting later than this after the previous one restarts the combo.
func set_attack_clip(clip: Dictionary, texture: Texture2D, hit_seconds: float = 0.0, combo_window: float = 1.0, hand_texture: Texture2D = null) -> void:
    if sprite == null:
        _ready()
    stop_attack_clip(false)
    attack_clip = WeaponClipScript.normalize(clip) if not clip.is_empty() and texture != null else {}
    attack_clip_texture = texture if not attack_clip.is_empty() else null
    clip_hit_seconds = maxf(0.0, hit_seconds)
    clip_combo_window = maxf(0.1, combo_window)
    clip_attack_index = 0
    clip_since_start = INF
    clip_sprite.texture = attack_clip_texture
    hand_sprite.texture = hand_texture if not attack_clip.is_empty() else null
    hand_sprite.visible = false
    _apply_visual_transform()

func clear_attack_clip() -> void:
    set_attack_clip({}, null)

func has_attack_clip() -> bool:
    return not attack_clip.is_empty() and attack_clip_texture != null and clip_sprite != null

func _play_clip_attack() -> void:
    if clip_since_start > clip_combo_window:
        clip_attack_index = 0
    clip_line = WeaponClipScript.timeline(attack_clip, clip_attack_index, clip_hit_seconds)
    clip_attack_index = (clip_attack_index + 1) % WeaponClipScript.attack_ranges(attack_clip).size()
    clip_elapsed = 0.0
    clip_since_start = 0.0
    clip_playing = true
    clip_attacks_played += 1
    # The weapon clip replaces a lesser action (a hurt clip, say).
    if action_state != "death":
        _clear_action()
    sprite.visible = false
    _hide_pose()
    for animated in state_sprites.values():
        animated.visible = false
    attack_sprite.stop()
    clip_sprite.visible = true
    _show_clip_frame(WeaponClipScript.frame_at(clip_line, 0.0))
    _set_current_state("attack")
    attack_started.emit()

func _process(delta: float) -> void:
    advance_attack_clip(delta)
    advance_pose(delta)
    advance_effects(delta)
    _update_fist_overlay()

func advance_attack_clip(delta: float) -> void:
    clip_since_start += maxf(0.0, delta)
    if not clip_playing:
        return
    clip_elapsed += maxf(0.0, delta)
    var frame := WeaponClipScript.frame_at(clip_line, clip_elapsed)
    if frame < 0:
        stop_attack_clip(true)
        return
    _show_clip_frame(frame)

## Timers for the code-driven parts: hurt tint, spawn fade, death fade,
## wind-up hold limit and dash afterimages. Public so tests can step it.
func advance_effects(delta: float) -> void:
    var step := maxf(0.0, delta)
    if step <= 0.0:
        return
    _hurt_flash = maxf(0.0, _hurt_flash - step)
    _spawn_fade = maxf(0.0, _spawn_fade - step)
    if not action_state.is_empty():
        _action_elapsed += step
        if action_state == "windup" and _action_elapsed > WINDUP_HOLD_LIMIT:
            _clear_action()
            _show_locomotion_sprite()
    if _death_elapsed >= 0.0:
        var before := _death_elapsed
        _death_elapsed += step
        if action_state != "death":
            # Code-driven death: fade and sink.
            var t := clampf(_death_elapsed / DEATH_FADE_SECONDS, 0.0, 1.0)
            position = _death_base_position + Vector2(0.0, DEATH_SINK_PIXELS * t)
            if before < DEATH_FADE_SECONDS and _death_elapsed >= DEATH_FADE_SECONDS:
                _finish_death()
    _advance_afterimages(step)
    _apply_modulate()

func _apply_modulate() -> void:
    var color := Color.WHITE
    if _hurt_flash > 0.0:
        color = color.lerp(HURT_FLASH_COLOR, clampf(_hurt_flash / HURT_FLASH_SECONDS, 0.0, 1.0))
    if _spawn_fade > 0.0:
        color.a *= 1.0 - clampf(_spawn_fade / SPAWN_FADE_SECONDS, 0.0, 1.0)
    if _death_elapsed >= 0.0 and action_state != "death":
        color.a *= 1.0 - clampf(_death_elapsed / DEATH_FADE_SECONDS, 0.0, 1.0)
    modulate = color

func _advance_afterimages(step: float) -> void:
    if _afterimages == null:
        return
    for ghost in _afterimages.get_children():
        var life: float = float(ghost.get_meta("life", 0.0)) - step
        if life <= 0.0:
            ghost.queue_free()
            continue
        ghost.set_meta("life", life)
        ghost.modulate.a = AFTERIMAGE_COLOR.a * life / AFTERIMAGE_LIFETIME
    if not dashing or _death_elapsed >= 0.0:
        return
    _afterimage_clock -= step
    if _afterimage_clock > 0.0:
        return
    _afterimage_clock = AFTERIMAGE_INTERVAL
    _spawn_afterimage()

func _spawn_afterimage() -> void:
    var source: Node2D = null
    var texture: Texture2D = null
    for animated in state_sprites.values():
        if animated.visible and animated.sprite_frames != null:
            source = animated
            texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
            break
    if source == null and is_pose_showing():
        var piece := AtlasTexture.new()
        piece.atlas = pose_sprite.texture
        piece.region = pose_sprite.region_rect
        source = pose_sprite
        texture = piece
    if source == null and sprite.visible:
        source = sprite
        texture = sprite.texture
    if source == null or texture == null:
        return
    var ghost := Sprite2D.new()
    ghost.texture = texture
    ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    ghost.top_level = true
    ghost.z_index = -1
    ghost.modulate = AFTERIMAGE_COLOR
    ghost.set_meta("life", AFTERIMAGE_LIFETIME)
    _afterimages.add_child(ghost)
    ghost.global_transform = source.global_transform

func afterimage_count() -> int:
    return _afterimages.get_child_count() if _afterimages != null else 0

func _show_clip_frame(frame: int) -> void:
    clip_frame = frame
    if frame >= 0:
        clip_sprite.region_rect = WeaponClipScript.frame_rect(attack_clip, frame)
    _update_hand(frame)

## Shows the gripping hand over the weapon on frames where the weapon is in front.
func _update_hand(frame: int) -> void:
    if hand_sprite == null:
        return
    var track: Array = attack_clip.get("track", [])
    var front := frame >= 0 and frame < track.size() and not bool(track[frame].get("behind", false))
    hand_sprite.visible = clip_playing and front and hand_sprite.texture != null
    if hand_sprite.visible:
        hand_sprite.region_rect = WeaponClipScript.frame_rect(attack_clip, frame)

## Stops a playing clip attack and shows idle/walk again.
func stop_attack_clip(emit_finished: bool = false) -> void:
    if not clip_playing:
        return
    clip_playing = false
    clip_frame = -1
    if hand_sprite != null:
        hand_sprite.visible = false
    if action_state.is_empty():
        _show_locomotion_sprite()
    elif clip_sprite != null:
        clip_sprite.visible = false
    if emit_finished:
        attack_finished.emit()

func clip_hides_weapon() -> bool:
    return clip_playing and str(attack_clip.get("mode", "hero")) == "hero"

## hero_weapon clips: the frame showing and a transform from cell pixels to
## global space (for placing the weapon in the hands).
func clip_places_weapon() -> bool:
    return clip_playing and clip_frame >= 0 and WeaponClipScript.has_track(attack_clip)

func clip_cell_to_global() -> Transform2D:
    var cell: Array = attack_clip.get("cell", [1.0, 1.0])
    return clip_sprite.global_transform * Transform2D(0.0, -Vector2(float(cell[0]), float(cell[1])) * 0.5)

# ---------- whichever clip has the weapon now (attack or idle/walk) ----------

## True when the frame showing tells where the weapon goes (a hero_weapon
## attack, idle or walk). Then placing_clip/frame/cell_to_global describe it.
func places_weapon() -> bool:
    return clip_places_weapon() or (is_pose_showing() and pose_frame >= 0 and WeaponClipScript.has_track(pose_clip))

func placing_clip() -> Dictionary:
    return attack_clip if clip_playing else pose_clip

func placing_frame() -> int:
    return clip_frame if clip_playing else pose_frame

func placing_cell_to_global() -> Transform2D:
    if clip_playing:
        return clip_cell_to_global()
    var cell: Array = pose_clip.get("cell", [1.0, 1.0])
    return pose_sprite.global_transform * Transform2D(0.0, -Vector2(float(cell[0]), float(cell[1])) * 0.5)

## The weapon is part of the frames showing (hero-mode attack, idle or walk).
func hides_weapon() -> bool:
    return clip_hides_weapon() or (is_pose_showing() and str(pose_clip.get("mode", "hero")) == "hero")

# ---------- weapon idle / walk ----------

## Sets the weapon's own idle or walk ({} or a null texture removes it).
## `hand_texture`: hero_weapon clips' gripping hand, drawn over the weapon.
func set_pose_clip(state: String, clip: Dictionary, texture: Texture2D, hand_texture: Texture2D = null) -> void:
    if sprite == null:
        _ready()
    if clip.is_empty() or texture == null:
        pose_clips.erase(state)
    else:
        pose_clips[state] = {"clip": WeaponClipScript.normalize(clip), "texture": texture, "hand": hand_texture if str(clip.get("mode", "")) == "hero_weapon" else null}
    pose_state = ""
    _refresh_locomotion(true)

func clear_pose_clips() -> void:
    pose_clips.clear()
    _hide_pose()
    _refresh_locomotion(true)

func has_pose_clip(state: String) -> bool:
    return pose_clips.has(state)

func is_pose_showing() -> bool:
    return pose_sprite != null and pose_sprite.visible and not pose_state.is_empty()

## Which pose clip a locomotion state shows ("" for none): its own; dash
## borrows the walk; jump and fall borrow the idle unless the hero has art
## of its own for them.
func _pose_key(state: String) -> String:
    if pose_clips.has(state):
        return state
    if state == "dash" and pose_clips.has("walk"):
        return "walk"
    if (state == "jump" or state == "fall") and pose_clips.has("idle") and not has_state(state):
        return "idle"
    return ""

func _show_pose(state: String) -> bool:
    var key := _pose_key(state)
    if key.is_empty() or pose_sprite == null:
        _hide_pose()
        return false
    var entry: Dictionary = pose_clips[key]
    if pose_state != key or not pose_sprite.visible:
        pose_state = key
        pose_clip = entry.clip
        pose_time = 0.0
        pose_sprite.texture = entry.texture
        pose_hand_sprite.texture = entry.hand
        _apply_visual_transform()
    pose_speed = DASH_FALLBACK_SPEED if state == "dash" and key == "walk" else 1.0
    sprite.visible = false
    for animated in state_sprites.values():
        animated.visible = false
    pose_sprite.visible = true
    _show_pose_frame(WeaponClipScript.loop_frame_at(pose_clip, pose_time))
    return true

func _hide_pose() -> void:
    if pose_sprite == null:
        return
    pose_sprite.visible = false
    pose_hand_sprite.visible = false
    pose_state = ""
    pose_frame = -1

func advance_pose(delta: float) -> void:
    if not is_pose_showing():
        return
    pose_time += maxf(0.0, delta) * pose_speed
    _show_pose_frame(WeaponClipScript.loop_frame_at(pose_clip, pose_time))

func _show_pose_frame(frame: int) -> void:
    pose_frame = frame
    pose_sprite.region_rect = WeaponClipScript.frame_rect(pose_clip, frame)
    var track: Array = pose_clip.get("track", [])
    var front := frame >= 0 and frame < track.size() and not bool(track[frame].get("behind", false))
    pose_hand_sprite.visible = front and pose_hand_sprite.texture != null
    if pose_hand_sprite.visible:
        pose_hand_sprite.region_rect = pose_sprite.region_rect

func set_facing(new_facing: int) -> void:
    facing = -1 if new_facing < 0 else 1
    _apply_visual_transform()

func set_scale_multiplier(new_multiplier: float) -> void:
    scale_multiplier = maxf(0.25, new_multiplier) if is_finite(new_multiplier) else 1.0
    _apply_visual_transform()

func _apply_visual_transform() -> void:
    if sprite == null:
        return
    var applied_scale := base_scale * scale_multiplier
    sprite.scale = Vector2(applied_scale * facing, applied_scale)
    sprite.position = Vector2(0.0, ground_local_y) + static_offset * sprite.scale
    for animation_sprite in state_sprites.values():
        if animation_offsets.has(animation_sprite):
            var clip_scale := animation_scale * scale_multiplier
            animation_sprite.scale = Vector2(clip_scale * facing, clip_scale)
            # Mirror/resize around the ground pivot, including asymmetric crop offsets.
            animation_sprite.position = Vector2(0.0, ground_local_y) + Vector2(animation_offsets[animation_sprite]) * animation_sprite.scale
    if clip_sprite != null and not attack_clip.is_empty():
        var asset := ConfigScript.asset_for(asset_id)
        var height := float(asset.get("initial_visible_height", 80.0)) if not asset.is_empty() else 80.0
        var clip_scale := WeaponClipScript.hero_scale(attack_clip, height) * scale_multiplier
        clip_sprite.scale = Vector2(clip_scale * facing, clip_scale)
        var cell: Array = attack_clip.cell
        var anchor: Array = attack_clip.anchor
        # Put the clip's ground anchor on the actor's ground point.
        var from_center := Vector2(float(anchor[0]) - float(cell[0]) * 0.5, float(anchor[1]) - float(cell[1]) * 0.5)
        clip_sprite.position = Vector2(0.0, ground_local_y) - from_center * clip_sprite.scale
        hand_sprite.scale = clip_sprite.scale
        hand_sprite.position = clip_sprite.position
    if pose_sprite != null and not pose_clip.is_empty():
        var pose_asset := ConfigScript.asset_for(asset_id)
        var pose_height := float(pose_asset.get("initial_visible_height", 80.0)) if not pose_asset.is_empty() else 80.0
        var pose_scale := WeaponClipScript.hero_scale(pose_clip, pose_height) * scale_multiplier
        pose_sprite.scale = Vector2(pose_scale * facing, pose_scale)
        var pose_cell: Array = pose_clip.cell
        var pose_anchor: Array = pose_clip.anchor
        var pose_from_center := Vector2(float(pose_anchor[0]) - float(pose_cell[0]) * 0.5, float(pose_anchor[1]) - float(pose_cell[1]) * 0.5)
        pose_sprite.position = Vector2(0.0, ground_local_y) - pose_from_center * pose_sprite.scale
        pose_hand_sprite.scale = pose_sprite.scale
        pose_hand_sprite.position = pose_sprite.position

func visible_top_local_y() -> float:
    var asset := ConfigScript.asset_for(asset_id)
    if asset.is_empty():
        return ground_local_y
    var visible_bounds: Rect2 = asset["visible_bounds"]
    return ground_local_y + (visible_bounds.position.y - float(asset["ground_anchor"].y)) * base_scale * scale_multiplier

func ground_anchor_local() -> Vector2:
    return Vector2(0.0, ground_local_y)
