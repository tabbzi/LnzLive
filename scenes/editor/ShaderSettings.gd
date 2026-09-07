extends WindowDialog
## ShaderSettings.gd
## Manages the UI panel and logic for Shader properties (rotation mode, input vector, etc.)

const SETTINGS_PATH: String = "user://settings.cfg"

signal texture_rotation_mode_changed(mode)
signal texture_rotation_input_changed(input_vec)
signal texture_affected_by_size_changed(is_affected)
signal texture_affected_by_rotation_changed(is_affected)
signal texture_flat_colors_changed(is_flat)

var _is_loading_settings: bool = false

var _pending_mode: int = 1
var _pending_input_vec: Vector2 = Vector2.ZERO
var _pending_affected_by_size: bool = true
var _pending_affected_by_rotation: bool = false
var _pending_render_flat_colors: bool = false

onready var mode_option: OptionButton = $MarginContainer/VBoxContainer/ModeOptionButton
onready var input_x_spinbox: SpinBox = $MarginContainer/VBoxContainer/HBoxContainer/InputX
onready var input_y_spinbox: SpinBox = $MarginContainer/VBoxContainer/HBoxContainer/InputY
onready var size_checkbox: CheckBox = $MarginContainer/VBoxContainer/HBoxContainer2/SizeCheckBox
onready var rotation_checkbox: CheckBox = $MarginContainer/VBoxContainer/HBoxContainer2/RotationCheckBox
onready var flat_colors_checkbox: CheckBox = $MarginContainer/VBoxContainer/HBoxContainer3/FlatColorsCheckBox

func _ready() -> void:
	# Apply initial pending values before connecting signals
	mode_option.selected = _pending_mode
	input_x_spinbox.value = _pending_input_vec.x
	input_y_spinbox.value = _pending_input_vec.y
	size_checkbox.pressed = _pending_affected_by_size
	rotation_checkbox.pressed = _pending_affected_by_rotation
	flat_colors_checkbox.pressed = _pending_render_flat_colors

	mode_option.connect("item_selected", self, "_on_mode_selected")
	input_x_spinbox.connect("value_changed", self, "_on_input_changed")
	input_y_spinbox.connect("value_changed", self, "_on_input_changed")
	size_checkbox.connect("toggled", self, "_on_size_toggled")
	rotation_checkbox.connect("toggled", self, "_on_rotation_toggled")
	flat_colors_checkbox.connect("toggled", self, "_on_flat_colors_toggled")

	# Load stored values to overwrite defaults
	_load_settings()

func get_render_flat_colors() -> bool:
	return flat_colors_checkbox.pressed

func _on_flat_colors_toggled(is_on: bool) -> void:
	emit_signal("texture_flat_colors_changed", is_on)
	if not _is_loading_settings:
		_save_settings()
	
func get_mode() -> int:
	return mode_option.selected

func get_input_vec() -> Vector2:
	return Vector2(input_x_spinbox.value, input_y_spinbox.value)

func get_affected_by_size() -> bool:
	return size_checkbox.pressed

func get_affected_by_rotation() -> bool:
	return rotation_checkbox.pressed

func _on_mode_selected(index: int) -> void:
	emit_signal("texture_rotation_mode_changed", index)
	if not _is_loading_settings:
		_save_settings()

func _on_input_changed(_value: float) -> void:
	var input_vec: Vector2 = Vector2(input_x_spinbox.value, input_y_spinbox.value)
	emit_signal("texture_rotation_input_changed", input_vec)
	if not _is_loading_settings:
		_save_settings()

func _on_size_toggled(is_on: bool) -> void:
	emit_signal("texture_affected_by_size_changed", is_on)
	if not _is_loading_settings:
		_save_settings()

func _on_rotation_toggled(is_on: bool) -> void:
	emit_signal("texture_affected_by_rotation_changed", is_on)
	if not _is_loading_settings:
		_save_settings()

func _on_CloseButton_pressed() -> void:
	hide()

func popup_centered(size: Vector2 = Vector2.ZERO) -> void:
	.popup_centered(size)
	raise()

func _save_settings() -> void:
	var values: Dictionary = {}
	values["mode"] = mode_option.selected
	values["input_x"] = input_x_spinbox.value
	values["input_y"] = input_y_spinbox.value
	values["affected_by_size"] = size_checkbox.pressed
	values["affected_by_rotation"] = rotation_checkbox.pressed
	values["flat_colors"] = flat_colors_checkbox.pressed
	LnzLiveUtils.save_config("ShaderProperties", values, SETTINGS_PATH)

func _load_settings() -> void:
	var data: Dictionary = LnzLiveUtils.load_config("ShaderProperties", SETTINGS_PATH)
	if data.empty():
		return

	_is_loading_settings = true
	mode_option.selected = data.get("mode", 1)
	input_x_spinbox.value = data.get("input_x", 0.0)
	input_y_spinbox.value = data.get("input_y", 0.0)
	size_checkbox.pressed = data.get("affected_by_size", true)
	rotation_checkbox.pressed = data.get("affected_by_rotation", false)
	flat_colors_checkbox.pressed = data.get("flat_colors", false)
	_is_loading_settings = false
