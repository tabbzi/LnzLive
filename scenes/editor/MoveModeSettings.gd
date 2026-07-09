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

func _ready() -> void:
	var viewport_size: Vector2 = get_viewport().size
	var panel: Control = self
	var panel_size: Vector2 = panel.rect_size
	
	var default_x: float = (viewport_size.x - panel_size.x) / 2.0
	var default_y: float = viewport_size.y - panel_size.y - 10.0
	var default_pos: Vector2 = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)
	
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("ClearButton").connect("pressed", self, "_on_ClearButton_pressed")
	find_node("UnselectButton").connect("pressed", self, "_on_UnselectButton_pressed")

	find_node("UnselectL").connect("pressed", self, "_on_UnselectSide_pressed", ["left"])
	find_node("UnselectC").connect("pressed", self, "_on_UnselectSide_pressed", ["center"])
	find_node("UnselectR").connect("pressed", self, "_on_UnselectSide_pressed", ["right"])

	_setup_group_buttons()
	
	var constraints: Array = ["Free", "LockX", "LockY", "LockZ", "LockXY", "LockXZ", "LockYZ"]
	for c in constraints:
		var node: Control = find_node(c)
		if node:
			node.connect("pressed", self, "_on_constraint_selected", [c])
	
	#find_node("MirrorX").connect("toggled", self, "_on_MirrorX_toggled")
	
	find_node("AlignX").connect("pressed", self, "_on_Align_pressed", ["x"])
	find_node("AlignY").connect("pressed", self, "_on_Align_pressed", ["y"])
	find_node("AlignZ").connect("pressed", self, "_on_Align_pressed", ["z"])
	
	var align_opt: OptionButton = find_node("AlignModeOption")
	align_opt.clear()
	align_opt.add_item("Negative (-)", 0)
	align_opt.add_item("Center (Average)", 1)
	align_opt.add_item("Positive (+)", 2)
	align_opt.selected = 1
	
	var btn_drop_floor: Button = find_node("DropFloor")
	btn_drop_floor.text = "Floor (max Y)"
	btn_drop_floor.connect("pressed", self, "_on_Snap_pressed", ["y", -1])

	var btn_raise_roof: Button = find_node("RaiseRoof")
	btn_raise_roof.text = "Roof (min Y)"
	btn_raise_roof.connect("pressed", self, "_on_Snap_pressed", ["y", 1])

	var btn_front: Button = find_node("ShoveFront")
	btn_front.text = "Front (min Z)"
	btn_front.connect("pressed", self, "_on_Snap_pressed", ["z", -1])
	
	var btn_back: Button = find_node("PushBack")
	btn_back.text = "Back (max Z)"
	btn_back.connect("pressed", self, "_on_Snap_pressed", ["z", 1])
	
	find_node("ApplyNudge").connect("pressed", self, "_on_ApplyNudge_pressed")

	var pivot_ball: SpinBox = find_node("PivotBall")
	if pivot_ball:
		pivot_ball.min_value = 0
		pivot_ball.max_value = 999
		pivot_ball.value = 0 # Default to 0
		pivot_ball.connect("value_changed", self, "_on_pivot_ui_changed")

	var use_pivot_cb: CheckBox = find_node("UsePivotCheckBox")
	if use_pivot_cb:
		use_pivot_cb.connect("toggled", self, "_on_pivot_ui_changed")

	find_node("ApplyRotate").connect("pressed", self, "_on_ApplyRotate_pressed")
	find_node("ApplyScale").connect("pressed", self, "_on_ApplyScale_pressed")
	
	var affected_ballz_input = find_node("AffectedBallz")
	if affected_ballz_input:
		affected_ballz_input.connect("text_entered", self, "_on_AffectedBallz_text_entered")
		affected_ballz_input.connect("text_changed", self, "_on_AffectedBallz_text_changed")

	find_node("FlipX").connect("pressed", self, "_on_Flip_pressed", ["x"])
	find_node("FlipY").connect("pressed", self, "_on_Flip_pressed", ["y"])
	find_node("FlipZ").connect("pressed", self, "_on_Flip_pressed", ["z"])

	_connect_settings_signals()
	load_settings()

# func show():
# 	$Panel.show()

# func hide():
# 	$Panel.hide()

func set_queued_count(count: int) -> void:
	find_node("QueuedLabel").text = "Queued Moves: " + str(count)

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
	var mx: bool = find_node("MirrorX").pressed
	var my: bool = find_node("MirrorY").pressed
	var mz: bool = find_node("MirrorZ").pressed
	
	return Vector3(
		-1.0 if mx else 1.0,
		-1.0 if my else 1.0,
		-1.0 if mz else 1.0
	)

func is_mirror_x_active() -> bool:
	return find_node("MirrorX").pressed

func _setup_group_buttons() -> void:
	var groups: Array = ["Head", "Body", "Legs", "Tail", "Ears", "Eyes"]
	for g in groups:
		var btn: Button = find_node(g)
		if btn:
			if not btn.is_connected("pressed", self, "_on_group_btn_pressed"):
				btn.connect("pressed", self, "_on_group_btn_pressed", [g])

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
	
	var constraints: Array = ["Free", "LockX", "LockY", "LockZ", "LockXY", "LockXZ", "LockYZ"]
	for c in constraints:
		var node: Control = find_node(c)
		if node:
			node.pressed = (c == selected_name)

	if not _is_loading_settings:
		save_settings()

func _on_Align_pressed(axis: String) -> void:
	var mode: int = find_node("AlignModeOption").selected
	emit_signal("align_selection", axis, mode)

func _on_Snap_pressed(axis: String, direction: int) -> void:
	emit_signal("snap_selection", axis, direction)

func _on_ApplyNudge_pressed() -> void:
	var dx: float = find_node("NudgeX").value
	var dy: float = find_node("NudgeY").value
	var dz: float = find_node("NudgeZ").value
	emit_signal("nudge_selection", Vector3(dx, dy, dz))

func update_pivot_max(max_balls: int) -> void:
	var pivot_ball: SpinBox = find_node("PivotBall")
	if pivot_ball:
		pivot_ball.max_value = max(0, max_balls - 1)

func change_nudge_value(axis: String, delta: float) -> void:
	var node_name: String = ""
	if axis == "x": node_name = "NudgeX"
	elif axis == "y": node_name = "NudgeY"
	elif axis == "z": node_name = "NudgeZ"
	
	if node_name != "":
		var sb: SpinBox = find_node(node_name)
		if sb:
			sb.value += delta

func apply_nudge_axis(axis: String, dirsign: float) -> void:
	var node_name: String = ""
	if axis == "x": node_name = "NudgeX"
	elif axis == "y": node_name = "NudgeY"
	elif axis == "z": node_name = "NudgeZ"
	
	if node_name != "":
		var sb: SpinBox = find_node(node_name)
		if sb:
			var amount = sb.value * dirsign
			var vector := Vector3.ZERO
			if axis == "x": vector.x = amount
			elif axis == "y": vector.y = amount
			elif axis == "z": vector.z = amount
			emit_signal("nudge_selection", vector)

func _on_ApplyRotate_pressed() -> void:
	var roll: float = find_node("RotateRoll").value
	var pitch: float = find_node("RotatePitch").value
	var yaw: float = find_node("RotateYaw").value
	
	var pivot_id: int = -1
	if find_node("UsePivotCheckBox").pressed:
		pivot_id = int(find_node("PivotBall").value)
	
	emit_signal("rotate_selection", Vector3(pitch, yaw, roll), pivot_id)

func _on_ApplyScale_pressed() -> void:
	var factor: float = find_node("ScaleFactor").value
	var scale_dist: bool = find_node("ScaleDist").pressed
	var scale_size: bool = find_node("ScaleSize").pressed

	var pivot_id: int = -1
	if find_node("UsePivotCheckBox").pressed:
		pivot_id = int(find_node("PivotBall").value)

	emit_signal("apply_scale", factor, scale_dist, scale_size, pivot_id)

func _on_Flip_pressed(axis: String) -> void:
	var vec: Vector3 = Vector3.ONE
	if axis == "x": vec.x = -1.0
	elif axis == "y": vec.y = -1.0
	elif axis == "z": vec.z = -1.0
	
	var pivot_id: int = -1
	if find_node("UsePivotCheckBox").pressed:
		pivot_id = int(find_node("PivotBall").value)
	
	emit_signal("flip_selection", vec, pivot_id)

func set_pivot_ball(id: int) -> void:
	var pivot_ball: SpinBox = find_node("PivotBall")
	var use_pivot_cb: CheckBox = find_node("UsePivotCheckBox")
	if pivot_ball and use_pivot_cb:
		pivot_ball.value = id
		use_pivot_cb.pressed = true
		emit_signal("pivot_changed")

func update_selected_balls_text(ball_ids: Array) -> void:
	var affected_ballz: Control = find_node("AffectedBallz")
	if affected_ballz and affected_ballz.has_focus():
		return

	ball_ids.sort()
	var text: String = ""
	
	if ball_ids.empty():
		if affected_ballz:
			affected_ballz.text = ""
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
		
	var range_array: PoolStringArray = PoolStringArray(ranges)
	if affected_ballz:
		affected_ballz.text = range_array.join(",")
		
	range_array.resize(0)

func _on_AffectedBallz_text_entered(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("select_balls_by_ids", ids)
	var affected_ballz: Control = find_node("AffectedBallz")
	if affected_ballz:
		affected_ballz.release_focus()

func _on_AffectedBallz_text_changed(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("select_balls_by_ids", ids)

func _on_pivot_ui_changed(_arg = null) -> void:
	emit_signal("pivot_changed")
	if not _is_loading_settings:
		save_settings()

func _connect_settings_signals() -> void:
	find_node("AlignModeOption").connect("item_selected", self, "_on_setting_changed")
	find_node("NudgeX").connect("value_changed", self, "_on_setting_changed")
	find_node("NudgeY").connect("value_changed", self, "_on_setting_changed")
	find_node("NudgeZ").connect("value_changed", self, "_on_setting_changed")

	find_node("MirrorX").connect("toggled", self, "_on_setting_changed")
	find_node("MirrorY").connect("toggled", self, "_on_setting_changed")
	find_node("MirrorZ").connect("toggled", self, "_on_setting_changed")

	find_node("RotateRoll").connect("value_changed", self, "_on_setting_changed")
	find_node("RotatePitch").connect("value_changed", self, "_on_setting_changed")
	find_node("RotateYaw").connect("value_changed", self, "_on_setting_changed")

	find_node("ScaleFactor").connect("value_changed", self, "_on_setting_changed")
	find_node("ScaleDist").connect("toggled", self, "_on_setting_changed")
	find_node("ScaleSize").connect("toggled", self, "_on_setting_changed")

	var reset_btn: Button = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

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
	config.set_value("MoveProperties", "align_mode", find_node("AlignModeOption").selected)

	config.set_value("MoveProperties", "nudge_x", find_node("NudgeX").value)
	config.set_value("MoveProperties", "nudge_y", find_node("NudgeY").value)
	config.set_value("MoveProperties", "nudge_z", find_node("NudgeZ").value)

	config.set_value("MoveProperties", "rotate_roll", find_node("RotateRoll").value)
	config.set_value("MoveProperties", "rotate_pitch", find_node("RotatePitch").value)
	config.set_value("MoveProperties", "rotate_yaw", find_node("RotateYaw").value)

	config.set_value("MoveProperties", "scale_factor", find_node("ScaleFactor").value)
	config.set_value("MoveProperties", "scale_dist", find_node("ScaleDist").pressed)
	config.set_value("MoveProperties", "scale_size", find_node("ScaleSize").pressed)

	config.set_value("MoveProperties", "mirror_x", find_node("MirrorX").pressed)
	config.set_value("MoveProperties", "mirror_y", find_node("MirrorY").pressed)
	config.set_value("MoveProperties", "mirror_z", find_node("MirrorZ").pressed)

	config.set_value("MoveProperties", "use_pivot", find_node("UsePivotCheckBox").pressed)
	config.set_value("MoveProperties", "pivot_ball", find_node("PivotBall").value)

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

	find_node("AlignModeOption").selected = config.get_value("MoveProperties", "align_mode", 1)

	find_node("NudgeX").value = config.get_value("MoveProperties", "nudge_x", 0.0)
	find_node("NudgeY").value = config.get_value("MoveProperties", "nudge_y", 0.0)
	find_node("NudgeZ").value = config.get_value("MoveProperties", "nudge_z", 0.0)

	find_node("RotateRoll").value = config.get_value("MoveProperties", "rotate_roll", 0.0)
	find_node("RotatePitch").value = config.get_value("MoveProperties", "rotate_pitch", 0.0)
	find_node("RotateYaw").value = config.get_value("MoveProperties", "rotate_yaw", 0.0)

	find_node("ScaleFactor").value = config.get_value("MoveProperties", "scale_factor", 1.0)
	find_node("ScaleDist").pressed = config.get_value("MoveProperties", "scale_dist", true)
	find_node("ScaleSize").pressed = config.get_value("MoveProperties", "scale_size", true)

	find_node("MirrorX").pressed = config.get_value("MoveProperties", "mirror_x", false)
	find_node("MirrorY").pressed = config.get_value("MoveProperties", "mirror_y", false)
	find_node("MirrorZ").pressed = config.get_value("MoveProperties", "mirror_z", false)

	find_node("UsePivotCheckBox").pressed = config.get_value("MoveProperties", "use_pivot", false)
	find_node("PivotBall").value = config.get_value("MoveProperties", "pivot_ball", 0.0)

	_is_loading_settings = false

func _on_reset_defaults_pressed() -> void:
	_is_loading_settings = true

	_on_constraint_selected("Free")

	find_node("AlignModeOption").selected = 1 # Center

	find_node("NudgeX").value = 0.0
	find_node("NudgeY").value = 0.0
	find_node("NudgeZ").value = 0.0

	find_node("RotateRoll").value = 0.0
	find_node("RotatePitch").value = 0.0
	find_node("RotateYaw").value = 0.0

	find_node("ScaleFactor").value = 1.0
	find_node("ScaleDist").pressed = true
	find_node("ScaleSize").pressed = true

	find_node("MirrorX").pressed = false
	find_node("MirrorY").pressed = false
	find_node("MirrorZ").pressed = false

	find_node("UsePivotCheckBox").pressed = false
	find_node("PivotBall").value = 0.0

	_is_loading_settings = false
	save_settings()
