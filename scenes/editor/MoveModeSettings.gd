extends DraggablePanel
## MoveModeSettings.gd
## Manages panel UI and logic for Move Mode

signal apply_moves
signal clear_moves
signal unselect_all
signal unselect_side(side)
signal align_selection(axis, mode) # mode: 0=min, 1=center, 2=max
signal snap_selection(axis, direction) # direction: -1=min, 1=max
signal nudge_selection(vector)
signal mirror_toggled(is_on)
signal select_group(group_name)
signal rotate_selection(rotation_degrees, pivot_id)
signal select_balls_by_ids(ids)
signal flip_selection(axis_vector, pivot_id)
signal pivot_changed
signal apply_scale(factor, scale_dist, scale_size, pivot_id)

var _is_loading_settings: bool = false

var current_constraint_mode: String = "free" # free, x, y, z, xy, xz, yz

onready var _apply_button: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ActionButtons/ApplyButton
onready var _clear_button: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ActionButtons/ClearButton
onready var _unselect_button: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ActionButtons/UnselectButton
onready var _unselect_l: Button = $VBoxContainer/ScrollContainer/VBoxContainer/FilterUnselectButtons/UnselectL
onready var _unselect_c: Button = $VBoxContainer/ScrollContainer/VBoxContainer/FilterUnselectButtons/UnselectC
onready var _unselect_r: Button = $VBoxContainer/ScrollContainer/VBoxContainer/FilterUnselectButtons/UnselectR
onready var _align_x: Button = $VBoxContainer/ScrollContainer/VBoxContainer/AlignButtons/AlignX
onready var _align_y: Button = $VBoxContainer/ScrollContainer/VBoxContainer/AlignButtons/AlignY
onready var _align_z: Button = $VBoxContainer/ScrollContainer/VBoxContainer/AlignButtons/AlignZ
onready var _align_mode_option: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/AlignModeOption
onready var _drop_floor: Button = $VBoxContainer/ScrollContainer/VBoxContainer/SnapButtonsGrid/DropFloor
onready var _raise_roof: Button = $VBoxContainer/ScrollContainer/VBoxContainer/SnapButtonsGrid/RaiseRoof
onready var _shove_front: Button = $VBoxContainer/ScrollContainer/VBoxContainer/SnapButtonsGrid/ShoveFront
onready var _push_back: Button = $VBoxContainer/ScrollContainer/VBoxContainer/SnapButtonsGrid/PushBack
onready var _apply_nudge: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ApplyNudge
onready var _apply_rotate: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ApplyRotate
onready var _apply_scale: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ApplyScale
onready var _pivot_ball: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/RotateGrid/PivotContainer/PivotBall
onready var _use_pivot_cb: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/RotateGrid/PivotContainer/UsePivotCheckBox
onready var _affected_ballz: Control = $VBoxContainer/ScrollContainer/VBoxContainer/AffectedBallz
onready var _flip_x: Button = $VBoxContainer/ScrollContainer/VBoxContainer/FlipContainer/FlipX
onready var _flip_y: Button = $VBoxContainer/ScrollContainer/VBoxContainer/FlipContainer/FlipY
onready var _flip_z: Button = $VBoxContainer/ScrollContainer/VBoxContainer/FlipContainer/FlipZ
onready var _nudge_x: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/NudgeGrid/NudgeX
onready var _nudge_y: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/NudgeGrid/NudgeY
onready var _nudge_z: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/NudgeGrid/NudgeZ
onready var _rotate_roll: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/RotateGrid/RotateRoll
onready var _rotate_pitch: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/RotateGrid/RotatePitch
onready var _rotate_yaw: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/RotateGrid/RotateYaw
onready var _scale_factor: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/ScaleGrid/ScaleFactor
onready var _scale_dist: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/ScaleGrid/ScaleDist
onready var _scale_size: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/ScaleGrid/ScaleSize
onready var _mirror_x: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/MirrorContainer/MirrorX
onready var _mirror_y: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/MirrorContainer/MirrorY
onready var _mirror_z: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/MirrorContainer/MirrorZ
onready var _reset_defaults: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ResetDefaultsButton
onready var _queued_label: Label = $VBoxContainer/ScrollContainer/VBoxContainer/QueuedLabel

var _constraint_buttons: Array = []

const _mirror_axes: Array = ["MirrorX", "MirrorY", "MirrorZ"]

func _ready() -> void:
	var viewport_size: Vector2 = get_viewport().size
	var panel: Control = self
	var panel_size: Vector2 = panel.rect_size
	
	var default_x: float = (viewport_size.x - panel_size.x) / 2.0
	var default_y: float = viewport_size.y - panel_size.y - 10.0
	var default_pos: Vector2 = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)
	
	_apply_button.connect("pressed", self, "_on_ApplyButton_pressed")
	_clear_button.connect("pressed", self, "_on_ClearButton_pressed")
	_unselect_button.connect("pressed", self, "_on_UnselectButton_pressed")

	_unselect_l.connect("pressed", self, "_on_UnselectSide_pressed", ["left"])
	_unselect_c.connect("pressed", self, "_on_UnselectSide_pressed", ["center"])
	_unselect_r.connect("pressed", self, "_on_UnselectSide_pressed", ["right"])

	_setup_group_buttons()
	
	var constraints: Array = ["Free", "LockX", "LockY", "LockZ", "LockXY", "LockXZ", "LockYZ"]
	_constraint_buttons = []
	for c in constraints:
		var node: Control = find_node(c)
		if node:
			node.connect("pressed", self, "_on_constraint_selected", [c])
			_constraint_buttons.append(node)
	
	_align_x.connect("pressed", self, "_on_Align_pressed", ["x"])
	_align_y.connect("pressed", self, "_on_Align_pressed", ["y"])
	_align_z.connect("pressed", self, "_on_Align_pressed", ["z"])

	_align_mode_option.clear()
	_align_mode_option.add_item("Negative (-)", 0)
	_align_mode_option.add_item("Center (Average)", 1)
	_align_mode_option.add_item("Positive (+)", 2)
	_align_mode_option.selected = 1
	
	_drop_floor.text = "Floor (max Y)"
	_drop_floor.connect("pressed", self, "_on_Snap_pressed", ["y", -1])

	_raise_roof.text = "Roof (min Y)"
	_raise_roof.connect("pressed", self, "_on_Snap_pressed", ["y", 1])

	_shove_front.text = "Front (min Z)"
	_shove_front.connect("pressed", self, "_on_Snap_pressed", ["z", -1])
	
	_push_back.text = "Back (max Z)"
	_push_back.connect("pressed", self, "_on_Snap_pressed", ["z", 1])
	
	_apply_nudge.connect("pressed", self, "_on_ApplyNudge_pressed")

	if _pivot_ball:
		_pivot_ball.min_value = 0
		_pivot_ball.max_value = 999
		_pivot_ball.value = 0 # Default to 0
		_pivot_ball.connect("value_changed", self, "_on_pivot_ui_changed")

	if _use_pivot_cb:
		_use_pivot_cb.connect("toggled", self, "_on_pivot_ui_changed")

	_apply_rotate.connect("pressed", self, "_on_ApplyRotate_pressed")
	_apply_scale.connect("pressed", self, "_on_ApplyScale_pressed")
	
	if _affected_ballz:
		_affected_ballz.connect("text_entered", self, "_on_AffectedBallz_text_entered")
		_affected_ballz.connect("text_changed", self, "_on_AffectedBallz_text_changed")

	_flip_x.connect("pressed", self, "_on_Flip_pressed", ["x"])
	_flip_y.connect("pressed", self, "_on_Flip_pressed", ["y"])
	_flip_z.connect("pressed", self, "_on_Flip_pressed", ["z"])

	_connect_settings_signals()
	load_settings()


func _nudge_node_name(axis: String) -> String:
	match axis:
		"x": return "NudgeX"
		"y": return "NudgeY"
		"z": return "NudgeZ"
	return ""

## Reads mirror checkbox states into a Vector3 (1.0 = off, -1.0 = on).
## Replaces the three find_node() calls in get_mirror_vector() with cached nodes.
func _read_mirror_state() -> Vector3:
	return Vector3(
		-1.0 if _mirror_x and _mirror_x.pressed else 1.0,
		-1.0 if _mirror_y and _mirror_y.pressed else 1.0,
		-1.0 if _mirror_z and _mirror_z.pressed else 1.0
	)


func _setup_group_buttons() -> void:
	var groups: Array = ["Head", "Body", "Legs", "Tail", "Ears", "Eyes"]
	for g in groups:
		var btn: Button = find_node(g)
		if btn:
			if not btn.is_connected("pressed", self, "_on_group_btn_pressed"):
				btn.connect("pressed", self, "_on_group_btn_pressed", [g])


func set_queued_count(count: int) -> void:
	if _queued_label:
		_queued_label.text = "Queued Moves: " + str(count)

func get_constraints() -> Dictionary:
	var res: Dictionary = {"x": false, "y": false, "z": false}
	
	match current_constraint_mode:
		"LockX":
			res.y = true
			res.z = true
		"LockY":
			res.x = true
			res.z = true
		"LockZ":
			res.x = true
			res.y = true
		"LockXY":
			res.z = true
		"LockXZ":
			res.y = true
		"LockYZ":
			res.x = true
		"Free":
			pass
			
	return res

func get_mirror_vector() -> Vector3:
	return _read_mirror_state()

func is_mirror_x_active() -> bool:
	return _mirror_x.pressed if _mirror_x else false

func change_nudge_value(axis: String, delta: float) -> void:
	var sb: SpinBox = null
	if axis == "x": sb = _nudge_x
	elif axis == "y": sb = _nudge_y
	elif axis == "z": sb = _nudge_z
	if sb:
		sb.value += delta

func apply_nudge_axis(axis: String, dirsign: float) -> void:
	var sb: SpinBox = null
	if axis == "x": sb = _nudge_x
	elif axis == "y": sb = _nudge_y
	elif axis == "z": sb = _nudge_z
	if sb:
		var amount = sb.value * dirsign
		var vector := Vector3.ZERO
		if axis == "x": vector.x = amount
		elif axis == "y": vector.y = amount
		elif axis == "z": vector.z = amount
		emit_signal("nudge_selection", vector)

func update_selected_balls_text(ball_ids: Array) -> void:
	if _affected_ballz and _affected_ballz.has_focus():
		return

	ball_ids.sort()
	
	if ball_ids.empty():
		if _affected_ballz:
			_affected_ballz.text = ""
		return
	
	var start: int = ball_ids[0]
	var prev: int = start
	var ranges: Array = []
	
	for i in range(1, ball_ids.size()):
		var curr: int = ball_ids[i]
		if curr == prev + 1:
			prev = curr
		else:
			if start == prev:
				ranges.append(str(start))
			else:
				ranges.append(str(start) + "-" + str(prev))
			start = curr
			prev = curr
			
	if start == prev:
		ranges.append(str(start))
	else:
		ranges.append(str(start) + "-" + str(prev))
		
	## Replaced PoolStringArray allocation with plain Array.
	## Godot 3.2 has no Array.join(), so build string manually.
	if _affected_ballz:
		var s: String = ""
		for i in range(ranges.size()):
			if i > 0:
				s += ","
			s += str(ranges[i])
		_affected_ballz.text = s

func update_pivot_max(max_balls: int) -> void:
	if _pivot_ball:
		_pivot_ball.max_value = max(0, max_balls - 1)


func _on_group_btn_pressed(group_name: String) -> void:
	emit_signal("select_group", group_name)

func _on_ApplyButton_pressed() -> void:
	emit_signal("apply_moves")

func _on_ClearButton_pressed() -> void:
	emit_signal("clear_moves")

func _on_UnselectButton_pressed() -> void:
	emit_signal("unselect_all")

func _on_UnselectSide_pressed(side: String) -> void:
	emit_signal("unselect_side", side)
	
func _on_constraint_selected(selected_name: String) -> void:
	current_constraint_mode = selected_name
	
	for i in range(_constraint_buttons.size()):
		var c: String = ["Free", "LockX", "LockY", "LockZ", "LockXY", "LockXZ", "LockYZ"][i]
		if _constraint_buttons[i]:
			_constraint_buttons[i].pressed = (c == selected_name)

	if not _is_loading_settings:
		save_settings()

func _on_Align_pressed(axis: String) -> void:
	emit_signal("align_selection", axis, _align_mode_option.selected)

func _on_Snap_pressed(axis: String, direction: int) -> void:
	emit_signal("snap_selection", axis, direction)

func _on_ApplyNudge_pressed() -> void:
	var dx: float = _nudge_x.value if _nudge_x else 0.0
	var dy: float = _nudge_y.value if _nudge_y else 0.0
	var dz: float = _nudge_z.value if _nudge_z else 0.0
	emit_signal("nudge_selection", Vector3(dx, dy, dz))

func _on_ApplyRotate_pressed() -> void:
	var roll: float = _rotate_roll.value if _rotate_roll else 0.0
	var pitch: float = _rotate_pitch.value if _rotate_pitch else 0.0
	var yaw: float = _rotate_yaw.value if _rotate_yaw else 0.0
	
	var pivot_id: int = -1
	if _use_pivot_cb and _use_pivot_cb.pressed and _pivot_ball:
		pivot_id = int(_pivot_ball.value)
	
	emit_signal("rotate_selection", Vector3(pitch, yaw, roll), pivot_id)

func _on_ApplyScale_pressed() -> void:
	var factor: float = _scale_factor.value if _scale_factor else 1.0
	var scale_dist: bool = _scale_dist.pressed if _scale_dist else true
	var scale_size: bool = _scale_size.pressed if _scale_size else true

	var pivot_id: int = -1
	if _use_pivot_cb and _use_pivot_cb.pressed and _pivot_ball:
		pivot_id = int(_pivot_ball.value)

	emit_signal("apply_scale", factor, scale_dist, scale_size, pivot_id)

func _on_Flip_pressed(axis: String) -> void:
	var vec: Vector3 = Vector3.ONE
	if axis == "x": vec.x = -1.0
	elif axis == "y": vec.y = -1.0
	elif axis == "z": vec.z = -1.0
	
	var pivot_id: int = -1
	if _use_pivot_cb and _use_pivot_cb.pressed and _pivot_ball:
		pivot_id = int(_pivot_ball.value)
	
	emit_signal("flip_selection", vec, pivot_id)

func set_pivot_ball(id: int) -> void:
	if _pivot_ball and _use_pivot_cb:
		_pivot_ball.value = id
		_use_pivot_cb.pressed = true
		emit_signal("pivot_changed")

func _on_AffectedBallz_text_entered(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("select_balls_by_ids", ids)
	if _affected_ballz:
		_affected_ballz.release_focus()

func _on_AffectedBallz_text_changed(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("select_balls_by_ids", ids)

func _on_pivot_ui_changed(_arg = null) -> void:
	emit_signal("pivot_changed")
	if not _is_loading_settings:
		save_settings()

func _connect_settings_signals() -> void:
	_align_mode_option.connect("item_selected", self, "_on_setting_changed")
	_nudge_x.connect("value_changed", self, "_on_setting_changed")
	_nudge_y.connect("value_changed", self, "_on_setting_changed")
	_nudge_z.connect("value_changed", self, "_on_setting_changed")

	_mirror_x.connect("toggled", self, "_on_setting_changed")
	_mirror_y.connect("toggled", self, "_on_setting_changed")
	_mirror_z.connect("toggled", self, "_on_setting_changed")

	_rotate_roll.connect("value_changed", self, "_on_setting_changed")
	_rotate_pitch.connect("value_changed", self, "_on_setting_changed")
	_rotate_yaw.connect("value_changed", self, "_on_setting_changed")

	_scale_factor.connect("value_changed", self, "_on_setting_changed")
	_scale_dist.connect("toggled", self, "_on_setting_changed")
	_scale_size.connect("toggled", self, "_on_setting_changed")

	if _reset_defaults:
		_reset_defaults.connect("pressed", self, "_on_reset_defaults_pressed")

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

	config.set_value("MoveProperties", "constraint_mode", current_constraint_mode)
	config.set_value("MoveProperties", "align_mode", _align_mode_option.selected)

	config.set_value("MoveProperties", "nudge_x", _nudge_x.value if _nudge_x else 0.0)
	config.set_value("MoveProperties", "nudge_y", _nudge_y.value if _nudge_y else 0.0)
	config.set_value("MoveProperties", "nudge_z", _nudge_z.value if _nudge_z else 0.0)

	config.set_value("MoveProperties", "rotate_roll", _rotate_roll.value if _rotate_roll else 0.0)
	config.set_value("MoveProperties", "rotate_pitch", _rotate_pitch.value if _rotate_pitch else 0.0)
	config.set_value("MoveProperties", "rotate_yaw", _rotate_yaw.value if _rotate_yaw else 0.0)

	config.set_value("MoveProperties", "scale_factor", _scale_factor.value if _scale_factor else 1.0)
	config.set_value("MoveProperties", "scale_dist", _scale_dist.pressed if _scale_dist else true)
	config.set_value("MoveProperties", "scale_size", _scale_size.pressed if _scale_size else true)

	config.set_value("MoveProperties", "mirror_x", _mirror_x.pressed if _mirror_x else false)
	config.set_value("MoveProperties", "mirror_y", _mirror_y.pressed if _mirror_y else false)
	config.set_value("MoveProperties", "mirror_z", _mirror_z.pressed if _mirror_z else false)

	config.set_value("MoveProperties", "use_pivot", _use_pivot_cb.pressed if _use_pivot_cb else false)
	config.set_value("MoveProperties", "pivot_ball", _pivot_ball.value if _pivot_ball else 0.0)

	var save_err: int = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving MoveModeSettings: ", save_err)

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		return

	_is_loading_settings = true

	var constraint: String = config.get_value("MoveProperties", "constraint_mode", "Free")
	_on_constraint_selected(constraint)

	_align_mode_option.selected = config.get_value("MoveProperties", "align_mode", 1)

	if _nudge_x: _nudge_x.value = config.get_value("MoveProperties", "nudge_x", 0.0)
	if _nudge_y: _nudge_y.value = config.get_value("MoveProperties", "nudge_y", 0.0)
	if _nudge_z: _nudge_z.value = config.get_value("MoveProperties", "nudge_z", 0.0)

	if _rotate_roll: _rotate_roll.value = config.get_value("MoveProperties", "rotate_roll", 0.0)
	if _rotate_pitch: _rotate_pitch.value = config.get_value("MoveProperties", "rotate_pitch", 0.0)
	if _rotate_yaw: _rotate_yaw.value = config.get_value("MoveProperties", "rotate_yaw", 0.0)

	if _scale_factor: _scale_factor.value = config.get_value("MoveProperties", "scale_factor", 1.0)
	if _scale_dist: _scale_dist.pressed = config.get_value("MoveProperties", "scale_dist", true)
	if _scale_size: _scale_size.pressed = config.get_value("MoveProperties", "scale_size", true)

	if _mirror_x: _mirror_x.pressed = config.get_value("MoveProperties", "mirror_x", false)
	if _mirror_y: _mirror_y.pressed = config.get_value("MoveProperties", "mirror_y", false)
	if _mirror_z: _mirror_z.pressed = config.get_value("MoveProperties", "mirror_z", false)

	if _use_pivot_cb: _use_pivot_cb.pressed = config.get_value("MoveProperties", "use_pivot", false)
	if _pivot_ball: _pivot_ball.value = config.get_value("MoveProperties", "pivot_ball", 0.0)

	_is_loading_settings = false

func _on_reset_defaults_pressed() -> void:
	_is_loading_settings = true

	_on_constraint_selected("Free")

	_align_mode_option.selected = 1 # Center

	if _nudge_x: _nudge_x.value = 0.0
	if _nudge_y: _nudge_y.value = 0.0
	if _nudge_z: _nudge_z.value = 0.0

	if _rotate_roll: _rotate_roll.value = 0.0
	if _rotate_pitch: _rotate_pitch.value = 0.0
	if _rotate_yaw: _rotate_yaw.value = 0.0

	if _scale_factor: _scale_factor.value = 1.0
	if _scale_dist: _scale_dist.pressed = true
	if _scale_size: _scale_size.pressed = true

	if _mirror_x: _mirror_x.pressed = false
	if _mirror_y: _mirror_y.pressed = false
	if _mirror_z: _mirror_z.pressed = false

	if _use_pivot_cb: _use_pivot_cb.pressed = false
	if _pivot_ball: _pivot_ball.value = 0.0

	_is_loading_settings = false
	save_settings()
