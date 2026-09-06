extends Control
class_name DesignCanvas
## DesignCanvas.gd
## Handles logic for drawing paintball design on a canvas

signal design_changed

var design_paintballs: Array = []
var brush_size: float = 30.0
var current_color_slot: int = 1
var is_drawing: bool = false
var coordinate_multiplier: float = 1.0
var brush_spacing: float = 5.0
var last_draw_pos: Vector2 = Vector2.ZERO
var current_mouse_pos: Vector2 = Vector2.ZERO
var is_mouse_inside: bool = false

var mirror_x: bool = false
var mirror_y: bool = false
var eraser_mode: bool = false

var straight_line_enabled: bool = false
var _last_click_pos: Vector2 = Vector2(-1, -1)

var slot_data_ref: Array = []

func _ready() -> void:
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		is_drawing = true
		last_draw_pos = event.position
		var current_pos: Vector2 = event.position

		var is_straight_line: bool = straight_line_enabled or Input.is_key_pressed(KEY_SHIFT)

		if is_straight_line and _last_click_pos != Vector2(-1, -1):
			var check_pos: Vector2 = _last_click_pos

			if Input.is_key_pressed(KEY_X):
				current_pos.y = check_pos.y
			elif Input.is_key_pressed(KEY_Y):
				current_pos.x = check_pos.x

			var dist: float = check_pos.distance_to(current_pos)
			var rect_size: Vector2 = get_rect().size
			var step_dist: float = (brush_spacing / 100.0) * rect_size.x
			var steps: int = max(1, round(dist / max(1.0, step_dist)))

			for i in range(1, steps + 1):
				var t: float = float(i) / float(steps)
				var interp_pos: Vector2 = check_pos.linear_interpolate(current_pos, t)
				var norm_x: float = (interp_pos.x - rect_size.x / 2.0) / (rect_size.x / 2.0)
				var norm_y: float = (interp_pos.y - rect_size.y / 2.0) / (rect_size.y / 2.0)
				if abs(norm_x) <= 1.0 and abs(norm_y) <= 1.0:
					var pb: Dictionary = {
						"x": norm_x,
						"y": norm_y,
						"diameter": brush_size,
						"color_slot": current_color_slot
					}
					design_paintballs.append(pb)
			update()
			emit_signal("design_changed")
		elif eraser_mode:
			_erase_at(current_pos)
		else:
			_add_paintball_symmetric(current_pos)
			update()

		_last_click_pos = current_pos

	elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		is_drawing = false

	elif event is InputEventMouseMotion:
		current_mouse_pos = event.position
		update()
		if is_drawing:
			var rect_size: Vector2 = get_rect().size
			var pixel_spacing: float = (brush_spacing / 100.0) * rect_size.x
			if event.position.distance_to(last_draw_pos) >= pixel_spacing:
				if eraser_mode:
					_erase_at(event.position)
				elif straight_line_enabled:
					# Straight line: stamp points continuously while dragging
					var center: Vector2 = rect_size / 2.0
					var relative: Vector2 = event.position - center
					var norm_x: float = relative.x / (rect_size.x / 2.0)
					var norm_y: float = relative.y / (rect_size.y / 2.0)
					if abs(norm_x) <= 1.0 and abs(norm_y) <= 1.0:
						var pb: Dictionary = {
							"x": norm_x,
							"y": norm_y,
							"diameter": brush_size,
							"color_slot": current_color_slot
						}
						design_paintballs.append(pb)
						update()
						emit_signal("design_changed")
				else:
					_add_paintball_symmetric(event.position)
				last_draw_pos = event.position

func _erase_at(pos: Vector2) -> void:
	var rect_size: Vector2 = get_rect().size
	var center: Vector2 = rect_size / 2.0

	var pixel_diameter: float = (brush_size / 100.0) * rect_size.x
	var erase_radius: float = pixel_diameter / 2.0

	var to_remove: Array = []
	for i in range(design_paintballs.size()):
		var pb: Dictionary = design_paintballs[i]
		var pb_pos: Vector2 = _norm_to_local(pb["x"], pb["y"])
		if pb_pos.distance_to(pos) <= erase_radius:
			to_remove.append(i)

	if not to_remove.empty():
		to_remove.invert()
		for i in to_remove:
			design_paintballs.remove(i)
		
		# Clean up temporary array
		to_remove.resize(0)
		
		update()
		emit_signal("design_changed")

func _add_paintball_symmetric(pos: Vector2) -> void:
	var rect_size: Vector2 = get_rect().size
	var center: Vector2 = rect_size / 2.0
	var relative: Vector2 = pos - center

	_add_paintball(pos)

	if mirror_x:
		var mx_pos: Vector2 = center + Vector2(-relative.x, relative.y)
		if mx_pos.distance_to(pos) > 1.0:
			_add_paintball(mx_pos)

	if mirror_y:
		var my_pos: Vector2 = center + Vector2(relative.x, -relative.y)
		if my_pos.distance_to(pos) > 1.0:
			_add_paintball(my_pos)

	if mirror_x and mirror_y:
		var mxy_pos: Vector2 = center + Vector2(-relative.x, -relative.y)
		var dist_pos: float = mxy_pos.distance_to(pos)
		var mx_pos: Vector2 = center + Vector2(-relative.x, relative.y)
		var my_pos: Vector2 = center + Vector2(relative.x, -relative.y)
		var dist_mx: float = mxy_pos.distance_to(mx_pos)
		var dist_my: float = mxy_pos.distance_to(my_pos)

		if dist_pos > 1.0 and dist_mx > 1.0 and dist_my > 1.0:
			_add_paintball(mxy_pos)

func _add_paintball(pos: Vector2) -> void:
	var rect_size: Vector2 = get_rect().size
	var center: Vector2 = rect_size / 2.0

	var norm_x: float = (pos.x - center.x) / (rect_size.x / 2.0)
	var norm_y: float = (pos.y - center.y) / (rect_size.y / 2.0)

	# Clamp to canvas
	if abs(norm_x) > 1.0 or abs(norm_y) > 1.0:
		return

	var pb: Dictionary = {
		"x": norm_x,
		"y": norm_y,
		"diameter": brush_size,
		"color_slot": current_color_slot
	}

	design_paintballs.append(pb)
	update()
	emit_signal("design_changed")

func _draw() -> void:
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.2, 0.2, 0.2))

	# Draw grid lines
	var center: Vector2 = rect_size / 2.0
	draw_line(Vector2(center.x, 0), Vector2(center.x, rect_size.y), Color(0.3, 0.3, 0.3), 2.0)
	draw_line(Vector2(0, center.y), Vector2(rect_size.x, center.y), Color(0.3, 0.3, 0.3), 2.0)

	# Draw symmetry lines
	if mirror_x:
		draw_line(Vector2(center.x, 0), Vector2(center.x, rect_size.y), Color(1, 0.5, 0.5, 0.5), 2.0)
	if mirror_y:
		draw_line(Vector2(0, center.y), Vector2(rect_size.x, center.y), Color(0.5, 0.5, 1, 0.5), 2.0)

	# Draw paintballs
	for pb in design_paintballs:
		var pos: Vector2 = _norm_to_local(pb["x"], pb["y"])
		var color: Color = _get_slot_color(pb["color_slot"])
		var pixel_diameter: float = (pb["diameter"] / 100.0) * rect_size.x
		draw_circle(pos, pixel_diameter / 2.0, color)

	if is_mouse_inside:
		var current_pixel_diam: float = (brush_size / 100.0) * rect_size.x
		draw_arc(current_mouse_pos, current_pixel_diam / 2.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 1.0)

func _norm_to_local(nx: float, ny: float) -> Vector2:
	var rect_size: Vector2 = get_rect().size
	var center: Vector2 = rect_size / 2.0
	var x: float = center.x + nx * (rect_size.x / 2.0)
	var y: float = center.y + ny * (rect_size.y / 2.0)
	return Vector2(x, y)

func _get_slot_color(slot_idx: int) -> Color:
	var idx: int = slot_idx - 1
	if idx >= 0 and idx < slot_data_ref.size():
		return slot_data_ref[idx].get("display_color", Color.white)
	return Color.white

func clear() -> void:
	design_paintballs.clear()
	update()
	emit_signal("design_changed")

func _on_mouse_entered() -> void:
	is_mouse_inside = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	update()

func _on_mouse_exited() -> void:
	is_mouse_inside = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	update()
