extends Node
class_name LnzParser

var r = RegEx.new()
var str_r = RegEx.new()

var species = 0
var scales = Vector2(255, 255)
var leg_extensions = Vector2(0, 0)
var body_extension = 0
var face_extension = 0
var ear_extension = 0
var head_enlargement = Vector2(100, 0)
var foot_enlargement = Vector2(100, 0)
var moves = {}
var balls = {}
var lines = []
var polygons = []
var addballs = {}
var paintballs = {}
var omissions = {}
var project_ball = []
var texture_list = []
var palette = null

var file_path

func _init(file_path):
	if file_path == null:
		return
	
	self.file_path = file_path
	r.compile("[-.\\d]+")
	str_r.compile("[\\S]+")
	
	var file = File.new()
	if file.file_exists(file_path):
		file.open(file_path, File.READ)
	else:
		print("File not found: " + file_path)
		return
	
	# Load base data
	get_texture_list(file)
	get_palette(file)
	get_species(file)
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
	while !this_line.begins_with("[" + section_name + "]") and !file.eof_reached():
		this_line = file.get_line()
	if file.eof_reached():
		return false
	return true
	
func get_parsed_lines(file: File, keys: Array):
	var return_array = []
	while true:
		var line = file.get_line().dedent()
		if line.empty() or line.begins_with("[") or file.eof_reached() or line.begins_with("#2"):
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
		if line.empty() or line.begins_with("[") or file.eof_reached() or line.begins_with("#2"):
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
	get_next_section(file, "Species")
	var parsed_lines = get_parsed_lines(file, ["species"])
	if parsed_lines.size() == 0:
		species = 2
	else:
		species = parsed_lines[0].species
	print("Species detected: " + str(species))

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

func get_palette(file: File):
	get_next_section(file, "Palette")
	var parsed_lines = get_parsed_line_strings(file, ["filepath"])
	for line in parsed_lines:
		var filename = line.filepath.get_file()
		palette = filename + ".png"

func parse_paintballs(file: File):
	file.seek(0)
	while file.get_line() != "[Paint Ballz]" and !file.eof_reached():
		pass
	while true:
		var line = file.get_line()
		if line.empty() or line.begins_with("[") or file.eof_reached():
			break
		if line.begins_with(";") or line.begins_with("#"):
			continue
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
	file.seek(0)
	while file.get_line() != "[Move]" and !file.eof_reached():
		pass
	while true:
		var line = file.get_line()
		if line.empty() or line.begins_with("[") or file.eof_reached():
			break
		if line.begins_with(";") or line.begins_with("#"):
			continue
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
		var move_array = moves.get(base, [])
		move_array.append({"position": position, "relative_to": relative_to})
		moves[base] = move_array

func get_project_balls(file: File):
	get_next_section(file, "Project Ball")
	var parsed_lines = get_parsed_lines(file, ["base", "projected", "amount"])
	for line in parsed_lines:
		project_ball.append({ball = line.projected, base = line.base, amount = line.amount})

func get_balls(file: File):
	get_next_section(file, "Ballz Info")
	var parsed_lines = get_parsed_lines(file, ["color", "outline_color", "speckle", "fuzz", "outline", "size", "group", "texture"])
	if parsed_lines.size() == 0:
		print("Error: No Ballz Info found.")
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
		#print("Added ball " + str(i) + " with size " + str(line.size))
		i += 1

func get_addballs(file: File):
	get_next_section(file, "Add Ball")
	var parsed_lines = get_parsed_lines(file, ["base", "x", "y", "z", "color", "outline_color", "speckle", "fuzz", "group", "outline", "size", "body_area", "add_group", "texture"])
	var max_ball_num = balls.keys().max() + 1
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
	get_next_section(file, "Default Scales")
	var parsed_lines = get_parsed_lines(file, ["scale"])
	if parsed_lines.size() > 0:
		scales = Vector2(parsed_lines[0].scale, parsed_lines[1].scale)
	
func get_leg_extensions(file: File):
	get_next_section(file, "Leg Extension")
	var parsed_lines = get_parsed_lines(file, ["extension"])
	if parsed_lines.size() > 0:
		leg_extensions = Vector2(parsed_lines[0].extension, parsed_lines[1].extension)
	
func get_body_extension(file: File):
	get_next_section(file, "Body Extension")
	var parsed_lines = get_parsed_lines(file, ["extension"])
	if parsed_lines.size() > 0:
		body_extension = parsed_lines[0].extension
	
func get_face_extension(file: File):
	get_next_section(file, "Face Extension")
	var parsed_lines = get_parsed_lines(file, ["extension"])
	if parsed_lines.size() > 0:
		face_extension = parsed_lines[0].extension

func get_ear_extension(file: File):
	get_next_section(file, "Ear Extension")
	var parsed_lines = get_parsed_lines(file, ["extension"])
	if parsed_lines.size() > 0:
		ear_extension = parsed_lines[0].extension
	
func get_head_enlargement(file: File):
	get_next_section(file, "Head Enlargement")
	var parsed_lines = get_parsed_lines(file, ["scale"])
	if parsed_lines.size() > 0:
		head_enlargement = Vector2(parsed_lines[0].scale, parsed_lines[1].scale)
	
func get_feet_enlargement(file: File):
	get_next_section(file, "Feet Enlargement")
	var parsed_lines = get_parsed_lines(file, ["scale"])
	if parsed_lines.size() > 0:
		foot_enlargement = Vector2(parsed_lines[0].scale, parsed_lines[1].scale)
	
func get_omissions(file: File):
	get_next_section(file, "Omissions")
	var parsed_lines = get_parsed_lines(file, ["ball_no"])
	omissions = {}
	for line in parsed_lines:
		omissions[line.ball_no] = true
		
func get_lines(file: File):
	get_next_section(file, "Linez")
	var parsed_lines = get_parsed_lines(file, ["start", "end", "fuzz", "color", "l_color", "r_color", "start_thickness", "end_thickness"])
	for line in parsed_lines:
		var line_data = LineData.new(line.start, line.end, line.start_thickness, line.end_thickness, line.fuzz, line.color, line.l_color, line.r_color)
		lines.append(line_data)

func get_polygons(file: File):
	get_next_section(file, "Polygons")
	var parsed_lines = get_parsed_lines(file, ["ball1", "ball2", "ball3", "ball4", "color", "l_edge_color", "r_edge_color", "fuzz", "texture"])
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
		polygons.append(poly_data)

func get_ball_size_override(file: File):
	get_next_section(file, "Ball Size Override")
	var parsed_lines = get_parsed_lines(file, ["ball", "size"])
	for line in parsed_lines:
		if balls.has(line.ball):
			balls[line.ball].size = line.size
		else:
			print("Warning: [Ball Size Override] override attempted for non-existent ball ", line.ball)

func get_color_info_override(file: File):
	get_next_section(file, "Color Info Override")
	var parsed_lines = get_parsed_lines(file, ["ball", "color", "group", "texture"])
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
			print("Warning: [Color Info Override] override attempted for non-existent ball ", line.ball)

func get_outline_color_override(file: File):
	get_next_section(file, "Outline Color Override")
	var parsed_lines = get_parsed_lines(file, ["ball", "outline_color"])
	for line in parsed_lines:
		if balls.has(line.ball):
			var ball_data = balls[line.ball]
			if "outline_color" in ball_data:
				ball_data.outline_color = line.outline_color
		else:
			print("Warning: [Outline Color Override] override for non-existent ball ", line.ball)

func get_fuzz_override(file: File):
	get_next_section(file, "Fuzz Override")
	var parsed_lines = get_parsed_lines(file, ["ball", "fuzz"])
	for line in parsed_lines:
		if balls.has(line.ball):
			var ball_data = balls[line.ball]
			if "fuzz" in ball_data:
				ball_data.fuzz = line.fuzz
		else:
			print("Warning: [Fuzz Override] override for non-existent ball ", line.ball)

func get_add_ball_override(file: File):
	get_next_section(file, "Add Ball Override")
	var parsed_lines = get_parsed_lines(file, ["ball", "base", "x", "y", "z"])
	for line in parsed_lines:
		if addballs.has(line.ball):
			addballs[line.ball].position = Vector3(line.x, line.y, line.z)
		else:
			print("Warning: [Add Ball Override] override attempted for non-existent ball ", line.ball)