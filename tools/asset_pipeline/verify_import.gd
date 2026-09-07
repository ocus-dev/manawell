extends SceneTree
## Load generated scenes without starting gameplay or accessing save data.
func _init() -> void:
	call_deferred("verify")

func verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var packed = load(args[0])
	if not packed is PackedScene:
		quit(2)
		return
	var asset = packed.instantiate()
	root.add_child(asset)
	var meshes = asset.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty() or not asset.find_children("*", "CollisionObject3D", true, false).is_empty():
		quit(3)
		return
	for mesh in meshes:
		if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
			quit(4)
			return
	print("ASSET_IMPORT_VERIFIED meshes=", meshes.size())
	asset.free()
	quit(0)
