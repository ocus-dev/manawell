extends Control

# Keep vector controls crisp while fitting the entire page below navigation.
var page: Control
var layout_pending := false

func configure(content: Control) -> void:
	page = content
	page.reparent(self)
	page.minimum_size_changed.connect(_queue_layout)
	resized.connect(_queue_layout)
	visibility_changed.connect(_queue_layout)
	_queue_layout()

func _queue_layout() -> void:
	if layout_pending:
		return
	layout_pending = true
	call_deferred("_fit")

func _fit() -> void:
	layout_pending = false
	if page == null or size.x <= 0 or size.y <= 0:
		return
	var width := maxf(1000.0, size.x)
	page.size.x = width
	var minimum := page.get_combined_minimum_size()
	width = maxf(width, minimum.x)
	var factor := minf(1.0, minf(size.x / width, size.y / maxf(1.0, minimum.y)))
	page.scale = Vector2.ONE * factor
	page.position = Vector2.ZERO
	page.size = Vector2(width, size.y / factor)
