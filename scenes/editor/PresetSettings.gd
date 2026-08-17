extends DraggablePanel
## PresetSettings.gd
## Manages the UI panel and logic for the Preset Mode settings
## This script controls the visibility of the settings panel and provides methods to:
## 1. Initialize the panel, connect all UI signals, and set up the paintball list (Tree)
## 2. Retrieve and set the full set of preset properties for the ball and its paintballz
## 3. Parse raw text input into structured paintball data for the list
## 4. Handle advanced list transformations (mirroring and custom/preset rotation)
## 5. Emit the `eyedropper_toggled(is_on)` signal to activate the sampling tool

var _is_loading_settings: bool = false

signal eyedropper_toggled(is_on)
signal apply_to_selection
signal unselect_all
signal select_balls_by_ids(ids)

onready var panel: Control = self
onready var scroll_vbox = $VBoxContainer/ScrollContainer/VBoxContainer
onready var paintballz_text_edit: TextEdit = scroll_vbox.get_node("RawLnzContainer/PaintballzTextEdit")
onready var set_paintballz_button: Button = scroll_vbox.get_node("RawLnzContainer/SetPaintballzButton")
onready var get_paintballz_button: Button = scroll_vbox.get_node("RawLnzContainer/GetPaintballzButton")
onready var show_raw_button: Button = scroll_vbox.get_node("ShowRawButton")
onready var raw_lnz_container: Control = scroll_vbox.get_node("RawLnzContainer")
onready var paintballz_tree: Tree = scroll_vbox.get_node("PaintballzTree")

onready var preview_viewport: Viewport = scroll_vbox.get_node("PreviewContainer/Viewport")
onready var preview_camera: Camera = scroll_vbox.get_node("PreviewContainer/Viewport/PreviewWorld/Camera")
onready var preview_world: Spatial = scroll_vbox.get_node("PreviewContainer/Viewport/PreviewWorld")

var ball_scene: PackedScene = preload("res://Ball.tscn")
var paintball_scene: PackedScene = preload("res://Paintball.tscn")
var default_palette: Texture = LnzLiveUtils.DEFAULT_PALETTE
var active_palette: Texture = default_palette
onready var preloader: ResourcePreloader = get_tree().root.get_node("Root/ResourcePreloader")
var ball_texture_list: Array = []

var recolor_line_scene: PackedScene = preload("res://scenes/editor/RecolorLine.tscn")

onready var eyedropper_toggle: CheckButton = scroll_vbox.get_node("ToolsContainer/EyedropperToggle")
onready var exclude_eyes_chk: CheckBox = scroll_vbox.get_node("SelectionActions/ExcludeEyesCheckBox")
onready var include_paintballz_chk: CheckBox = scroll_vbox.get_node("IncludeContainer/IncludePaintballzCheckBox")
onready var scale_paintballz_chk: CheckBox = scroll_vbox.get_node("IncludeContainer/ScalePaintballzCheckBox")

onready var base_properties_grid: GridContainer = scroll_vbox.get_node("BasePropertiesGrid")
onready var include_size_chk: CheckBox = base_properties_grid.get_node("IncludeSizeCheckBox")
onready var include_color_chk: CheckBox = base_properties_grid.get_node("IncludeColorCheckBox")
onready var include_outline_color_chk: CheckBox = base_properties_grid.get_node("IncludeOutlineColorCheckBox")
onready var include_outline_chk: CheckBox = base_properties_grid.get_node("IncludeOutlineCheckBox")
onready var include_fuzz_chk: CheckBox = base_properties_grid.get_node("IncludeFuzzCheckBox")
onready var include_texture_chk: CheckBox = base_properties_grid.get_node("IncludeTextureCheckBox")

onready var size_spinbox: SpinBox = base_properties_grid.get_node("SizeContainer/SizeSpinBox")
onready var size_mode_option: OptionButton = base_properties_grid.get_node("SizeContainer/SizeModeOption")

onready var color_edit = base_properties_grid.get_node("ColorLineEdit")
onready var outline_color_edit = base_properties_grid.get_node("OutlineColorLineEdit")
onready var outline_spinbox: SpinBox = base_properties_grid.get_node("OutlineSpinBox")
onready var fuzz_spinbox: SpinBox = base_properties_grid.get_node("FuzzSpinBox")
onready var texture_spinbox: SpinBox = base_properties_grid.get_node("TextureSpinBox")

onready var roll_spinbox: SpinBox = scroll_vbox.get_node("CustomRotationContainer/RollSpinBox")
onready var pitch_spinbox: SpinBox = scroll_vbox.get_node("CustomRotationContainer/PitchSpinBox")
onready var yaw_spinbox: SpinBox = scroll_vbox.get_node("CustomRotationContainer/YawSpinBox")

onready var size_scale_spin: SpinBox = scroll_vbox.get_node("ScaleSettingsGrid/SizeScaleSpinBox")
onready var pos_scale_spin: SpinBox = scroll_vbox.get_node("ScaleSettingsGrid/PosScaleSpinBox")
onready var link_scale_chk: CheckBox = scroll_vbox.get_node("ScaleSettingsGrid/LinkScaleCheckBox")

onready var mirror_x_btn: Button = scroll_vbox.get_node("MirrorGrid/MirrorXButton")
onready var mirror_y_btn: Button = scroll_vbox.get_node("MirrorGrid/MirrorYButton")
onready var mirror_z_btn: Button = scroll_vbox.get_node("MirrorGrid/MirrorZButton")

onready var recolor_rules_container = scroll_vbox.get_node("RecolorRulesContainer")
onready var autofill_btn: Button = scroll_vbox.get_node("RecolorActions/AutofillRecolorsButton")
onready var apply_recolor_btn: Button = scroll_vbox.get_node("RecolorActions/ApplyRecolorsButton")
onready var clear_recolor_btn: Button = scroll_vbox.get_node("RecolorActions/ClearRecolorsButton")

var _base_paintballz_data: Array = []
var source_ball_reference_size: float = 10

const SizeMode = {
	SET = 0,
	SUM = 1,
	TRUE = 2
}

func _ready() -> void:
	eyedropper_toggle.connect("toggled", self, "_on_EyedropperToggle_toggled")

	set_paintballz_button.connect("pressed", self, "_on_SetPaintballzButton_pressed")
	get_paintballz_button.connect("pressed", self, "_on_GetPaintballzButton_pressed")
	show_raw_button.connect("pressed", self, "_on_ShowRawButton_pressed")

	mirror_x_btn.connect("pressed", self, "_on_MirrorButton_pressed", ["x"])
	mirror_y_btn.connect("pressed", self, "_on_MirrorButton_pressed", ["y"])
	mirror_z_btn.connect("pressed", self, "_on_MirrorButton_pressed", ["z"])

	size_spinbox.connect("value_changed", self, "_on_property_changed")
	size_mode_option.connect("item_selected", self, "_on_property_changed")
	color_edit.connect("text_changed", self, "_on_property_changed")
	outline_color_edit.connect("text_changed", self, "_on_property_changed")
	outline_spinbox.connect("value_changed", self, "_on_property_changed")
	fuzz_spinbox.connect("value_changed", self, "_on_property_changed")
	texture_spinbox.connect("value_changed", self, "_on_property_changed")

	include_size_chk.connect("toggled", self, "_on_property_changed")
	include_color_chk.connect("toggled", self, "_on_property_changed")
	include_outline_color_chk.connect("toggled", self, "_on_property_changed")
	include_outline_chk.connect("toggled", self, "_on_property_changed")
	include_fuzz_chk.connect("toggled", self, "_on_property_changed")
	include_texture_chk.connect("toggled", self, "_on_property_changed")

	roll_spinbox.connect("value_changed", self, "_on_rotation_changed")
	pitch_spinbox.connect("value_changed", self, "_on_rotation_changed")
	yaw_spinbox.connect("value_changed", self, "_on_rotation_changed")

	size_scale_spin.connect("value_changed", self, "_on_scale_changed", [true])
	pos_scale_spin.connect("value_changed", self, "_on_scale_changed", [false])
	link_scale_chk.connect("toggled", self, "_on_property_changed")

	var apply_btn: Button = scroll_vbox.get_node("SelectionActions/ApplyButton")
	apply_btn.connect("pressed", self, "_on_ApplyButton_pressed")

	var unselect_btn: Button = scroll_vbox.get_node("SelectionActions/UnselectButton")
	unselect_btn.connect("pressed", self, "_on_UnselectButton_pressed")

	var affected_ballz = scroll_vbox.get_node("AffectedBallz")
	affected_ballz.connect("text_entered", self, "_on_AffectedBallz_text_entered")
	affected_ballz.connect("text_changed", self, "_on_AffectedBallz_text_changed")

	paintballz_tree.columns = 12
	paintballz_tree.set_column_titles_visible(true)
	paintballz_tree.set_column_title(0, "Ball")
	paintballz_tree.set_column_title(1, "Dia")
	paintballz_tree.set_column_title(2, "X")
	paintballz_tree.set_column_title(3, "Y")
	paintballz_tree.set_column_title(4, "Z")
	paintballz_tree.set_column_title(5, "Col")
	paintballz_tree.set_column_title(6, "OutCol")
	paintballz_tree.set_column_title(7, "Fuzz")
	paintballz_tree.set_column_title(8, "Out")
	paintballz_tree.set_column_title(9, "Grp")
	paintballz_tree.set_column_title(10, "Tex")
	paintballz_tree.set_column_title(11, "Anc")

	paintballz_tree.connect("item_edited", self, "_on_Tree_item_edited")
	paintballz_tree.select_mode = Tree.SELECT_SINGLE

	autofill_btn.connect("pressed", self, "_on_AutofillRecolorsButton_pressed")
	apply_recolor_btn.connect("pressed", self, "_on_ApplyRecolorsButton_pressed")
	clear_recolor_btn.connect("pressed", self, "_on_ClearRecolorsButton_pressed")

	connect("visibility_changed", self, "_on_visibility_changed")
	
	var viewport_size: Vector2 = get_viewport().size
	var panel_size: Vector2 = panel.rect_size
	
	var default_x: float = (viewport_size.x - panel_size.x) / 2
	var default_y: float = viewport_size.y - panel_size.y - 10
	var default_pos: Vector2 = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)

	if not is_inside_tree():
		return

	_refresh_active_palette_from_dog_generator()

	_connect_settings_signals()
	load_settings()

	_connect_dog_generator_signal()

	call_deferred("update_preview")
	_update_paintballz_tree_color_icons()

func _refresh_active_palette_from_dog_generator() -> void:
	var dog_gen = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if dog_gen:
		if dog_gen.has_method("get_is_babyz_mode"):
			if dog_gen.get_is_babyz_mode():
				active_palette = LnzLiveUtils.BABYZ_PALETTE
			else:
				active_palette = LnzLiveUtils.DEFAULT_PALETTE
		elif dog_gen.get("is_babyz_mode") != null:
			if dog_gen.is_babyz_mode:
				active_palette = LnzLiveUtils.BABYZ_PALETTE
			else:
				active_palette = LnzLiveUtils.DEFAULT_PALETTE
		else:
			active_palette = LnzLiveUtils.DEFAULT_PALETTE
	else:
		active_palette = LnzLiveUtils.DEFAULT_PALETTE

func _connect_dog_generator_signal() -> void:
	var dog_gen = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if dog_gen and dog_gen.has_signal("palette_changed"):
		if dog_gen.is_connected("palette_changed", self, "_on_dog_generator_palette_changed"):
			dog_gen.disconnect("palette_changed", self, "_on_dog_generator_palette_changed")
		dog_gen.connect("palette_changed", self, "_on_dog_generator_palette_changed")

func _on_dog_generator_palette_changed(palette_name = "") -> void:
	_refresh_active_palette_from_dog_generator()
	update_preview()
	_update_paintballz_tree_color_icons()
	_update_recolor_rules_previews()

func _on_visibility_changed() -> void:
	if visible:
		update_preview()
		_update_paintballz_tree_color_icons()
		_update_recolor_rules_previews()
	else:
		clear_preview()

func clear_preview() -> void:
	if not is_instance_valid(preview_world):
		return
		
	for child in preview_world.get_children():
		if child.name.begins_with("PreviewBall") or child.name.begins_with("Paintball") or child.is_in_group("preview_objects"):
			child.queue_free()

func set_texture_list(list: Array) -> void:
	ball_texture_list = list
	if ball_texture_list.size() > 0:
		texture_spinbox.max_value = ball_texture_list.size() - 1
	update_preview()

func set_palette(palette_name) -> void:
	var pal_texture: Texture = null
	
	if palette_name != null and str(palette_name) != "":
		var user_res_path: String = "user://resources/palettes/" + palette_name
		var res_res_path: String = "res://resources/palettes/" + palette_name
		
		if ResourceLoader.exists(user_res_path):
			pal_texture = ResourceLoader.load(user_res_path)
		elif ResourceLoader.exists(res_res_path):
			pal_texture = ResourceLoader.load(res_res_path)
		elif preloader and preloader.has_resource("palette_" + palette_name.to_lower()):
			pal_texture = preloader.get_resource("palette_" + palette_name.to_lower())

	if pal_texture == null:
		pal_texture = _get_current_palette_texture()
	
	if pal_texture:
		active_palette = pal_texture
	else:
		active_palette = default_palette
		
	update_preview()
	_update_paintballz_tree_color_icons()
	_update_recolor_rules_previews()

func _get_current_palette_texture() -> Texture:
	var dog_gen = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if dog_gen:
		if dog_gen.has_method("get_is_babyz_mode"):
			if dog_gen.get_is_babyz_mode():
				return LnzLiveUtils.BABYZ_PALETTE
			else:
				return LnzLiveUtils.DEFAULT_PALETTE
		var is_babyz_val = dog_gen.get("is_babyz_mode")
		if is_babyz_val != null:
			if is_babyz_val:
				return LnzLiveUtils.BABYZ_PALETTE
			else:
				return LnzLiveUtils.DEFAULT_PALETTE
	
	return LnzLiveUtils.DEFAULT_PALETTE

func sync_camera(main_camera_transform: Transform) -> void:
	if preview_camera and is_instance_valid(preview_camera):
		preview_camera.global_transform.basis = main_camera_transform.basis
		var dist: float = 3.0
		preview_camera.global_transform.origin = main_camera_transform.basis.z * dist
		preview_camera.global_transform.basis.x *= -1.0

func _on_property_changed(_val = null) -> void:
	if _is_loading_settings: return
	save_settings()
	update_preview()

func _on_scale_changed(value: float, is_size_control: bool) -> void:
	if _is_loading_settings: return
	
	if link_scale_chk.pressed:
		_is_loading_settings = true
		if is_size_control:
			pos_scale_spin.value = value
		else:
			size_scale_spin.value = value
		_is_loading_settings = false
	
	save_settings()
	update_preview()

func _on_rotation_changed(_val = null) -> void:
	if _is_loading_settings: return
	_apply_rotation_to_tree()
	save_settings()
	update_preview()

func _on_EyedropperToggle_toggled(is_on: bool) -> void:
	emit_signal("eyedropper_toggled", is_on)

func _on_ShowRawButton_pressed() -> void:
	raw_lnz_container.visible = not raw_lnz_container.visible

func _on_Tree_item_edited() -> void:
	_base_paintballz_data.clear()
	var root: TreeItem = paintballz_tree.get_root()
	if root:
		var item: TreeItem = root.get_children()
		while item:
			var p_data: Dictionary = _read_item_data(item)
			_base_paintballz_data.append(p_data)
			item = item.get_next()

	_reset_rotation_spinboxes()
	update_preview()
	_update_paintballz_tree_color_icons()

func _read_item_data(item: TreeItem) -> Dictionary:
	return {
		"base": item.get_text(0).to_int(),
		"size": item.get_text(1).to_int(),
		"position": Vector3(item.get_text(2).to_float(), item.get_text(3).to_float(), item.get_text(4).to_float()),
		"color_index": item.get_text(5).to_int(),
		"outline_color_index": item.get_text(6).to_int(),
		"fuzz": item.get_text(7).to_int(),
		"outline": item.get_text(8).to_int(),
		"group": item.get_text(9).to_int(),
		"texture_id": item.get_text(10).to_int(),
		"anchored": item.get_text(11).to_int()
	}

func _apply_rotation_to_tree() -> void:
	_is_loading_settings = true

	var roll: float = deg2rad(roll_spinbox.value)
	var pitch: float = deg2rad(pitch_spinbox.value)
	var yaw: float = deg2rad(yaw_spinbox.value)

	var basis: Basis = Basis(Vector3(roll, pitch, yaw))

	paintballz_tree.clear()
	var root: TreeItem = paintballz_tree.create_item()

	for p_data in _base_paintballz_data:
		var new_pos: Vector3 = basis.xform(p_data.position)

		var item: TreeItem = paintballz_tree.create_item(root)
		_setup_tree_item(item, p_data, new_pos)

	_is_loading_settings = false

func _reset_rotation_spinboxes() -> void:
	_is_loading_settings = true
	roll_spinbox.value = 0
	pitch_spinbox.value = 0
	yaw_spinbox.value = 0
	_is_loading_settings = false

func _on_MirrorButton_pressed(axis: String) -> void:
	for p_data in _base_paintballz_data:
		if axis == "x": p_data.position.x *= -1
		if axis == "y": p_data.position.y *= -1
		if axis == "z": p_data.position.z *= -1

	_reset_rotation_spinboxes()

	_populate_tree_from_base()
	save_settings()
	update_preview()

func _populate_tree_from_base() -> void:
	paintballz_tree.clear()
	var root: TreeItem = paintballz_tree.create_item()
	for p_data in _base_paintballz_data:
		var item: TreeItem = paintballz_tree.create_item(root)
		_setup_tree_item(item, p_data, p_data.position)
	_update_paintballz_tree_color_icons()

func _setup_tree_item(item: TreeItem, p_data: Dictionary, pos: Vector3) -> void:
	item.set_text(0, str(p_data.base))
	item.set_text(1, str(p_data["size"]))
	item.set_text(2, str(pos.x))
	item.set_text(3, str(pos.y))
	item.set_text(4, str(pos.z))
	item.set_text(5, str(p_data.color_index))
	item.set_text(6, str(p_data.outline_color_index))
	item.set_text(7, str(p_data.fuzz))
	item.set_text(8, str(p_data.outline))
	item.set_text(9, str(p_data.group))
	item.set_text(10, str(p_data.texture_id))
	item.set_text(11, str(p_data.anchored))

	for i in range(12):
		item.set_editable(i, true)

func _on_SetPaintballzButton_pressed() -> void:
	var text: String = paintballz_text_edit.text
	var lines: Array = text.split("\n")

	_base_paintballz_data.clear()

	for line in lines:
		if line.empty() or line.begins_with(";") or line.begins_with("#") or line.begins_with("["):
			continue

		var parts: Array = _split_and_clean_paintball(line)
		
		if parts.size() < 9:
			continue

		var tex_index: int = 10
		var anchor_index: int = 11

		var p_data: Dictionary = {
			"base": parts[0].to_int(),
			"size": parts[1].to_int(),
			"position": Vector3(parts[2].to_float(), parts[3].to_float(), parts[4].to_float()),
			"color_index": parts[5].to_int(),
			"outline_color_index": parts[6].to_int(),
			"fuzz": parts[7].to_int(),
			"outline": parts[8].to_int(),
			"group": parts[9].to_int(),
			"texture_id": parts[tex_index].to_int() if parts.size() > tex_index else -1,
			"anchored": parts[anchor_index].to_int() if parts.size() > anchor_index else 0
		}
		_base_paintballz_data.append(p_data)

	_reset_rotation_spinboxes()
	_populate_tree_from_base()
	save_settings()
	update_preview()

func _on_GetPaintballzButton_pressed() -> void:
	var lnz_lines: Array = []
	var root: TreeItem = paintballz_tree.get_root()
	if not root:
		return
	
	var item: TreeItem = root.get_children()
	while item:
		var parts: Array = []
		for i in range(11):
			parts.append(item.get_text(i))
		
		var res_str: PoolStringArray = PoolStringArray(parts)
		lnz_lines.append(res_str.join("\t"))
		res_str.resize(0)
		item = item.get_next()
	
	var res_str_final: PoolStringArray = PoolStringArray(lnz_lines)
	paintballz_text_edit.text = res_str_final.join("\n")
	res_str_final.resize(0)

func _split_and_clean_paintball(line: String) -> Array:
	var line_parts: Array = line.split(";", false, 1)
	var data_part: String = line_parts[0].strip_edges()

	data_part = data_part.replace(",", " ")
	data_part = data_part.replace("\t", " ")

	var parts: Array = data_part.split(" ", false)
	
	var cleaned_parts: Array = []
	for part in parts:
		cleaned_parts.append(part.strip_edges())
		
	return cleaned_parts

func _load_texture(texture_filename: String) -> Texture:
	var root_node: Node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if root_node and root_node.has_method("load_texture"):
		return root_node.load_texture(texture_filename, get_tree().root.get_node("Root/ResourcePreloader"))

	var texture: Texture = null
	var base_name: String = texture_filename.get_basename()
	var extension: String = texture_filename.get_extension()
	var filename_variants: Array = []
	filename_variants.append(texture_filename)
	filename_variants.append(texture_filename.to_upper())
	filename_variants.append(texture_filename.to_lower())
	filename_variants.append(base_name + "." + extension.to_upper())
	filename_variants.append(base_name + "." + extension.to_lower())
	filename_variants.append(base_name.to_upper() + "." + extension)
	filename_variants.append(base_name.to_lower() + "." + extension)
	filename_variants.append(base_name.to_upper() + "." + extension.to_upper())
	filename_variants.append(base_name.to_lower() + "." + extension.to_lower())

	var deduped: Array = []
	for v in filename_variants:
		if not (v in deduped):
			deduped.append(v)
	filename_variants = deduped

	for variant in filename_variants:
		var resource_path: String = "res://resources/textures/" + variant
		var user_resource_path: String = "user://resources/textures/" + variant

		if ResourceLoader.exists(resource_path):
			texture = ResourceLoader.load(resource_path)
			break
		elif ResourceLoader.exists(user_resource_path):
			texture = ResourceLoader.load(user_resource_path)
			break

	return texture

func update_preview() -> void:
	if not visible:
		return
		
	for child in preview_world.get_children():
		if child.name.begins_with("PreviewBall") or child.name.begins_with("Paintball") or child.is_in_group("preview_objects"):
			child.free()

	var base_visual_ball: Spatial = ball_scene.instance()
	base_visual_ball.add_to_group("preview_objects")
	preview_world.add_child(base_visual_ball)

	var base_size: float = size_spinbox.value
	if base_size < 1: base_size = 1

	base_visual_ball.ball_size = base_size

	if include_color_chk.pressed:
		base_visual_ball.color_index = color_edit.text.to_int()
	else:
		base_visual_ball.color_index = 0

	if include_outline_color_chk.pressed:
		base_visual_ball.outline_color_index = outline_color_edit.text.to_int()
	else:
		base_visual_ball.outline_color_index = 0

	if include_outline_chk.pressed:
		base_visual_ball.outline = int(outline_spinbox.value)
	else:
		base_visual_ball.outline = -1

	if include_fuzz_chk.pressed:
		base_visual_ball.fuzz_amount = clamp(int(fuzz_spinbox.value) / 2, 0, 5)
	else:
		base_visual_ball.fuzz_amount = 0

	base_visual_ball.palette = active_palette

	if include_texture_chk.pressed:
		var tex_id: int = int(texture_spinbox.value)
		if tex_id >= 0 and tex_id < ball_texture_list.size():
			var tex_info: Dictionary = ball_texture_list[tex_id]
			var path: String = ""
			if typeof(tex_info) == TYPE_DICTIONARY and tex_info.has("filename"):
				path = tex_info.filename

			if not path.empty():
				var loaded_tex: Texture = _load_texture(path)
				if loaded_tex:
					base_visual_ball.texture = loaded_tex
					if tex_info.has("transparent_color"):
						base_visual_ball.transparent_color = tex_info.transparent_color
					if tex_info.has("texture_size") and tex_info.texture_size != null:
						base_visual_ball.texture_size = tex_info.texture_size

	base_visual_ball.transform.origin = Vector3.ZERO

	if include_paintballz_chk.pressed:
		var root: TreeItem = paintballz_tree.get_root()
		if root:
			var paintballs_from_tree: Array = []
			var item: TreeItem = root.get_children()
			while item:
				var size: int = item.get_text(1).to_int()
				var pos: Vector3 = Vector3(item.get_text(2).to_float(), item.get_text(3).to_float(), item.get_text(4).to_float())
				var col: int = item.get_text(5).to_int()
				var out_col: int = item.get_text(6).to_int()
				var fuzz: int = item.get_text(7).to_int()
				var outline: int = item.get_text(8).to_int()
				var tex_id: int = item.get_text(9).to_int()

				paintballs_from_tree.append({
					"size": size,
					"pos": pos,
					"col": col,
					"out_col": out_col,
					"fuzz": fuzz,
					"outline": outline,
					"tex_id": tex_id
				})

				item = item.get_next()

			paintballs_from_tree.invert()

			var z_add_counter: float = 0.0
			for pb_data in paintballs_from_tree:
				var size: int = pb_data["size"]
				var pos: Vector3 = pb_data.pos
				var col: int = pb_data.col
				var out_col: int = pb_data.out_col
				var fuzz: int = pb_data.fuzz
				var outline: int = pb_data.outline
				var tex_id: int = pb_data.tex_id

				var pb_visual: Spatial = paintball_scene.instance()
				base_visual_ball.add_child(pb_visual)

				var s_scale: float = size_scale_spin.value
				var p_scale: float = pos_scale_spin.value

				var final_size: float = float(base_size) * (float(size) / 100.0) * s_scale
				final_size -= 1.0 - fmod(final_size, 2.0)

				pb_visual.ball_size = final_size
				pb_visual.base_ball_size = base_size
				pb_visual.color_index = col
				pb_visual.outline_color_index = out_col
				pb_visual.outline = outline
				pb_visual.fuzz_amount = clamp(fuzz / 2, 0, 5)
				pb_visual.palette = active_palette

				pb_visual.z_add = z_add_counter
				z_add_counter += 1.0

				pb_visual.base_ball_position = Vector3.ZERO

				if tex_id >= 0 and tex_id < ball_texture_list.size():
					var tex_info: Dictionary = ball_texture_list[tex_id]
					var path: String = ""
					if typeof(tex_info) == TYPE_DICTIONARY and tex_info.has("filename"):
						path = tex_info.filename

					if not path.empty():
						var loaded_tex: Texture = _load_texture(path)
						if loaded_tex:
							pb_visual.texture = loaded_tex
							if tex_info.has("transparent_color"):
								pb_visual.transparent_color = tex_info.transparent_color
							if tex_info.has("texture_size") and tex_info.texture_size != null:
								pb_visual.texture_size = tex_info.texture_size

				var pixel_world_size: float = 0.002
				var pb_pos: Vector3 = pos * Vector3(1, -1, 1) * (float(base_size) / 2.0) * pixel_world_size * p_scale

				pb_visual.transform.origin = pb_pos

func is_eyedropper_active() -> bool:
	return eyedropper_toggle.pressed

func get_properties() -> Dictionary:
	var properties: Dictionary = {}

	properties["exclude_eyes"] = exclude_eyes_chk.pressed

	if include_size_chk.pressed:
		properties["size"] = int(round(size_spinbox.value))
		properties["size_mode"] = size_mode_option.selected

	if include_color_chk.pressed:
		properties["color_index"] = color_edit.text.to_int()
	if include_outline_color_chk.pressed:
		properties["outline_color_index"] = outline_color_edit.text.to_int()
	if include_outline_chk.pressed:
		properties["outline"] = int(outline_spinbox.value)
	if include_fuzz_chk.pressed:
		properties["fuzz"] = int(fuzz_spinbox.value)
	if include_texture_chk.pressed:
		properties["texture_id"] = int(texture_spinbox.value)

	properties["apply_ballz"] = true
	properties["apply_paintballz"] = include_paintballz_chk.pressed
	properties["scale_paintballz"] = scale_paintballz_chk.pressed

	properties["paintball_size_scale"] = size_scale_spin.value
	properties["paintball_pos_scale"] = pos_scale_spin.value

	if include_paintballz_chk.pressed:
		var paintballz: Array = []
		var root: TreeItem = paintballz_tree.get_root()
		if root:
			var item: TreeItem = root.get_children()
			while item:
				var p_data: Dictionary = _read_item_data(item)
				paintballz.append(p_data)
				item = item.get_next()
		properties["paintballz"] = paintballz

	return properties

func set_properties(properties: Dictionary) -> void:
	_is_loading_settings = true

	if properties.has("size"):
		size_spinbox.value = properties["size"]
		source_ball_reference_size = properties["size"]

	if properties.has("color_index"):
		color_edit.text = str(properties.color_index)
	if properties.has("outline_color_index"):
		outline_color_edit.text = str(properties.outline_color_index)
	if properties.has("outline"):
		outline_spinbox.value = properties.outline
	if properties.has("fuzz"):
		fuzz_spinbox.value = properties.fuzz
	if properties.has("texture_id"):
		texture_spinbox.value = properties.texture_id

	roll_spinbox.value = 0
	pitch_spinbox.value = 0
	yaw_spinbox.value = 0

	if properties.has("paintball_size_scale"):
		size_scale_spin.value = properties.paintball_size_scale
	else:
		size_scale_spin.value = 1.0

	if properties.has("paintball_pos_scale"):
		pos_scale_spin.value = properties.paintball_pos_scale
	else:
		pos_scale_spin.value = 1.0

	_base_paintballz_data.clear()

	if properties.has("paintballz"):
		for pb in properties.paintballz:
			if typeof(pb) == TYPE_OBJECT:
				_base_paintballz_data.append(_convert_lnz_object_to_dict(pb))
			elif typeof(pb) == TYPE_DICTIONARY:
				_base_paintballz_data.append(pb.duplicate())

	_populate_tree_from_base()

	_is_loading_settings = false
	save_settings()
	update_preview()

func _convert_lnz_object_to_dict(obj: Object) -> Dictionary:
	return {
		"base": obj.base,
		"size": obj["size"],
		"position": obj.normalised_position,
		"color_index": obj.color_index,
		"outline_color_index": obj.outline_color_index,
		"fuzz": obj.fuzz,
		"outline": obj.outline,
		"group": obj.group,
		"texture_id": obj.texture_id,
		"anchored": obj.anchored
	}

func _on_ApplyButton_pressed() -> void:
	emit_signal("apply_to_selection")

func _on_UnselectButton_pressed() -> void:
	emit_signal("unselect_all")

func _on_AffectedBallz_text_entered(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("select_balls_by_ids", ids)
	scroll_vbox.get_node("AffectedBallz").release_focus()

func _on_AffectedBallz_text_changed(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("select_balls_by_ids", ids)

func update_selected_balls_text(ball_ids: Array) -> void:
	var affected_ballz = scroll_vbox.get_node("AffectedBallz")
	if affected_ballz.has_focus():
		return

	ball_ids.sort()

	if ball_ids.empty():
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

	var res_str: PoolStringArray = PoolStringArray(ranges)
	affected_ballz.text = res_str.join(",")
	res_str.resize(0)

func _connect_settings_signals() -> void:
	include_paintballz_chk.connect("toggled", self, "_on_property_changed")
	scale_paintballz_chk.connect("toggled", self, "_on_property_changed")
	
	var reset_btn: Button = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)
		return

	config.set_value("PresetProperties", "size", size_spinbox.value)
	config.set_value("PresetProperties", "size_mode", size_mode_option.selected)
	config.set_value("PresetProperties", "color", color_edit.text)
	config.set_value("PresetProperties", "outline_color", outline_color_edit.text)
	config.set_value("PresetProperties", "outline", outline_spinbox.value)
	config.set_value("PresetProperties", "fuzz", fuzz_spinbox.value)
	config.set_value("PresetProperties", "texture", texture_spinbox.value)
	
	config.set_value("PresetProperties", "include_size", include_size_chk.pressed)
	config.set_value("PresetProperties", "include_color", include_color_chk.pressed)
	config.set_value("PresetProperties", "include_outline_color", include_outline_color_chk.pressed)
	config.set_value("PresetProperties", "include_outline", include_outline_chk.pressed)
	config.set_value("PresetProperties", "include_fuzz", include_fuzz_chk.pressed)
	config.set_value("PresetProperties", "include_texture", include_texture_chk.pressed)
	
	config.set_value("PresetProperties", "size_scale", size_scale_spin.value)
	config.set_value("PresetProperties", "pos_scale", pos_scale_spin.value)
	config.set_value("PresetProperties", "link_scale", link_scale_chk.pressed)
	
	config.set_value("PresetProperties", "include_paintballz", include_paintballz_chk.pressed)
	config.set_value("PresetProperties", "scale_paintballz", scale_paintballz_chk.pressed)
	
	config.set_value("PresetProperties", "paintballz_data", _base_paintballz_data)

	var save_err: int = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving PresetSettings: ", save_err)

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		return
	
	print("[STATUS] PresetSettings: loading settings configuration")
	_is_loading_settings = true

	size_spinbox.value = config.get_value("PresetProperties", "size", 10.0)
	size_mode_option.selected = config.get_value("PresetProperties", "size_mode", 2)
	color_edit.text = config.get_value("PresetProperties", "color", "0")
	outline_color_edit.text = config.get_value("PresetProperties", "outline_color", "0")
	outline_spinbox.value = config.get_value("PresetProperties", "outline", -1.0)
	fuzz_spinbox.value = config.get_value("PresetProperties", "fuzz", 0.0)
	texture_spinbox.value = config.get_value("PresetProperties", "texture", -1.0)
	
	include_size_chk.pressed = config.get_value("PresetProperties", "include_size", true)
	include_color_chk.pressed = config.get_value("PresetProperties", "include_color", true)
	include_outline_color_chk.pressed = config.get_value("PresetProperties", "include_outline_color", true)
	include_outline_chk.pressed = config.get_value("PresetProperties", "include_outline", true)
	include_fuzz_chk.pressed = config.get_value("PresetProperties", "include_fuzz", true)
	include_texture_chk.pressed = config.get_value("PresetProperties", "include_texture", true)
	
	size_scale_spin.value = config.get_value("PresetProperties", "size_scale", 1.0)
	pos_scale_spin.value = config.get_value("PresetProperties", "pos_scale", 1.0)
	link_scale_chk.pressed = config.get_value("PresetProperties", "link_scale", false)
	
	include_paintballz_chk.pressed = config.get_value("PresetProperties", "include_paintballz", true)
	scale_paintballz_chk.pressed = config.get_value("PresetProperties", "scale_paintballz", false)
	
	_base_paintballz_data = config.get_value("PresetProperties", "paintballz_data", [])
	_populate_tree_from_base()
	
	_is_loading_settings = false

func _on_reset_defaults_pressed() -> void:
	_is_loading_settings = true
	
	size_spinbox.value = 10.0
	size_mode_option.selected = 2
	color_edit.text = "0"
	outline_color_edit.text = "0"
	outline_spinbox.value = -1.0
	fuzz_spinbox.value = 0.0
	texture_spinbox.value = -1.0
	
	include_size_chk.pressed = true
	include_color_chk.pressed = true
	include_outline_color_chk.pressed = true
	include_outline_chk.pressed = true
	include_fuzz_chk.pressed = true
	include_texture_chk.pressed = true
	
	size_scale_spin.value = 1.0
	pos_scale_spin.value = 1.0
	link_scale_chk.pressed = false
	
	include_paintballz_chk.pressed = true
	scale_paintballz_chk.pressed = false
	
	_base_paintballz_data.clear()
	_populate_tree_from_base()
	
	_is_loading_settings = false
	
	save_settings()
	update_preview()

func _on_ClearRecolorsButton_pressed() -> void:
	for child in recolor_rules_container.get_children():
		child.queue_free()

func _on_AutofillRecolorsButton_pressed() -> void:
	_on_ClearRecolorsButton_pressed()
	
	var unique_pairs: Dictionary = {}
	for p_data in _base_paintballz_data:
		var col_str: String = str(p_data.color_index)
		var tex_str: String = str(p_data.texture_id) if p_data.texture_id != -1 else ""
		var key: String = col_str + "|" + tex_str
		
		if not unique_pairs.has(key):
			unique_pairs[key] = {
				"color": col_str,
				"texture": tex_str
			}
	
	for key in unique_pairs:
		var pair: Dictionary = unique_pairs[key]
		var line: Control = recolor_line_scene.instance()
		recolor_rules_container.add_child(line)
		
		line.get_node("BeforeColor").text = pair.color
		line.get_node("BeforeTexture").text = pair.texture
		
		var before_color = line.get_node("BeforeColor")
		var after_color = line.get_node("AfterColor")
		
		_setup_preview_wrapper(before_color, "BeforeColor_" + str(line.get_instance_id()))
		_setup_preview_wrapper(after_color, "AfterColor_" + str(line.get_instance_id()))

		var remove_btn: Button = line.get_node_or_null("RemoveButton")
		if remove_btn:
			remove_btn.connect("pressed", self, "_on_remove_recolor_line", [line])	

		_update_recolor_rules_previews()

func _on_remove_recolor_line(line: Control) -> void:
	if is_instance_valid(line) and line.get_parent() == recolor_rules_container:
		var remove_btn: Button = line.get_node_or_null("RemoveButton")
		if remove_btn and remove_btn.is_connected("pressed", self, "_on_remove_recolor_line"):
			remove_btn.disconnect("pressed", self, "_on_remove_recolor_line")
			
		line.queue_free()
		_update_recolor_rules_previews()


func _on_ApplyRecolorsButton_pressed() -> void:
	var rules: Array = []
	for line in recolor_rules_container.get_children():
		if line.is_queued_for_deletion(): continue
		
		var ramp_btn: CheckBox = line.get_node_or_null("ColorRampCheck")
		if not ramp_btn:
			continue
			
		var before_color_edit = line.get_node_or_null("BeforeColorWrapper/BeforeColor")
		var after_color_edit = line.get_node_or_null("AfterColorWrapper/AfterColor")
		
		var before_color: String = ""
		var after_color: String = ""
		
		if before_color_edit:
			before_color = before_color_edit.text.strip_edges()
		else:
			before_color = line.get_node("BeforeColor").text.strip_edges()
			
		if after_color_edit:
			after_color = after_color_edit.text.strip_edges()
		else:
			after_color = line.get_node("AfterColor").text.strip_edges()

		var before_texture_edit = line.get_node_or_null("BeforeTextureWrapper/BeforeTexture")
		var after_texture_edit = line.get_node_or_null("AfterTextureWrapper/AfterTexture")
		
		var before_texture: String = ""
		var after_texture: String = ""
		
		if before_texture_edit:
			before_texture = before_texture_edit.text.strip_edges()
		else:
			before_texture = line.get_node("BeforeTexture").text.strip_edges()
			
		if after_texture_edit:
			after_texture = after_texture_edit.text.strip_edges()
		else:
			after_texture = line.get_node("AfterTexture").text.strip_edges()

		rules.append({
			"before_color": before_color,
			"after_color": after_color,
			"before_texture": before_texture,
			"after_texture": after_texture,
			"is_ramp": ramp_btn.pressed
		})
	
	if rules.empty(): 
		return

	for p_data in _base_paintballz_data:
		var color_str: String = str(p_data.color_index)
		var texture_str: String = str(p_data.texture_id) if p_data.texture_id != -1 else ""

		for rule in rules:
			var tex_match: bool = rule.before_texture == "" or rule.before_texture == texture_str
			if not tex_match: 
				continue

			var result_color: String = ""
			if rule.is_ramp:
				result_color = LnzLiveUtils.get_ramp_color(color_str, rule)
			elif rule.before_color == "" or rule.before_color == color_str:
				result_color = rule.after_color
			
			if result_color != null and result_color != "":
				p_data.color_index = int(result_color)
				if not rule.after_texture.empty():
					p_data.texture_id = int(rule.after_texture)
				break 

	_populate_tree_from_base()
	update_preview()
	save_settings()


func _update_paintballz_tree_color_icons() -> void:
	var root: TreeItem = paintballz_tree.get_root()
	if not root:
		return
	
	var item: TreeItem = root.get_children()
	while item:
		var color_idx_str: String = item.get_text(5)
		var color_idx: int = 0
		if color_idx_str.is_valid_integer():
			color_idx = color_idx_str.to_int()
		
		# Get color from active palette
		var color: Color = Color.black
		if active_palette:
			var img: Image = active_palette.get_data()
			if img:
				img.lock()
				var w: int = img.get_width()
				var h: int = img.get_height()
				var x: int = color_idx % w
				var y: int = color_idx / w
				if x < w and y < h:
					color = img.get_pixel(x, y)
				img.unlock()
		
		var tex: ImageTexture = _create_color_preview_texture(color)
		
		item.set_icon(0, tex)
		
		item = item.get_next()

func _create_color_preview_texture(color: Color) -> ImageTexture:
	var img: Image = Image.new()
	img.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex: ImageTexture = ImageTexture.new()
	tex.create_from_image(img)
	return tex

func _setup_preview_wrapper(le, le_name: String) -> void:
	if not le: return
	var parent: Node = le.get_parent()

	var hbox = HBoxContainer.new()
	hbox.name = le_name + "Wrapper"
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pos: int = le.get_index()
	var orig_owner: Node = le.owner
	
	parent.remove_child(le)
	parent.add_child(hbox)
	
	if orig_owner != null:
		hbox.owner = orig_owner
	
	parent.move_child(hbox, pos)

	hbox.add_child(le)
	if orig_owner != null:
		le.owner = orig_owner
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var preview_container = HBoxContainer.new()
	preview_container.name = le_name + "_Preview"
	hbox.add_child(preview_container)
	if orig_owner != null:
		preview_container.owner = orig_owner

	if not le.is_connected("text_changed", self, "_on_color_list_text_changed"):
		le.connect("text_changed", self, "_on_color_list_text_changed", [preview_container])

func _on_color_list_text_changed(new_text: String, container: Container) -> void:
	LnzLiveUtils.update_color_list_previews(container, new_text, _get_cached_palette_colors())

func _update_recolor_rules_previews() -> void:
	var lines: Array = recolor_rules_container.get_children()
	for l in lines:
		if l.is_queued_for_deletion(): continue
		
		var id: String = str(l.get_instance_id())
		
		var bc = l.get_node_or_null("BeforeColor_" + str(id) + "Wrapper/BeforeColor")
		var bc_prev: Node = l.get_node_or_null("BeforeColor_" + str(id) + "Wrapper/BeforeColor_" + str(id) + "_Preview")
		if bc and bc_prev: 
			LnzLiveUtils.update_color_list_previews(bc_prev, bc.text, _get_cached_palette_colors())

		var ac = l.get_node_or_null("AfterColor_" + str(id) + "Wrapper/AfterColor")
		var ac_prev: Node = l.get_node_or_null("AfterColor_" + str(id) + "Wrapper/AfterColor_" + str(id) + "_Preview")
		if ac and ac_prev: 
			LnzLiveUtils.update_color_list_previews(ac_prev, ac.text, _get_cached_palette_colors())

func _get_cached_palette_colors() -> Array:
	var dog_gen = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	var is_babyz: bool = false
	
	if dog_gen:
		if dog_gen.has_method("get_is_babyz_mode"):
			is_babyz = dog_gen.get_is_babyz_mode()
		else:
			# Check for property safely
			var is_babyz_val = dog_gen.get("is_babyz_mode")
			if is_babyz_val != null:
				is_babyz = is_babyz_val
	
	var palette_to_use: Texture
	if is_babyz:
		palette_to_use = LnzLiveUtils.BABYZ_PALETTE
	else:
		palette_to_use = LnzLiveUtils.DEFAULT_PALETTE

	var colors: Array = []
	var img: Image = palette_to_use.get_data()
	if img:
		img.lock()
		var w: int = img.get_width()
		var h: int = img.get_height()
		for i in range(256):
			var x: int = i % w
			var y: int = i / h
			if x < w and y < h:
				colors.append(img.get_pixel(x, y))
			else:
				colors.append(Color.black)
		img.unlock()
	return colors
