extends Node

## ComfyUI client for the Creature Lab: uploads images, queues API graphs
## (MiniMax H3 animation, Trellis 2 cutouts), waits for them and downloads the
## outputs. Unlike comfy_cutout.gd it accepts a ComfyUI on the local network
## (the GPU box at DEFAULT_URL), since generation runs on another machine.
##
## Everything is async: `await run_graph(...)`. Progress goes out through
## `status_changed`.

signal status_changed(text: String)

const ComfyCutoutScript = preload("res://scripts/tools/comfy_cutout.gd")
const AnimationScript = preload("res://scripts/model/creature_animation.gd")

const DEFAULT_URL := "http://192.168.1.102:8188"
const SETTINGS_PATH := "user://creature_lab_settings.json"

var base_url := DEFAULT_URL
var poll_interval := 2.0
## H3 renders take minutes; masks seconds.
var timeout_seconds := 3600.0
var busy := false
var cancel_requested := false
## From the last check_server(): whether the H3 node lets last_frame be empty.
var last_frame_optional := false

func _ready() -> void:
	base_url = saved_url()

# ---------- settings ----------

static func saved_url() -> String:
	if FileAccess.file_exists(SETTINGS_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if saved is Dictionary and not str(saved.get("comfy_url", "")).is_empty():
			return str(saved["comfy_url"])
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

# ---------- API ----------

## {"ok", "error", "h3": bool, "trellis": bool, "last_frame_optional": bool,
##  "missing_models": Array}
func check_server() -> Dictionary:
	var result := {"ok": false, "error": "", "h3": false, "trellis": false, "last_frame_optional": false, "missing_models": []}
	var stats := await _request(HTTPClient.METHOD_GET, "/system_stats", PackedByteArray(), PackedStringArray(), 6.0)
	if not stats.ok:
		result.error = "ComfyUI isn't answering at %s. Is it running with --listen so other machines can reach it?" % base_url
		return result
	var h3_info: Variant = _json(await _request(HTTPClient.METHOD_GET, "/object_info/" + AnimationScript.H3_NODE, PackedByteArray(), PackedStringArray(), 20.0))
	var cut_info: Variant = _json(await _request(HTTPClient.METHOD_GET, "/object_info/" + AnimationScript.CUTOUT_NODE, PackedByteArray(), PackedStringArray(), 20.0))
	result.h3 = h3_info is Dictionary and (h3_info as Dictionary).has(AnimationScript.H3_NODE)
	result.trellis = cut_info is Dictionary and (cut_info as Dictionary).has(AnimationScript.CUTOUT_NODE)
	if result.h3:
		var optional: Dictionary = h3_info[AnimationScript.H3_NODE].get("input", {}).get("optional", {})
		result.last_frame_optional = optional.has("last_frame")
	last_frame_optional = result.last_frame_optional
	for pair in [["UNETLoader", "unet_name", AnimationScript.UNET], ["CLIPLoader", "clip_name", AnimationScript.CLIP], ["VAELoader", "vae_name", AnimationScript.VIDEO_VAE], ["VAELoader", "vae_name", AnimationScript.AUDIO_VAE]]:
		var info: Variant = _json(await _request(HTTPClient.METHOD_GET, "/object_info/" + str(pair[0]), PackedByteArray(), PackedStringArray(), 20.0))
		if not info is Dictionary or not (info as Dictionary).has(pair[0]):
			continue
		var required: Dictionary = info[pair[0]].get("input", {}).get("required", {})
		var choices: Variant = required.get(pair[1], [[]])[0]
		if choices is Array and not (choices as Array).has(pair[2]):
			result.missing_models.append(pair[2])
	if not result.h3:
		result.error = "ComfyUI is running but the %s node isn't installed." % AnimationScript.H3_NODE
	elif not result.missing_models.is_empty():
		result.error = "ComfyUI is missing model files: %s." % ", ".join(result.missing_models)
	else:
		result.ok = true
	return result

## Uploads a PNG; returns {"ok", "error", "name"} where name is what
## LoadImage takes.
func upload(path: String, upload_name: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return _fail("Couldn't read %s." % path)
	var boundary := "----TelosCreatureLab%d" % Time.get_ticks_usec()
	var body := PackedByteArray()
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\nContent-Type: image/png\r\n\r\n" % [boundary, upload_name]).to_utf8_buffer())
	body.append_array(bytes)
	body.append_array(("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--%s--\r\n" % [boundary, boundary]).to_utf8_buffer())
	var uploaded := await _request(HTTPClient.METHOD_POST, "/upload/image", body, PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary]), 120.0)
	if not uploaded.ok:
		return _fail("Upload failed: " + str(uploaded.error))
	var info: Variant = _json(uploaded)
	if not info is Dictionary or not info.has("name"):
		return _fail("ComfyUI didn't return an upload name.")
	var reference := str(info["name"])
	if not str(info.get("subfolder", "")).is_empty():
		reference = str(info["subfolder"]) + "/" + reference
	return {"ok": true, "error": "", "name": reference}

## Queues `graph` and waits for it. `on_queued` (optional) gets the prompt id
## as soon as ComfyUI accepts the job, so callers can save it.
## Returns {"ok", "error", "prompt_id", "history"}.
func run_graph(graph: Dictionary, token: String, label: String, on_queued: Callable = Callable()) -> Dictionary:
	if busy:
		return _fail("ComfyUI is already working on a job from the lab.")
	busy = true
	cancel_requested = false
	var result := await _run_graph(graph, token, label, on_queued)
	busy = false
	return result

## Waits for an already-queued prompt (resuming after a restart).
func wait_for(prompt_id: String, label: String) -> Dictionary:
	if busy:
		return _fail("ComfyUI is already working on a job from the lab.")
	busy = true
	cancel_requested = false
	var result := await _wait(prompt_id, label)
	busy = false
	return result

func cancel() -> void:
	cancel_requested = true

## Asks ComfyUI to stop the running job (best effort).
func interrupt() -> void:
	await _request(HTTPClient.METHOD_POST, "/interrupt", PackedByteArray(), PackedStringArray(), 10.0)

func _run_graph(graph: Dictionary, token: String, label: String, on_queued: Callable) -> Dictionary:
	# Free models from other work first, like the Python pipeline. Best effort.
	await _request(HTTPClient.METHOD_POST, "/free", JSON.stringify({"unload_models": true, "free_memory": true}).to_utf8_buffer(), PackedStringArray(["Content-Type: application/json"]), 30.0)
	_status("Queuing %s on %s..." % [label, base_url])
	var queued := await _request(HTTPClient.METHOD_POST, "/prompt", ComfyCutoutScript.prompt_json(graph, token).to_utf8_buffer(), PackedStringArray(["Content-Type: application/json"]), 60.0)
	if not queued.ok:
		return _fail("ComfyUI rejected the graph: " + str(queued.error))
	var info: Variant = _json(queued)
	if not info is Dictionary or not info.has("prompt_id"):
		return _fail("ComfyUI didn't return a prompt id.")
	var prompt_id := str(info["prompt_id"])
	if on_queued.is_valid():
		on_queued.call(prompt_id)
	return await _wait(prompt_id, label)

func _wait(prompt_id: String, label: String) -> Dictionary:
	var started := Time.get_ticks_msec()
	while true:
		if cancel_requested:
			var stopped := _fail("Stopped waiting. ComfyUI may still finish %s; open the take later to collect it." % label)
			stopped["prompt_id"] = prompt_id
			stopped["cancelled"] = true
			return stopped
		var waited := (Time.get_ticks_msec() - started) / 1000.0
		if waited > timeout_seconds:
			var late := _fail("Timed out after %d s waiting for ComfyUI (prompt %s)." % [int(timeout_seconds), prompt_id])
			late["prompt_id"] = prompt_id
			return late
		var history := await _request(HTTPClient.METHOD_GET, "/history/" + prompt_id, PackedByteArray(), PackedStringArray(), 30.0)
		var parsed: Variant = _json(history) if history.ok else null
		if parsed is Dictionary and parsed.has(prompt_id):
			var entry: Dictionary = parsed[prompt_id]
			var status: Dictionary = entry.get("status", {})
			if str(status.get("status_str", "")) == "error":
				var failed := _fail("ComfyUI reported an error: %s" % _error_text(status))
				failed["prompt_id"] = prompt_id
				failed["history"] = entry
				return failed
			if bool(status.get("completed", false)):
				_status("%s finished." % label.capitalize())
				return {"ok": true, "error": "", "prompt_id": prompt_id, "history": entry}
		_status("%s... %ds%s" % [label.capitalize(), int(waited), await _queue_note(prompt_id)])
		await get_tree().create_timer(poll_interval).timeout
	return _fail("unreachable")

## " (2 ahead in the queue)" or "" when running.
func _queue_note(prompt_id: String) -> String:
	var queue: Variant = _json(await _request(HTTPClient.METHOD_GET, "/queue", PackedByteArray(), PackedStringArray(), 10.0))
	if not queue is Dictionary:
		return ""
	var running: Array = queue.get("queue_running", [])
	for row in running:
		if row is Array and row.size() > 1 and str(row[1]) == prompt_id:
			return " (rendering)"
	var pending: Array = queue.get("queue_pending", [])
	var ahead := running.size()
	for row in pending:
		if row is Array and row.size() > 1 and str(row[1]) == prompt_id:
			return " (%d ahead in the queue)" % ahead
		ahead += 1
	return ""

## The image records a node saved: [{"filename", "subfolder", "type"}].
static func output_images(history: Dictionary, node_id: String) -> Array:
	return history.get("outputs", {}).get(node_id, {}).get("images", [])

## Downloads one output image record; returns {"ok", "error", "bytes"}.
func download(picture: Dictionary) -> Dictionary:
	var query := "?filename=%s&subfolder=%s&type=%s" % [str(picture.get("filename", "")).uri_encode(), str(picture.get("subfolder", "")).uri_encode(), str(picture.get("type", "output")).uri_encode()]
	var response := await _request(HTTPClient.METHOD_GET, "/view" + query, PackedByteArray(), PackedStringArray(), 120.0)
	if not response.ok:
		return _fail("Couldn't download %s: %s" % [picture.get("filename", "?"), response.error])
	return {"ok": true, "error": "", "bytes": response.body}

## Trellis 2 cutout of one PNG. Returns {"ok", "error", "image": Image}.
func cut_out(path: String, job_name: String) -> Dictionary:
	var uploaded := await upload(path, "telos-creature-%s.png" % job_name)
	if not uploaded.ok:
		return uploaded
	var graph := AnimationScript.cutout_graph(str(uploaded.name), "Telos/Creatures/cutout/%s" % job_name)
	var done := await run_graph(graph, "creature-cutout:%s" % job_name, "Trellis 2 cutout")
	if not done.ok:
		return done
	var images := output_images(done.history, AnimationScript.CUTOUT_OUTPUT_NODE)
	if images.size() != 1:
		return _fail("Expected one image from the cutout graph, got %d." % images.size())
	var fetched := await download(images[0])
	if not fetched.ok:
		return fetched
	var image := Image.new()
	if image.load_png_from_buffer(fetched.bytes) != OK:
		return _fail("The cutout ComfyUI returned isn't a readable PNG.")
	return {"ok": true, "error": "", "image": image}

# ---------- transport ----------

func _request(method: int, endpoint: String, body: PackedByteArray, headers: PackedStringArray, timeout: float) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.body_size_limit = -1
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
		return {"ok": false, "code": code, "error": "HTTP %d %s" % [code, bytes.get_string_from_utf8().left(600)]}
	return {"ok": true, "code": code, "body": bytes}

static func _json(response: Dictionary) -> Variant:
	if not response.get("ok", false):
		return null
	return JSON.parse_string((response["body"] as PackedByteArray).get_string_from_utf8())

static func _error_text(status: Dictionary) -> String:
	for message in status.get("messages", []):
		if message is Array and message.size() > 1 and str(message[0]) == "execution_error" and message[1] is Dictionary:
			return "%s: %s" % [message[1].get("node_type", "node"), str(message[1].get("exception_message", "")).strip_edges()]
	return str(status.get("messages", [])).right(600)

func _status(text: String) -> void:
	status_changed.emit(text)

func _fail(message: String) -> Dictionary:
	_status(message)
	return {"ok": false, "error": message}
