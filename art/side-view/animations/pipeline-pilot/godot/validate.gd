extends SceneTree
func _initialize():
	var frames = load("res://animation.tres") as SpriteFrames
	assert(frames != null)
	assert(frames.get_frame_count("idle") == 37)
	var duration = 0.0
	for i in range(37):
		duration += frames.get_frame_duration("idle", i) / frames.get_animation_speed("idle")
	assert(abs(duration - 73.0 / 24.0) < 0.0001)
	var visual = load("res://visual.tscn").instantiate()
	var sprite = visual.get_node("AnimatedSprite2D")
	var anchor = Vector2(283, 534)
	var dimensions = Vector2(568, 542)
	assert((sprite.position + (anchor - dimensions / 2) * sprite.scale).length() < 0.001)
	visual.free()
	print("PASS: 37 frames, exact clip duration, SpriteFrames/scene load, fixed ground pivot")
	quit()
