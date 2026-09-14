extends SceneTree

const LoaderScript = preload("res://scripts/model/level_data_loader.gd")

func _init() -> void:
	var root_path := "res://data/ld01/fixtures/valid"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		root_path = args[0]
	var loader: RefCounted = LoaderScript.new()
	if loader.load(root_path):
		print("LD01 validation passed: %s (%d acts)" % [root_path, loader.act_ids().size()])
		call_deferred("_finish", 0)
		return
	for diagnostic in loader.get_diagnostics():
		printerr(diagnostic)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	quit(exit_code)