extends Button
## ExportButtonOBJ.gd
## Exports currently loaded petz and animation frame as a 3D model Wavefront OBJ file
## - Collects all visible, non-omitted Ball.gd nodes
## - Writes each ball as a UV-sphere mesh (vertices + faces)
## - Writes each Line as a tapered cylinder mesh
## - Writes each Polygon as a quad

func _ready() -> void:
	connect("pressed", self, "_on_pressed")

func _on_pressed() -> void:
	var pet_node: Node = get_tree().root.get_node("Root/PetRoot/Node")
	var anim_idx: int = pet_node.current_animation
	var start_idx: int = pet_node.bhd.animation_ranges[anim_idx].actual_start
	var text_edit: Control = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	var filename: String = text_edit.filepath.get_file().get_basename() + "_" + str(anim_idx) + "_" + str(start_idx) + ".obj"
	var content_bytes: PoolByteArray = _export_current_model()

	_save_file_as(filename, content_bytes)

func _export_current_model() -> PoolByteArray:
	var obj_lines: PoolStringArray = PoolStringArray()

	obj_lines.append("# Exported Petz Model")
	obj_lines.append("o Petz\n")

	var dog: Node = get_tree().root.get_node("Root/PetRoot/Node")
	var pixel_world_size: float = dog.pixel_world_size
	var lines: Array = dog.lnz.lines
	var polys: Array = dog.lnz.polygons

	var all_ball_nodes: Array = []
	var by_no: Dictionary = {}
	for b in dog.ball_map.values():
		if "ball_no" in b and "ball_size" in b and b.has_method("is_visible_in_tree"):
			if not b.omitted and b.visible_override:
				all_ball_nodes.append(b)
				by_no[b.ball_no] = b

	var vertex_offset: int = 1
	var S_SEG: int = 12 
	var S_RNG: int = 8  

	# BALLZ
	for bd in all_ball_nodes:
		var center: Vector3 = bd.global_transform.origin
		var radius: float = bd.ball_size * pixel_world_size * 0.5

		# Vertices
		for i in range(S_RNG + 1):
			var phi: float = PI * i / S_RNG
			var sin_phi: float = sin(phi)
			var cos_phi: float = cos(phi)
			for j in range(S_SEG):
				var theta: float = TAU * j / S_SEG
				var x: float = radius * sin_phi * cos(theta)
				var y: float = radius * cos_phi
				var z: float = radius * sin_phi * sin(theta)
				obj_lines.append("v %f %f %f" % [center.x + x, center.y + y, center.z + z])
		
		# Faces
		for i in range(S_RNG):
			for j in range(S_SEG):
				var a: int = vertex_offset + i * S_SEG + j
				var b: int = vertex_offset + (i + 1) * S_SEG + j
				var c: int = vertex_offset + (i + 1) * S_SEG + (j + 1) % S_SEG
				var d: int = vertex_offset + i * S_SEG + (j + 1) % S_SEG
				obj_lines.append("f %d %d %d" % [a, b, c])
				obj_lines.append("f %d %d %d" % [a, c, d])
		
		vertex_offset += (S_RNG + 1) * S_SEG
	
	# LINEZ 
	for ld in lines:
		var b1: Node = by_no.get(ld.start)
		var b2: Node = by_no.get(ld.end)
		if b1 == null or b2 == null: continue

		var p1: Vector3 = b1.global_transform.origin
		var p2: Vector3 = b2.global_transform.origin
		
		var diff: Vector3 = p2 - p1 
		var length: float = diff.length() 
		if length < 0.0001: continue
		var dir: Vector3 = diff.normalized() 
		
		var r1: float = max(b1.ball_size * (ld.s_thick / 100.0) * pixel_world_size * 0.5, 0.0)
		var r2: float = max(b2.ball_size * (ld.e_thick / 100.0) * pixel_world_size * 0.5, 0.0)

		var v_up: Vector3 = Vector3(0, 1, 0)
		if abs(v_up.dot(dir)) > 0.9:
			v_up = Vector3(1, 0, 0)
		var v_right: Vector3 = v_up.cross(dir).normalized()
		var v_true_up: Vector3 = dir.cross(v_right).normalized()
		
		var segments: int = 6
		
		for i in range(segments):
			var angle: float = TAU * i / segments
			var ring_offset: Vector3 = (v_right * cos(angle) + v_true_up * sin(angle))
			
			var v1: Vector3 = p1 + ring_offset * r1
			var v2: Vector3 = p2 + ring_offset * r2
			
			obj_lines.append("v %f %f %f" % [v1.x, v1.y, v1.z])
			obj_lines.append("v %f %f %f" % [v2.x, v2.y, v2.z])
		
		for i in range(segments):
			var i_next: int = (i + 1) % segments
			var a: int = vertex_offset + i * 2
			var b: int = vertex_offset + i * 2 + 1
			var c: int = vertex_offset + i_next * 2 + 1
			var d: int = vertex_offset + i_next * 2
			
			obj_lines.append("f %d %d %d" % [a, b, c])
			obj_lines.append("f %d %d %d" % [a, c, d])
		
		vertex_offset += segments * 2

	# POLYGONZ
	for pd in polys:
		var pts: Array = []
		for key in ["ball1", "ball2", "ball3", "ball4"]:
			var bd: Node = by_no.get(pd[key])
			if bd:
				var pp: Vector3 = bd.global_transform.origin
				pts.append(pp)
		
		if pts.size() == 4:
			for p in pts:
				obj_lines.append("v %f %f %f" % [p.x, p.y, p.z])
			obj_lines.append("f %d %d %d" % [vertex_offset, vertex_offset + 1, vertex_offset + 2])
			obj_lines.append("f %d %d %d" % [vertex_offset, vertex_offset + 2, vertex_offset + 3])
			vertex_offset += 4

	return obj_lines.join("\n").to_utf8()

func _save_file_as(filename: String, content_bytes: PoolByteArray) -> void:
	if OS.has_feature("HTML5"):
		var escaped_filename: String = filename.replace("'", "\\'")
		var base64_content: String = Marshalls.raw_to_base64(content_bytes)

		var mime_type: String = "application/octet-stream"

		var js_code: String = """
		var element = document.createElement('a');
		element.setAttribute('href', 'data:""" + mime_type + """;base64,' + '""" + base64_content + """');
		element.setAttribute('download', '""" + escaped_filename + """');

		element.style.display = 'none';
		document.body.appendChild(element);
		element.click();
		document.body.removeChild(element);
		"""
		JavaScript.eval(js_code)

	else:
		var save_dialog: FileDialog = FileDialog.new()

		save_dialog.connect("file_selected", self, "_on_SaveDialog_file_selected", [content_bytes])

		save_dialog.add_filter("*.obj ; Wavefront OBJ")
		save_dialog.mode = FileDialog.MODE_SAVE_FILE
		save_dialog.access = FileDialog.ACCESS_FILESYSTEM
		save_dialog.window_title = "Save File As"
		save_dialog.current_file = filename

		save_dialog.rect_min_size = Vector2(400, 400)

		add_child(save_dialog)
		save_dialog.popup_centered()

func _on_SaveDialog_file_selected(path: String, content_bytes: PoolByteArray) -> void:
	var file: File = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_buffer(content_bytes)
		file.close()
		print("File saved successfully to: " + path)
	else:
		print("Error saving file to: " + path)
		
	content_bytes.resize(0)

	if is_instance_valid(self):
		for child in get_children():
			if child is FileDialog and child.window_title == "Save File As":
				child.queue_free()
				return

# pose quick ref
#catz
#214 is helens
#306 is showpose
#309 is hanging
#177 is cute paw

# after loading exported OBJ into Blender, a good order of operations for a nice mesh is...
# separate body parts especially eyes
# select all verts in edit mode (a) > mesh > merge (m) > merge by distance
# subdivision modifier x2
# apply with crtl + a > visual geo to mesh
# join objects to one
# remesh with very low voxel 0.0015 m
# remesh better
