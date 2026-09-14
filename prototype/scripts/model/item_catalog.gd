extends RefCounted

# Fixed first-clear rewards. Collection ownership is separate from future equipment.
const ITEMS := {
    "core.heavy_breech": {"label": "Heavy Breech", "category": "weapon", "glyph": "HB", "description": "A reinforced weapon chamber recovered from the foundry approach."},
    "module.high_volume": {"label": "High-volume Cylinder", "category": "harvester", "glyph": "HC", "description": "A heavy displacement cylinder salvaged from the intake works."},
    "chassis.bulwark": {"label": "Bulwark Plating", "category": "hero", "glyph": "BP", "description": "Layered protective plating with reinforced mounting brackets."},
    "core.cycler": {"label": "Cycle Driver", "category": "weapon", "glyph": "CD", "description": "A compact autoloader drive recovered at Cinder Crossing."},
    "module.fast_cycle": {"label": "Fast-cycle Rotor", "category": "harvester", "glyph": "FR", "description": "A lightweight rotor from the pressure pumping station."},
    "chassis.runner": {"label": "Runner Frame", "category": "hero", "glyph": "RF", "description": "An articulated chassis assembly found in the rail graveyard."},
    "core.accelerator": {"label": "Long Accelerator", "category": "weapon", "glyph": "LA", "description": "A linear accelerator barrel recovered beyond the furnace rampart."},
    "module.bracing": {"label": "Anchor Bracing", "category": "harvester", "glyph": "AB", "description": "Heavy stabilizer braces salvaged from the Crown Well."},
    "chassis.jump_servos": {"label": "Jump Servos", "category": "hero", "glyph": "JS", "description": "A matched pair of high-load servos recovered from the act guardian."},
}
const REWARDS := ["core.heavy_breech", "module.high_volume", "chassis.bulwark", "core.cycler", "module.fast_cycle", "chassis.runner", "core.accelerator", "module.bracing", "chassis.jump_servos"]

static func reward_for(act_id: String, node_id: String) -> String:
    if act_id != "act_01":
        return ""
    for i in range(REWARDS.size()):
        if node_id == "act_01_node_%02d" % (i + 1):
            return REWARDS[i]
    return ""

static func source_for(id: String) -> String:
    return "Act 1 · Level %d first clear" % (REWARDS.find(id) + 1)

static func has_item(id: String) -> bool:
    return ITEMS.has(id)

static func definition_for(id: String) -> Dictionary:
    return ITEMS.get(id, {}).duplicate(true)

static func description_for(id: String) -> String:
    return str(ITEMS.get(id, {}).get("description", ""))

static func icon_path_for(id: String) -> String:
    if not ITEMS.has(id):
        return ""
    return "res://assets/ui-icons/items/%s.png" % id
