extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const NoticeHostScript = preload("res://scripts/ui/notice_host.gd")
const SettingsPanelScript = preload("res://scripts/ui/settings_panel.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")

class ResetStore extends RefCounted:
	var writes_allowed: bool = true
	var last_error: String = ""
	var loaded_production_utc_timestamp: float = 0.0
	var loaded_snapshot: Dictionary = {}
	var clear_count: int = 0

	func clear_save() -> bool:
		clear_count += 1
		return true

var actions: Array[String] = []
var dismissed: int = 0
var cleared: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var notice: Control = NoticeHostScript.new()
	root.add_child(notice)
	notice.action_requested.connect(_on_notice_action)
	notice.dismissed.connect(_on_notice_dismissed)
	notice.configure({"save_failure": "Save failed; retry save.", "pending_save": true})
	assert(TestCheckScript.check(notice.visible, "save issue notice is visible"))
	assert(TestCheckScript.check(notice.get_node("NoticeContent/Actions/Retry").text == "Retry save", "save issue remains actionable"))
	notice.get_node("NoticeContent/Actions/Retry").emit_signal("pressed")
	assert(TestCheckScript.check(actions == ["retry_save"], "save retry emits its action"))
	notice.get_node("NoticeContent/Actions/Dismiss").emit_signal("pressed")
	assert(TestCheckScript.check(dismissed == 1, "notice dismissal is separate from retry"))
	notice.configure({"offline": "Welcome back: 4.00 mana earned while away.", "offline_pending_total": 4.0})
	assert(TestCheckScript.check(notice.get_node("NoticeContent/Actions/Retry").text == "Retry settlement", "pending settlement remains actionable"))
	notice.dismiss()
	assert(TestCheckScript.check(actions == ["retry_save"], "dismissing settlement does not emit credit"))
	notice.configure({"offline": "Welcome back: 4.00 mana earned while away.", "offline_pending_total": 4.0})
	assert(TestCheckScript.check(notice.visible == false, "dismissed offline notice stays dismissed through refresh"))
	var settings: Control = SettingsPanelScript.new()
	root.add_child(settings)
	settings.clear_requested.connect(_on_clear)
	settings.configure({"developer_mode": false, "pending_save": false, "offline_pending_total": 0.0})
	assert(TestCheckScript.check(not settings.get_node("SettingsContent/DeveloperControls").visible, "developer controls are hidden normally"))
	settings.request_clear()
	settings.get_node("SettingsContent/ClearConfirmation/ClearConfirmationContent/CancelClear").emit_signal("pressed")
	assert(TestCheckScript.check(cleared == 0, "cancel reset makes no changes"))
	settings.request_clear()
	settings.get_node("SettingsContent/ClearConfirmation/ClearConfirmationContent/ConfirmClear").emit_signal("pressed")
	assert(TestCheckScript.check(cleared == 1, "confirmed reset emits once"))
	settings.configure({"developer_mode": true, "pending_save": true, "offline_pending_total": 2.0})
	assert(TestCheckScript.check(settings.get_node("SettingsContent/DeveloperControls").visible, "developer controls appear only in developer mode"))
	assert(TestCheckScript.check(not settings.get_node("SettingsContent/RetrySave").disabled, "pending save has a retry action"))
	assert(TestCheckScript.check(not settings.get_node("SettingsContent/RetrySettlement").disabled, "pending settlement has a retry action"))
	settings.get_node("SettingsContent/CloseSettings").emit_signal("pressed")
	assert(TestCheckScript.check(settings.get_node("SettingsContent/CloseSettings") != null, "Settings exposes a visible close action"))
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	var reset_store := ResetStore.new()
	controller.save_store = reset_store
	controller.account_state.bank = 99.0
	controller.account_state.owned_upgrades["damage_1"] = true
	await process_frame
	var settings_button: Button = controller.encounter_hud.operations.resource_strip.get_node("ResourceStripContent/SettingsButton")
	settings_button.emit_signal("pressed")
	assert(TestCheckScript.check(controller.encounter_hud.settings_panel.visible, "operations Settings opens the existing settings panel"))
	controller.encounter_hud.settings_panel.get_node("SettingsContent/CloseSettings").emit_signal("pressed")
	assert(TestCheckScript.check(not controller.encounter_hud.settings_panel.visible, "Settings Close hides the panel"))
	controller.encounter_hud.settings_panel.visible = true
	controller.encounter_hud.settings_panel.get_node("SettingsContent/ClearSavedProgress").emit_signal("pressed")
	assert(TestCheckScript.check(controller.encounter_hud.settings_panel.confirmation.visible, "clear progress opens confirmation"))
	assert(TestCheckScript.check(controller.encounter_hud.settings_panel.confirmation.get_global_rect().size.y >= 136.0, "clear confirmation has visible space"))
	controller.encounter_hud.settings_panel.get_node("SettingsContent/ClearConfirmation/ClearConfirmationContent/ConfirmClear").emit_signal("pressed")
	assert(TestCheckScript.check(reset_store.clear_count == 1, "reset uses injected save store"))
	assert(TestCheckScript.check(controller.account_state.bank == 0.0 and not controller.account_state.has_upgrade("damage_1"), "reset returns fresh account state"))
	assert(TestCheckScript.check(not controller.encounter_hud.settings_panel.visible, "successful clear closes Settings"))
	assert(TestCheckScript.check(controller.encounter_hud.operations.expedition_panel.view_data.get("destination_id", "") == "well_1", "clear restores fresh operations state"))
	controller.queue_free()
	print("notices_settings: save=actionable offline=dismiss-safe reset=cancel+confirm developer-gate=verified")
	quit(0)

func _on_notice_action(action_id: String) -> void:
	actions.append(action_id)

func _on_notice_dismissed() -> void:
	dismissed += 1

func _on_clear() -> void:
	cleared += 1
