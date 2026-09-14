extends RefCounted

static var cache: Dictionary = {}

static func texture(base_id: String) -> Texture2D:
    if cache.has(base_id):
        return cache[base_id]
    var catalog = preload("res://scripts/model/item_catalog.gd")
    if not catalog.has_item(base_id):
        return null
    var path := catalog.icon_path_for(base_id)
    if not ResourceLoader.exists(path):
        return null
    var loaded := load(path) as Texture2D
    cache[base_id] = loaded
    return loaded
