extends DraggablePanel
## StructSettings.gd
## Manages Struct Mode panel UI: presets, vertex/edge data, base assignment, bake logic

signal apply_struct_strings(addballz_str, linez_str)
signal affected_list_changed(ball_ids)

var vertices: Array = []
var edges: Array = []
var next_vertex_id: int = 1
var next_edge_id: int = 1

var presets: Array = []
var active_preset_idx: int = 0

var base_mode: int = 1
var single_base_spin: int = 0
var proximity_range: float = 50.0
var base_ball_range: String = ""

var pet_view: Control = null

var presets_tree: Tree = null
var add_preset_button: Button = null
var remove_preset_button: Button = null
var base_mode_option: OptionButton = null
var single_base_spin_box: SpinBox = null
var proximity_range_spin_box: SpinBox = null
var base_ball_range_edit: LineEdit = null
var bake_button: Button = null
var vertex_count_label: Label = null

const PRESET_FIELDS: Array = ["name", "color", "outline_color", "z_add", "fuzz", "group", "outline", "size", "body_area", "add_group", "texture", "base"]
const PRESET_DEFAULTS: Dictionary = {
	"name": "Preset 1",
	"color": 10,
	"outline_color": 10,
	"z_add": 0,
	"fuzz": 0,
	"group": 0,
	"outline": -1,
	"size": 10,
	"body_area": 1,
	"add_group": 0,
	"texture": -1,
	"base": 0
}

func _ready() -> void:
	restore_position(_default_position())
	
	presets_tree = find_node("PresetsTree")
	add_preset_button = find_node("AddPresetButton")
	remove_preset_button = find_node("RemovePresetButton")
	base_mode_option = find_node("BaseModeOption")
	single_base_spin_box = find_node("SingleBaseSpinBox")
	proximity_range_spin_box = find_node("ProximityRangeSpinBox")
	base_ball_range_edit = find_node("AffectedBallzEdit")
	bake_button = find_node("BakeButton")
	vertex_count_label = find_node("VertexCountLabel")
	
	presets_tree.connect("item_edited", self, "_on_tree_item_edited")
	add_preset_button.connect("pressed", self, "_on_add_preset_pressed")
	remove_preset_button.connect("pressed", self, "_on_remove_preset_pressed")
	base_mode_option.connect("item_selected", self, "_on_base_mode_selected")
	single_base_spin_box.connect("value_changed", self, "_on_single_base_changed")
	proximity_range_spin_box.connect("value_changed", self, "_on_proximity_range_changed")
	base_ball_range_edit.connect("text_changed", self, "_on_base_ball_range_changed")
	bake_button.connect("pressed", self, "_on_bake_button_pressed")
	
	base_mode_option.add_item("Single Base")
	base_mode_option.add_item("Proximity Base")
	base_mode_option.add_item("Per-Preset Base")
	base_mode_option.selected = base_mode
	
	_update_base_mode_ui()
	_add_default_preset()
	_update_tree()
	_update_vertex_count()


func _add_default_preset() -> void:
	var p: Dictionary = PRESET_DEFAULTS.duplicate()
	p["name"] = "Preset " + str(presets.size() + 1)
	presets.append(p)
	active_preset_idx = presets.size() - 1


func _update_tree() -> void:
	if not is_instance_valid(presets_tree):
		return
	presets_tree.clear()
	var root = presets_tree.create_item()
	for i in range(presets.size()):
		var p = presets[i]
		var name_item = presets_tree.create_item(root)
		name_item.set_editable(0, true)
		name_item.set_text(0, "name")
		name_item.set_text(1, p.get("name", "Preset"))
		name_item.set_metadata(0, {"preset_idx": i, "field": "name"})
		for field in PRESET_FIELDS:
			if field == "name":
				continue
			var item = presets_tree.create_item(root)
			item.set_editable(0, true)
			item.set_text(0, field)
			item.set_text(1, str(p.get(field, 0)))
			item.set_metadata(0, {"preset_idx": i, "field": field})
	_update_tree_selection_visual()


func _update_tree_selection_visual() -> void:
	var root = presets_tree.get_root()
	if not is_instance_valid(root):
		return
	var child = root.get_children()
	while is_instance_valid(child):
		if child.get_metadata(0).get("preset_idx", -1) == active_preset_idx:
			child.set_custom_color(0, Color(0, 0.8, 0, 1))
		else:
			child.set_custom_color(0, Color(1, 1, 1, 1))
		child = child.get_next()


func _on_tree_item_edited() -> void:
	var item = presets_tree.get_selected()
	if not is_instance_valid(item):
		return
	var meta = item.get_metadata(0)
	if not meta:
		return
	var preset_idx = meta.get("preset_idx", -1)
	var field = meta.get("field", "")
	if preset_idx < 0 or preset_idx >= presets.size():
		return
	var val_text = item.get_text(1)
	if field == "name":
		presets[preset_idx][field] = val_text
	else:
		presets[preset_idx][field] = val_text.to_int()
	_update_tree_selection_visual()


func _on_add_preset_pressed() -> void:
	var p: Dictionary = PRESET_DEFAULTS.duplicate()
	p["name"] = "Preset " + str(presets.size() + 1)
	presets.append(p)
	active_preset_idx = presets.size() - 1
	_update_tree()


func _on_remove_preset_pressed() -> void:
	if presets.size() <= 1:
		return
	var root = presets_tree.get_root()
	if not is_instance_valid(root):
		return
	var selected = presets_tree.get_selected()
	if not is_instance_valid(selected):
		return
	var meta = selected.get_metadata(0)
	if not meta:
		return
	var preset_idx = meta.get("preset_idx", -1)
	if preset_idx < 0:
		return
	presets.erase(presets[preset_idx])
	if active_preset_idx >= presets.size():
		active_preset_idx = presets.size() - 1
	_update_tree()


func _on_base_mode_selected(idx: int) -> void:
	base_mode = idx
	base_mode_option.selected = idx
	_update_base_mode_ui()


func _on_single_base_changed(value: float) -> void:
	single_base_spin = int(value)


func _on_proximity_range_changed(value: float) -> void:
	proximity_range = value


func _on_base_ball_range_changed(text: String) -> void:
	base_ball_range = text


func _update_base_mode_ui() -> void:
	var root = presets_tree.get_root()
	if is_instance_valid(single_base_spin_box):
		single_base_spin_box.visible = (base_mode == 0)
	if is_instance_valid(proximity_range_spin_box):
		proximity_range_spin_box.visible = (base_mode == 1)


func get_base_for_vertex(vertex: Dictionary, pet_node: Node) -> int:
	match base_mode:
		0:
			return single_base_spin
		1:
			var max_dist = proximity_range
			var min_dist = 10000.0
			var best_base = 0
			var allowed_ids: Array = []
			if not base_ball_range.strip_edges().empty():
				allowed_ids = LnzLiveUtils.parse_number_list(base_ball_range)
			var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
			for b in all_balls:
				if not "ball_no" in b:
					continue
				if allowed_ids.size() > 0 and not (b.ball_no in allowed_ids):
					continue
				var dist = b.global_transform.origin.distance_to(vertex.pos)
				if dist < max_dist and dist < min_dist:
					min_dist = dist
					best_base = b.ball_no
			return best_base
		2:
			var preset = presets[vertex.get("preset_id", 0)]
			return preset.get("base", 0)
	return 0


func get_preset_color(preset_id: int) -> Color:
	var color_idx: int = presets[preset_id].get("color", 10)
	var h = fmod((color_idx / 10) * 0.137, 1.0)
	return Color.from_hsv(h, 0.8, 0.9)


func _find_visual_ball_by_no(ball_no: int) -> Node:
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for b in all_balls:
		if "ball_no" in b and b.ball_no == ball_no:
			return b
	return null


func _on_bake_button_pressed() -> void:
	if vertices.size() == 0:
		return
	var start_id = KeyBallsData.max_base_ball_num
	if pet_view and pet_view.lnz and pet_view.lnz.addballs.size() > 0:
		var keys = pet_view.lnz.addballs.keys()
		start_id = keys.max() + 1
	var vertex_to_addball_id = {}
	var addball_lines = PoolStringArray()
	var line_lines = PoolStringArray()
	for i in range(vertices.size()):
		var v = vertices[i]
		var base_id = get_base_for_vertex(v, pet_view)
		if base_id == 0:
			print("[WARNING] StructMode: Vertex " + str(i) + " has no valid base. Skipping.")
			continue
		var base_ball = _find_visual_ball_by_no(base_id)
		if not is_instance_valid(base_ball):
			print("[WARNING] StructMode: Visual ball " + str(base_id) + " not found. Skipping.")
			continue
		var world_rel_pos = v.pos - base_ball.global_transform.origin
		var local_rel_pos = base_ball.global_transform.basis.inverse().xform(world_rel_pos)
		var lnz_delta = LnzLiveUtils.world_to_lnz_delta(
			local_rel_pos,
			pet_view.pixel_world_size,
			pet_view.lnz.scales.x
		)
		var body_area = 1
		if KeyBallsData.bodyarea_map.has(base_id):
			body_area = KeyBallsData.bodyarea_map[base_id]
		var p = presets[v.get("preset_id", 0)]
		var line_str = "%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d" % [
			base_id,
			lnz_delta.x, lnz_delta.y, lnz_delta.z,
			p.get("color", -1),
			p.get("outline_color", 0),
			p.get("z_add", 0),
			p.get("fuzz", 0),
			p.get("group", 0),
			p.get("outline", -1),
			p.get("size", 10),
			body_area,
			p.get("add_group", 0),
			p.get("texture", -1)
		]
		addball_lines.append(line_str)
		vertex_to_addball_id[i] = start_id
		start_id += 1
	var line_mode_settings = get_tree().root.find_node("LineModeSettings", true, false)
	for e in edges:
		var from_idx = int(e.x)
		var to_idx = int(e.y)
		if not vertex_to_addball_id.has(from_idx) or not vertex_to_addball_id.has(to_idx):
			continue
		var id1 = vertex_to_addball_id[from_idx]
		var id2 = vertex_to_addball_id[to_idx]
		var l_fuzz = 0
		var l_color = 10
		var l_outline_color_left = -1
		var l_outline_color_right = -1
		var l_start_thickness = 10
		var l_end_thickness = 10
		var l_outline = -1
		var l_draw_order = -1
		if is_instance_valid(line_mode_settings):
			var props = line_mode_settings.get_properties()
			if props.get("apply_fuzz", false):
				l_fuzz = props.get("fuzz", 0)
			if props.get("apply_color", false):
				l_color = props.get("color", 10)
			if props.get("apply_left_outline", false):
				l_outline_color_left = props.get("left_outline_color", -1)
			if props.get("apply_right_outline", false):
				l_outline_color_right = props.get("right_outline_color", -1)
			if props.get("apply_start_thickness", false):
				l_start_thickness = props.get("start_thickness", 10)
			if props.get("apply_end_thickness", false):
				l_end_thickness = props.get("end_thickness", 10)
			if props.get("apply_outline_type", false):
				l_outline = props.get("outline_type", -1)
			if props.get("apply_draw_order", false):
				l_draw_order = props.get("draw_order", -1)
		var line_str = "%d, %d, %d, %d, %d, %d, %d, %d, %d, %d" % [
			id1, id2, l_fuzz, l_color,
			l_outline_color_left, l_outline_color_right,
			l_start_thickness, l_end_thickness, l_outline, l_draw_order
		]
		line_lines.append(line_str)
	var addballz_str = addball_lines.join("\n")
	var linez_str = line_lines.join("\n")
	emit_signal("apply_struct_strings", addballz_str, linez_str)
	vertices.clear()
	edges.clear()
	_update_vertex_count()
	if pet_view and pet_view.has_method("_update_struct_visuals"):
		pet_view._update_struct_visuals()


func _update_vertex_count() -> void:
	if is_instance_valid(vertex_count_label):
		vertex_count_label.text = "Vertices: " + str(vertices.size()) + " | Edges: " + str(edges.size())
		bake_button.disabled = (vertices.size() == 0)


func add_affected_ball_ids(ids: Array) -> void:
	var current_text = base_ball_range_edit.text.strip_edges()
	var existing_ids: Array = []
	if current_text != "":
		existing_ids = LnzLiveUtils.parse_number_list(current_text)
	for id in ids:
		if not (id in existing_ids):
			existing_ids.append(id)
	var str_ids = PoolStringArray()
	for id in existing_ids:
		str_ids.append(str(id))
	base_ball_range_edit.text = str_ids.join(", ")
	if is_instance_valid(base_ball_range_edit):
		base_ball_range_edit.caret_position = base_ball_range_edit.text.length()
	emit_signal("affected_list_changed", existing_ids)
