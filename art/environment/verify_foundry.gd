extends SceneTree

func _init() -> void:
	call_deferred("verify")

func verify() -> void:
	var packed = load("res://scenes/main.tscn")
	if packed == null:
		quit(1)
		return
	var arena = packed.instantiate()
	# Rendering-only inspection: do not start gameplay or touch player saves.
	arena.set_script(null)
	arena.get_node("Hero").set_script(null)
	root.add_child(arena)
	var scenery = arena.get_node_or_null("FoundryScenery")
	if scenery == null or arena.get_node("Floor").visible:
		quit(2)
		return
	var meshes = scenery.find_children("*", "MeshInstance3D", true, false)
	var bodies = scenery.find_children("*", "CollisionObject3D", true, false)
	if meshes.is_empty() or not bodies.is_empty():
		quit(3)
		return
	if arena.get_node("FloorBody/CollisionShape3D").shape.size != Vector3(28, .2, 28):
		quit(4)
		return
	print("Foundry: ", meshes.size(), " meshes; zero added collision bodies; original floor collision retained.")
	if "--texture-pilot" in OS.get_cmdline_user_args():
		var textured_meshes: int = 0
		for mesh_instance in meshes:
			var material = mesh_instance.get_active_material(0)
			if material is StandardMaterial3D and material.albedo_texture != null:
				textured_meshes += 1
		if textured_meshes != 50:
			push_error("Expected 49 textured slabs and one textured housing; got %d" % textured_meshes)
			quit(6)
			return
		print("Texture pilot: 50 meshes have imported color textures.")
	for frame in range(12):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		var filename = "godot-textured-preview.png" if "--texture-pilot" in OS.get_cmdline_user_args() else "godot-preview.png"
		var result = picture.save_png(ProjectSettings.globalize_path("res://../art/environment/" + filename))
		if result != OK:
			quit(5)
			return
	print("FOUNDRY_VERIFICATION_PASSED")
	quit(0)
