extends DraggablePanel
## PaintballSettings.gd
## Manages the UI panel and logic for the Paintball Mode settings
## This script controls the visibility of the settings panel and provides methods to:
## 1. Initialize the panel to the bottom center of the viewport and connect UI signals
## 2. Show and hide the panel
## 3. Retrieve all current paintball properties (e.g., diameter, color, fuzz)
## 4. Emit the `apply_paintballz` signal when the "Apply" button is pressed
## 5. Emit the `delete_mode_toggled(is_on)` signal when the checkbox is toggled

signal apply_paintballz
signal clear_paintballz
signal delete_mode_toggled(is_on)

var _is_loading_settings: bool = false

onready var paintballz_tree: Tree = find_node("PaintballzTree")
onready var _apply_button: Button = find_node("ApplyButton")
onready var _clear_button: Button = find_node("ClearButton")
onready var _eraser_checkbox: CheckBox = find_node("EraserCheckBox")
onready var _tab_container: TabContainer = find_node("TabContainer")
onready var _brush_space_slider: HSlider = find_node("BrushSpaceSlider")
onready var _diameter_min: SpinBox = find_node("DiameterMin")
onready var _diameter_max: SpinBox = find_node("DiameterMax")
onready var _tapered: CheckBox = find_node("Tapered")
onready var _pixel_mode: CheckBox = find_node("PixelMode")

onready var _color: Control = find_node("Color")
var _color_preview: Control = null

onready var _outline_color: Control = find_node("OutlineColor")
var _outline_color_preview: Control = null

onready var _outline_type_min: SpinBox = find_node("OutlineTypeMin")
onready var _outline_type_max: SpinBox = find_node("OutlineTypeMax")
onready var _fuzz_min: SpinBox = find_node("FuzzMin")
onready var _fuzz_max: SpinBox = find_node("FuzzMax")
onready var _texture: Control = find_node("Texture")
onready var _group: SpinBox = find_node("Group")
onready var _anchored: CheckBox = find_node("Anchored")
onready var _target: OptionButton = find_node("Target")
onready var _freeline_checkbox: CheckBox = find_node("FreelineCheckBox")
onready var _spacing: SpinBox = find_node("Spacing")
onready var _jitter: SpinBox = find_node("Jitter")
onready var _ordered: CheckBox = find_node("Ordered")
onready var _repeat: CheckBox = find_node("Repeat")
onready var _shuffle: CheckBox = find_node("Shuffle")
onready var _random_walk_checkbox: CheckBox = find_node("RandomWalkCheckBox")
onready var _walk_steps: SpinBox = find_node("WalkStepsSpinBox")
onready var _walk_spread: SpinBox = find_node("WalkSpreadSpinBox")
onready var _design_canvas: Control = find_node("DesignCanvas")
onready var _design_total_diameter: SpinBox = find_node("DesignTotalDiameter")
onready var _design_total_diameter_max: SpinBox = find_node("DesignTotalDiameterMax")
onready var _design_pixel_mode: CheckBox = find_node("DesignPixelMode")
onready var _design_jitter: SpinBox = find_node("DesignJitter")
onready var _brush_size_slider: HSlider = find_node("BrushSizeSlider")
onready var _brush_size_label: Label = find_node("BrushSizeLabel")
onready var _brush_space_label: Label = find_node("BrushSpaceLabel")
onready var _mirror_x: CheckBox = find_node("MirrorX")
onready var _mirror_y: CheckBox = find_node("MirrorY")
onready var _canvas_eraser: CheckBox = find_node("CanvasEraser")
onready var _rotate_fixed: CheckBox = find_node("RotateFixed")
onready var _rotate_jitter: SpinBox = find_node("RotateJitter")
onready var _spread_jitter: SpinBox = find_node("SpreadJitter")
onready var _slots_tree: Tree = find_node("SlotsTree")
onready var _add_slot_button: Button = find_node("AddSlotButton")
onready var _remove_slot_button: Button = find_node("RemoveSlotButton")
onready var _clear_grid_button: Button = find_node("ClearGridButton")
onready var _export_settings_btn: Button = find_node("ExportSettingsButton")
onready var _import_settings_btn: Button = find_node("ImportSettingsButton")
onready var _reset_defaults_btn: Button = find_node("ResetDefaultsButton")
onready var _interpolate_button: Button = find_node("InterpolateButton")
onready var _interpolate_steps: SpinBox = find_node("InterpolateStepsSpinBox")
onready var _gen_palette_button: Button = find_node("GenPaletteButton")
onready var _gen_palette_type_select: OptionButton = find_node("GenPaletteTypeSelect")
onready var _gen_palette_base_input: Control = find_node("GenPaletteBaseInput")
onready var _pattern_info_button: Button = find_node("PatternInfoButton")
onready var _pattern_info_dialog: WindowDialog = find_node("PatternInfoDialog")
onready var _import_pattern_button: Button = find_node("ImportPatternButton")
onready var _export_pattern_button: Button = find_node("ExportPatternButton")

var dog_generator: Node = null
var default_palette = LnzLiveUtils.DEFAULT_PALETTE
var active_palette = default_palette
var cached_palette_colors: Array = []

onready var preloader: ResourcePreloader = get_tree().root.get_node("Root/ResourcePreloader")

var design_color_slots: Array = [
	{
		"color": "105",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(1, 1, 0)
	},
	{
		"color": "95",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(1, 0, 0)
	},
	{
		"color": "145",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(0, 1, 0)
	},
	{
		"color": "155",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(0, 0, 1)
	}
]

const DESIGN_CANVAS_SIZE: float = 200.0

func _ready() -> void:
	_apply_button.connect("pressed", self, "_on_ApplyButton_pressed")
	_clear_button.connect("pressed", self, "_on_ClearButton_pressed")
	_eraser_checkbox.connect("toggled", self, "_on_DeleteModeCheckBox_toggled")

	if is_instance_valid(_interpolate_button):
		_interpolate_button.connect("pressed", self, "_on_InterpolateColors_pressed")
		
	if is_instance_valid(_gen_palette_button):
		_gen_palette_button.connect("pressed", self, "_on_GeneratePaletteButton_pressed")
		
	if is_instance_valid(_gen_palette_type_select):
		if _gen_palette_type_select.get_item_count() == 0:
			_gen_palette_type_select.add_item("Off")
			_gen_palette_type_select.add_item("Monochromatic")
			_gen_palette_type_select.add_item("Analogous")
			_gen_palette_type_select.add_item("Complementary")
			_gen_palette_type_select.add_item("Triadic")
			_gen_palette_type_select.add_item("Split Complementary")

	var viewport_size: Vector2 = get_viewport().size
	var panel: Control = self
	var panel_size: Vector2 = panel.rect_size
	
	var default_x: float = (viewport_size.x - panel_size.x) / 2.0
	var default_y: float = viewport_size.y - panel_size.y - 10.0
	var default_pos: Vector2 = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)

	if get_tree().get_root().has_node("Root/PetRoot/Node"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot/Node")
	elif get_tree().get_root().has_node("Root/PetRoot"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot")
		
	if dog_generator:
		dog_generator.connect("palette_changed", self, "_on_palette_changed")

	_setup_color_previews()
	_connect_settings_signals()
	_connect_design_signals()

	_brush_space_slider.connect("value_changed", self, "_on_brush_space_changed")

	_setup_slots_tree()
	load_settings()
	set_process(true)

func _setup_color_previews() -> void:
	_setup_preview_wrapper("Color")
	_setup_preview_wrapper("OutlineColor")
	
	_color_preview = find_node("Color_Preview", true, false)
	_outline_color_preview = find_node("OutlineColor_Preview", true, false)

func _setup_preview_wrapper(le_name: String) -> void:
	var le: Control = find_node(le_name, true, false)
	if not le: return
	var parent: Control = le.get_parent()

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
		le.connect("text_changed", self, "_on_color_list_text_changed", [le_name])

func _on_color_list_text_changed(new_text: String, le_name: String) -> void:
	if le_name == "Color" and _color_preview:
		_update_previews_inner(new_text, _color_preview)
	elif le_name == "OutlineColor" and _outline_color_preview:
		_update_previews_inner(new_text, _outline_color_preview)

func _refresh_all_previews() -> void:
	if _color and _color_preview:
		_update_previews_inner(_color.text, _color_preview)
		
	if _outline_color and _outline_color_preview:
		_update_previews_inner(_outline_color.text, _outline_color_preview)

func _update_previews_inner(text: String, container: Container) -> void:
	LnzLiveUtils.update_color_list_previews(container, text, cached_palette_colors)

func _get_ball_node(ball_no: int) -> Spatial:
	if ball_no < 0: return null
	var all_balls: Array = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for b in all_balls:
		if "ball_no" in b and b.ball_no == ball_no:
			return b
	return null

func _get_pb_world_radius(dict: Dictionary, node: Node, base_ball: Spatial) -> float:
	if is_instance_valid(node):
		var mi: MeshInstance = node if node is MeshInstance else node.get_node_or_null("MeshInstance")
		if mi: return mi.scale.x * 0.5
	if is_instance_valid(base_ball):
		var diam_pct: float = float(dict.get("diameter", dict.get("size", dict.get("diam", 20.0))))
		return base_ball.scale.x * (diam_pct / 100.0) * 0.5
	return 0.05

func _on_InterpolateColors_pressed() -> void:
	if not is_instance_valid(_interpolate_steps): return
	var steps: int = int(_interpolate_steps.value)
	if steps <= 0: return
	
	var color_lineedit = _color
	if not is_instance_valid(color_lineedit): return
	var color_str: String = color_lineedit.text
	var color_list: Array = LnzLiveUtils.parse_number_list(color_str)
	if color_list.size() < 2: return
	
	var new_list: Array = []
	for i in range(color_list.size() - 1):
		var c1_idx: int = color_list[i]
		var c2_idx: int = color_list[i+1]
		
		new_list.append(c1_idx)
		
		var in_same_ramp: bool = false
		if c1_idx >= 10 and c1_idx <= 199 and c2_idx >= 10 and c2_idx <= 199:
			if int(c1_idx / 10) == int(c2_idx / 10):
				in_same_ramp = true
				
		if in_same_ramp:
			for step in range(1, steps + 1):
				var t: float = float(step) / float(steps + 1)
				var interp_idx: int = int(round(lerp(c1_idx, c2_idx, t)))
				new_list.append(interp_idx)
		else:
			var col1: Color = get_color_from_index(c1_idx)
			var col2: Color = get_color_from_index(c2_idx)
			for step in range(1, steps + 1):
				var t: float = float(step) / float(steps + 1)
				var interp_col: Color = col1.linear_interpolate(col2, t)
				var closest_idx: int = get_closest_palette_index(interp_col)
				new_list.append(closest_idx)
			
	new_list.append(color_list[color_list.size() - 1])
	
	var res_str: PoolStringArray = PoolStringArray()
	for idx in new_list:
		res_str.append(str(idx))
	color_lineedit.text = res_str.join(",")
	res_str.resize(0)
	save_settings()
	_refresh_all_previews()

func _on_GeneratePaletteButton_pressed() -> void:
	randomize()
	
	var base_input: Control = _gen_palette_base_input
	var type_select: OptionButton = _gen_palette_type_select
	var color_lineedit = _color
	
	if not is_instance_valid(color_lineedit): 
		return
	
	var base_index: int = 0
	
	var has_valid_input: bool = false
	if is_instance_valid(base_input):
		if base_input is LineEdit and base_input.text.strip_edges() != "":
			var parsed: Array = LnzLiveUtils.parse_number_list(base_input.text)
			if parsed.size() > 0: 
				base_index = parsed[0]
				has_valid_input = true
		elif base_input is SpinBox:
			base_index = int(base_input.value)
			has_valid_input = true

	if not has_valid_input:
		var parsed: Array = LnzLiveUtils.parse_number_list(color_lineedit.text)
		if parsed.size() > 0: 
			base_index = parsed[randi() % parsed.size()]
		else:
			base_index = randi() % 256 
		
	var base_color: Color = get_color_from_index(base_index)
	
	var p_type: int = 0
	if is_instance_valid(type_select):
		p_type = type_select.selected
	
	var generated_colors: Array = LnzLiveUtils.generate_theory_colors(base_color, p_type, 4)
	
	var new_indices: Array = []
	
	if generated_colors.empty():
		new_indices.append(get_closest_palette_index(base_color))
	else:
		for c in generated_colors:
			var idx: int = get_closest_palette_index(c)
			if not new_indices.has(idx):
				new_indices.append(idx)
			
	var res_str: PoolStringArray = PoolStringArray()
	for idx in new_indices:
		res_str.append(str(idx))
		
	color_lineedit.text = res_str.join(",")
	res_str.resize(0)
	save_settings()
	_refresh_all_previews()
	
	var gen_btn: Button = _gen_palette_button
	if is_instance_valid(gen_btn): gen_btn.release_focus()
	if is_instance_valid(base_input) and base_input is Control: base_input.release_focus()
	color_lineedit.release_focus()

func _process(delta: float) -> void:
	if _is_loading_settings: return
	
	var raw_array = null
	if is_instance_valid(dog_generator) and "_pending_paintballs_data" in dog_generator:
		raw_array = dog_generator.get("_pending_paintballs_data")
	elif is_instance_valid(dog_generator) and "pending_paintballs" in dog_generator:
		raw_array = dog_generator.get("pending_paintballs")
	
	if typeof(raw_array) != TYPE_ARRAY:
		var pvc: Node = get_tree().root.find_node("PetViewContainer", true, false)
		if is_instance_valid(pvc) and "pending_paintballs" in pvc:
			raw_array = pvc.get("pending_paintballs")

	if typeof(raw_array) != TYPE_ARRAY or raw_array.empty():
		return

	var props: Dictionary = get_properties()

	var items: Array = []
	for i in range(raw_array.size()):
		var val = raw_array[i]
		var dict: Dictionary = {}
		var node: Node = null
		
		if typeof(val) == TYPE_DICTIONARY:
			dict = val
			node = val.get("node")
		elif typeof(val) == TYPE_OBJECT and val is Node:
			node = val
			if "paintball_data" in val: dict = val.get("paintball_data")
			elif val.has_meta("paintball_data"): dict = val.get_meta("paintball_data")

		var base_no: int = dict.get("base_ball_no", dict.get("ball", -1))
		if base_no == -1 and is_instance_valid(node) and "base_ball_no" in node:
			base_no = node.get("base_ball_no")

		var base_ball: Spatial = _get_ball_node(base_no)
		if not is_instance_valid(base_ball): continue

		var world_pos: Vector3 = Vector3.ZERO
		if is_instance_valid(node) and node.is_inside_tree():
			world_pos = node.global_transform.origin
		elif is_instance_valid(base_ball):
			var rel: Vector3 = dict.get("relative_pos_local", Vector3.ZERO)
			world_pos = base_ball.to_global(rel)

		items.append({
			"raw": val,
			"dict": dict,
			"node": node,
			"base_ball": base_ball,
			"world_pos": world_pos,
			"radius": _get_pb_world_radius(dict, node, base_ball)
		})

	var is_random_walk: bool = props.get("random_walk", false)
	var is_freeline: bool = props.get("freeline", false)

	if is_random_walk and not is_freeline:
		var walk_steps: int = props.get("walk_steps", 3)
		var walk_spread: float = props.get("walk_spread", 50.0) / 100.0
		var new_walks: Array = []

		for item in items:
			var dict: Dictionary = item.dict
			if dict.get("walk_done", false): continue
			dict["walk_done"] = true

			var base_origin: Vector3 = item.base_ball.global_transform.origin
			var curr_size: float = dict.get("diameter", dict.get("size", 20.0))
			
			var walk_positions: Array = LnzLiveUtils.generate_surface_walk(item.world_pos, base_origin, item.radius, walk_steps, walk_spread)
			
			for s in range(walk_steps):
				var curr_pos: Vector3 = walk_positions[s]
				curr_size *= rand_range(0.7, 0.95)
				curr_size = max(1.0, floor(curr_size))
				
				var child_dict: Dictionary = dict.duplicate(true)
				child_dict["walk_done"] = true 
				child_dict["noise_checked"] = true 
				if child_dict.has("node"): child_dict.erase("node")
				if child_dict.has("mesh"): child_dict.erase("mesh")

				var local_rel: Vector3 = item.base_ball.to_local(curr_pos)
				var pixel_scale: float = 0.002
				var engine_scale: float = 1.0
				if is_instance_valid(dog_generator):
					if "pixel_world_size" in dog_generator: pixel_scale = dog_generator.pixel_world_size
					if "lnz" in dog_generator and dog_generator.lnz != null:
						if "scales" in dog_generator.lnz:
							engine_scale = dog_generator.lnz.scales.x

				var lnz_rel: Vector3 = LnzLiveUtils.world_to_lnz_delta(curr_pos - base_origin, pixel_scale, engine_scale)

				child_dict["relative_pos_local"] = local_rel
				child_dict["relative_pos_lnz"] = lnz_rel
				if child_dict.has("x"):
					child_dict["x"] = lnz_rel.x
					child_dict["y"] = lnz_rel.y
					child_dict["z"] = lnz_rel.z
				if child_dict.has("position"):
					child_dict["position"] = lnz_rel

				child_dict["diameter"] = max(1.0, curr_size)
				if child_dict.has("size"): child_dict["size"] = max(1.0, curr_size)
				
				new_walks.append(child_dict)

		for w in new_walks:
			if is_instance_valid(dog_generator) and dog_generator.has_method("add_pending_paintball"):
				dog_generator.add_pending_paintball(w)
	else:
		for item in items:
			item.dict["walk_done"] = true

func get_closest_palette_index(target_color: Color) -> int:
	if cached_palette_colors.empty():
		return 0
	var best_index: int = 0
	var min_dist: float = INF
	for i in range(cached_palette_colors.size()):
		var c: Color = cached_palette_colors[i]
		var dist: float = pow(c.r - target_color.r, 2) + pow(c.g - target_color.g, 2) + pow(c.b - target_color.b, 2)
		if dist < min_dist:
			min_dist = dist
			best_index = i
	return best_index

func _on_ApplyButton_pressed() -> void:
	print("[STATUS] PaintballSettings: apply_paintballz signal emitted")
	emit_signal("apply_paintballz")

func _on_ClearButton_pressed() -> void:
	print("[STATUS] PaintballSettings: clear_paintballz signal emitted")
	emit_signal("clear_paintballz")

func _on_DeleteModeCheckBox_toggled(is_on: bool) -> void:
	print("[STATUS] PaintballSettings: delete_mode_toggled signal emitted, is_on: %s" % is_on)
	emit_signal("delete_mode_toggled", is_on)

func _on_palette_changed(palette_name = "") -> void:
	if not dog_generator or not dog_generator.current_palette_texture:
		return
		
	var img: Image = dog_generator.current_palette_texture.get_data()
	if img == null:
		return
		
	img.lock()
	
	var img_width: int = img.get_width()
	var img_height: int = img.get_height()
	
	cached_palette_colors.clear()
	for i in range(256):
		var x: int = i % img_width
		var y: int = i / img_width
		if x < img_width and y < img_height:
			cached_palette_colors.append(img.get_pixel(x, y))
		else:
			cached_palette_colors.append(Color.black)
			
	for slot in design_color_slots:
		# Parse the color string (e.g. "105" or "105, 95") and grab the first index
		var color_list: Array = LnzLiveUtils.parse_number_list(str(slot.color))
		if color_list and color_list.size() > 0:
			var index: int = int(color_list[0])
			var x: int = index % img_width
			var y: int = index / img_width
			
			if x < img_width and y < img_height:
				slot.display_color = img.get_pixel(x, y)
	
	img.unlock()
	
	_refresh_slot_buttons()
	_design_canvas.update()
	_refresh_all_previews()

func get_color_from_index(index: int) -> Color:
	if index >= 0 and index < cached_palette_colors.size():
		return cached_palette_colors[index]
	return Color.white

func is_design_mode_active() -> bool:
	return _tab_container.current_tab == 1

func get_properties() -> Dictionary:
	var properties: Dictionary = {}
	properties["diameter_min"] = _diameter_min.value
	properties["diameter_max"] = _diameter_max.value
	properties["tapered"] = _tapered.pressed
	properties["pixel_mode"] = _pixel_mode.pressed
	properties["color"] = _color.text if _color else ""
	properties["outline_color"] = _outline_color.text if _outline_color else ""
	properties["outline_type_min"] = _outline_type_min.value
	properties["outline_type_max"] = _outline_type_max.value
	properties["fuzz_min"] = _fuzz_min.value
	properties["fuzz_max"] = _fuzz_max.value
	properties["texture"] = _texture.text if _texture else ""
	properties["group"] = _group.value
	properties["anchored"] = _anchored.pressed
	properties["target_mode"] = _target.selected
	properties["freeline"] = _freeline_checkbox.pressed
	properties["spacing"] = _spacing.value
	properties["jitter"] = _jitter.value
	properties["ordered"] = _ordered.pressed
	properties["repeat"] = _repeat.pressed
	properties["shuffle"] = _shuffle.pressed
	properties["random_walk"] = _random_walk_checkbox.pressed
	properties["walk_steps"] = _walk_steps.value
	properties["walk_spread"] = _walk_spread.value
	return properties

func export_paintball_json() -> void:
	print("[STATUS] PaintballSettings: started exporting paintball JSON (HTML5 feature: %s)" % OS.has_feature("HTML5"))
	if OS.has_feature("HTML5"):
		var settings_dict: Dictionary = get_properties()
		settings_dict["exporter"] = "LnzLive"
		var json_string: String = JSON.print(settings_dict, "  ")
		var filename: String = str("LnzLive_paintball_preset_", OS.get_unix_time(), ".json")
		var base64_content: String = Marshalls.raw_to_base64(json_string.to_utf8())
		var js_code: String = """
		var element = document.createElement('a');
		element.setAttribute('href', 'data:application/json;base64,' + '""" + base64_content + """');
		element.setAttribute('download', '""" + filename + """');
		element.style.display = 'none';
		document.body.appendChild(element);
		element.click();
		document.body.removeChild(element);
		"""
		JavaScript.eval(js_code)
		print("[STATUS] PaintballSettings: triggered web download for %s" % filename)
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.window_title = "Export Paintball Preset"
		file_dialog.mode = FileDialog.MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Preset"]
		file_dialog.rect_min_size = Vector2(400, 400)
		file_dialog.current_file = str("LnzLive_paintball_preset_", OS.get_unix_time(), ".json")
		file_dialog.connect("file_selected", self, "_save_settings_file")
		file_dialog.connect("popup_hide", file_dialog, "free")
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _save_settings_file(path: String) -> void:
	var settings_dict: Dictionary = get_properties()
	settings_dict["exporter"] = "LnzLive"
	var json_string: String = JSON.print(settings_dict, "  ")
	var file: File = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(json_string)
		file.close()
		print("[STATUS] PaintballSettings: exported settings to %s" % path)
	else:
		print("[ERROR] PaintballSettings: failed to open file for writing settings export: %s" % path)

func _on_ImportPresetButton_pressed() -> void:
	print("[STATUS] PaintballSettings: import preset button pressed")
	if OS.has_feature("HTML5"):
		var js_code: String = """
		var input = document.createElement('input');
		input.type = 'file';
		input.accept = '.json';
		input.onchange = e => { 
		   var file = e.target.files[0]; 
		   var reader = new FileReader();
		   reader.readAsText(file,'UTF-8');
		   reader.onload = readerEvent => {
			   var content = readerEvent.target.result;
			   window.godotPaintballImport(content);
		   }
		}
		input.click();
		"""
		var callback = JavaScript.create_callback(self, "_on_web_import_completed")
		JavaScript.get_interface("window").godotPaintballImport = callback
		JavaScript.eval(js_code)
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.window_title = "Import Paintball Preset"
		file_dialog.mode = FileDialog.MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Preset"]
		file_dialog.rect_min_size = Vector2(400, 400)
		file_dialog.connect("file_selected", self, "_load_preset_file")
		file_dialog.connect("popup_hide", file_dialog, "free")
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _on_web_import_completed(args: Array) -> void:
	var content: String = args[0]
	var json_res = JSON.parse(content)
	if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
		print("[STATUS] PaintballSettings: web import parsed successfully, applying dictionary")
		_apply_settings_dict(json_res.result)
	else:
		print("[ERROR] PaintballSettings: web import failed to parse JSON (Error code: %d)" % json_res.error)

func _load_preset_file(path: String) -> void:
	print("[STATUS] PaintballSettings: attempting to load preset from %s" % path)
	var file: File = File.new()
	if file.open(path, File.READ) == OK:
		var text: String = file.get_as_text()
		var json_res = JSON.parse(text)
		if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
			print("[STATUS] PaintballSettings: successfully loaded and parsed preset file")
			_apply_settings_dict(json_res.result)
		else:
			print("[ERROR] PaintballSettings: failed to parse JSON preset from %s (Error code: %d)" % [path, json_res.error])
		file.close()
	else:
		print("[ERROR] PaintballSettings: failed to open preset file for reading: %s" % path)

func _apply_settings_dict(data: Dictionary) -> void:
	print("[STATUS] PaintballSettings: applying settings dictionary")
	_is_loading_settings = true
	if data.has("diameter_min"): _diameter_min.value = data["diameter_min"]
	if data.has("diameter_max"): _diameter_max.value = data["diameter_max"]
	if data.has("tapered"): _tapered.pressed = data["tapered"]
	if data.has("pixel_mode"): _pixel_mode.pressed = data["pixel_mode"]
	if data.has("color"): _color.text = str(data["color"])
	if data.has("outline_color"): _outline_color.text = str(data["outline_color"])
	if data.has("outline_type_min"): _outline_type_min.value = data["outline_type_min"]
	if data.has("outline_type_max"): _outline_type_max.value = data["outline_type_max"]
	if data.has("fuzz_min"): _fuzz_min.value = data["fuzz_min"]
	if data.has("fuzz_max"): _fuzz_max.value = data["fuzz_max"]
	if data.has("texture"): _texture.text = str(data["texture"])
	if data.has("group"): _group.value = data["group"]
	if data.has("anchored"): _anchored.pressed = data["anchored"]
	if data.has("target_mode"): _target.selected = data["target_mode"]
	if data.has("freeline"): _freeline_checkbox.pressed = data["freeline"]
	if data.has("spacing"): _spacing.value = data["spacing"]
	if data.has("jitter"): _jitter.value = data["jitter"]
	if data.has("ordered"): _ordered.pressed = data["ordered"]
	if data.has("repeat"): _repeat.pressed = data["repeat"]
	if data.has("shuffle"): _shuffle.pressed = data["shuffle"]
	if data.has("random_walk"): _random_walk_checkbox.pressed = data["random_walk"]
	if data.has("walk_steps"): _walk_steps.value = data["walk_steps"]
	if data.has("walk_spread"): _walk_spread.value = data["walk_spread"]
	_is_loading_settings = false
	save_settings()
	_refresh_all_previews()

func paste_paintball_design(center_dir: Vector3, basis: Basis, ball_no: int, ball_lnz_diameter: float, override_footprint: float = -1.0, design_rotation_angle: float = 0.0, jitter_enabled: bool = true) -> Dictionary:
	print("[STATUS] PaintballSettings: paste_paintball_design started on ball_no: %d" % ball_no)
	var design_canvas: Control = _design_canvas
	var paintballs: Array = design_canvas.design_paintballs
	
	var out_pos: PoolVector3Array = PoolVector3Array()
	var out_diams: PoolIntArray = PoolIntArray()
	var out_colors: PoolIntArray = PoolIntArray()
	var out_outlines: PoolIntArray = PoolIntArray()
	var out_out_types: PoolIntArray = PoolIntArray()
	var out_fuzz: PoolIntArray = PoolIntArray()
	var out_group: PoolIntArray = PoolIntArray()
	var out_tex: PoolIntArray = PoolIntArray()
	var out_anchored: PoolIntArray = PoolIntArray()

	var pixel_mode: bool = _design_pixel_mode.pressed
	
	var sampled_scale: float = rand_range(_design_total_diameter.value, _design_total_diameter_max.value)
	if override_footprint > 0:
		sampled_scale *= override_footprint
	
	var footprint_lnz: float = 0.0
	if pixel_mode:
		footprint_lnz = sampled_scale
	else:
		footprint_lnz = ball_lnz_diameter * (sampled_scale / 100.0)
	
	var d_jitter: float = _design_jitter.value if jitter_enabled else 0.0
	var r_jitter: float = _rotate_jitter.value if jitter_enabled else 0.0
	var s_jitter: float = _spread_jitter.value if jitter_enabled else 0.0
	var r_fixed: bool = _rotate_fixed.pressed if jitter_enabled else false

	if jitter_enabled and r_jitter > 0:
		if r_fixed:
			design_rotation_angle += deg2rad(r_jitter)
		else:
			design_rotation_angle += deg2rad(rand_range(-r_jitter, r_jitter))

	var rotated_basis: Basis = basis.rotated(center_dir, design_rotation_angle)
	var tangent_x: Vector3 = rotated_basis.x
	var tangent_y: Vector3 = rotated_basis.z

	var spread_offset: Vector3 = Vector3.ZERO
	if jitter_enabled and s_jitter > 0:
		var s_scale: float = (footprint_lnz / 2.0) * (s_jitter / 100.0)
		spread_offset = tangent_x * rand_range(-s_scale, s_scale) + tangent_y * rand_range(-s_scale, s_scale)

	var ball_lnz_diam_safe: float = max(1.0, ball_lnz_diameter)

	for pb in paintballs:
		if pb.color_slot - 1 >= design_color_slots.size():
			print("[WARNING] PaintballSettings: paste_paintball_design skipped pb due to invalid color_slot reference: %d" % pb.color_slot)
			continue
		var slot_data: Dictionary = design_color_slots[pb.color_slot - 1]

		var dx: float = pb.x * (footprint_lnz / 2.0)
		var dy: float = -pb.y * (footprint_lnz / 2.0)
		if d_jitter > 0:
			var j_amt: float = (d_jitter / 100.0) * (footprint_lnz / 2.0)
			dx += rand_range(-j_amt, j_amt)
			dy += rand_range(-j_amt, j_amt)

		var pos_on_plane: Vector3 = center_dir * (ball_lnz_diameter * 0.5) + tangent_x * dx + tangent_y * dy + spread_offset
		out_pos.append(pos_on_plane.normalized())

		var slot_scale: float = float(slot_data.get("scale", 100)) / 100.0
		var pb_size_units: float = footprint_lnz * (float(pb.diameter) / 100.0) * slot_scale
		
		if d_jitter > 0:
			pb_size_units *= (1.0 + rand_range(-d_jitter/100.0, d_jitter/100.0))
		
		var final_pb_percentage: float = (pb_size_units / ball_lnz_diam_safe) * 100.0
		out_diams.append(int(max(1, round(final_pb_percentage))))

		var color_list: Array = LnzLiveUtils.parse_number_list(slot_data.color)
		out_colors.append(color_list[randi() % color_list.size()] if color_list else 0)
		
		var out_col_list: Array = LnzLiveUtils.parse_number_list(slot_data.outline_color)
		out_outlines.append(int(out_col_list[0]) if out_col_list else 244)
		
		var tex_list: Array = LnzLiveUtils.parse_number_list(slot_data.texture, true)
		out_tex.append(int(tex_list[0]) if tex_list else 0)

		out_out_types.append(int(slot_data.outline_type))
		out_fuzz.append(int(slot_data.get("fuzz", 0)))
		out_group.append(int(slot_data.get("group", 0)))
		out_anchored.append(1 if slot_data.get("anchored", true) else 0)

	print("[STATUS] PaintballSettings: paste_paintball_design finished processing %d paintballs" % out_pos.size())
	return {
		"positions": out_pos, 
		"diameters": out_diams, 
		"colors": out_colors,
		"outlines": out_outlines, 
		"outline_types": out_out_types, 
		"fuzzes": out_fuzz,
		"groups": out_group, 
		"textures": out_tex, 
		"anchored": out_anchored
	}

func _connect_settings_signals() -> void:
	_diameter_min.connect("value_changed", self, "_on_setting_changed")
	_diameter_max.connect("value_changed", self, "_on_setting_changed")
	_tapered.connect("toggled", self, "_on_setting_changed")
	_pixel_mode.connect("toggled", self, "_on_setting_changed")
	
	if _color: _color.connect("text_changed", self, "_on_setting_changed")
	if _outline_color: _outline_color.connect("text_changed", self, "_on_setting_changed")
	
	_outline_type_min.connect("value_changed", self, "_on_setting_changed")
	_outline_type_max.connect("value_changed", self, "_on_setting_changed")
	_fuzz_min.connect("value_changed", self, "_on_setting_changed")
	_fuzz_max.connect("value_changed", self, "_on_setting_changed")
	if _texture: _texture.connect("text_changed", self, "_on_setting_changed")
	_group.connect("value_changed", self, "_on_setting_changed")
	_anchored.connect("toggled", self, "_on_setting_changed")
	_target.connect("item_selected", self, "_on_setting_changed")
	_freeline_checkbox.connect("toggled", self, "_on_setting_changed")
	_spacing.connect("value_changed", self, "_on_setting_changed")
	_jitter.connect("value_changed", self, "_on_setting_changed")
	_ordered.connect("toggled", self, "_on_setting_changed")
	_repeat.connect("toggled", self, "_on_setting_changed")
	_shuffle.connect("toggled", self, "_on_setting_changed")
	_eraser_checkbox.connect("toggled", self, "_on_setting_changed")
	_random_walk_checkbox.connect("toggled", self, "_on_setting_changed")
	_walk_steps.connect("value_changed", self, "_on_setting_changed")
	_walk_spread.connect("value_changed", self, "_on_setting_changed")

	if _export_settings_btn: _export_settings_btn.connect("pressed", self, "export_paintball_json")
	if _import_settings_btn: _import_settings_btn.connect("pressed", self, "_on_ImportPresetButton_pressed")

	if _reset_defaults_btn:
		_reset_defaults_btn.connect("pressed", self, "_on_reset_defaults_pressed")

func _connect_design_signals() -> void:
	_design_canvas.connect("design_changed", self, "_on_setting_changed")
	_clear_grid_button.connect("pressed", _design_canvas, "clear")
	_brush_size_slider.connect("value_changed", self, "_on_brush_size_changed")
	_design_total_diameter.connect("value_changed", self, "_on_setting_changed")
	_design_total_diameter_max.connect("value_changed", self, "_on_setting_changed")
	_rotate_fixed.connect("toggled", self, "_on_setting_changed")
	_design_pixel_mode.connect("toggled", self, "_on_setting_changed")

	_add_slot_button.connect("pressed", self, "_on_AddSlotButton_pressed")
	_remove_slot_button.connect("pressed", self, "_on_RemoveSlotButton_pressed")

	_mirror_x.connect("toggled", self, "_on_design_tool_toggled")
	_mirror_y.connect("toggled", self, "_on_design_tool_toggled")
	_canvas_eraser.connect("toggled", self, "_on_design_tool_toggled")
	_import_pattern_button.connect("pressed", self, "_on_import_pattern_pressed")
	_export_pattern_button.connect("pressed", self, "_on_export_pattern_pressed")
	_design_jitter.connect("value_changed", self, "_on_setting_changed")
	_rotate_jitter.connect("value_changed", self, "_on_setting_changed")
	_spread_jitter.connect("value_changed", self, "_on_setting_changed")

	_pattern_info_button.connect("pressed", self, "_on_pattern_info_pressed")
	_pattern_info_dialog.find_node("CloseButton").connect("pressed", self, "_on_info_close_pressed")

	_slots_tree.connect("item_edited", self, "_on_SlotsTree_item_edited")
	_slots_tree.connect("cell_selected", self, "_on_SlotsTree_cell_selected")
	_slots_tree.connect("item_selected", self, "_on_SlotsTree_cell_selected")

func _on_design_tool_toggled(_arg = null) -> void:
	_design_canvas.mirror_x = _mirror_x.pressed
	_design_canvas.mirror_y = _mirror_y.pressed
	_design_canvas.eraser_mode = _canvas_eraser.pressed
	_design_canvas.update()
	save_settings()

func _on_pattern_info_pressed() -> void:
	_pattern_info_dialog.popup_centered()

func _on_info_close_pressed() -> void:
	_pattern_info_dialog.hide()

func _on_import_pattern_pressed() -> void:
	if OS.has_feature("HTML5"):
		print("[WARNING] PaintballSettings: importing patterns is not yet supported in web version")
		JavaScript.eval("window.alert('Importing patterns is not yet supported in web version.');")
		return

	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.mode = FileDialog.MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.json ; JSON Pattern"]
	file_dialog.connect("file_selected", self, "_load_pattern_file")
	file_dialog.connect("popup_hide", file_dialog, "free")
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)

func _load_pattern_file(path: String) -> void:
	print("[STATUS] PaintballSettings: attempting to load pattern from %s" % path)
	var file: File = File.new()
	if file.open(path, File.READ) == OK:
		var text: String = file.get_as_text()
		var json_res = JSON.parse(text)
		if json_res.error == OK:
			var data: Dictionary = json_res.result
			if data.has("paintballs") and data.has("slots"):
				_design_canvas.design_paintballs = data.paintballs

				if data.slots is Array:
					design_color_slots.clear()
					for s in data.slots:
						if s.has("display_color_r"):
							s["display_color"] = Color(s["display_color_r"], s["display_color_g"], s["display_color_b"])
							s.erase("display_color_r")
							s.erase("display_color_g")
							s.erase("display_color_b")
						design_color_slots.append(s)

				if data.has("info") and data["info"] is Dictionary:
					var info: Dictionary = data["info"]
					_pattern_info_dialog.find_node("AuthorEdit").text = info.get("author", "")
					_pattern_info_dialog.find_node("WebsiteEdit").text = info.get("website", "")
					_pattern_info_dialog.find_node("DescEdit").text = info.get("description", "")

				_refresh_slot_buttons()
				_design_canvas.update()
				_design_canvas.emit_signal("design_changed")
				print("[STATUS] PaintballSettings: loaded and applied pattern from %s" % path)
		else:
			print("[ERROR] PaintballSettings: failed to parse JSON pattern from %s" % path)
		file.close()
	else:
		print("[ERROR] PaintballSettings: failed to open pattern file for reading: %s" % path)
	
	_on_palette_changed()

func _on_clear_design_pressed() -> void:
	print("[STATUS] PaintballSettings: design canvas cleared")
	_design_canvas.clear()
	
	design_color_slots = [
		{
			"color": "105",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"scale": 100,
			"display_color": Color(1, 1, 0)
		},
		{
			"color": "95",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"scale": 100,
			"display_color": Color(1, 0, 0)
		},
		{
			"color": "145",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"scale": 100,
			"display_color": Color(0, 1, 0)
		},
		{
			"color": "155",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"scale": 100,
			"display_color": Color(0, 0, 1)
		}
	]

	_refresh_slot_buttons()
	_design_canvas.emit_signal("design_changed")
	_on_palette_changed()

func _on_export_pattern_pressed() -> void:
	var author: String = _pattern_info_dialog.find_node("AuthorEdit").text.strip_edges()
	var filename: String = "LnzLive_paintball_pattern_"
	if not author.empty():
		filename = str(filename, author.replace(" ", "_"), "_")
	filename = str(filename, OS.get_unix_time(), ".json")

	print("[STATUS] PaintballSettings: generating export for pattern, filename: %s" % filename)
	if OS.has_feature("HTML5"):
		var data: Dictionary = _get_pattern_data_dict()
		var json_string: String = JSON.print(data, "\t")
		var base64_content: String = Marshalls.raw_to_base64(json_string.to_utf8())
		var js_code: String = """
		var element = document.createElement('a');
		element.setAttribute('href', 'data:application/json;base64,' + '""" + base64_content + """');
		element.setAttribute('download', '""" + filename + """');
		element.style.display = 'none';
		document.body.appendChild(element);
		element.click();
		document.body.removeChild(element);
		"""
		JavaScript.eval(js_code)
		print("[STATUS] PaintballSettings: pattern download triggered via web bridge")
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.window_title = "Export Stamp Pattern"
		file_dialog.mode = FileDialog.MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Pattern"]
		file_dialog.current_file = filename
		file_dialog.connect("file_selected", self, "_save_pattern_file")
		file_dialog.connect("popup_hide", file_dialog, "free")
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _get_pattern_data_dict() -> Dictionary:
	var data: Dictionary = {
		"exporter": "LnzLive",
		"info": {
			"time_generated": OS.get_datetime(),
			"author": _pattern_info_dialog.find_node("AuthorEdit").text,
			"website": _pattern_info_dialog.find_node("WebsiteEdit").text,
			"description": _pattern_info_dialog.find_node("DescEdit").text
		},
		"paintballs": _design_canvas.design_paintballs,
		"slots": []
	}

	for s in design_color_slots:
		var slot_copy: Dictionary = s.duplicate()
		if slot_copy.has("display_color") and slot_copy["display_color"] is Color:
			var col: Color = slot_copy["display_color"]
			slot_copy["display_color_r"] = col.r
			slot_copy["display_color_g"] = col.g
			slot_copy["display_color_b"] = col.b
			slot_copy.erase("display_color")
		data.slots.append(slot_copy)
	return data

func _save_pattern_file(path: String) -> void:
	var data: Dictionary = _get_pattern_data_dict()
	var file: File = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(JSON.print(data, "\t"))
		file.close()
		print("[STATUS] PaintballSettings: saved pattern file to %s" % path)
	else:
		print("[ERROR] PaintballSettings: failed to open file for saving pattern to %s" % path)

func _on_brush_size_changed(value: float) -> void:
	_design_canvas.brush_size = value
	_brush_size_label.text = "Brush Size (" + str(value) + "%)"

func _on_brush_space_changed(value: float) -> void:
	_design_canvas.brush_spacing = value
	_brush_space_label.text = "Brush Spacing (" + str(value) + "%)"

func _refresh_slot_buttons() -> void:
	_populate_slots_tree()
	_design_canvas.slot_data_ref = design_color_slots
	_design_canvas.update()

func _setup_slots_tree() -> void:
	var tree: Tree = _slots_tree
	tree.set_column_titles_visible(true)
	tree.columns = 9
	tree.set_column_title(0, "Color")
	tree.set_column_title(1, "Col")
	tree.set_column_title(2, "OutCol")
	tree.set_column_title(3, "Tex")
	tree.set_column_title(4, "Out")
	tree.set_column_title(5, "Fuzz")
	tree.set_column_title(6, "Grp")
	tree.set_column_title(7, "Anc")
	tree.set_column_title(8, "Scale")

	tree.set_column_expand(0, false)
	tree.set_column_min_width(0, 40)

	tree.set_column_expand(7, false)
	tree.set_column_min_width(7, 30)

	tree.set_column_expand(8, false)
	tree.set_column_min_width(8, 60)

func _populate_slots_tree() -> void:
	var tree: Tree = _slots_tree
	tree.clear()
	var root: TreeItem = tree.create_item()

	for i in range(design_color_slots.size()):
		var slot: Dictionary = design_color_slots[i]
		var item: TreeItem = tree.create_item(root)

		# Col 0: Display Color
		item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
		var icon: Texture = _create_color_icon(slot.color)
		if icon:
			var img_data: Image = icon.get_data()
			if img_data != null:
				img_data.lock()
				slot.display_color = img_data.get_pixel(0, 0)
				img_data.unlock()
				item.set_icon(0, icon)
			else:
				var default_icon: Texture = _create_color_icon(slot.display_color)
				item.set_icon(0, default_icon)
		else:
			var default_icon: Texture = _create_color_icon(slot.display_color)
			item.set_icon(0, default_icon)
		item.set_editable(0, false)

		# Col 1: LNZ Color (String)
		item.set_text(1, str(slot.color))
		item.set_editable(1, true)

		# Col 2: Outline Color (String)
		item.set_text(2, str(slot.outline_color))
		item.set_editable(2, true)

		# Col 3: Texture (String)
		item.set_text(3, str(slot.texture))
		item.set_editable(3, true)

		# Col 4: Outline Type (Range)
		item.set_cell_mode(4, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(4, -2, 10, 1)
		item.set_range(4, slot.outline_type)
		item.set_editable(4, true)

		# Col 5: Fuzz (Range)
		item.set_cell_mode(5, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(5, 0, 100, 1)
		item.set_range(5, slot.get("fuzz", 0))
		item.set_editable(5, true)

		# Col 6: Group (Range)
		item.set_cell_mode(6, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(6, -1, 100, 1)
		item.set_range(6, slot.get("group", 0))
		item.set_editable(6, true)

		# Col 7: Anchored (Check)
		item.set_cell_mode(7, TreeItem.CELL_MODE_CHECK)
		item.set_checked(7, slot.get("anchored", true))
		item.set_editable(7, true)

		# Col 8: Scale (Range %)
		item.set_cell_mode(8, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(8, 1, 500, 1)
		item.set_range(8, slot.get("scale", 100))
		item.set_editable(8, true)

		item.set_metadata(0, i)

func get_color_preview_icon(color_index: int) -> ImageTexture:
	var pet_node: Node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if not pet_node: return null
	if pet_node.has_method("generate_color_icon"):
		return pet_node.generate_color_icon(color_index)
	return null

func _create_color_icon(color_str) -> Texture:
	if typeof(color_str) == TYPE_COLOR:
		var img: Image = Image.new()
		img.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(color_str)
		var tex: ImageTexture = ImageTexture.new()
		tex.create_from_image(img)
		return tex

	var color_list: Array = LnzLiveUtils.parse_number_list(str(color_str))
	if color_list and color_list.size() > 0:
		var icon: Texture = get_color_preview_icon(color_list[0])
		if icon:
			return icon

	var img: Image = Image.new()
	img.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.white)
	var tex: ImageTexture = ImageTexture.new()
	tex.create_from_image(img)
	return tex

func _on_SlotsTree_item_edited() -> void:
	if _is_loading_settings: return

	var tree: Tree = _slots_tree
	var item: TreeItem = tree.get_edited()
	if not item: return

	var idx: int = item.get_metadata(0)
	if idx < 0 or idx >= design_color_slots.size(): return

	var col: int = tree.get_selected_column()

	design_color_slots[idx].color = item.get_text(1)
	design_color_slots[idx].outline_color = item.get_text(2)
	design_color_slots[idx].texture = item.get_text(3)
	design_color_slots[idx].outline_type = int(item.get_range(4))
	design_color_slots[idx].fuzz = int(item.get_range(5))
	design_color_slots[idx].group = int(item.get_range(6))
	design_color_slots[idx].anchored = item.is_checked(7)
	design_color_slots[idx].scale = int(item.get_range(8))

	if col == 1:
		var new_icon: Texture = _create_color_icon(design_color_slots[idx].color)
		item.set_icon(0, new_icon)
		if new_icon:
			var img_data: Image = new_icon.get_data()
			if img_data != null:
				img_data.lock()
				design_color_slots[idx].display_color = img_data.get_pixel(0, 0)
				img_data.unlock()
				item.set_icon(0, new_icon)

	save_settings()
	call_deferred("_on_palette_changed")

func _on_SlotsTree_cell_selected() -> void:
	var tree: Tree = _slots_tree
	var item: TreeItem = tree.get_selected()
	if not item: return

	var idx: int = item.get_metadata(0)
	var col: int = tree.get_selected_column()

	var canvas: Control = _design_canvas
	if canvas:
		canvas.current_color_slot = idx + 1

func _on_slot_display_color_changed(color: Color, idx: int, item: TreeItem) -> void:
	if idx >= 0 and idx < design_color_slots.size():
		design_color_slots[idx].display_color = color
		item.set_icon(0, _create_color_icon(color))
		_design_canvas.update()
		save_settings()

func _on_AddSlotButton_pressed() -> void:
	print("[STATUS] PaintballSettings: adding new color slot")
	var new_slot: Dictionary = {
		"color": "255",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"scale": 100,
		"display_color": Color(randf(), randf(), randf())
	}
	design_color_slots.append(new_slot)
	_refresh_slot_buttons()
	save_settings()

func _on_RemoveSlotButton_pressed() -> void:
	var tree: Tree = _slots_tree
	var item: TreeItem = tree.get_selected()
	if not item: return

	var idx: int = item.get_metadata(0)
	if design_color_slots.size() <= 1:
		print("[WARNING] PaintballSettings: cannot remove slot, minimum of 1 slot required")
		return

	print("[STATUS] PaintballSettings: removing color slot index %d" % idx)
	design_color_slots.remove(idx)

	var canvas: Control = _design_canvas
	var to_remove: Array = []
	for i in range(canvas.design_paintballs.size()):
		var pb: Dictionary = canvas.design_paintballs[i]
		if pb.color_slot == idx + 1:
			to_remove.append(i)
		elif pb.color_slot > idx + 1:
			pb.color_slot -= 1

	to_remove.invert()
	for i in to_remove:
		_design_canvas.design_paintballs.remove(i)

	_refresh_slot_buttons()
	_design_canvas.update()
	save_settings()

func _on_setting_changed(_arg = null) -> void:
	if _is_loading_settings:
		return

	save_settings()

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("[WARNING] PaintballSettings: error loading existing settings config for save: ", err)
		return

	config.set_value("PaintballProperties", "diameter_min", _diameter_min.value)
	config.set_value("PaintballProperties", "diameter_max", _diameter_max.value)
	config.set_value("PaintballProperties", "tapered", _tapered.pressed)
	config.set_value("PaintballProperties", "pixel_mode", _pixel_mode.pressed)
	
	if _color: config.set_value("PaintballProperties", "color", _color.text)
	if _outline_color: config.set_value("PaintballProperties", "outline_color", _outline_color.text)
	
	config.set_value("PaintballProperties", "outline_type_min", _outline_type_min.value)
	config.set_value("PaintballProperties", "outline_type_max", _outline_type_max.value)
	config.set_value("PaintballProperties", "fuzz_min", _fuzz_min.value)
	config.set_value("PaintballProperties", "fuzz_max", _fuzz_max.value)
	config.set_value("PaintballProperties", "texture", _texture.text if _texture else "")
	config.set_value("PaintballProperties", "group", _group.value)
	config.set_value("PaintballProperties", "anchored", _anchored.pressed)
	config.set_value("PaintballProperties", "target", _target.selected)
	config.set_value("PaintballProperties", "freeline", _freeline_checkbox.pressed)
	config.set_value("PaintballProperties", "spacing", _spacing.value)
	config.set_value("PaintballProperties", "jitter", _jitter.value)
	config.set_value("PaintballProperties", "ordered", _ordered.pressed)
	config.set_value("PaintballProperties", "repeat", _repeat.pressed)
	config.set_value("PaintballProperties", "shuffle", _shuffle.pressed)
	config.set_value("PaintballProperties", "random_walk", _random_walk_checkbox.pressed)
	config.set_value("PaintballProperties", "walk_steps", _walk_steps.value)
	config.set_value("PaintballProperties", "walk_spread", _walk_spread.value)

	config.set_value("DesignMode", "design_paintballs", _design_canvas.design_paintballs)
	config.set_value("DesignMode", "brush_size", _brush_size_slider.value)
	config.set_value("DesignMode", "design_total_diameter", _design_total_diameter.value)
	config.set_value("DesignMode", "design_total_diameter_max", _design_total_diameter_max.value)
	config.set_value("DesignMode", "design_pixel_mode", _design_pixel_mode.pressed)
	config.set_value("DesignMode", "color_slots_v2", design_color_slots)

	config.set_value("DesignMode", "mirror_x", _mirror_x.pressed)
	config.set_value("DesignMode", "mirror_y", _mirror_y.pressed)
	config.set_value("DesignMode", "canvas_eraser", _canvas_eraser.pressed)
	config.set_value("DesignMode", "design_jitter", _design_jitter.value)
	config.set_value("DesignMode", "rotate_jitter", _rotate_jitter.value)
	config.set_value("DesignMode", "rotate_fixed", _rotate_fixed.pressed)
	config.set_value("DesignMode", "spread_jitter", _spread_jitter.value)

	var save_err: int = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("[ERROR] PaintballSettings: failed to save config to %s (Error: %s)" % [SETTINGS_PATH, save_err])

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		print("[WARNING] PaintballSettings: could not load config from %s, using defaults (Error: %d)" % [SETTINGS_PATH, err])
		return

	print("[STATUS] PaintballSettings: loading settings configuration")
	_is_loading_settings = true

	_diameter_min.value = config.get_value("PaintballProperties", "diameter_min", 10.0)
	_diameter_max.value = config.get_value("PaintballProperties", "diameter_max", 20.0)
	_tapered.pressed = config.get_value("PaintballProperties", "tapered", false)
	_pixel_mode.pressed = config.get_value("PaintballProperties", "pixel_mode", false)
	
	if _color: _color.text = config.get_value("PaintballProperties", "color", "")
	if _outline_color: _outline_color.text = config.get_value("PaintballProperties", "outline_color", "244")
	
	_outline_type_min.value = config.get_value("PaintballProperties", "outline_type_min", -1.0)
	_outline_type_max.value = config.get_value("PaintballProperties", "outline_type_max", -1.0)
	_fuzz_min.value = config.get_value("PaintballProperties", "fuzz_min", 0.0)
	_fuzz_max.value = config.get_value("PaintballProperties", "fuzz_max", 0.0)
	if _texture: _texture.text = config.get_value("PaintballProperties", "texture", "0")
	_group.value = config.get_value("PaintballProperties", "group", 0.0)
	_anchored.pressed = config.get_value("PaintballProperties", "anchored", true)
	_target.selected = config.get_value("PaintballProperties", "target", 0)
	_freeline_checkbox.pressed = config.get_value("PaintballProperties", "freeline", false)
	_spacing.value = config.get_value("PaintballProperties", "spacing", 5.0)
	_jitter.value = config.get_value("PaintballProperties", "jitter", 0.0)
	_ordered.pressed = config.get_value("PaintballProperties", "ordered", false)
	_repeat.pressed = config.get_value("PaintballProperties", "repeat", false)
	_shuffle.pressed = config.get_value("PaintballProperties", "shuffle", false)
	_random_walk_checkbox.pressed = config.get_value("PaintballProperties", "random_walk", false)
	_walk_steps.value = config.get_value("PaintballProperties", "walk_steps", 3.0)
	_walk_spread.value = config.get_value("PaintballProperties", "walk_spread", 5.0)

	var loaded_paintballs: Array = config.get_value("DesignMode", "design_paintballs", [])
	if loaded_paintballs.size() > 0:
		_design_canvas.design_paintballs = loaded_paintballs
		_design_canvas.update()
		_design_canvas.emit_signal("design_changed")

	_brush_size_slider.value = config.get_value("DesignMode", "brush_size", 30.0)
	_design_total_diameter.value = config.get_value("DesignMode", "design_total_diameter", 20.0)
	_design_total_diameter_max.value = config.get_value("DesignMode", "design_total_diameter_max", 30.0)
	_design_pixel_mode.pressed = config.get_value("DesignMode", "design_pixel_mode", false)
	_design_canvas.brush_size = _brush_size_slider.value
	_brush_size_label.text = "Brush Size (" + str(_brush_size_slider.value) + "%)"
	_brush_space_label.text = "Brush Spacing (" + str(_brush_space_slider.value) + "%)"


	var loaded_slots_v2: Array = config.get_value("DesignMode", "color_slots_v2", [])
	if loaded_slots_v2.size() > 0:
		design_color_slots = loaded_slots_v2
	else:
		var loaded_slots: Array = config.get_value("DesignMode", "color_slots", [])
		if loaded_slots.size() == 4:
			for i in range(4):
				var old_slot: Dictionary = loaded_slots[i]
				design_color_slots[i].color = old_slot.color
				design_color_slots[i].outline_color = old_slot.outline_color
				design_color_slots[i].texture = old_slot.texture
				design_color_slots[i].outline_type = old_slot.outline_type

	_mirror_x.pressed = config.get_value("DesignMode", "mirror_x", false)
	_mirror_y.pressed = config.get_value("DesignMode", "mirror_y", false)
	_canvas_eraser.pressed = config.get_value("DesignMode", "canvas_eraser", false)
	_design_jitter.value = config.get_value("DesignMode", "design_jitter", 0.0)
	_rotate_jitter.value = config.get_value("DesignMode", "rotate_jitter", 0.0)
	_rotate_fixed.pressed = config.get_value("DesignMode", "rotate_fixed", false)
	_spread_jitter.value = config.get_value("DesignMode", "spread_jitter", 0.0)

	_on_design_tool_toggled(null)

	_refresh_slot_buttons()
	_is_loading_settings = false
	_on_palette_changed()
	_refresh_all_previews()

func _on_reset_defaults_pressed() -> void:
	print("[STATUS] PaintballSettings: resetting to default settings")
	_is_loading_settings = true

	_diameter_min.value = 10.0
	_diameter_max.value = 20.0
	_tapered.pressed = false
	_pixel_mode.pressed = false
	
	if _color: _color.text = ""
	if _outline_color: _outline_color.text = "244"
	
	_outline_type_min.value = -1.0
	_outline_type_max.value = -1.0
	_fuzz_min.value = 0.0
	_fuzz_max.value = 0.0
	if _texture: _texture.text = "0"
	_group.value = 0.0
	_anchored.pressed = true
	_target.selected = 0
	_freeline_checkbox.pressed = false
	_spacing.value = 5.0
	_jitter.value = 0.0
	_ordered.pressed = false
	_repeat.pressed = false
	_shuffle.pressed = false
	_eraser_checkbox.pressed = false

	_random_walk_checkbox.pressed = false
	_walk_steps.value = 3.0
	_walk_spread.value = 5.0

	_mirror_x.pressed = false
	_mirror_y.pressed = false
	_canvas_eraser.pressed = false
	_design_jitter.value = 0.0
	_rotate_fixed.pressed = false

	_design_canvas.clear()
	_brush_size_slider.value = 30.0
	_design_total_diameter.value = 20.0
	_design_total_diameter_max.value = 30.0
	_design_pixel_mode.pressed = false

	design_color_slots = [
		{
			"color": "105",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"display_color": Color(1, 1, 0)
		},
		{
			"color": "95",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"display_color": Color(1, 0, 0)
		},
		{
			"color": "145",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"display_color": Color(0, 1, 0)
		},
		{
			"color": "155",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"display_color": Color(0, 0, 1)
		}
	]
	_refresh_slot_buttons()
	_on_design_tool_toggled(null)

	_is_loading_settings = false
	save_settings()
	_on_palette_changed()
	_refresh_all_previews()
