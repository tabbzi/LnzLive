extends Node
class_name LnzParser
## lnz_parser.gd
## A data class that parses entries from LNZ data

var r = RegEx.new()
var str_r = RegEx.new()
var variation_r = RegEx.new()

var species = 0
var scales = Vector2(255, 255)
var eyelid_color = 244
var leg_extensions = Vector2(0, 0)
var body_extension = 0
var face_extension = 0
var ear_extension = 0
var head_enlargement = Vector2(100, 0)
var foot_enlargement = Vector2(100, 0)
var moves = []
var balls = {}
var lines = []
var polygons = []
var addballs = {}
var paintballs = {}
var omissions = {}
var project_ball = []
var texture_list = []
var no_texture_rotate = []
var palette = null

var file_path
var raw_data = {}

func _init(file_path):
	if file_path == null:
		return
	
	self.file_path = file_path
	r.compile("[-.\\d]+")
	str_r.compile("[\\S]+")
	variation_r.compile("^#(\\d+)(?:\\.(\\w+))?")
	
	var file = File.new()
	if file.file_exists(file_path):
		file.open(file_path, File.READ)
	else:
		print("File not found: " + file_path)
		return
	
	# Load base data
	get_texture_list(file)
	get_no_texture_rotate(file)
	get_palette(file)
	get_species(file)
	get_eyelid_color(file)
	get_default_scales(file)
	get_leg_extensions(file)
	get_body_extension(file)
	get_face_extension(file)
	get_ear_extension(file)
	get_head_enlargement(file)
	get_feet_enlargement(file)
	get_omissions(file)
	get_lines(file)
	get_polygons(file)
	get_balls(file)
	get_addballs(file)

	# Apply overrides after loading base data
	get_ball_size_override(file)
	get_fuzz_override(file)
	get_add_ball_override(file)
	get_color_info_override(file)
	get_outline_color_override(file)

	# Additional parsing for project balls and moves
	get_project_balls(file)
	parse_paintballs(file)
	parse_moves(file)

	file.close()

func get_next_section(file: File, section_name: String):
	file.seek(0)
	var this_line = ""
	var target = "[" + section_name + "]"
	while !this_line.begins_with(target) and !file.eof_reached():
		this_line = file.get_line()
	if file.eof_reached():
		return false
	return true

func _read_section_lines(file: File, section_name: String) -> Dictionary:
	if not get_next_section(file, section_name):
		return {}

	var data = { "default": [], "variations": {} }
	var current_list = data["default"]

	while true:
		var line = file.get_line().dedent()
		if line.empty() or line.begins_with("[") or file.eof_reached():
			break

		if line.begins_with("#"):
			# Check for variation end sequence
			if line.begins_with("##"):
				current_list = data["default"]
				continue

			var match_res = variation_r.search(line)
			if match_res:
				var code = match_res.get_string(1)
				if match_res.get_string(2):
					code += "." + match_res.get_string(2)
				data["variations"][code] = []
				current_list = data["variations"][code]
				continue
			else:
				# Likely comment
				pass

		if line.begins_with(";"):
			continue

		current_list.append(line)

	raw_data[section_name] = data
	return data

func _parse_lines_to_dicts(lines: Array, keys: Array, use_str_regex: bool = false) -> Array:
	var return_array = []
	var regex = str_r if use_str_regex else r

	for line in lines:
		if use_str_regex:
			var parsed = regex.search_all(line)
			var dict = {}
			var i = 0
			for key in keys:
				if i < parsed.size():
					dict[key] = parsed[i].get_string()
					i += 1
				else:
					dict[key] = ""
			return_array.append(dict)
		else:
			var parsed = regex.search_all(line)
			if parsed.size() == 0:
				continue
			var dict = {}
			for i in range(keys.size()):
				if i < parsed.size():
					dict[keys[i]] = int(parsed[i].get_string())
			return_array.append(dict)
	return return_array

func get_active_lines(section_name: String, state: Dictionary) -> Array:
	if not raw_data.has(section_name):
		return []

	var data = raw_data[section_name]
	var default_lines = data["default"]
	var variation_lines = []
	var variation_found = false

	# Check for explicit section override
	if state.has("Sections") and state["Sections"].has(section_name):
		var idx = str(state["Sections"][section_name])
		if data["variations"].has(idx):
			variation_lines = data["variations"][idx]
			variation_found = true

	# Check Link Groups if no override found
	if not variation_found and state.has("Link Groups"):
		for link_group in state["Link Groups"]:
			var index = str(state["Link Groups"][link_group])
			var code = index + "." + link_group
			if data["variations"].has(code):
				variation_lines = data["variations"][code]
				variation_found = true
				break

			# Fallback: Try just the index if linked variation not found
			if data["variations"].has(index):
				variation_lines = data["variations"][index]
				variation_found = true
				break

	# For property setters, usually replacement is desired.
	# But for lists, concatenation is standard LNZ behavior (common + specific).
	# In LNZ files, if a property setter has variations, the 'default' block is typically empty
	# or contains values that act as defaults if no variation is selected.
	# If we concatenate, we might get [DefaultVal, VariationVal].
	# Most 'get_...' functions take the FIRST value (e.g. parsed_lines[0]).
	# If we want the variation to override, it must come FIRST.
	# OR, we assume that if a variation is active, we should IGNORE default?
	# BUT [Move] sections rely on Default + Variation.
	# Let's check if concatenating Default + Variation works generally.
	# For [Move]: Default lines... Var lines... -> Correct order.
	# For [Body Extension]: Default (empty) ... Var lines -> Correct.
	# For [Leg Extension] (no var): Default ... Var (empty) -> Correct.
	# For [Body Extension] with Base: DefaultVal ... VarVal.
	# If get_body_extension reads index 0, it gets DefaultVal. WRONG.

	# LNZ Parser logic usually reads lines sequentially.
	# If a section allows multiple values (Move), it's fine.
	# If a section allows ONE value, usually the variation block REPLACES the default.
	# But 'get_active_lines' is generic.

	# Concatenate Default + Variation
	# BUT, we might need to ensure Variation comes LAST or handle it in the specific getter
	# Actually, standard LNZ parsers read top to bottom
	# [Body Ext]
	# 10
	# #1
	# 20
	# ##
	# This parses to 10. Then encounters #1. If active, parses 20 (overwriting 10).
	# BUT the order could be Default lines THEN Variation lines, or Default could be on either end of variation block
	# And the specific `process_` function needs to handle sequential overwrites.

	# Let's check `process_body_extension`.
	# It calls `get_parsed_lines`. Then takes `parsed_lines[0]`.
	# If we pass [10, 20], it takes 10. It does NOT overwrite.
	# So `process_` functions for singletons need to loop and take the LAST value?
	# We CANNOT assume property sections don't mix base+var like that

	# If we are just returning lines, we should return Default + Variation
	return default_lines + variation_lines

func apply_variation_state(state: Dictionary):
	# Re-run processing for all variable sections
	if raw_data.has("Species"):
		process_species(get_active_lines("Species", state))
	if raw_data.has("256 Eyelid Color"):
		process_eyelid_color(get_active_lines("256 Eyelid Color", state))
	if raw_data.has("Default Scales"):
		process_default_scales(get_active_lines("Default Scales", state))
	if raw_data.has("Leg Extension"):
		process_leg_extensions(get_active_lines("Leg Extension", state))
	if raw_data.has("Body Extension"):
		process_body_extension(get_active_lines("Body Extension", state))
	if raw_data.has("Face Extension"):
		process_face_extension(get_active_lines("Face Extension", state))
	if raw_data.has("Ear Extension"):
		process_ear_extension(get_active_lines("Ear Extension", state))
	if raw_data.has("Head Enlargement"):
		process_head_enlargement(get_active_lines("Head Enlargement", state))
	if raw_data.has("Feet Enlargement"):
		process_feet_enlargement(get_active_lines("Feet Enlargement", state))

	if raw_data.has("Ballz Info"):
		process_balls(get_active_lines("Ballz Info", state))
	if raw_data.has("Add Ball"):
		process_addballs(get_active_lines("Add Ball", state))
	if raw_data.has("Linez"):
		process_lines(get_active_lines("Linez", state))
	if raw_data.has("Polygons"):
		process_polygons(get_active_lines("Polygons", state))
	if raw_data.has("Paint Ballz"):
		process_paintballs(get_active_lines("Paint Ballz", state))
	if raw_data.has("Move"):
		process_moves(get_active_lines("Move", state))
	if raw_data.has("Project Ball"):
		process_project_balls(get_active_lines("Project Ball", state))

	# Overrides
	if raw_data.has("Ball Size Override"):
		process_ball_size_override(get_active_lines("Ball Size Override", state))
	if raw_data.has("Color Info Override"):
		process_color_info_override(get_active_lines("Color Info Override", state))
	if raw_data.has("Outline Color Override"):
		process_outline_color_override(get_active_lines("Outline Color Override", state))
	if raw_data.has("Fuzz Override"):
		process_fuzz_override(get_active_lines("Fuzz Override", state))
	if raw_data.has("Add Ball Override"):
		process_add_ball_override(get_active_lines("Add Ball Override", state))
	if raw_data.has("Omissions"):
		process_omissions(get_active_lines("Omissions", state))

func get_parsed_lines(file: File, keys: Array):
	# Legacy support if called directly, though internal methods use _read_section_lines now
	var return_array = []
	while true:
		var line = file.get_line().dedent()
		if line.empty() or line.begins_with("[") or file.eof_reached():
			break
		if line.begins_with(";") or line.begins_with("#"):
			continue
		var parsed = r.search_all(line)
		if parsed.size() == 0:
			continue
		var dict = {}
		for i in range(keys.size()):
			if i < parsed.size():
				dict[keys[i]] = int(parsed[i].get_string())
		return_array.append(dict)
	return return_array

func get_parsed_line_strings(file: File, keys: Array):
	var return_array = []
	while true:
		var line = file.get_line().dedent()
		if line.empty() or line.begins_with("[") or file.eof_reached():
			break
		if line.begins_with(";") or line.begins_with("#"):
			continue
		var parsed = str_r.search_all(line)
		var dict = {}
		var i = 0
		for key in keys:
			if i < parsed.size():
				dict[key] = parsed[i].get_string()
				i += 1
			else:
				dict[key] = ""
		return_array.append(dict)
	return return_array

func get_species(file: File):
	var data = _read_section_lines(file, "Species")
	if data.empty():
		# Fallback logic for determining species via Default Linez File
		print("[Species] not found. Looking for [Default Linez File] as a fallback.")
		file.seek(0)
		get_next_section(file, "Default Linez File")
		var path_line = file.get_line().strip_edges()
		var lower_path = path_line.to_lower()
		if "dog" in lower_path:
			print("[Default Linez File] path contained 'dog'. Setting species to Dogz (Species = 2).")
			species = 2
		elif "cat" in lower_path:
			print("[Default Linez File] path contained 'cat'. Setting species to Catz (Species = 1).")
			species = 1
		elif "baby" in lower_path:
			print("[Default Linez File] path contained 'baby'. Setting species to Babyz (Species = 3).")
			species = 3
		else:
			print("Could not determine species from file. Defaulting to Catz (Species = 1).")
			species = 1
		return

	process_species(data["default"])

func process_species(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["species"])
	if parsed_lines.size() > 0:
		# Take the last valid entry to support overrides
		species = parsed_lines[parsed_lines.size() - 1].species

		if species == 1:
			print("[Species] detected: Catz (Species = " + str(species) + ")")
		elif species == 2:
			print("[Species] detected: Dogz (Species = " + str(species) + ")")
		elif species == 3:
			print("[Species] detected: Babyz (Species = " + str(species) + ")")
		else:
			print("[Species] detected: ??? (Species = " + str(species) + ")")

func get_texture_list(file: File):
	get_next_section(file, "Texture List")
	var parsed_lines = get_parsed_line_strings(file, ["filepath", "transparent_color", "width", "height"])
	for line in parsed_lines:
		var filename = line.filepath.get_file()
		var texture_size = null

		if line.has("width") and line.has("height"):
			var width = float(line.width) if line.width.is_valid_float() else 256
			var height = float(line.height) if line.height.is_valid_float() else 256
			if width != null and height != null:
				texture_size = Vector2(width, height)

		texture_list.append({filename = filename, transparent_color = line.transparent_color, texture_size = texture_size})

func get_no_texture_rotate(file: File):
	get_next_section(file, "No Texture Rotate")
	var parsed_lines = get_parsed_lines(file, ["ball_no"])
	no_texture_rotate = []
	for line in parsed_lines:
		no_texture_rotate.append(line.ball_no)

func get_palette(file: File):
	get_next_section(file, "Palette")
	var parsed_lines = get_parsed_line_strings(file, ["filepath"])
	for line in parsed_lines:
		var filename = line.filepath.get_file()
		palette = filename + ".png"

func parse_paintballs(file: File):
	var data = _read_section_lines(file, "Paint Ballz")
	if data.empty(): return
	process_paintballs(data["default"])

func process_paintballs(lines: Array):
	self.paintballs.clear()
	for line in lines:
		var split_line = r.search_all(line)
		if split_line.size() < 11:
			continue
		var base = int(split_line[0].get_string())
		var diameter = int(split_line[1].get_string())
		var position = Vector3(
			float(split_line[2].get_string()),
			float(split_line[3].get_string()),
			float(split_line[4].get_string())
		)
		var color = int(split_line[5].get_string())
		var outline_color = int(split_line[6].get_string()) if int(split_line[6].get_string()) != -1 else 0
		var fuzz = int(split_line[7].get_string())
		var outline = int(split_line[8].get_string())
		var texture = int(split_line[10].get_string())
		var anchored = int(split_line[11].get_string()) if split_line.size() > 11 else 0

		var paintball = PaintBallData.new(base, diameter, position, color, outline_color, outline, fuzz, 0, texture, anchored)
		var pb_array = self.paintballs.get(base, [])
		pb_array.append(paintball)
		self.paintballs[base] = pb_array

func parse_moves(file: File):
	var data = _read_section_lines(file, "Move")
	if data.empty(): return
	process_moves(data["default"])

func process_moves(lines: Array):
	moves.clear()
	for line in lines:
		var split_line = r.search_all(line)
		if split_line.size() < 4:
			continue
		var base = int(split_line[0].get_string())
		var position = Vector3(
			int(split_line[1].get_string()),
			int(split_line[2].get_string()),
			int(split_line[3].get_string())
		)
		var relative_to = int(split_line[4].get_string()) if split_line.size() > 4 else base
		moves.append({"ball_no": base, "position": position, "relative_to": relative_to})
		
func get_project_balls(file: File):
	var data = _read_section_lines(file, "Project Ball")
	if data.empty(): return
	process_project_balls(data["default"])

func process_project_balls(lines: Array):
	project_ball.clear()
	var parsed_lines = _parse_lines_to_dicts(lines, ["fixed_ball", "project_ball", "amount"])
	for line in parsed_lines:
		var amount = line.amount
		project_ball.append({
			"fixed_ball": line.fixed_ball,
			"project_ball": line.project_ball,
			"min_projection": amount - 50,
			"max_projection": amount + 50,
			"comment": ""
		})

func get_eyelid_color(file: File):
	var data = _read_section_lines(file, "256 Eyelid Color")
	if data.empty():
		eyelid_color = 244
		return
	process_eyelid_color(data["default"])

func process_eyelid_color(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["color", "group"])
	if parsed_lines.size() > 0:
		eyelid_color = parsed_lines[parsed_lines.size() - 1]["color"]
	else:
		pass # Keep existing or default

func get_balls(file: File):
	var data = _read_section_lines(file, "Ballz Info")
	if data.empty():
		print("Error: No Ballz Info found.")
		return
	process_balls(data["default"])

func process_balls(lines: Array):
	self.balls.clear()
	var parsed_lines = _parse_lines_to_dicts(lines, ["color", "outline_color", "speckle", "fuzz", "outline", "size", "group", "texture"])
	var i = 0
	for line in parsed_lines:
		var bd = BallData.new(
			line.size, 
			Vector3.ZERO, 
			i, 
			Vector3.ZERO,
			line.color,
			line.outline_color, 
			line.outline, 
			line.fuzz, 
			0.0, 
			line.group, 
			line.texture)
		self.balls[i] = bd
		i += 1

func get_addballs(file: File):
	var data = _read_section_lines(file, "Add Ball")
	if data.empty(): return
	process_addballs(data["default"])

func process_addballs(lines: Array):
	self.addballs.clear()
	var parsed_lines = _parse_lines_to_dicts(lines, ["base", "x", "y", "z", "color", "outline_color", "speckle", "fuzz", "group", "outline", "size", "body_area", "add_group", "texture"])
	# Recalculate starting index based on current balls
	# Wait, if balls changed, keys.max might change.
	var max_ball_num = 0
	if balls.size() > 0:
		max_ball_num = balls.keys().max() + 1

	for line in parsed_lines:
		var pos = Vector3(line.x, line.y, line.z)
		var ball = AddBallData.new(
			line.base,
		 max_ball_num, 
		line.size, 
		pos,
		line.color, 
		line.outline_color, 
		line.outline, 
		line.fuzz,
		 0, 
		line.group, 
		line.body_area, 
		line.texture)
		addballs[max_ball_num] = ball
		max_ball_num += 1

func get_default_scales(file: File):
	var data = _read_section_lines(file, "Default Scales")
	if data.empty(): return
	process_default_scales(data["default"])

func process_default_scales(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["scale"])
	for i in range(parsed_lines.size()):
		if i % 2 == 0:
			scales.x = parsed_lines[i].scale
		else:
			scales.y = parsed_lines[i].scale

func get_leg_extensions(file: File):
	var data = _read_section_lines(file, "Leg Extension")
	if data.empty(): return
	process_leg_extensions(data["default"])

func process_leg_extensions(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["extension"])
	for i in range(parsed_lines.size()):
		if i % 2 == 0:
			leg_extensions.x = parsed_lines[i].extension
		else:
			leg_extensions.y = parsed_lines[i].extension
	
func get_body_extension(file: File):
	var data = _read_section_lines(file, "Body Extension")
	if data.empty(): return
	process_body_extension(data["default"])

func process_body_extension(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["extension"])
	if parsed_lines.size() > 0:
		body_extension = parsed_lines[parsed_lines.size() - 1].extension
	
func get_face_extension(file: File):
	var data = _read_section_lines(file, "Face Extension")
	if data.empty(): return
	process_face_extension(data["default"])

func process_face_extension(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["extension"])
	if parsed_lines.size() > 0:
		face_extension = parsed_lines[parsed_lines.size() - 1].extension

func get_ear_extension(file: File):
	var data = _read_section_lines(file, "Ear Extension")
	if data.empty(): return
	process_ear_extension(data["default"])

func process_ear_extension(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["extension"])
	if parsed_lines.size() > 0:
		ear_extension = parsed_lines[parsed_lines.size() - 1].extension
	
func get_head_enlargement(file: File):
	var data = _read_section_lines(file, "Head Enlargement")
	if data.empty(): return
	process_head_enlargement(data["default"])

func process_head_enlargement(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["scale"])
	for i in range(parsed_lines.size()):
		if i % 2 == 0:
			head_enlargement.x = parsed_lines[i].scale
		else:
			head_enlargement.y = parsed_lines[i].scale
	
func get_feet_enlargement(file: File):
	var data = _read_section_lines(file, "Feet Enlargement")
	if data.empty(): return
	process_feet_enlargement(data["default"])

func process_feet_enlargement(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["scale"])
	for i in range(parsed_lines.size()):
		if i % 2 == 0:
			foot_enlargement.x = parsed_lines[i].scale
		else:
			foot_enlargement.y = parsed_lines[i].scale
	
func get_omissions(file: File):
	var data = _read_section_lines(file, "Omissions")
	if data.empty(): return
	process_omissions(data["default"])

func process_omissions(lines: Array):
	omissions.clear()
	var parsed_lines = _parse_lines_to_dicts(lines, ["ball_no"])
	for line in parsed_lines:
		omissions[line.ball_no] = true
		
func get_lines(file: File):
	var data = _read_section_lines(file, "Linez")
	if data.empty(): return
	process_lines(data["default"])

func process_lines(lines: Array):
	self.lines.clear()
	var parsed_lines = _parse_lines_to_dicts(lines, ["start", "end", "fuzz", "color", "l_color", "r_color", "start_thickness", "end_thickness"])
	for line in parsed_lines:
		var line_data = LineData.new(line.start, line.end, line.start_thickness, line.end_thickness, line.fuzz, line.color, line.l_color, line.r_color)
		self.lines.append(line_data)

func get_polygons(file: File):
	var data = _read_section_lines(file, "Polygons")
	if data.empty(): return
	process_polygons(data["default"])

func process_polygons(lines: Array):
	self.polygons.clear()
	var parsed_lines = _parse_lines_to_dicts(lines, ["ball1", "ball2", "ball3", "ball4", "color", "l_edge_color", "r_edge_color", "fuzz", "texture"])
	for line in parsed_lines:
		var poly_data = PolyData.new(
			line.ball1,
			line.ball2,
			line.ball3,
			line.ball4,
			line.color,
			line.l_edge_color,
			line.r_edge_color,
			line.fuzz,
			line.texture
		)
		self.polygons.append(poly_data)

func get_ball_size_override(file: File):
	var data = _read_section_lines(file, "Ball Size Override")
	if data.empty(): return
	process_ball_size_override(data["default"])

func process_ball_size_override(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["ball", "size"])
	for line in parsed_lines:
		if balls.has(line.ball):
			balls[line.ball].size = line.size
		else:
			pass # Ignoring warning for silence on updates

func get_color_info_override(file: File):
	var data = _read_section_lines(file, "Color Info Override")
	if data.empty(): return
	process_color_info_override(data["default"])

func process_color_info_override(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["ball", "color", "group", "texture"])
	for line in parsed_lines:
		if balls.has(line.ball):
			var ball_data = balls[line.ball]
			if "color_index" in ball_data:
				ball_data.color_index = line.color
			if "group" in ball_data and line.has("group"):
				ball_data.group = line.group
			if "texture_id" in ball_data and line.has("texture"):
				ball_data.texture_id = line.texture
		else:
			pass

func get_outline_color_override(file: File):
	var data = _read_section_lines(file, "Outline Color Override")
	if data.empty(): return
	process_outline_color_override(data["default"])

func process_outline_color_override(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["ball", "outline_color"])
	for line in parsed_lines:
		if balls.has(line.ball):
			var ball_data = balls[line.ball]
			if "outline_color" in ball_data:
				ball_data.outline_color = line.outline_color
		else:
			pass

func get_fuzz_override(file: File):
	var data = _read_section_lines(file, "Fuzz Override")
	if data.empty(): return
	process_fuzz_override(data["default"])

func process_fuzz_override(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["ball", "fuzz"])
	for line in parsed_lines:
		if balls.has(line.ball):
			var ball_data = balls[line.ball]
			if "fuzz" in ball_data:
				ball_data.fuzz = line.fuzz
		else:
			pass

func get_add_ball_override(file: File):
	var data = _read_section_lines(file, "Add Ball Override")
	if data.empty(): return
	process_add_ball_override(data["default"])

func process_add_ball_override(lines: Array):
	var parsed_lines = _parse_lines_to_dicts(lines, ["ball", "x", "y", "z"])
	for line in parsed_lines:
		if addballs.has(line.ball):
			addballs[line.ball].position = Vector3(line.x, line.y, line.z)
		else:
			pass

func get_available_variations() -> Dictionary:
	var result = {
		"sections": {},
		"link_groups": {}
	}
	for section in raw_data:
		var variations = raw_data[section]["variations"].keys()
		if variations.empty():
			continue

		result["sections"][section] = variations

		# Populate link groups
		for v in variations:
			if "." in v:
				var parts = v.split(".")
				if parts.size() >= 2:
					var idx = parts[0]
					var link = parts[1]
					if not result["link_groups"].has(link):
						result["link_groups"][link] = []
					if not idx in result["link_groups"][link]:
						result["link_groups"][link].append(idx)

	return result
