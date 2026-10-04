extends SceneTree

## Mech skill tree: the circuit-board layout, unlock rules, Scrap costs, the
## save field, the panel and opening it by clicking the Home command center.

const SkillTree = preload("res://scripts/model/skill_tree.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SkillTreeBoard = preload("res://scripts/ui/skill_tree_board.gd")
const GameFlow = preload("res://scripts/model/game_flow.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_layout()
	_test_rules()
	_test_save_field()
	await _test_home_panel()
	print("PASS skill tree: circuit-board layout, Scrap unlock rules, save round trip, panel, opens from the command center")
	quit(0)

func _test_layout() -> void:
	var ids: Array[String] = SkillTree.node_ids()
	assert(SkillTree.BRANCHES.size() == 6, "six branches out of the core")
	assert(ids.size() == SkillTree.BRANCHES.size() * SkillTree.BRANCH_TEMPLATE.size())
	var angles := {}
	for branch in SkillTree.BRANCHES:
		angles[int(branch.angle)] = true
		assert(SkillTree.NODE_CONTENT.has(branch.id), "content for %s" % branch.id)
	assert(angles.size() == 6, "branches point six different ways")
	var core_children := 0
	for node_id in ids:
		var node: Dictionary = SkillTree.node_def(node_id)
		var parent := str(node.parent)
		assert(parent == SkillTree.CORE_ID or SkillTree.has_skill(parent), "%s hangs off a real node" % node_id)
		if parent == SkillTree.CORE_ID:
			core_children += 1
		assert(int(node.cost) > 0)
		assert(not node.effects.is_empty(), "%s does something" % node_id)
		for effect in node.effects:
			assert(SkillTree.STAT_LABELS.has(effect.stat), "%s uses a known stat" % node_id)
		if str(node.tier) != "minor":
			assert(not str(node.code).is_empty(), "chips carry a code")
		# Outside the painted core chip and inside the painting.
		var at: Vector2 = node.position
		assert(absf(at.x) > SkillTreeBoard.CORE_HALF.x or absf(at.y) > SkillTreeBoard.CORE_HALF.y, "%s clears the core" % node_id)
		assert(Rect2(-SkillTree.ART_CORE, SkillTree.ART_SIZE).grow(-60.0).has_point(at), "%s on the board" % node_id)
	assert(core_children == 6, "one trace per branch leaves the core")
	# No two nodes overlap.
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			assert(SkillTree.position_of(ids[i]).distance_to(SkillTree.position_of(ids[j])) > 40.0, "%s and %s don't overlap" % [ids[i], ids[j]])
	# Every trace runs from the parent (or the core's edge) to its node.
	for node_id in ids:
		var parent := str(SkillTree.node_def(node_id).parent)
		var path := SkillTreeBoard.route_for(node_id)
		assert(path[path.size() - 1].is_equal_approx(SkillTree.position_of(node_id)))
		if parent == SkillTree.CORE_ID:
			var exit := path[0]
			assert(absf(exit.x) <= SkillTreeBoard.CORE_HALF.x + 1.0 and absf(exit.y) <= SkillTreeBoard.CORE_HALF.y + 1.0, "first trace starts at the core")
		else:
			assert(path[0].is_equal_approx(SkillTree.position_of(parent)))

func _test_rules() -> void:
	var unlocked := {}
	assert(SkillTree.can_unlock(unlocked, 100, "weapons_1"), "first node of a branch hangs off the core")
	assert(not SkillTree.can_unlock(unlocked, 100, "weapons_2"), "needs its parent first")
	assert(not SkillTree.can_unlock(unlocked, 0, "weapons_1"), "needs Scrap")
	assert(SkillTree.is_reachable(unlocked, "armor_1") and not SkillTree.is_reachable(unlocked, "armor_2"))
	var account: RefCounted = AccountStateScript.new()
	account.scrap = 10
	assert(account.unlock_skill_node("weapons_1"))
	assert(account.scrap == 10 - int(SkillTree.node_def("weapons_1").cost), "Scrap is spent")
	assert(not account.unlock_skill_node("weapons_1"), "only once")
	assert(account.unlock_skill_node("weapons_2"))
	assert(not account.unlock_skill_node("weapons_3"), "too expensive now")
	assert(not account.skill_unlock_blocker("weapons_3").is_empty())
	assert(not account.unlock_skill_node("armor_1", true), "not during a run")
	var totals := SkillTree.stat_totals(account.skill_nodes)
	assert(is_equal_approx(float(totals["attack_damage_increased"]), 0.08), "effects add up")
	assert(SkillTree.describe_effect({"stat": "attack_damage", "operation": "increased", "value": 0.04}) == "+4% attack damage")
	assert(SkillTree.describe_effect({"stat": "max_health", "operation": "flat", "value": 10.0}) == "+10 max health")
	assert(SkillTree.describe_effect({"stat": "health_regen", "operation": "flat", "value": 0.005}) == "+0.5% health regen per second")
	var refunded: int = account.refund_skill_nodes()
	assert(refunded == 8 and account.scrap == 10 and account.skill_nodes.is_empty(), "refund returns every Scrap")
	# Floating nodes (parent not powered) are dropped.
	var clean := SkillTree.sanitize({"weapons_2": true, "armor_1": true, "nope": true})
	assert(clean.has("armor_1") and not clean.has("weapons_2") and not clean.has("nope"))
	assert(SkillTree.total_cost() == 6 * 68)

func _test_save_field() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.scrap = 50
	account.unlock_skill_node("drill_1")
	account.unlock_skill_node("drill_2")
	var payload: Dictionary = account.to_save_payload()
	assert(", ".join(payload["skill_nodes"]) == "drill_1, drill_2", "saved as a sorted id list")
	assert(AccountStateScript.validate_save_payload(payload).valid)
	var loaded: RefCounted = AccountStateScript.new()
	loaded.from_save_payload(payload)
	assert(loaded.skill_nodes.has("drill_1") and loaded.skill_nodes.has("drill_2") and loaded.scrap == 50 - 8)
	# Old saves have no field; unknown or repeated ids are rejected.
	var old := payload.duplicate(true)
	old.erase("skill_nodes")
	assert(AccountStateScript.validate_save_payload(old).valid)
	var fresh: RefCounted = AccountStateScript.new()
	fresh.from_save_payload(old)
	assert(fresh.skill_nodes.is_empty())
	var bad := payload.duplicate(true)
	bad["skill_nodes"] = ["drill_1", "not_a_node"]
	assert(not AccountStateScript.validate_save_payload(bad).valid)
	bad["skill_nodes"] = ["drill_1", "drill_1"]
	assert(not AccountStateScript.validate_save_payload(bad).valid)

func _test_home_panel() -> void:
	GameFlow.home_hero_id = "hero_1"
	var home: Node2D = load("res://scenes/home_area.tscn").instantiate()
	home.persistence_enabled = false
	root.add_child(home)
	await process_frame
	assert(home.skill_panel != null and not home.is_skill_tree_open(), "panel built, closed at first")
	# Clicking empty ground or sky does nothing; the building opens the tree.
	assert(not home.click_world(Vector2(640, 690)), "ground isn't the command center")
	assert(not home.click_world(Vector2(2000, 300)), "other sections aren't the command center")
	var rect: Rect2 = home.command_center_rect()
	var door := Vector2(rect.get_center().x, rect.end.y - rect.size.y * 0.2)
	assert(home.is_on_command_center(door))
	assert(home.click_world(door), "clicking the command center opens the skill tree")
	assert(home.is_skill_tree_open())
	await process_frame
	# The board fits and finds the core and nodes under the mouse.
	var board: Control = home.skill_panel.board
	assert(board.size.x > 400.0 and board.size.y > 400.0, "board has room")
	assert(board.node_at(Vector2.ZERO) == SkillTree.CORE_ID)
	assert(board.node_at(SkillTree.position_of("salvage_k")) == "salvage_k")
	assert(board.node_at(board.to_board(board.to_local_point(SkillTree.position_of("armor_f2")))) == "armor_f2")
	# The hero holds still while the tree is open.
	var start_x: float = home.hero.position.x
	home.move_right_held = true
	for i in 30:
		home.step(1.0 / 60.0)
	assert(is_equal_approx(home.hero.position.x, start_x), "no walking while the tree is open")
	home.move_right_held = false
	# Unlock through the panel: Scrap is spent and `changed` fires.
	var changes := [0]
	home.skill_panel.changed.connect(func() -> void: changes[0] += 1)
	home.account.scrap = 4
	assert(not home.skill_panel.unlock("mobility_2"), "parent first")
	assert(home.skill_panel.unlock("mobility_1"))
	assert(home.account.skill_nodes.has("mobility_1") and home.account.scrap == 1 and changes[0] == 1)
	board.select("mobility_2")
	assert(home.skill_panel.unlock_button.disabled, "can't afford the next one")
	assert(home.skill_panel.refund_all() == 3 and home.account.scrap == 4)
	# Esc closes it.
	var esc := InputEventAction.new()
	esc.action = "pause_game"
	esc.pressed = true
	home._unhandled_input(esc)
	assert(not home.is_skill_tree_open(), "Esc closes the tree")
	assert(not home.leaving, "and stays in Home")
	# The hangar opens the same tree.
	var hangar: Rect2 = home.building_rect(home.building_index("hangar"))
	var hangar_door := Vector2(hangar.get_center().x, hangar.end.y - hangar.size.y * 0.2)
	assert(home.skill_tree_building_at(hangar_door) == "hangar")
	assert(home.click_world(hangar_door), "clicking the hangar opens the skill tree")
	assert(home.is_skill_tree_open())
	home.close_skill_tree()
	home.queue_free()
	await process_frame
