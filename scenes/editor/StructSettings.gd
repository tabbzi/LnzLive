extends DraggablePanel
## StructSettings.gd
## Manages Struct Mode panel UI: presets, vertex/edge data, base assignment, bake logic

signal apply_struct_strings(addballz_str, linez_str, polygonz_str)
signal affected_list_changed(ball_ids)

var vertices: Array = []
var edges: Array = []
var next_vertex_id: int = 1
var next_edge_id: int = 1
var next_group_id: int = 1
var active_group_id: int = 0

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

var shape_option: OptionButton = null
var segments_spin_box: SpinBox = null
var segments_spin_edit: LineEdit = null
var taper_spin_box: SpinBox = null
var hollow_check_box: CheckBox = null
var symmetric_check_box: CheckBox = null
var radius_spin_box: SpinBox = null
var height_spin_box: SpinBox = null
var bake_primitive_button: Button = null
var primitive_vertex_count_label: Label = null

var primitive_segments: int = 16
var primitive_taper: float = 1.0
var primitive_is_hollow: bool = true
var primitive_is_symmetric: bool = false
var primitive_radius: float = 1.0
var primitive_height: float = 1.0
var primitive_shape: int = 0

var preview_verts: Array = []
var preview_edges: Array = []
var preview_faces: Array = []

const PRESET_FIELDS: Array = ["name", "color", "outline_color", "speckle", "fuzz", "group", "outline", "size", "body_area", "add_group", "texture", "base"]
const PRESET_DEFAULTS: Dictionary = {
	"name": "Preset 1",
	"color": 10,
	"outline_color": 10,
	"speckle": 0,
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
	presets_tree.columns = 2
	presets_tree.hide_root = true
	presets_tree.set_column_titles_visible(true)
	presets_tree.set_column_title(0, "Property")
	presets_tree.set_column_title(1, "Value")
	
	var lbl = find_node("PresetsLabel")
	if is_instance_valid(lbl) and lbl.has_font("font"):
		presets_tree.add_font_override("font", lbl.get_font("font"))
		presets_tree.add_font_override("title_button_font", lbl.get_font("font"))
	
	add_preset_button = find_node("AddPresetButton")
	remove_preset_button = find_node("RemovePresetButton")
	base_mode_option = find_node("BaseModeOption")
	single_base_spin_box = find_node("SingleBaseSpinBox")
	proximity_range_spin_box = find_node("ProximityRangeSpinBox")
	base_ball_range_edit = find_node("AffectedBallzEdit")
	bake_button = find_node("BakeButton")
	vertex_count_label = find_node("VertexCountLabel")
	
	if is_instance_valid(base_mode_option) and base_mode_option.get_item_count() == 0:
		base_mode_option.add_item("Single Base Ball")
		base_mode_option.add_item("Closest Base Ball (Proximity)")
		base_mode_option.add_item("Per-Preset Base Ball")
		base_mode_option.selected = base_mode
	
	# Primitives controls
	shape_option = find_node("ShapeOption")
	segments_spin_box = find_node("SegmentsSpinBox")
	segments_spin_edit = find_node("SegmentsSpinEdit")
	taper_spin_box = find_node("TaperSpinBox")
	hollow_check_box = find_node("HollowCheckBox")
	symmetric_check_box = find_node("SymmetricCheckBox")
	radius_spin_box = find_node("RadiusSpinBox")
	height_spin_box = find_node("HeightSpinBox")
	bake_primitive_button = find_node("BakePrimitiveButton")
	primitive_vertex_count_label = find_node("PrimitiveVertexCountLabel")
	
	if is_instance_valid(shape_option):
		shape_option.add_item("Cube")
		shape_option.add_item("Sphere")
		shape_option.add_item("Cone")
		shape_option.add_item("Ring")
		shape_option.add_item("Plane")
		shape_option.add_item("Star")
	
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
		
		name_item.set_editable(0, false)
		name_item.set_editable(1, true)
		name_item.set_text(0, "Preset Name")
		name_item.set_text(1, p.get("name", "Preset"))
		name_item.set_metadata(0, {"preset_idx": i, "field": "name"})
		
		name_item.set_custom_bg_color(0, Color(0.2, 0.2, 0.2, 1))
		name_item.set_custom_bg_color(1, Color(0.2, 0.2, 0.2, 1))
		
		for field in PRESET_FIELDS:
			if field == "name":
				continue
			var item = presets_tree.create_item(name_item)
			item.set_editable(0, false)
			item.set_editable(1, true)
			item.set_text(0, field)
			item.set_text(1, str(p.get(field, 0)))
			item.set_metadata(0, {"preset_idx": i, "field": field})
	_update_tree_selection_visual()


func _update_tree_selection_visual() -> void:
	var root = presets_tree.get_root()
	if not is_instance_valid(root):
		return
	var preset_item = root.get_children()
	while is_instance_valid(preset_item):
		var meta = preset_item.get_metadata(0)
		var is_active = false
		if meta:
			is_active = (meta.get("preset_idx", -1) == active_preset_idx)
		var color = Color(0, 0.8, 0, 1) if is_active else Color(1, 1, 1, 1)
		preset_item.set_custom_color(0, color)
		preset_item.set_custom_color(1, color)
		var field_item = preset_item.get_children()
		while is_instance_valid(field_item):
			field_item.set_custom_color(0, color)
			field_item.set_custom_color(1, color)
			field_item = field_item.get_next()
		preset_item = preset_item.get_next()

func _on_tree_item_selected() -> void:
	var item = presets_tree.get_selected()
	if not is_instance_valid(item):
		return
	var meta = item.get_metadata(0)
	if meta:
		var idx = meta.get("preset_idx", -1)
		if idx != -1 and idx != active_preset_idx:
			active_preset_idx = idx
			_update_tree_selection_visual()


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
	active_preset_idx = preset_idx
	_update_tree_selection_visual()
	if is_instance_valid(pet_view) and pet_view.has_method("_update_struct_visuals"):
		pet_view._update_struct_visuals()


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
	var ids: Array = []
	if text.strip_edges() != "":
		ids = LnzLiveUtils.parse_number_list(text)
	emit_signal("affected_list_changed", ids)

func _update_base_mode_ui() -> void:
	var root = presets_tree.get_root()
	if is_instance_valid(single_base_spin_box):
		single_base_spin_box.visible = (base_mode == 0)
	if is_instance_valid(proximity_range_spin_box):
		proximity_range_spin_box.visible = (base_mode == 1)


func get_base_for_vertex(vertex: Dictionary) -> int:
	match base_mode:
		0:
			return single_base_spin
		1:
			var px_scale = pet_view.pixel_world_size if is_instance_valid(pet_view) else 0.002
			var max_dist = proximity_range * px_scale * 10.0
			var min_dist = 10000.0
			var best_base = 0
			var allowed_ids: Array = []
			if not base_ball_range.strip_edges().empty():
				allowed_ids = LnzLiveUtils.parse_number_list(base_ball_range)
			var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
			for b in all_balls:
				if not is_instance_valid(b) or not ("ball_no" in b):
					continue
				if allowed_ids.size() > 0 and not (b.ball_no in allowed_ids):
					continue
				var dist = b.global_transform.origin.distance_to(vertex.pos)
				if dist <= max_dist and dist < min_dist:
					min_dist = dist
					best_base = b.ball_no
			# Fallback to closest allowed ball if none within proximity_range
			if best_base == 0:
				for b in all_balls:
					if not is_instance_valid(b) or not ("ball_no" in b):
						continue
					if allowed_ids.size() > 0 and not (b.ball_no in allowed_ids):
						continue
					var dist = b.global_transform.origin.distance_to(vertex.pos)
					if dist < min_dist:
						min_dist = dist
						best_base = b.ball_no
			return max(0, best_base) as int
		2:
			var pid = clamp(vertex.get("preset_id", 0), 0, presets.size() - 1)
			return presets[pid].get("base", 0)
	return 0


func get_preset_color(preset_id: int) -> Color:
	if preset_id < 0 or preset_id >= presets.size():
		preset_id = 0
	var color_idx: int = presets[preset_id].get("color", 10)
	if color_idx == 0:
		return Color(0, 0, 0, 0)
	var h = fmod((color_idx / 10) * 0.137, 1.0)
	return Color.from_hsv(h, 0.8, 0.9)


func _on_bake_button_pressed() -> void:
	if vertices.size() == 0:
		return
	var start_id = KeyBallsData.max_base_ball_num
	if pet_view and pet_view.pet_node and pet_view.pet_node.lnz and pet_view.pet_node.lnz.addballs.size() > 0:
		var keys = pet_view.pet_node.lnz.addballs.keys()
		start_id = keys.max() + 1
	var vertex_to_addball_id = {}
	var addball_lines = PoolStringArray()
	var line_lines = PoolStringArray()
	for i in range(vertices.size()):
		var v = vertices[i]
		var base_id = get_base_for_vertex(v)
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
			pet_view.pet_node.lnz.scales.x
		)
		var body_area = 1
		if KeyBallsData.bodyarea_map.has(base_id):
			body_area = KeyBallsData.bodyarea_map[base_id]
		var p = presets[v.get("preset_id", 0)]
		var gid: int = v.get("group_id", 0)
		var line_str = "%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d" % [
			base_id,
			lnz_delta.x, lnz_delta.y, lnz_delta.z,
			p.get("color", -1),
			p.get("outline_color", 0),
			p.get("speckle", 0),
			p.get("fuzz", 0),
			gid,
			p.get("outline", -1),
			p.get("size", 10),
			body_area,
			p.get("add_group", 0),
			p.get("texture", -1),
			-1
		]
		addball_lines.append(line_str)
		vertex_to_addball_id[i] = start_id
		start_id += 1
	var line_mode_settings = get_tree().root.find_node("LineModeSettings", true, false)
	for e in edges:
		var from_idx = int(e["x"])
		var to_idx = int(e["y"])
		if not vertex_to_addball_id.has(from_idx) or not vertex_to_addball_id.has(to_idx):
			continue
		var id1 = vertex_to_addball_id[from_idx]
		var id2 = vertex_to_addball_id[to_idx]
		var line_str = _format_line_string(id1, id2)
		line_lines.append(line_str)
	var addballz_str = addball_lines.join("\n")
	var linez_str = line_lines.join("\n")
	emit_signal("apply_struct_strings", addballz_str, linez_str, "")
	vertices.clear()
	edges.clear()
	_update_vertex_count()
	if pet_view and pet_view.has_method("_update_struct_visuals"):
		pet_view._update_struct_visuals()


func _update_vertex_count() -> void:
	if is_instance_valid(vertex_count_label):
		vertex_count_label.text = "Vertices: %d | Edges: %d" % [vertices.size(), edges.size()]
		bake_button.disabled = (vertices.size() == 0)


func update_selected_balls_text(ids: Array) -> void:
	var str_ids = PoolStringArray()
	for id in ids:
		str_ids.append(str(id))
	var text_val = str_ids.join(", ")
	base_ball_range = text_val
	if is_instance_valid(base_ball_range_edit):
		base_ball_range_edit.text = text_val

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


### Primitives Mode ###

func _on_primitive_shape_selected(idx: int) -> void:
	primitive_shape = idx
	_update_primitive_shape_label()
	_rebuild_preview()
	_update_primitive_vertex_count()


func _on_primitive_segments_changed(value: float) -> void:
	primitive_segments = max(3, int(value))
	if is_instance_valid(segments_spin_edit):
		segments_spin_edit.value = primitive_segments
	_update_primitive_vertex_count()
	_rebuild_preview()


func _on_primitive_segments_input_changed(new_text: String) -> void:
	var val = new_text.strip_edges().to_int()
	if val > 0:
		primitive_segments = max(3, val)
	if is_instance_valid(segments_spin_box):
		segments_spin_box.value = primitive_segments
	_update_primitive_vertex_count()
	_rebuild_preview()


func _on_primitive_taper_changed(value: float) -> void:
	primitive_taper = clamp(value, 0.01, 1.0)
	_rebuild_preview()


func _on_primitive_hollow_toggled(toggled: bool) -> void:
	primitive_is_hollow = toggled
	_rebuild_preview()


func _on_primitive_symmetric_toggled(toggled: bool) -> void:
	primitive_is_symmetric = toggled
	_rebuild_preview()


func _on_primitive_radius_changed(value: float) -> void:
	primitive_radius = max(0.01, value)
	_rebuild_preview()


func _on_primitive_height_changed(value: float) -> void:
	primitive_height = max(0.01, value)
	_rebuild_preview()


func _update_primitive_shape_label() -> void:
	if not is_instance_valid(shape_option):
		return
	var labels = ["Cube", "Sphere", "Cone", "Ring", "Plane", "Star"]
	if is_instance_valid(primitive_vertex_count_label):
		primitive_vertex_count_label.text = labels[primitive_shape]


func _rebuild_preview() -> void:
	preview_verts.clear()
	preview_edges.clear()
	preview_faces.clear()
	match primitive_shape:
		0: _generate_cube()
		1: _generate_sphere()
		2: _generate_cone()
		3: _generate_ring()
		4: _generate_plane()
		5: _generate_star()
	_update_primitive_vertex_count()


func _update_primitive_vertex_count() -> void:
	if is_instance_valid(primitive_vertex_count_label):
		primitive_vertex_count_label.text = "Verts: %d | Edges: %d | Faces: %d" % [preview_verts.size(), preview_edges.size(), preview_faces.size()]
		bake_primitive_button.disabled = (preview_verts.size() == 0)


func _generate_cube() -> void:
	var r = primitive_radius
	var h = primitive_height / 2.0
	var hw = r / 2.0
	var hh = h / 2.0
	preview_verts = [
		Vector3(-hw, -hh, -hw), Vector3(hw, -hh, -hw),
		Vector3(hw, -hh, hw), Vector3(-hw, -hh, hw),
		Vector3(-hw, hh, -hw), Vector3(hw, hh, -hw),
		Vector3(hw, hh, hw), Vector3(-hw, hh, hw)
	]
	preview_edges = [
		[0,1],[1,2],[2,3],[3,0],
		[4,5],[5,6],[6,7],[7,4],
		[0,4],[1,5],[2,6],[3,7]
	]
	preview_faces = [
		[0,1,2,3], [4,7,6,5],
		[0,4,5,1], [3,2,6,7],
		[1,5,6,2], [0,3,7,4]
	]
	if primitive_is_symmetric:
		_mirror_shape()


func _generate_sphere() -> void:
	var verts = []
	var edges = []
	var faces = []
	var lat_steps = max(3, primitive_segments / 2)
	var lon_steps = max(3, primitive_segments)
	var r = primitive_radius
	verts.append(Vector3(0, r, 0))
	for lat in range(1, lat_steps):
		var phi = PI * lat / lat_steps
		var row_start = verts.size()
		for lon in range(0, lon_steps):
			var theta = 2 * PI * lon / lon_steps
			verts.append(Vector3(r * sin(phi) * cos(theta), r * cos(phi), r * sin(phi) * sin(theta)))
		for i in range(lon_steps - 1):
			edges.append([row_start + i, row_start + i + 1])
		edges.append([row_start + lon_steps - 1, row_start])
		for i in range(lon_steps - 1):
			faces.append([row_start + i, row_start + lon_steps + i, row_start + lon_steps + i + 1, row_start + i + 1])
	verts.append(Vector3(0, -r, 0))
	var south_idx = verts.size() - 1
	var last_row_start = verts.size() - lon_steps - 1
	for i in range(lon_steps):
		edges.append([last_row_start + i, south_idx])
	preview_verts = verts
	preview_edges = edges
	preview_faces = faces
	if primitive_is_symmetric:
		_mirror_shape()


func _generate_cone() -> void:
	var verts = []
	var edges = []
	var faces = []
	var r = primitive_radius / 2.0
	var h = primitive_height / 2.0
	var steps = max(3, primitive_segments)
	verts.append(Vector3(0, -h, 0))
	var bottom_center_idx = 0
	var bottom_ring_start = verts.size()
	for i in range(steps):
		var theta = 2 * PI * i / steps
		verts.append(Vector3(r * cos(theta), -h, r * sin(theta)))
	for i in range(steps - 1):
		edges.append([bottom_ring_start + i, bottom_ring_start + i + 1])
	edges.append([bottom_ring_start + steps - 1, bottom_ring_start])
	var top_r = r * primitive_taper
	if top_r > 0.001:
		var top_ring_start = verts.size()
		for i in range(steps):
			var theta = 2 * PI * i / steps
			verts.append(Vector3(top_r * cos(theta), h, top_r * sin(theta)))
		for i in range(steps - 1):
			edges.append([top_ring_start + i, top_ring_start + i + 1])
		edges.append([top_ring_start + steps - 1, top_ring_start])
		for i in range(steps):
			edges.append([bottom_ring_start + i, top_ring_start + i])
		for i in range(steps - 1):
			faces.append([bottom_ring_start + i, top_ring_start + i, top_ring_start + i + 1, bottom_ring_start + i + 1])
	else:
		verts.append(Vector3(0, h, 0))
		var top_idx = verts.size() - 1
		for i in range(steps):
			edges.append([bottom_ring_start + i, top_idx])
		for i in range(steps - 1):
			faces.append([bottom_center_idx, bottom_ring_start + i, bottom_ring_start + i + 1])
		faces.append([bottom_center_idx, bottom_ring_start + steps - 1, bottom_ring_start])
	if not primitive_is_hollow:
		for i in range(steps):
			edges.append([bottom_center_idx, bottom_ring_start + i])
	preview_verts = verts
	preview_edges = edges
	preview_faces = faces
	if primitive_is_symmetric:
		_mirror_shape()


func _generate_ring() -> void:
	var verts = []
	var edges = []
	var faces = []
	var outer_r = primitive_radius / 2.0
	var tube_r = primitive_radius / 6.0
	var major_steps = max(6, primitive_segments)
	var minor_steps = max(4, primitive_segments / 2)
	for i in range(major_steps):
		var theta = 2 * PI * i / major_steps
		var next_theta = 2 * PI * (i + 1) / major_steps
		var cx = outer_r * cos(theta)
		var cz = outer_r * sin(theta)
		var row_start = verts.size()
		for j in range(minor_steps):
			var phi = 2 * PI * j / minor_steps
			verts.append(Vector3(tube_r * cos(phi) * cos(theta) + cx, tube_r * sin(phi), tube_r * cos(phi) * sin(theta) + cz))
		for j in range(minor_steps - 1):
			edges.append([row_start + j, row_start + j + 1])
		edges.append([row_start + minor_steps - 1, row_start])
		if i < major_steps - 1:
			for j in range(minor_steps):
				edges.append([row_start + j, row_start + minor_steps + j])
			for j in range(minor_steps - 1):
				faces.append([row_start + j, row_start + minor_steps + j, row_start + minor_steps + j + 1, row_start + j + 1])
	preview_verts = verts
	preview_edges = edges
	preview_faces = faces
	if primitive_is_symmetric:
		_mirror_shape()


func _generate_plane() -> void:
	var verts = []
	var edges = []
	var faces = []
	var hw = primitive_radius / 2.0
	var hh = primitive_height / 2.0
	var steps = max(2, primitive_segments)
	for j in range(steps + 1):
		for i in range(steps + 1):
			verts.append(Vector3(-hw + 2.0 * hw * i / steps, 0, -hh + 2.0 * hh * j / steps))
	for j in range(steps + 1):
		for i in range(steps):
			edges.append([j * (steps + 1) + i, j * (steps + 1) + i + 1])
	for i in range(steps + 1):
		for j in range(steps):
			edges.append([j * (steps + 1) + i, (j + 1) * (steps + 1) + i])
	for j in range(steps):
		for i in range(steps):
			faces.append([j * (steps + 1) + i, (j + 1) * (steps + 1) + i, (j + 1) * (steps + 1) + i + 1, j * (steps + 1) + i + 1])
	preview_verts = verts
	preview_edges = edges
	preview_faces = faces
	if primitive_is_symmetric:
		_mirror_shape()


func _generate_star() -> void:
	var verts = []
	var edges = []
	var faces = []
	var points = max(3, primitive_segments / 2)
	var outer_r = primitive_radius / 2.0
	var inner_r = outer_r * 0.4
	var h = primitive_height / 2.0
	var bottom_ring_start = verts.size()
	for i in range(points * 2):
		var theta = PI * i / points - PI / 2.0
		var r = outer_r if i % 2 == 0 else inner_r
		verts.append(Vector3(r * cos(theta), -h, r * sin(theta)))
	var top_ring_start = verts.size()
	var top_outer = outer_r * primitive_taper
	var top_inner = inner_r * primitive_taper
	for i in range(points * 2):
		var theta = PI * i / points - PI / 2.0
		var r = top_outer if i % 2 == 0 else top_inner
		verts.append(Vector3(r * cos(theta), h, r * sin(theta)))
	for i in range(points * 2):
		var next_i = (i + 1) % (points * 2)
		edges.append([bottom_ring_start + i, bottom_ring_start + next_i])
	for i in range(points * 2):
		var next_i = (i + 1) % (points * 2)
		edges.append([top_ring_start + i, top_ring_start + next_i])
	for i in range(points * 2):
		edges.append([bottom_ring_start + i, top_ring_start + i])
		for j in range(points * 2):
			if j == i:
				faces.append([bottom_ring_start + i, top_ring_start + i, top_ring_start + (i + 1) % (points * 2), bottom_ring_start + (i + 1) % (points * 2)])
	preview_verts = verts
	preview_edges = edges
	preview_faces = faces
	if primitive_is_symmetric:
		_mirror_shape()


func _mirror_shape() -> void:
	var mirrored_verts = []
	var mirrored_edges = []
	var mirrored_faces = []
	var offset = preview_verts.size()
	for v in preview_verts:
		mirrored_verts.append(Vector3(-v.x, v.y, -v.z))
	for e in preview_edges:
		mirrored_edges.append([e[0], e[1]])
	for i in range(mirrored_verts.size()):
		mirrored_verts[i] = Vector3(-mirrored_verts[i].x, mirrored_verts[i].y, -mirrored_verts[i].z)
	var mirrored_edge_offset = mirrored_verts.size()
	for e in mirrored_edges:
		mirrored_edges.append([e[0] + mirrored_edge_offset, e[1] + mirrored_edge_offset])
	var mirrored_face_offset = mirrored_verts.size()
	for f in preview_faces:
		var new_face = [f[0] + mirrored_face_offset, f[1] + mirrored_face_offset, f[2] + mirrored_face_offset]
		if f.size() > 3:
			new_face.append(f[3] + mirrored_face_offset)
		mirrored_faces.append(new_face)
	preview_verts = preview_verts + mirrored_verts
	preview_edges = preview_edges + mirrored_edges
	preview_faces = preview_faces + mirrored_faces


func _find_visual_ball_by_no(ball_no: int) -> Node:
	if is_instance_valid(pet_view) and is_instance_valid(pet_view.pet_node) and pet_view.pet_node.ball_map:
		if pet_view.pet_node.ball_map.has(ball_no):
			var b = pet_view.pet_node.ball_map[ball_no]
			if is_instance_valid(b):
				return b
		return null
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for b in all_balls:
		if "ball_no" in b and b.ball_no == ball_no:
			return b
	return null


func _format_line_string(id1: int, id2: int) -> String:
	var line_mode_settings = get_tree().root.find_node("LineModeSettings", true, false)
	var l_fuzz = 0
	var l_color = 10
	var l_outline_color_left = -1
	var l_outline_color_right = -1
	var l_start_thickness = 100
	var l_end_thickness = 100
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
	return "%d, %d, %d, %d, %d, %d, %d, %d, %d, %d" % [
		id1, id2, l_fuzz, l_color,
		l_outline_color_left, l_outline_color_right,
		l_start_thickness, l_end_thickness, l_outline, l_draw_order
	]


### Vertex / Edge / Group Manipulation ###

func delete_vertices(sel_indices: Array) -> void:
	if sel_indices.empty():
		return
	var to_delete: Dictionary = {}
	for idx in sel_indices:
		to_delete[idx] = true
	var old_to_new: Dictionary = {}
	var new_verts: Array = []
	for i in range(vertices.size()):
		if not to_delete.has(i):
			old_to_new[i] = new_verts.size()
			new_verts.append(vertices[i])
	var new_edges: Array = []
	for e in edges:
		var ox: int = int(e["x"])
		var oy: int = int(e["y"])
		if old_to_new.has(ox) and old_to_new.has(oy):
			new_edges.append({"x": old_to_new[ox], "y": old_to_new[oy]})
	vertices = new_verts
	edges = new_edges
	_update_vertex_count()

func delete_edges_between(sel_indices: Array) -> void:
	if sel_indices.empty():
		return
	var sel_set: Dictionary = {}
	for idx in sel_indices:
		sel_set[idx] = true
	var new_edges: Array = []
	for e in edges:
		if sel_set.has(int(e["x"])) and sel_set.has(int(e["y"])):
			continue
		new_edges.append(e)
	edges = new_edges
	_update_vertex_count()

func toggle_edges_for_selection(sel_indices: Array) -> void:
	if sel_indices.size() < 2:
		return
	for i in range(sel_indices.size() - 1):
		var a: int = sel_indices[i]
		var b: int = sel_indices[i + 1]
		if a == b:
			continue
		var found_idx: int = -1
		for ei in range(edges.size()):
			var ex: int = int(edges[ei]["x"])
			var ey: int = int(edges[ei]["y"])
			if (ex == a and ey == b) or (ex == b and ey == a):
				found_idx = ei
				break
		if found_idx != -1 and sel_indices.size() == 2:
			edges.remove(found_idx)
		elif found_idx == -1:
			edges.append({"x": a, "y": b})
	_update_vertex_count()

func assign_active_preset_to_vertices(sel_indices: Array) -> void:
	for idx in sel_indices:
		if idx >= 0 and idx < vertices.size():
			vertices[idx]["preset_id"] = active_preset_idx

func get_group_vertices_for_selection(sel_indices: Array) -> Array:
	var target_groups: Dictionary = {}
	for idx in sel_indices:
		if idx >= 0 and idx < vertices.size():
			target_groups[vertices[idx].get("group_id", 0)] = true
	var result: Array = []
	for i in range(vertices.size()):
		if target_groups.has(vertices[i].get("group_id", 0)):
			result.append(i)
	return result

func scale_vertices(sel_indices: Array, factor: float) -> void:
	if sel_indices.empty():
		return
	var center: Vector3 = Vector3.ZERO
	var count: int = 0
	for idx in sel_indices:
		if idx >= 0 and idx < vertices.size():
			center += vertices[idx].pos
			count += 1
	if count == 0:
		return
	center /= float(count)
	for idx in sel_indices:
		if idx >= 0 and idx < vertices.size():
			vertices[idx].pos = center + (vertices[idx].pos - center) * factor

### Preset Helpers ###

func _on_bake_primitive_pressed() -> void:
	if preview_verts.size() == 0:
		return
	# Merge primitive verts/edges into the struct vertex system
	var new_group = next_group_id
	next_group_id += 1
	var vert_offset = vertices.size()
	for v in preview_verts:
		vertices.append({"pos": v, "preset_id": active_preset_idx, "group_id": new_group})
	active_group_id = new_group
	var edge_offset = preview_verts.size()
	for e in preview_edges:
		edges.append({"x": e[0] + vert_offset, "y": e[1] + vert_offset})
	preview_verts.clear()
	preview_edges.clear()
	preview_faces.clear()
	_update_vertex_count()
	if is_instance_valid(pet_view) and pet_view.has_method("_update_struct_visuals"):
		pet_view._update_struct_visuals()
