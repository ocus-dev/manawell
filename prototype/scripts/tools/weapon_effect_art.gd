extends RefCounted

## Effect sprite sheets for the Weapon Lab: built-in generated flipbooks (so
## you can try effects before making art), importing a ready-made sprite
## sheet, and packing separate frame PNGs (for example frames exported from a
## ComfyUI video) into one horizontal strip.
##
## Sheets are saved under art/weapons/effects/<weapon id>/ and copied into
## assets/weapons/<id>/<revision>/effects/ when the weapon is published.

const Art = preload("res://scripts/tools/weapon_lab_art.gd")

const EFFECTS_RELATIVE := "art/weapons/effects"
const KINDS := {
	"slash_arc": {"label": "Slash arc", "frames": 8, "color": Color("bfefff"), "fps": 24.0, "trigger": "strike", "anchor": [0.5, 0.5], "follow": true, "size": 150.0},
	"spark_burst": {"label": "Spark burst", "frames": 8, "color": Color("ffb347"), "fps": 24.0, "trigger": "hit", "anchor": [0.95, 0.5], "follow": false, "size": 96.0},
	"impact_ring": {"label": "Impact ring", "frames": 8, "color": Color("ffffff"), "fps": 30.0, "trigger": "hit", "anchor": [0.95, 0.5], "follow": false, "size": 110.0},
	"glow_pulse": {"label": "Glow pulse", "frames": 10, "color": Color("66b8ff"), "fps": 20.0, "trigger": "windup", "anchor": [0.5, 0.5], "follow": true, "size": 120.0},
	"muzzle_flash": {"label": "Muzzle flash", "frames": 4, "color": Color("ffe27a"), "fps": 30.0, "trigger": "hit", "anchor": [1.0, 0.5], "follow": true, "size": 80.0},
}
const KIND_ORDER := ["slash_arc", "spark_burst", "impact_ring", "glow_pulse", "muzzle_flash"]
const CELL := 128

static func effects_dir(weapon_id: String) -> String:
	var folder := Art.slug(weapon_id)
	return Art.repo_root().path_join(EFFECTS_RELATIVE).path_join(folder if not folder.is_empty() else "unsorted")

## A new effect entry (WeaponEffects fields + "source") for a generated kind.
static func generate_effect(kind: String, weapon_id: String, color: Color = Color(0, 0, 0, 0)) -> Dictionary:
	var spec: Dictionary = KINDS.get(kind, KINDS["spark_burst"])
	var tint: Color = color if color.a > 0.0 else spec.color
	var image := generate(kind, int(spec.frames), tint)
	var path := _unique_path(effects_dir(weapon_id), kind)
	if image.save_png(path) != OK:
		return {}
	return {"label": str(spec.label), "source": path, "frame_count": int(spec.frames), "columns": int(spec.frames), "fps": float(spec.fps), "trigger": str(spec.trigger), "at": 0.5, "anchor": spec.anchor.duplicate(), "follow": bool(spec.follow), "align": true, "size": float(spec.size), "rotation": 0.0, "offset": [0.0, 0.0], "additive": true, "opacity": 1.0}

## Copies a sprite sheet into the effects folder. `frame_count` / `columns`
## describe its layout; 0 columns means a single horizontal strip.
static func import_sheet(absolute_path: String, weapon_id: String, frame_count: int, columns: int = 0) -> Dictionary:
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return {}
	var path := _unique_path(effects_dir(weapon_id), Art.slug(absolute_path.get_file().get_basename()))
	image.convert(Image.FORMAT_RGBA8)
	if image.save_png(path) != OK:
		return {}
	var count := maxi(1, frame_count)
	return {"label": absolute_path.get_file().get_basename().capitalize().left(40), "source": path, "frame_count": count, "columns": count if columns <= 0 else mini(columns, count), "fps": 24.0, "trigger": "hit", "anchor": [0.95, 0.5], "follow": false, "align": true, "size": 96.0, "rotation": 0.0, "offset": [0.0, 0.0], "additive": true, "opacity": 1.0}

## Packs separate frame images (in file-name order) into one strip.
static func import_frames(paths: PackedStringArray, weapon_id: String) -> Dictionary:
	var sorted := Array(paths)
	sorted.sort()
	var frames: Array[Image] = []
	var cell := Vector2i.ZERO
	for path in sorted:
		var image := Image.load_from_file(str(path))
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		frames.append(image)
		cell = Vector2i(maxi(cell.x, image.get_width()), maxi(cell.y, image.get_height()))
	if frames.is_empty():
		return {}
	var strip := Image.create_empty(cell.x * frames.size(), cell.y, false, Image.FORMAT_RGBA8)
	for index in range(frames.size()):
		var frame: Image = frames[index]
		strip.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(index * cell.x + (cell.x - frame.get_width()) / 2, (cell.y - frame.get_height()) / 2))
	var base := Art.slug(str(sorted[0]).get_file().get_basename()).rstrip("0123456789_")
	var path := _unique_path(effects_dir(weapon_id), base if not base.is_empty() else "frames")
	if strip.save_png(path) != OK:
		return {}
	return {"label": (base if not base.is_empty() else "Frames").capitalize().left(40), "source": path, "frame_count": frames.size(), "columns": frames.size(), "fps": 24.0, "trigger": "hit", "anchor": [0.95, 0.5], "follow": false, "align": true, "size": 96.0, "rotation": 0.0, "offset": [0.0, 0.0], "additive": true, "opacity": 1.0}

static func _unique_path(directory: String, stem: String) -> String:
	DirAccess.make_dir_recursive_absolute(directory)
	var base := stem if not stem.is_empty() else "effect"
	var path := directory.path_join(base + ".png")
	var suffix := 2
	while FileAccess.file_exists(path):
		path = directory.path_join("%s_%d.png" % [base, suffix])
		suffix += 1
	return path

# ---------- generated flipbooks ----------

## A horizontal strip of `frames` CELL x CELL frames.
static func generate(kind: String, frames: int, color: Color) -> Image:
	var strip := Image.create_empty(CELL * frames, CELL, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var sparks: Array = []
	for i in range(14):
		sparks.append({"angle": rng.randf_range(-PI, PI), "speed": rng.randf_range(0.55, 1.0), "width": rng.randf_range(1.5, 3.0)})
	for frame in range(frames):
		var t := float(frame) / maxf(1.0, float(frames - 1))
		for y in range(CELL):
			for x in range(CELL):
				var p := Vector2(x + 0.5 - CELL * 0.5, y + 0.5 - CELL * 0.5) / (CELL * 0.5)
				var alpha := 0.0
				match kind:
					"slash_arc":
						alpha = _slash(p, t)
					"spark_burst":
						alpha = _sparks(p, t, sparks)
					"impact_ring":
						alpha = _ring(p, t)
					"glow_pulse":
						alpha = _glow(p, t)
					"muzzle_flash":
						alpha = _flash(p, t)
				if alpha <= 0.004:
					continue
				# Hot white core blending out to the tint at the edges.
				var shade := color.lerp(Color.WHITE, clampf(alpha - 0.55, 0.0, 1.0) * 1.6)
				strip.set_pixel(frame * CELL + x, y, Color(shade.r, shade.g, shade.b, clampf(alpha, 0.0, 1.0)))
	return strip

static func _slash(p: Vector2, t: float) -> float:
	# A crescent sweeping from -110 deg to +40 deg, trailing and fading.
	var radius := p.length()
	var angle := atan2(p.y, p.x)
	var head := lerpf(-1.9, 0.7, minf(1.0, t * 1.4))
	var tail := head - lerpf(0.4, 1.6, minf(1.0, t * 1.6))
	if angle > head or angle < tail:
		return 0.0
	var along := (angle - tail) / maxf(0.001, head - tail)
	var band := 1.0 - absf(radius - 0.72) / (0.05 + 0.12 * along)
	return clampf(band, 0.0, 1.0) * along * (1.0 - smoothstep(0.65, 1.0, t))

static func _sparks(p: Vector2, t: float, sparks: Array) -> float:
	var best := 0.0
	var reach := 0.15 + t * 0.85
	for spark in sparks:
		var direction := Vector2.from_angle(float(spark.angle))
		var along := p.dot(direction)
		var tip := reach * float(spark.speed)
		var tail := maxf(0.0, tip - 0.35)
		if along < tail or along > tip:
			continue
		var across := absf(p.cross(direction)) * 64.0
		var line := 1.0 - across / float(spark.width)
		best = maxf(best, clampf(line, 0.0, 1.0) * ((along - tail) / maxf(0.001, tip - tail)))
	return best * (1.0 - t * 0.85)

static func _ring(p: Vector2, t: float) -> float:
	var radius := p.length()
	var ring_radius := 0.1 + t * 0.85
	var width := 0.14 * (1.0 - t) + 0.03
	var band := 1.0 - absf(radius - ring_radius) / width
	var core := (1.0 - radius / 0.35) * (1.0 - t * 2.5)
	return maxf(clampf(band, 0.0, 1.0) * (1.0 - t), clampf(core, 0.0, 1.0))

static func _glow(p: Vector2, t: float) -> float:
	var pulse := sin(t * PI)
	var radius := p.length() / (0.35 + 0.55 * pulse)
	return clampf(1.0 - radius, 0.0, 1.0) * clampf(1.0 - radius, 0.0, 1.0) * pulse * 1.2

static func _flash(p: Vector2, t: float) -> float:
	var radius := p.length()
	var angle := atan2(p.y, p.x)
	var spikes := pow(absf(cos(angle * 2.5)), 6.0)
	var reach := (0.35 + 0.6 * spikes) * (1.0 - t * 0.5)
	var body := 1.0 - radius / maxf(0.01, reach)
	return clampf(body, 0.0, 1.0) * (1.0 - t * 0.9) * 1.3
