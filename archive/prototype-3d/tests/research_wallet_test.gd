extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const UiViewStateScript = preload("res://scripts/ui/ui_view_state.gd")
const ResourceStripScript = preload("res://scripts/ui/resource_strip.gd")
const UpgradeCardScript = preload("res://scripts/ui/upgrade_card.gd")

var purchase_count: int = 0
var purchased_id: String = ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.bank = 40.0
	var run_state: RefCounted = RunStateScript.new()
	var view: Dictionary = UiViewStateScript.build(account, run_state).operations
	var damage: Dictionary = _upgrade(view.research.upgrades, "damage_1")
	var pump: Dictionary = _upgrade(view.research.upgrades, "pump_1")
	assert(TestCheckScript.check(damage.available, "exact funds make damage upgrade available"))
	assert(TestCheckScript.check(damage.amount_needed == 0, "exact funds have no deficit"))
	assert(TestCheckScript.check(pump.amount_needed == 20, "insufficient funds report the exact deficit"))
	var strip: Control = ResourceStripScript.new()
	root.add_child(strip)
	strip.configure(view.research)
	assert(TestCheckScript.check(strip.get_node("ResourceStripContent/BankedMana").text == "Banked mana 40.00", "wallet uses stable number formatting"))
	var card: Control = UpgradeCardScript.new()
	root.add_child(card)
	card.purchase_requested.connect(_on_purchase_requested)
	card.configure(damage)
	card.get_node("UpgradeCardContent/ActionRow/Purchase").emit_signal("pressed")
	card.get_node("UpgradeCardContent/ActionRow/Purchase").emit_signal("pressed")
	assert(TestCheckScript.check(purchase_count == 2, "card emits one purchase intent per click"))
	assert(TestCheckScript.check(purchased_id == "damage_1", "purchase emits the stable upgrade ID"))
	var owned: Dictionary = damage.duplicate(true)
	owned.owned = true
	owned.available = false
	owned.availability_reason = "Owned"
	card.configure(owned)
	assert(TestCheckScript.check(card.get_node("UpgradeCardContent/ActionRow/Purchase").text == "Owned", "owned upgrade replaces Buy"))
	assert(TestCheckScript.check(card.get_node("UpgradeCardContent/ActionRow/Purchase").disabled, "owned upgrade cannot be purchased"))
	var active_run: RefCounted = RunStateScript.new()
	active_run.start("preview-run", "well_1", "hero_1", "standard")
	var combat_view: Dictionary = UiViewStateScript.build(account, active_run).operations.research
	assert(TestCheckScript.check(not _upgrade(combat_view.upgrades, "damage_1").available, "research is unavailable during combat"))
	assert(TestCheckScript.check(_upgrade(combat_view.upgrades, "damage_1").availability_reason == "Unavailable during extraction.", "combat lockout is readable"))
	print("research_wallet: definitions=verified exact-funds=verified deficit=verified owned=verified combat-lock=verified")
	quit(0)

func _upgrade(upgrades: Array, upgrade_id: String) -> Dictionary:
	for upgrade in upgrades:
		if str(upgrade.get("id", "")) == upgrade_id:
			return upgrade
	return {}

func _on_purchase_requested(upgrade_id: String) -> void:
	purchase_count += 1
	purchased_id = upgrade_id
