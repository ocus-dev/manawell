extends Node

## Talks to a local ComfyUI server to cut a weapon out of its background with
## Trellis 2 (the Trellis2RemoveBackground node), the same graph the Python
## weapon pipeline submits: art/side-view/workflows/06_cutout.api.json.
##
## Everything is async: `await cut_out(...)`. Progress goes out through
## `status_changed`. Only localhost servers are accepted.

signal status_changed(text: String)

const DEFAULT_URL := "http://127.0.0.1:8188"
const REMOVE_BACKGROUND_NODE := "Trellis2RemoveBackground"
const WORKFLOW_RELATIVE := "art/side-view/workflows/06_cutout.api.json"
const CONFIG_RELATIVE := "tools/asset_pipeline/config.json"
const SETTINGS_PATH := "user://weapon_lab_settings.json"
## Used when the workflow file is missing. Mirrors 06_cutout.api.json.
const DEFAULT_GRAPH := {
	"1": {"class_type": "LoadImage", "inputs": {"image": "choose-approved-concept.png"}},
	"2": {"class_type": "Trellis2RemoveBackground", "inputs": {"image": ["1", 0], "low_vram": true}},
	"3": {"class_type": "InvertMask", "inputs": {"mask": ["2", 1]}},
	"4": {"class_type": "JoinImageWithAlpha", "inputs": {"image": ["1", 0], "alpha": ["3", 0]}},
	"5": {"class_type": "SaveImage", "inputs": {"images": ["4", 0], "filename_prefix": "Telos/Weapons/cutout"}},
}

var base_url := DEFAULT_URL
var poll_interval := 1.0
var timeout_seconds := 900.0
var busy := false
var cancel_requested := false

func _ready() -> void:
	base_url = saved_url()

# ---------- settings ----------

## The URL saved from the Weapon Lab, else concept_url from
## tools/asset_pipeline/config.json, else http://127.0.0.1:8188.
static func saved_url() -> String:
	if FileAccess.file_exists(SETTINGS_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if saved is Dictionary and not str(saved.get("comfy_url", "")).is_empty():
			return str(saved["comfy_url"])
	var config_path := _repo_path(CONFIG_RELATIVE)
	if FileAccess.file_exists(config_path):
		var config = JSON.parse_string(FileAccess.get_file_as_string(config_path))
		if config is Dictionary and not str(config.get("concept_url", "")).is_empty():
			return str(config["concept_url"])
	return DEFAULT_URL

func set_url(url: String) -> String:
	var cleaned := url.strip_edges().trim_suffix("/")
	if cleaned.is_empty():
		cleaned = DEFAULT_URL
	if not cleaned.begins_with("http://") and not cleaned.begins_with("https://"):
		cleaned = "http://" + cleaned
	base_url = cleaned
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"comfy_url": base_url}, "  "))
		file.close()
	return base_url

static func is_local_url(url: String) -> bool:
	var rest := url.trim_prefix("http://").trim_prefix("https://")
	var host := rest.split("/")[0]
	if host.begins_with("["):
		host = host.substr(1, host.find("]") - 1)
	else:
		host = host.split(":")[0]
	return host in ["localhost", "127.0.0.1", "::1"]

static func _repo_path(relative: String) -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(relative)

static func load_graph() -> Dictionary:
	var path := _repo_path(WORKFLOW_RELATIVE)
	if FileAccess.file_exists(path):
		var graph = JSON.parse_string(FileAccess.get_file_as_string(path))
		if graph is Dictionary and graph.has("1") and graph.has("5"):
			return restore_link_integers(graph)
	return DEFAULT_GRAPH.duplicate(true)

## Godot's JSON parser reads every number as a float, so a node link like
## ["1", 0] comes back as ["1", 0.0] and ComfyUI rejects it ("list indices
## must be integers or slices, not float"). Turn link output slots back into ints.
## The /prompt body. Link slots are forced to integers twice over: in the
## data, and in the text in case a number still serializes as "0.0".
static func prompt_json(graph: Dictionary, token: String) -> String:
	var text := JSON.stringify({"prompt": restore_link_integers(graph.duplicate(true)), "extra_data": {"telos_job": token}})
	var links := RegEx.create_from_string("\\[\\s*(\"[^\"]*\")\\s*,\\s*(-?\\d+)\\.0+\\s*\\]")
	return links.sub(text, "[$1,$2]", true)

static func restore_link_integers(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value:
			value[key] = restore_link_integers(value[key])
		return value
	if value is Array:
		if value.size() == 2 and value[0] is String and value[1] is float and is_equal_approx(value[1], roundf(value[1])):
			return [value[0], int(value[1])]
		for index in range(value.size()):
			value[index] = restore_link_integers(value[index])
		return value
	return value

# ---------- API ----------

## {"ok": bool, "error": String, "has_trellis": bool}
func check_server() -> Dictionary:
	if not is_local_url(base_url):
		return {"ok": false, "has_trellis": false, "error": "Only a local ComfyUI server is supported (localhost / 127.0.0.1)."}
	var stats := await _request(HTTPClient.METHOD_GET, "/system_stats", PackedByteArray(), PackedStringArray(), 5.0)
	if not stats.ok:
		return {"ok": false, "has_trellis": false, "error": "ComfyUI isn't answering at %s. Start ComfyUI, then try again." % base_url}
	var info := await _request(HTTPClient.METHOD_GET, "/object_info/" + REMOVE_BACKGROUND_NODE, PackedByteArray(), PackedStringArray(), 15.0)
	var parsed = _json(info) if info.ok else null
	var has_node: bool = parsed is Dictionary and (parsed as Dictionary).has(REMOVE_BACKGROUND_NODE)
	if not has_node:
		return {"ok": false, "has_trellis": false, "error": "ComfyUI is running but the %s node (Trellis 2) isn't installed or loaded." % REMOVE_BACKGROUND_NODE}
	return {"ok": true, "has_trellis": true, "error": ""}

## Runs the Trellis 2 cutout graph on `image_path` (absolute).
## Returns {"ok", "image": Image, "error", "prompt_id", "history"}.
func cut_out(image_path: String, job_id: String) -> Dictionary:
	if busy:
		return _fail("A cutout is already running.")
	busy = true
	cancel_requested = false
	var result := await _cut_out(image_path, job_id)
	busy = false
	return result

func cancel() -> void:
	cancel_requested = true

func _cut_out(image_path: String, job_id: String) -> Dictionary:
	_status("Checking ComfyUI at %s..." % base_url)
	var check := await check_server()
	if not check.ok:
		return _fail(check.error)
	var bytes := FileAccess.get_file_as_bytes(image_path)
	if bytes.is_empty():
		return _fail("Couldn't read %s." % image_path)
	_status("Uploading image to ComfyUI...")
	var upload_name := "telos-weapon-%s.png" % job_id
	var boundary := "----TelosWeaponLab%d" % Time.get_ticks_usec()
	var body := PackedByteArray()
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\nContent-Type: image/png\r\n\r\n" % [boundary, upload_name]).to_utf8_buffer())
	body.append_array(bytes)
	body.append_array(("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--%s--\r\n" % [boundary, boundary]).to_utf8_buffer())
	var uploaded := await _request(HTTPClient.METHOD_POST, "/upload/image", body, PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary]), 60.0)
	if not uploaded.ok:
		return _fail("Upload failed: " + str(uploaded.error))
	var upload_info = _json(uploaded)
	if not upload_info is Dictionary or not upload_info.has("name"):
		return _fail("ComfyUI didn't return an upload name.")
	var image_ref := str(upload_info["name"])
	if not str(upload_info.get("subfolder", "")).is_empty():
		image_ref = str(upload_info["subfolder"]) + "/" + image_ref
	var graph := load_graph()
	graph["1"]["inputs"]["image"] = image_ref
	graph["5"]["inputs"]["filename_prefix"] = "Telos/Weapons/%s/cutout" % job_id
	# Free models from other work first, like the Python pipeline does. Best effort.
	await _request(HTTPClient.METHOD_POST, "/free", JSON.stringify({"unload_models": true, "free_memory": true}).to_utf8_buffer(), PackedStringArray(["Content-Type: application/json"]), 30.0)
	_status("Queuing the Trellis 2 cutout...")
	var token := "weapon:%s" % job_id
	var queued := await _request(HTTPClient.METHOD_POST, "/prompt", prompt_json(graph, token).to_utf8_buffer(), PackedStringArray(["Content-Type: application/json"]), 60.0)
	if not queued.ok:
		return _fail("ComfyUI rejected the cutout graph: " + str(queued.error))
	var queued_info = _json(queued)
	if not queued_info is Dictionary or not queued_info.has("prompt_id"):
		return _fail("ComfyUI didn't return a prompt id.")
	var prompt_id := str(queued_info["prompt_id"])
	var started := Time.get_ticks_msec()
	var history_entry: Dictionary = {}
	while true:
		if cancel_requested:
			return _fail("Cutout cancelled. ComfyUI may still finish the job in the background.")
		var waited := (Time.get_ticks_msec() - started) / 1000.0
		if waited > timeout_seconds:
			return _fail("Timed out after %d s waiting for ComfyUI (prompt %s)." % [int(timeout_seconds), prompt_id])
		_status("Trellis 2 is cutting out the weapon... %ds" % int(waited))
		var history := await _request(HTTPClient.METHOD_GET, "/history/" + prompt_id, PackedByteArray(), PackedStringArray(), 30.0)
		if history.ok:
			var parsed = _json(history)
			if parsed is Dictionary and parsed.has(prompt_id):
				history_entry = parsed[prompt_id]
				var status: Dictionary = history_entry.get("status", {})
				if str(status.get("status_str", "")) == "error":
					return _fail("ComfyUI reported an error: %s" % str(status.get("messages", [])).right(600))
				if bool(status.get("completed", false)):
					break
		await get_tree().create_timer(poll_interval).timeout
	var images: Array = history_entry.get("outputs", {}).get("5", {}).get("images", [])
	if images.size() != 1:
		return _fail("Expected one image from the cutout graph, got %d." % images.size())
	var picture: Dictionary = images[0]
	_status("Downloading the cutout...")
	var query := "?filename=%s&subfolder=%s&type=%s" % [str(picture.get("filename", "")).uri_encode(), str(picture.get("subfolder", "")).uri_encode(), str(picture.get("type", "output")).uri_encode()]
	var download := await _request(HTTPClient.METHOD_GET, "/view" + query, PackedByteArray(), PackedStringArray(), 60.0)
	if not download.ok:
		return _fail("Couldn't download the cutout: " + str(download.error))
	var image := Image.new()
	if image.load_png_from_buffer(download.body) != OK:
		return _fail("The cutout ComfyUI returned isn't a readable PNG.")
	_status("Cutout received.")
	return {"ok": true, "image": image, "error": "", "prompt_id": prompt_id, "history": history_entry, "gpu_work": {"submitted": true, "prompt_id": prompt_id, "reconciliation": "found", "token": token, "status": "complete"}}

func _request(method: int, endpoint: String, body: PackedByteArray, headers: PackedStringArray, timeout: float) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var error := http.request_raw(base_url + endpoint, headers, method, body)
	if error != OK:
		http.queue_free()
		return {"ok": false, "error": "request failed (%s)" % error_string(error)}
	var response: Array = await http.request_completed
	http.queue_free()
	var result: int = response[0]
	var code: int = response[1]
	var bytes: PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "no response from %s" % base_url}
	if code < 200 or code >= 300:
		return {"ok": false, "code": code, "error": "HTTP %d %s" % [code, bytes.get_string_from_utf8().left(400)]}
	return {"ok": true, "code": code, "body": bytes}

func _json(response: Dictionary) -> Variant:
	if not response.get("ok", false):
		return null
	return JSON.parse_string((response["body"] as PackedByteArray).get_string_from_utf8())

func _status(text: String) -> void:
	status_changed.emit(text)

func _fail(message: String) -> Dictionary:
	_status(message)
	return {"ok": false, "image": null, "error": message}
