extends DraggablePanel
## LineModeSettings.gd
## Manages the UI panel and logic for the Line Mode settings
## This script controls the visibility of the settings panel and provides methods to:
## 1. Initialize the panel to the bottom center of the viewport
## 2. Show and hide the panel
## 3. Retrieve all current line properties (e.g., fuzz, color, thickness) set by the user

var _is_loading_settings: bool = false
var polygon_mode: bool = false

signal polygon_mode_toggled(is_on)

func _ready() -> void:
	var viewport_size: Vector2 = get_viewport().size
	var panel: Control = self
	var panel_size: Vector2 = panel.rect_size
	
	var default_x: float = (viewport_size.x - panel_size.x) / 2.0
	var default_y: float = viewport_size.y - panel_size.y - 10.0
	var default_pos: Vector2 = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)

	_connect_settings_signals()
	load_settings()
	_update_polygon_mode()

func get_properties() -> Dictionary:
	var properties: Dictionary = {}
	
	var fuzz_node: Control = find_node("Fuzz")
	var color_node: Control = find_node("Color")
	var left_outline_node: Control = find_node("LeftOutlineColor")
	var right_outline_node: Control = find_node("RightOutlineColor")
	var start_thick_node: Control = find_node("StartThickness")
	var end_thick_node: Control = find_node("EndThickness")
	var outline_type_node: Control = find_node("OutlineType")
	var draw_order_node: Control = find_node("DrawOrder")
	
	var replace_fuzz_node: Button = find_node("ReplaceFuzz")
	var replace_color_node: Button = find_node("ReplaceColor")
	var replace_left_outline_node: Button = find_node("ReplaceLeftOutlineColor")
	var replace_right_outline_node: Button = find_node("ReplaceRightOutlineColor")
	var replace_start_thick_node: Button = find_node("ReplaceStartThickness")
	var replace_end_thick_node: Button = find_node("ReplaceEndThickness")
	var replace_outline_type_node: Button = find_node("ReplaceOutlineType")
	var replace_draw_order_node: Button = find_node("ReplaceDrawOrder")
	
	properties["fuzz"] = fuzz_node.value
	properties["color"] = color_node.text.to_int()
	properties["left_outline_color"] = left_outline_node.text.to_int()
	properties["right_outline_color"] = right_outline_node.text.to_int()
	properties["start_thickness"] = start_thick_node.value
	properties["end_thickness"] = end_thick_node.value
	properties["outline_type"] = outline_type_node.value
	properties["draw_order"] = draw_order_node.value

	properties["apply_fuzz"] = replace_fuzz_node.pressed
	properties["apply_color"] = replace_color_node.pressed
	properties["apply_left_outline"] = replace_left_outline_node.pressed
	properties["apply_right_outline"] = replace_right_outline_node.pressed
	properties["apply_start_thick"] = replace_start_thick_node.pressed
	properties["apply_end_thick"] = replace_end_thick_node.pressed
	properties["apply_outline_type"] = replace_outline_type_node.pressed
	properties["apply_draw_order"] = replace_draw_order_node.pressed
	
	return properties

func _connect_settings_signals() -> void:
	var fuzz_node: Control = find_node("Fuzz")
	var color_node: Control = find_node("Color")
	var left_outline_node: Control = find_node("LeftOutlineColor")
	var right_outline_node: Control = find_node("RightOutlineColor")
	var start_thick_node: Control = find_node("StartThickness")
	var end_thick_node: Control = find_node("EndThickness")
	var outline_type_node: Control = find_node("OutlineType")
	var draw_order_node: Control = find_node("DrawOrder")
	
	var replace_fuzz_node: Button = find_node("ReplaceFuzz")
	var replace_color_node: Button = find_node("ReplaceColor")
	var replace_left_outline_node: Button = find_node("ReplaceLeftOutlineColor")
	var replace_right_outline_node: Button = find_node("ReplaceRightOutlineColor")
	var replace_start_thick_node: Button = find_node("ReplaceStartThickness")
	var replace_end_thick_node: Button = find_node("ReplaceEndThickness")
	var replace_outline_type_node: Button = find_node("ReplaceOutlineType")
	var replace_draw_order_node: Button = find_node("ReplaceDrawOrder")

	fuzz_node.connect("value_changed", self, "_on_setting_changed")
	color_node.connect("text_changed", self, "_on_setting_changed")
	left_outline_node.connect("text_changed", self, "_on_setting_changed")
	right_outline_node.connect("text_changed", self, "_on_setting_changed")
	start_thick_node.connect("value_changed", self, "_on_setting_changed")
	end_thick_node.connect("value_changed", self, "_on_setting_changed")
	outline_type_node.connect("value_changed", self, "_on_setting_changed")
	draw_order_node.connect("value_changed", self, "_on_setting_changed")

	replace_fuzz_node.connect("toggled", self, "_on_setting_changed")
	replace_color_node.connect("toggled", self, "_on_setting_changed")
	replace_left_outline_node.connect("toggled", self, "_on_setting_changed")
	replace_right_outline_node.connect("toggled", self, "_on_setting_changed")
	replace_start_thick_node.connect("toggled", self, "_on_setting_changed")
	replace_end_thick_node.connect("toggled", self, "_on_setting_changed")
	replace_outline_type_node.connect("toggled", self, "_on_setting_changed")
	replace_draw_order_node.connect("toggled", self, "_on_setting_changed")

	var reset_btn: Button = find_node("ResetDefaultsButton")
	var polygon_cb: Button = find_node("PolygonModeCheckBox")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")
	if polygon_cb:
		polygon_cb.connect("toggled", self, "_on_PolygonModeCheckBox_toggled")

func _on_setting_changed(_arg = null) -> void:
	if _is_loading_settings:
		return
	save_settings()

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)
		return

	config.set_value("LineProperties", "fuzz", find_node("Fuzz").value)
	config.set_value("LineProperties", "color", find_node("Color").text)
	config.set_value("LineProperties", "left_outline_color", find_node("LeftOutlineColor").text)
	config.set_value("LineProperties", "right_outline_color", find_node("RightOutlineColor").text)
	config.set_value("LineProperties", "start_thickness", find_node("StartThickness").value)
	config.set_value("LineProperties", "end_thickness", find_node("EndThickness").value)
	config.set_value("LineProperties", "outline_type", find_node("OutlineType").value)
	config.set_value("LineProperties", "draw_order", find_node("DrawOrder").value)

	config.set_value("LineProperties", "replace_fuzz", find_node("ReplaceFuzz").pressed)
	config.set_value("LineProperties", "replace_color", find_node("ReplaceColor").pressed)
	config.set_value("LineProperties", "replace_left_outline_color", find_node("ReplaceLeftOutlineColor").pressed)
	config.set_value("LineProperties", "replace_right_outline_color", find_node("ReplaceRightOutlineColor").pressed)
	config.set_value("LineProperties", "replace_start_thickness", find_node("ReplaceStartThickness").pressed)
	config.set_value("LineProperties", "replace_end_thickness", find_node("ReplaceEndThickness").pressed)
	config.set_value("LineProperties", "replace_outline_type", find_node("ReplaceOutlineType").pressed)
	config.set_value("LineProperties", "replace_draw_order", find_node("ReplaceDrawOrder").pressed)
	config.set_value("LineProperties", "polygon_mode", find_node("PolygonModeCheckBox").pressed)

	var save_err: int = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving LineMode settings: ", save_err)

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		return

	print("[STATUS] LineModeSettings: loading settings configuration")
	_is_loading_settings = true

	find_node("Fuzz").value = config.get_value("LineProperties", "fuzz", 0)
	find_node("Color").text = config.get_value("LineProperties", "color", "-1")
	find_node("LeftOutlineColor").text = config.get_value("LineProperties", "left_outline_color", "-1")
	find_node("RightOutlineColor").text = config.get_value("LineProperties", "right_outline_color", "-1")
	find_node("StartThickness").value = config.get_value("LineProperties", "start_thickness", 100)
	find_node("EndThickness").value = config.get_value("LineProperties", "end_thickness", 100)
	find_node("OutlineType").value = config.get_value("LineProperties", "outline_type", 0)
	find_node("DrawOrder").value = config.get_value("LineProperties", "draw_order", 0)

	find_node("ReplaceFuzz").pressed = config.get_value("LineProperties", "replace_fuzz", true)
	find_node("ReplaceColor").pressed = config.get_value("LineProperties", "replace_color", true)
	find_node("ReplaceLeftOutlineColor").pressed = config.get_value("LineProperties", "replace_left_outline_color", true)
	find_node("ReplaceRightOutlineColor").pressed = config.get_value("LineProperties", "replace_right_outline_color", true)
	find_node("ReplaceStartThickness").pressed = config.get_value("LineProperties", "replace_start_thickness", true)
	find_node("ReplaceEndThickness").pressed = config.get_value("LineProperties", "replace_end_thickness", true)
	find_node("ReplaceOutlineType").pressed = config.get_value("LineProperties", "replace_outline_type", true)
	find_node("ReplaceDrawOrder").pressed = config.get_value("LineProperties", "replace_draw_order", true)
	find_node("PolygonModeCheckBox").pressed = config.get_value("LineProperties", "polygon_mode", false)

	_is_loading_settings = false

func _on_reset_defaults_pressed() -> void:
	_is_loading_settings = true

	find_node("Fuzz").value = 0
	find_node("Color").text = "-1"
	find_node("LeftOutlineColor").text = "-1"
	find_node("RightOutlineColor").text = "-1"
	find_node("StartThickness").value = 100
	find_node("EndThickness").value = 100
	find_node("OutlineType").value = 0
	find_node("DrawOrder").value = 0

	find_node("ReplaceFuzz").pressed = true
	find_node("ReplaceColor").pressed = true
	find_node("ReplaceLeftOutlineColor").pressed = true
	find_node("ReplaceRightOutlineColor").pressed = true
	find_node("ReplaceStartThickness").pressed = true
	find_node("ReplaceEndThickness").pressed = true
	find_node("ReplaceOutlineType").pressed = true
	find_node("ReplaceDrawOrder").pressed = true

	_is_loading_settings = false
	save_settings()

func _update_polygon_mode() -> void:
	var check_box: Button = find_node("PolygonModeCheckBox")
	if check_box:
		polygon_mode = check_box.pressed
		emit_signal("polygon_mode_toggled", polygon_mode)

func _on_PolygonModeCheckBox_toggled(is_on: bool) -> void:
	polygon_mode = is_on
	save_settings()
	emit_signal("polygon_mode_toggled", is_on)
