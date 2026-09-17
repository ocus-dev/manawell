extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var designer: Control = load("res://scenes/tools/weapon_designer.tscn").instantiate()
	root.add_child(designer)
	for frame in range(8):
		await process_frame
	var toolbar: HBoxContainer = designer.find_child("AuthoringToolbar", true, false)
	var body: HSplitContainer = designer.find_child("AuthoringBody", true, false)
	var editor: GridContainer = designer.find_child("EditorGrid", true, false)
	var sidebar: VBoxContainer = designer.find_child("PreviewSidebar", true, false)
	assert(toolbar != null and body != null and editor != null and sidebar != null)
	assert(editor.columns == 2, "Authoring controls should use the available width in two columns")
	assert(toolbar.get_global_rect().end.y < 100.0, "Primary actions should remain at the top of the screen")
	assert(body.get_global_rect().end.y <= 720.5, "Authoring workspace must stay inside the viewport")
	assert(sidebar.get_global_rect().end.x <= 1280.5, "Preview sidebar must stay inside the viewport")
	if "--capture-layout" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../work/weapon-flow/weapon-designer-layout.png")
	designer.queue_free()
	await process_frame
	print("PASS weapon designer layout: top actions, two-column editor, bounded preview sidebar")
	quit(0)
