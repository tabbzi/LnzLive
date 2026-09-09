class_name DraggablePanel
extends Panel
## DraggablePanel.gd
## 1. Allows a `Panel` or `PanelContainer` node be clicked and dragged
## 2. Saves last position that panels have been dragged but not off-screen

const SETTINGS_PATH: String = "user://settings.cfg"
const CONFIG_SECTION: String = "PanelPositions"

var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var is_docked: bool = false

var dock_button: Button
var resize_grip: Control
var original_rect_size: Vector2
var _resize_start_size: Vector2 = Vector2.ZERO

var _is_loading_settings: bool = false

func _ready() -> void:
	get_viewport().connect("size_changed", self, "_on_viewport_resized")

	dock_button = Button.new()
	
	add_child(dock_button)

	_stylize_button(dock_button, "Dock")

	dock_button.set_anchors_and_margins_preset(Control.PRESET_TOP_RIGHT)
	dock_button.margin_right = -35
	dock_button.margin_top = 5
	dock_button.margin_left = -95
	dock_button.margin_bottom = 25

	dock_button.connect("pressed", self, "_on_dock_button_pressed")
	
	update_buttons()
	_create_resize_grip()

func _create_resize_grip() -> void:
	resize_grip = Control.new()
	resize_grip.name = "ResizeGrip"
	resize_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	resize_grip.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_RIGHT)
	resize_grip.margin_left = -20
	resize_grip.margin_top = -20
	resize_grip.margin_right = 0
	resize_grip.margin_bottom = 0
	resize_grip.connect("draw", self, "_on_resize_grip_draw")
	resize_grip.connect("gui_input", self, "_on_resize_grip_input")
	add_child(resize_grip)
	_hide_resize_grip()

func _on_resize_grip_draw() -> void:
	var w: float = rect_size.x
	var h: float = rect_size.y
	var lines: int = 4
	var step: float = min(w, h) / lines
	
	for i in range(1, lines + 1):
		var y: float = h - step * i
		var x: float = w - step * i
		draw_line(Vector2(x, y), Vector2(w, y), Color(0.5, 0.5, 0.5, 0.7), 1.0)
		draw_line(Vector2(x, y), Vector2(x, h), Color(0.5, 0.5, 0.5, 0.7), 1.0)

func _show_resize_grip() -> void:
	if resize_grip:
		resize_grip.visible = true
		resize_grip.update()

func _hide_resize_grip() -> void:
	if resize_grip:
		resize_grip.visible = false

func _stylize_button(btn: Button, btn_text: String) -> void:
	btn.text = btn_text
	
	var style_normal: StyleBoxFlat = load("res://resources/styles/styleboxflat_button_normal.tres")
	var style_hover: StyleBoxFlat = load("res://resources/styles/styleboxflat_button_hover.tres")
	var pixel_font: Font = load("res://resources/fonts/font_pixel_maz_24.tres")

	btn.add_stylebox_override("normal", style_normal)
	btn.add_stylebox_override("hover", style_hover)
	btn.add_stylebox_override("pressed", style_normal)
	btn.add_stylebox_override("focus", load("res://resources/styles/stylebox_empty.tres"))
	btn.add_font_override("font", pixel_font)
	
	btn.set_deferred("flat", false)

func _gui_input(event: InputEvent) -> void:
	if is_docked:
		return

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				raise()
				dragging = true
				drag_start = get_global_mouse_position() - rect_global_position
			else:
				dragging = false
				save_position()
				
	elif event is InputEventMouseMotion and dragging:
		rect_global_position = get_global_mouse_position() - drag_start

func _on_resize_grip_input(event: InputEvent) -> void:
	if is_docked:
		return
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				_resize_start_size = rect_size
				dragging = true
				drag_start = get_global_mouse_position()
			else:
				dragging = false
				save_position()
	elif event is InputEventMouseMotion and dragging:
		var delta: Vector2 = get_global_mouse_position() - drag_start
		rect_size = _resize_start_size + delta
		if resize_grip:
			resize_grip.update()

func save_position() -> void:
	if is_docked: return
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(CONFIG_SECTION, self.name, _get_clamped_position())
	config.save(SETTINGS_PATH)

func restore_position(default_pos: Vector2) -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK and config.has_section_key(CONFIG_SECTION, self.name):
		rect_global_position = config.get_value(CONFIG_SECTION, self.name)
	else:
		rect_global_position = default_pos
	rect_global_position = _get_clamped_position()

func _on_viewport_resized() -> void:
	if not is_docked:
		rect_global_position = _get_clamped_position()

func _get_clamped_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = get_panel_size()
	var new_x: float = clamp(rect_global_position.x, 0, max(0, viewport_size.x - panel_size.x))
	var new_y: float = clamp(rect_global_position.y, 0, max(0, viewport_size.y - panel_size.y))
	return Vector2(new_x, new_y)

func _on_dock_button_pressed() -> void:
	var sidebar: Node = get_tree().root.find_node("VBoxContainer", true, false)
	if sidebar and sidebar.has_method("dock_panel"):
		if is_docked:
			sidebar.undock_panel(self)
		else:
			sidebar.dock_panel(self)

func _on_close_button_pressed() -> void:
	_on_dock_button_pressed()

func set_docked(docked: bool) -> void:
	is_docked = docked
	dragging = false
	
	if is_docked:
		_hide_resize_grip()
		set_anchors_and_margins_preset(Control.PRESET_WIDE)
		margin_left = 0
		margin_right = 0
		margin_top = 0
		margin_bottom = 0
		size_flags_horizontal = SIZE_EXPAND_FILL
		size_flags_vertical = SIZE_EXPAND_FILL
	else:
		set_anchors_and_margins_preset(Control.PRESET_TOP_LEFT)
		rect_size = rect_min_size
		_show_resize_grip()
		restore_position(_default_position())

	update_buttons()

func update_buttons() -> void:
	if is_docked:
		dock_button.text = "Pop out"
	else:
		dock_button.text = "Dock"

func _default_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport().size
	var panel_size: Vector2 = get_panel_size()
	var default_x: float = (viewport_size.x - panel_size.x) / 2.0
	var default_y: float = viewport_size.y - panel_size.y - 10.0
	return Vector2(default_x, default_y)

func get_panel_size() -> Vector2:
	if is_docked:
		return rect_size
	if original_rect_size.x > 0 and original_rect_size.y > 0:
		return original_rect_size
	return rect_min_size
