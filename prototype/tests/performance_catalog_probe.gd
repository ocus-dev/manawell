extends SceneTree
func _init() -> void:
    var account = load("res://scripts/model/account_state.gd").new()
    var run = load("res://scripts/model/run_state.gd").new()
    var ui = load("res://scripts/ui/ui_view_state.gd")
    for i in range(2):
        ui.build(account, run)
    var started := Time.get_ticks_usec()
    for i in range(20):
        ui.build(account, run)
    print("HUD_MODEL_MS=", (Time.get_ticks_usec()-started)/20000.0)
    started = Time.get_ticks_usec()
    for i in range(20):
        load("res://scripts/model/content_catalog.gd").new()
    print("CONTENT_CATALOG_MS=", (Time.get_ticks_usec()-started)/20000.0)
    started = Time.get_ticks_usec()
    for i in range(20):
        load("res://scripts/model/campaign_catalog.gd").new()
    print("CAMPAIGN_CATALOG_MS=", (Time.get_ticks_usec()-started)/20000.0)
    quit()
