extends Node

# dog_generator.gd
# - Generates and manages 3D model based on LNZ data (ballz, paintballz, linez, polygonz)
# - Controls animations, textures, palettes, and geometry
# NOTE: Could really use a rename and refactor, script is huge...

# SECTIONS:
#	SETUP & INITIALIZATION
#   SIGNALS
#	MODEL GENERATION
#	TEXTURES & PALETTES
#	RENDERING & GEOMETRY
#	TRANSFORMATIONS
#	ANIMATIONS
#	VISIBILITY
# 	PAINTBALLZ

export var pixel_world_size = 0.002

var balls = []
var lines = []
var polygons = []

var ball_map = {}
var paintball_map = {}
var lines_map = {}
var polygons_map = {}

var _hidden_balls = []
var _hidden_lines = []
var _hidden_polygons = []
var _hidden_paintballs = []

var _ball_to_lines_map = {}
var _ball_to_polygons_map = {}

export var draw_balls = true
export var draw_special_balls = false
export var draw_addballs = true
export var draw_lines = true
export var draw_paintballs = true
export var draw_polygons = true
export var draw_omitted_balls = false

var ball_scene = preload("res://Ball.tscn")
var paintball_scene = preload("res://Paintball.tscn")
var line_scene = preload("res://Line.tscn")
var polygon_scene = preload("res://Polygon.tscn")

var bhd: BhdParser
var lnz: LnzParser
var current_animation = 0
var current_frame = 0
var current_bdt: BdtParser

var t_pose_checkbox = null
var t_pose_active = false
var is_setting_tpose = false
var _saved_anim_index = 0
var _saved_frame_index = 0

var _pending_paintballs_data = []
var _pending_paintball_nodes = []
var _auto_paintballs_data = []
var _auto_paintball_nodes = []

var render_flat_colors_global = false

var _texture_cache = {}
var _atlas_manifest = {}
var _atlas_textures = {}
var _perf_texture_load_time = 0

var _orig_lnz_pos := {}
var _orig_world_pos := {}

var eyelid_dir_map := {}
var eyelid_mode := 0

var bhd_file_list = []
var current_bdt_prefix = "CAT"

var _skip_next_rebuild = false

var current_variation_config = {}
var last_loaded_filepath = ""

onready var pet_view = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
onready var console_log = pet_view.find_node("ConsoleLog", true, false)
# if console_log:
# 	console_log.log_message("")

onready var eyelid_button := get_tree().get_root().get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer"
	+ "/VBoxContainer/DropDownMenu/EyeLidButton"
) as Button

const EYELID_LABELS = ["neutral", "none", "angry", "scared"]
const EYELID_TILTS  = [  0.0,      0.0,     -30.0,      30.0 ]
const EYELID_ICONS  = [
	LnzLiveUtils.ICON_EYE_NEUTRAL,
	LnzLiveUtils.ICON_EYE_NOLID,
	LnzLiveUtils.ICON_EYE_ANGRY,
	LnzLiveUtils.ICON_EYE_SCARED
]

onready var preloader = get_tree().root.get_node("Root/ResourcePreloader") as ResourcePreloader

onready var bhd_option_button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/ModelSwitcher/ModelOptionButton") as OptionButton
onready var bhd_prompt_dialog = get_tree().root.get_node("Root/SceneRoot/BhdPromptDialog") as ConfirmationDialog
onready var bhd_prompt_option = get_tree().root.get_node("Root/SceneRoot/BhdPromptDialog/VBoxContainer/ModelOptionButton") as OptionButton

onready var game_option_button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/ModelSwitcher/GameOptionButton") as OptionButton

var is_babyz_mode = false

var current_palette_texture = null

signal animation_loaded(num_of_frames)
signal bhd_loaded(num_of_animations)
signal ball_mouse_enter(ball_info)
signal ball_mouse_exit(ball_no)
signal ball_selected(ball_no, is_addball)

signal ball_moved(ball_no, new_position)
signal ball_resized(ball_no, size_dif)

signal addball_deleted(ball_no)
signal addball_created(reference_ball)
signal line_created(start_ball, end_ball)

signal palette_changed(palette_name)


### SETUP & INITIALIZATION ###
# _ready
# get_root
# populate_bhd_list

func _ready():
	var t_start = OS.get_ticks_msec()
	var f = File.new()
	if f.open("res://resources/texture_atlas/atlas_manifest.json", File.READ) == OK:
		var result = JSON.parse(f.get_as_text())
		if result.error == OK:
			_atlas_manifest = result.result
			print("[STATUS] dog_generator: read texture atlas manifest with " + str(_atlas_manifest.size()) + " entries in " + str(OS.get_ticks_msec() - t_start) + "ms")
		else:
			print("[ERROR] dog_generator: failed to parse texture atlas manifest")
		f.close()
	else:
		print("[ERROR] dog_generator: failed to open texture atlas manifest")

	var editor = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	editor.connect("find_line", self, "_on_LnzTextEdit_find_line")
	editor.connect("find_paintball", self, "_on_LnzTextEdit_find_paintball")
	editor.connect("find_polygon", self, "_on_LnzTextEdit_find_polygon")
	editor.connect("find_move", self, "_on_LnzTextEdit_find_move")
	editor.connect("find_project_ball", self, "_on_LnzTextEdit_find_project_ball")
	eyelid_button.icon         = EYELID_ICONS[eyelid_mode]
	t_pose_checkbox = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/TPoseCheckBox")

	populate_bhd_list()

	if bhd_option_button:
		bhd_option_button.connect("item_selected", self, "_on_BhdSwitcher_item_selected")
	if bhd_prompt_dialog:
		bhd_prompt_dialog.connect("confirmed", self, "_on_BhdPrompt_confirmed")

	if game_option_button:
		game_option_button.clear()
		game_option_button.add_item("Petz")
		game_option_button.add_item("Babyz")
		game_option_button.connect("item_selected", self, "_on_GameSwitcher_item_selected")

func get_root():
	if Engine.is_editor_hint():
		return get_tree().get_edited_scene_root().get_node("PetRoot")
	else:
		return get_tree().root.get_node("Root/PetRoot")

func populate_bhd_list():
	bhd_file_list.clear()
	var dir = Directory.new()
	if dir.open("res://resources/animations") == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".bhd"):
				bhd_file_list.append(file_name)
			file_name = dir.get_next()

	bhd_file_list.sort()

	bhd_option_button.clear()
	bhd_prompt_option.clear()
	for file in bhd_file_list:
		bhd_option_button.add_item(file)
		bhd_prompt_option.add_item(file)

	bhd_option_button.select(-1)
	bhd_prompt_option.select(-1)


### SIGNALS ###
# _on_BhdSwitcher_item_selected
# _on_BhdPrompt_confirmed
# _on_GameSwitcher_item_selected
# emit_ball_move
# emit_ball_resize
# signal_ball_mouse_enter
# signal_ball_mouse_exit
# signal_paintball_mouse_enter
# signal_paintball_mouse_exit
# signal_ball_selected
# signal_ball_deleted
# _on_LnzTextEdit_find_ball
# _on_LnzTextEdit_find_line
# _on_LnzTextEdit_find_paintball
# _on_LnzTextEdit_find_polygon
# _on_LnzTextEdit_find_move
# _on_LnzTextEdit_find_project_ball
# _on_ToolsMenu_print_ball_colors
# _on_OptionButton_file_selected
# _on_OptionButton_file_saved

func _on_BhdSwitcher_item_selected(index):
	var bhd_name = bhd_option_button.get_item_text(index)
	init_ball_data(0, false, "res://resources/animations/" + bhd_name)
	if lnz:
		init_visual_balls(lnz, true)

func _on_BhdPrompt_confirmed():
	var selected_idx = bhd_prompt_option.selected
	if selected_idx != -1:
		var bhd_name = bhd_prompt_option.get_item_text(selected_idx)
		for i in range(bhd_option_button.get_item_count()):
			if bhd_option_button.get_item_text(i) == bhd_name:
				bhd_option_button.select(i)
				break

		init_ball_data(0, false, "res://resources/animations/" + bhd_name)
		init_visual_balls(lnz, true)
		emit_signal("palette_changed", lnz.palette)

func _on_GameSwitcher_item_selected(index):
	if !lnz:
		return
	if lnz.species == 0:
		var selected_idx = bhd_option_button.selected
		if selected_idx != -1:
			var bhd_name = bhd_option_button.get_item_text(selected_idx)
			init_ball_data(0, false, "res://resources/animations/" + bhd_name)
	else:
		init_ball_data(lnz.species)

	init_visual_balls(lnz, true)
	emit_signal("palette_changed", lnz.palette)

func emit_ball_move(ball_no: int, new_position: Vector3):
	_skip_next_rebuild = true
	emit_signal("ball_moved", ball_no, new_position)

func emit_ball_resize(ball_no: int, size_dif: int):
	_skip_next_rebuild = true
	emit_signal("ball_resized", ball_no, size_dif)

func signal_ball_mouse_enter(ball_info):
	emit_signal("ball_mouse_enter", ball_info)

func signal_ball_mouse_exit(ball_no):
	emit_signal("ball_mouse_exit", ball_no)

func signal_paintball_mouse_enter(ball_info):
	emit_signal("ball_mouse_enter", {ball_no = "Paintball on " + str(ball_info.base_ball_no)})

func signal_paintball_mouse_exit():
	emit_signal("ball_mouse_exit", 0)

func signal_ball_selected(ball_no, section):
	print("[STATUS] Node: signal_ball_selected: ball_no %d, section %s" % [ball_no, section])
	var ball = ball_map[ball_no]
	var is_addball = false
	if ball.base_ball_no != -1 and !("override_ball_no" in ball):
		is_addball = true
	emit_signal("ball_selected", section, ball_no, is_addball, lnz.balls.keys().max() + 1)

func signal_ball_deleted(ball_no):
	print("[STATUS] Node: signal_ball_deleted: ball_no %d" % ball_no)
	var ball = ball_map[ball_no]
	if ball.base_ball_no != -1:
		emit_signal("addball_deleted", ball_no)

func _on_LnzTextEdit_find_ball(ball_no):
	print("[STATUS] Node: _on_LnzTextEdit_find_ball: flashing ball %d" % ball_no)
	if ball_map.has(ball_no):
		ball_map[ball_no].flash()
	else:
		print("[WARNING] Node: _on_LnzTextEdit_find_ball: ball %d not found in ball_map" % ball_no)

func _on_LnzTextEdit_find_line(line_no):
	print("[STATUS] Node: _on_LnzTextEdit_find_line: flashing line %d" % line_no)
	if lines_map.has(line_no):
		var line = lines_map[line_no]
		line.flash()
		var line_data = lnz.lines[line_no]
		if ball_map.has(line_data.start):
			ball_map[line_data.start].flash()
		if ball_map.has(line_data.end):
			ball_map[line_data.end].flash()
	else:
		print("[WARNING] Node: _on_LnzTextEdit_find_line: line %d not found in lines_map" % line_no)

func _on_LnzTextEdit_find_paintball(line_no):
	print("[STATUS] Node: _on_LnzTextEdit_find_paintball: flashing paintball line %d" % line_no)
	var all_paintballs = []
	for ball_no in lnz.paintballs:
		for paintball in lnz.paintballs[ball_no]:
			all_paintballs.append(paintball)
	if line_no < all_paintballs.size():
		var paintball_data = all_paintballs[line_no]
		var base_ball_no = paintball_data.base
		if paintball_map.has(base_ball_no):
			var paintball_visuals = paintball_map[base_ball_no]
			# This is tricky because the visual paintballs might not be in the same order
			# For now, let's just flash the base ball
			if ball_map.has(base_ball_no):
				ball_map[base_ball_no].flash()
		else:
			print("[WARNING] Node: _on_LnzTextEdit_find_paintball: base ball %d has no visual paintballs" % base_ball_no)
	else:
		print("[WARNING] Node: _on_LnzTextEdit_find_paintball: line_no %d out of bounds" % line_no)

func _on_LnzTextEdit_find_polygon(line_no):
	print("[STATUS] Node: _on_LnzTextEdit_find_polygon: flashing polygon %d" % line_no)
	if polygons_map.has(line_no):
		var polygon = polygons_map[line_no]
		polygon.flash()
		var polygon_data = lnz.polygons[line_no]
		if ball_map.has(polygon_data.ball1):
			ball_map[polygon_data.ball1].flash()
		if ball_map.has(polygon_data.ball2):
			ball_map[polygon_data.ball2].flash()
		if ball_map.has(polygon_data.ball3):
			ball_map[polygon_data.ball3].flash()
		if ball_map.has(polygon_data.ball4):
			ball_map[polygon_data.ball4].flash()
	else:
		print("[WARNING] Node: _on_LnzTextEdit_find_polygon: polygon %d not found in polygons_map" % line_no)

func _on_LnzTextEdit_find_move(line_no):
	print("[STATUS] Node: _on_LnzTextEdit_find_move: flashing move %d" % line_no)
	if line_no < lnz.moves.size():
		var move_data = lnz.moves[line_no]
		if ball_map.has(move_data.ball_no):
			ball_map[move_data.ball_no].flash()
		else:
			print("[WARNING] Node: _on_LnzTextEdit_find_move: ball %d from move not found" % move_data.ball_no)
	else:
		print("[WARNING] Node: _on_LnzTextEdit_find_move: move index %d out of bounds" % line_no)

func _on_LnzTextEdit_find_project_ball(line_no):
	print("[STATUS] Node: _on_LnzTextEdit_find_project_ball: flashing project ball %d" % line_no)
	if line_no < lnz.project_ball.size():
		var project_data = lnz.project_ball[line_no]
		if ball_map.has(project_data.fixed_ball):
			ball_map[project_data.fixed_ball].flash()
		if ball_map.has(project_data.project_ball):
			ball_map[project_data.project_ball].flash()
	else:
		print("[WARNING] Node: _on_LnzTextEdit_find_project_ball: index %d out of bounds" % line_no)

func _on_ToolsMenu_print_ball_colors():
	print("[STATUS] Node: _on_ToolsMenu_print_ball_colors: compiling and copying ball colors to clipboard")
	var ball_map_string = ""
	for b in ball_map:
		var ball = ball_map[b]
		var d
		if b < KeyBallsData.max_base_ball_num:
			d = lnz.balls[b]
		else:
			d = lnz.addballs[b]
		if "ball_no" in ball:
			var this_ball_string = (
				str(ball.ball_no)
				+ ",\t\t"
				+ str(ball.color_index)
				+ ",\t\t"
				+ str(d.group)
				+ ",\t\t"
				+ str(d.texture_id).replace("0", "3")
			)
			if ball_map_string != "":
				ball_map_string += "\n"
			ball_map_string += this_ball_string
			#print("[INFO] dog_generator: _on_ToolsMenu_print_ball_colors: " + this_ball_string)
	OS.set_clipboard(ball_map_string)
	print("[STATUS] Node: _on_ToolsMenu_print_ball_colors: successfully populated clipboard")

func _on_OptionButton_file_selected(file_name):
	generate_pet(file_name)

func _on_OptionButton_file_saved(file_name):
	generate_pet(file_name)


### MODEL GENERATION ###
# generate_pet
# set_skip_next_rebuild
# init_ball_data
# clear_lnz_data
# recompose_model
# init_visual_balls

func generate_pet(file_path):
	var t_start = OS.get_ticks_msec()
	_perf_texture_load_time = 0

	var full_rebuild = !_skip_next_rebuild
	_skip_next_rebuild = false

	var lnz_info = LnzParser.new(file_path)
	lnz = lnz_info
	lnz.get_species()

	if file_path != last_loaded_filepath:
		last_loaded_filepath = file_path
		current_variation_config = {}
		for section_name in lnz.sections_map:
			current_variation_config[section_name] = [0]
			if lnz.sections_map[section_name].has(1):
				current_variation_config[section_name].append(1)
	else:
		var old_config = current_variation_config.duplicate()
		current_variation_config = {}
		for section_name in lnz.sections_map:
			current_variation_config[section_name] = [0]

			if old_config.has(section_name):
				var old_ids = old_config[section_name]
				for id in old_ids:
					if id != 0 and lnz.sections_map[section_name].has(id):
						if not current_variation_config[section_name].has(id):
							current_variation_config[section_name].append(id)
				current_variation_config[section_name].sort()

	var variation_tree = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/Variations")
	if variation_tree:
		variation_tree.setup(self, lnz)

	KeyBallsData.species = lnz_info.species
	KeyBallsData.build_bodyarea_map()

	var comment_model = ""
	var comment_game = ""

	if lnz_info.species == 0:
		var f = File.new()
		if f.open(file_path, File.READ) == OK:
			for i in range(10):
				if f.eof_reached():
					break
				var line = f.get_line()
				if line.begins_with("; MODEL: "):
					comment_model = line.substr(9).strip_edges()
					print(comment_model)
					if console_log:
						console_log.log_message(
							"Auto-detected %s as game model from LNZ comment!" % comment_model
						)
				elif line.begins_with("; GAME: "):
					comment_game = line.substr(8).strip_edges()
					print(comment_game)
					if console_log:
						console_log.log_message(
							"Auto-detected %s as game palette from LNZ comment!" % comment_game
						)
			f.close()

	if game_option_button:
		if lnz_info.species == KeyBallsData.Species.BABY or comment_game == "BABYZ":
			game_option_button.select(1)  # Babyz
		else:
			game_option_button.select(0)  # Petz

	if lnz_info.species == 0:
		var selected_idx = bhd_option_button.selected
		if comment_model != "":
			init_ball_data(0, !full_rebuild, "res://resources/animations/" + comment_model + ".bhd")
		elif selected_idx != -1:
			var bhd_name = bhd_option_button.get_item_text(selected_idx)
			init_ball_data(0, !full_rebuild, "res://resources/animations/" + bhd_name)
		else:
			bhd_prompt_dialog.popup_centered()
			return
	else:
		init_ball_data(lnz_info.species, !full_rebuild)

	recompose_model()

	print("[TIME] dog_generator: generate_pet: model generation from BHD+LNZ completed in " + str(OS.get_ticks_msec() - t_start) + "ms")
	print("[TIME] dog_generator: generate_pet: texture loading completed in " + str(_perf_texture_load_time) + "ms")

func set_skip_next_rebuild(val: bool):
	_skip_next_rebuild = val

func init_ball_data(species, keep_visuals: bool = false, custom_bhd_path: String = ""):
	if not keep_visuals:
		_hidden_balls.clear()
		_hidden_lines.clear()
		_hidden_polygons.clear()
		_hidden_paintballs.clear()

	if t_pose_checkbox:
		t_pose_active = t_pose_checkbox.pressed

	clear_lnz_data(keep_visuals)

	var bhd_file = ""
	var bdt_prefix = ""

	if custom_bhd_path != "":
		bhd_file = custom_bhd_path
		bdt_prefix = custom_bhd_path.get_file().get_basename()
	elif species == KeyBallsData.Species.DOG:
		bhd_file = "res://resources/animations/DOG.bhd"
		bdt_prefix = "DOG"
	elif species == KeyBallsData.Species.CAT:
		bhd_file = "res://resources/animations/CAT.bhd"
		bdt_prefix = "CAT"
	elif species == KeyBallsData.Species.BABY:
		bhd_file = "res://resources/animations/BABY.bhd"
		bdt_prefix = "BABY"
	else:
		bhd_file = "res://resources/animations/CAT.bhd"
		bdt_prefix = "CAT"

	current_bdt_prefix = bdt_prefix
	bhd = BhdParser.new(bhd_file)

	if current_animation >= bhd.animation_ranges.size():
		current_animation = 0
		var anim_picker = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/AnimPicker")
		if anim_picker:
			anim_picker.text = "0"

	var anim_to_load = 0 if t_pose_active else current_animation

	var filename = bhd_file.get_file()
	for i in range(bhd_option_button.get_item_count()):
		if bhd_option_button.get_item_text(i) == filename:
			bhd_option_button.select(i)
			break

	emit_signal("bhd_loaded", bhd.animation_ranges.size())
	if bhd.animation_ranges.empty():
		print("[ERROR] dog_generator: init_ball_data: failed to load animations for BHD: ", bhd_file)
		return

	var first_anim_frames = bhd.get_frame_offsets_for(anim_to_load)

	if current_frame >= first_anim_frames.size():
		current_frame = 0

	var frame_to_use = 0 if t_pose_active else current_frame

	var bdt_filename = bdt_prefix + str(anim_to_load) + ".bdt"
	current_bdt = BdtParser.new(bdt_filename, first_anim_frames, bhd.num_balls)

	emit_signal("animation_loaded", first_anim_frames.size())

	for n in bhd.num_balls:
		var x = current_bdt.frames[frame_to_use][n]
		balls.append(BallData.new(bhd.ball_sizes[n], x.position, n, x.rotation))

	KeyBallsData.max_base_ball_num = bhd.num_balls

	if t_pose_active:
		symmetrize_skeleton()

func clear_lnz_data(keep_visuals: bool = false):
	# for ball in balls:
	# 	if ball != null:
	# 		ball.queue_free()
	balls.clear()

	if not keep_visuals:
		ball_map.clear()
		paintball_map.clear()
		polygons_map.clear()
		lines_map.clear()

		_hidden_balls.clear()
		_hidden_lines.clear()
		_hidden_polygons.clear()
		_hidden_paintballs.clear()

func recompose_model():
	# Clear LNZ data structures
	lnz.balls.clear()
	lnz.paintballs.clear()
	lnz.lines.clear()
	lnz.addballs.clear()
	lnz.omissions.clear()
	lnz.project_ball.clear()
	lnz.polygons.clear()
	lnz.moves.clear()
	lnz.texture_list.clear()
	lnz.custom_eyes.clear()
	lnz.whisker_connections.clear()
	lnz.no_texture_rotate.clear()
	lnz.quadrant_balls.clear()

	# Parse Sections
	var ordered_sections = [
		"Texture List",
		"Palette",
		"No Texture Rotate",
		"Default Scales",
		"Leg Extension",
		"Body Extension",
		"Face Extension",
		"Ear Extension",
		"Head Enlargement",
		"Feet Enlargement",
		"Z Shade Slope",
		"256 Eyelid Color",
		"Eyelash Info",
		"Eyes",
		"Whiskers",
		"Ballz Info",
		"Add Ball",
		"Linez",
		"Polygons",
		"Ball Size Override",
		"Fuzz Override",
		"Add Ball Override",
		"Color Info Override",
		"Outline Color Override",
		"Omissions"
	]

	var section_methods = {
		"Texture List": "get_texture_list",
		"Palette": "get_palette",
		"No Texture Rotate": "get_no_texture_rotate",
		"Default Scales": "get_default_scales",
		"Leg Extension": "get_leg_extensions",
		"Body Extension": "get_body_extension",
		"Face Extension": "get_face_extension",
		"Ear Extension": "get_ear_extension",
		"Head Enlargement": "get_head_enlargement",
		"Feet Enlargement": "get_feet_enlargement",
		"Omissions": "get_omissions",
		"Linez": "get_lines",
		"Polygons": "get_polygons",
		"Ballz Info": "get_balls",
		"Add Ball": "get_addballs",
		"256 Eyelid Color": "get_eyelid_color",
		"Eyelash Info": "get_eyelash_info",
		"Eyes": "get_eyes",
		"Whiskers": "get_whiskers",
		"Z Shade Slope": "get_z_shade_slope",
		"Ball Size Override": "get_ball_size_override",
		"Fuzz Override": "get_fuzz_override",
		"Add Ball Override": "get_add_ball_override",
		"Color Info Override": "get_color_info_override",
		"Outline Color Override": "get_outline_color_override"
	}

	for section in ordered_sections:
		if current_variation_config.has(section):
			var method = section_methods[section]
			var reader = lnz.compile_section(section, current_variation_config[section])
			lnz.call(method, reader)

	if current_variation_config.has("Paint Ballz"):
		lnz.parse_paintballs(lnz.compile_section("Paint Ballz", current_variation_config["Paint Ballz"]))

	if current_variation_config.has("Move"):
		lnz.parse_moves(lnz.compile_section("Move", current_variation_config["Move"]))

	if current_variation_config.has("Project Ball"):
		lnz.get_project_balls(lnz.compile_section("Project Ball", current_variation_config["Project Ball"]))

	init_visual_balls(lnz, true)
	emit_signal("palette_changed", lnz.palette)

func init_visual_balls(lnz_info: LnzParser, new_create: bool = false):
	if new_create || lnz_info.species != KeyBallsData.species:
		_hidden_balls.clear()
		_hidden_lines.clear()
		_hidden_polygons.clear()
		_hidden_paintballs.clear()
		
		_ball_to_lines_map.clear()
		_ball_to_polygons_map.clear()
		
		if KeyBallsData.species != lnz_info.species:
			KeyBallsData.species = lnz_info.species
			KeyBallsData.build_bodyarea_map()

	is_babyz_mode = false

	if (lnz_info.species == KeyBallsData.Species.BABY):
		is_babyz_mode = true
	elif (game_option_button and game_option_button.selected == 1):
		is_babyz_mode = true

	var pal_texture = null
	var default_palette = LnzLiveUtils.DEFAULT_PALETTE

	if is_babyz_mode:
		default_palette = LnzLiveUtils.BABYZ_PALETTE

	if lnz_info.palette != null and lnz_info.palette != "":
		pal_texture = load_palette_resource(lnz_info.palette, is_babyz_mode)

	if pal_texture == null:
		pal_texture = default_palette

	current_palette_texture = pal_texture

	var base_balls_temp = {}
	for b in balls:
		# Create a fresh copy of the BallData so apply_sizes doesn't ruin the original animation data
		base_balls_temp[b.ball_no] = BallData.new(b.size, b.position, b.ball_no, b.rotation)
	var collated_data = base_balls_temp

	# dumb code - duplicate the lnz info to prevent movements being applied multiple times
	var addballs = {}
	for k in lnz_info.addballs:
		var a = lnz_info.addballs[k]
		var final_size = a.size
		if a.anchor_ball != -1 and base_balls_temp.has(a.anchor_ball):
			var anchor_bhd_size = base_balls_temp[a.anchor_ball].size
			final_size = anchor_bhd_size + a.size

		addballs[k] = AddBallData.new(
			a.base,
			a.ball_no,
			final_size,
			a.position,
			a.color_index,
			a.outline_color_index,
			a.outline,
			a.fuzz,
			a.z_add,
			a.group,
			a.body_area,
			a.texture_id,
			a.add_group,
			a.anchor_ball
		)

	var paintballs = {}

	for k in lnz_info.paintballs:
		var ar = lnz_info.paintballs[k]
		paintballs[k] = ar.duplicate()
		var i = 0
		for a in ar:
			paintballs[k][i] = {
				base = a.base,
				size = a.size,
				normalised_position = a.normalised_position,
				color_index = a.color_index,
				outline = a.outline,
				outline_color_index = a.outline_color_index,
				fuzz = a.fuzz,
				z_add = a.z_add,
				group = a.group,
				texture_id = a.texture_id,
				anchored = a.anchored
			}
			i += 1

	collated_data = {balls = collated_data, addballs = addballs, paintballs = paintballs}
	collated_data = munge_balls(collated_data, lnz_info)
	collated_data = apply_extensions(collated_data, lnz_info)
	collated_data = apply_sizes(collated_data, lnz_info)
	collated_data.omissions = lnz_info.omissions

	generate_balls(
		collated_data,
		lnz_info.species,
		lnz_info.texture_list,
		current_palette_texture,
		new_create,
		lnz_info.no_texture_rotate
	)

	if new_create:
		call_deferred("_finish_dependent_geometry", new_create)
	else:
		apply_projections()
		generate_polygons(
			lnz_info.polygons,
			lnz_info.species,
			current_palette_texture,
			new_create,
			lnz_info.texture_list
		)
		generate_lines(lnz_info.lines, lnz_info.species, current_palette_texture, new_create)
		generate_whiskers(new_create)
		_restore_hidden_states()


### TEXTURES & PALETTES ###
# load_texture
# load_texture_from_list
# clear_texture_cache_for
# clear_texture_cache
# generate_color_icon
# load_palette_resource

func load_texture(texture_filename: String, preloader: ResourcePreloader) -> Texture:
	var t_start = OS.get_ticks_msec()
	if _texture_cache.has(texture_filename):
		_perf_texture_load_time += (OS.get_ticks_msec() - t_start)
		return _texture_cache[texture_filename]

	var texture = null
	var base_name = texture_filename.get_basename()
	var extension = texture_filename.get_extension()

	# Check atlas manifest first
	var atlas_key = texture_filename.get_basename() # e.g. "hair10" from "hair10.bmp"

	# Try exact match or case-insensitive match against manifest keys
	var manifest_entry = null
	if _atlas_manifest.has(atlas_key):
		manifest_entry = _atlas_manifest[atlas_key]
	else:
		# Search case-insensitive
		for key in _atlas_manifest.keys():
			if key.to_lower() == atlas_key.to_lower():
				manifest_entry = _atlas_manifest[key]
				break

	if manifest_entry:
		var atlas_file = manifest_entry["babyz_atlas"] if is_babyz_mode else manifest_entry["petz_atlas"]
		# Fix extension .bmp -> .png for atlas file
		if atlas_file.to_lower().ends_with(".bmp"):
			atlas_file = atlas_file.get_basename() + ".png"

		var atlas_path = "res://resources/texture_atlas/" + atlas_file
		var atlas_tex = null

		if _atlas_textures.has(atlas_path):
			atlas_tex = _atlas_textures[atlas_path]
		elif ResourceLoader.exists(atlas_path):
			atlas_tex = ResourceLoader.load(atlas_path)
			_atlas_textures[atlas_path] = atlas_tex

		if atlas_tex:
			var region = Rect2(
				manifest_entry["x"], manifest_entry["y"], manifest_entry["w"], manifest_entry["h"]
			)
			texture = AtlasTexture.new()
			texture.atlas = atlas_tex
			texture.region = region

			_texture_cache[texture_filename] = texture
			print("[INFO] dog_generator: load_texture: loaded atlas texture: " + texture_filename)
			_perf_texture_load_time += (OS.get_ticks_msec() - t_start)
			return texture
		else:
			print("[WARNING] dog_generator: load_texture: texture atlas file not found: " + atlas_path)

	print("[INFO] dog_generator: load_texture: loading individual texture: " + texture_filename)
	var filename_variants = []
	filename_variants.append(texture_filename)
	filename_variants.append(texture_filename.to_upper())
	filename_variants.append(texture_filename.to_lower())
	filename_variants.append(base_name + "." + extension.to_upper())
	filename_variants.append(base_name + "." + extension.to_lower())
	filename_variants.append(base_name.to_upper() + "." + extension)
	filename_variants.append(base_name.to_lower() + "." + extension)
	filename_variants.append(base_name.to_upper() + "." + extension.to_upper())
	filename_variants.append(base_name.to_lower() + "." + extension.to_lower())

	var deduped = []
	for v in filename_variants:
		if not v in deduped:
			deduped.append(v)
	filename_variants = deduped

	# ALL MODES + USER TEXTURE: exact 8-bit index parsing
	if texture == null:
		var loaded_path = ""
		var dir = Directory.new()
		for variant in filename_variants:
			if dir.file_exists("user://resources/textures/" + variant):
				loaded_path = "user://resources/textures/" + variant
				break
			elif dir.file_exists("res://resources/textures/" + variant):
				loaded_path = "res://resources/textures/" + variant
				break

		if loaded_path != "":
			var raw_bmp_data = LnzLiveUtils.load_raw_8bit_bmp(loaded_path, is_babyz_mode)
			if raw_bmp_data.has("data"):
				var w = raw_bmp_data["w"]
				var h = raw_bmp_data["h"]
				var data = raw_bmp_data["data"]
				var img = Image.new()
				img.create_from_data(w, h, false, Image.FORMAT_R8, data)
				texture = ImageTexture.new()
				texture.create_from_image(img, 0)
				print("[INFO] dog_generator: CPU-baked exact index map from binary: " + loaded_path)
	
	# FALLBACK: native loader
	if texture == null:
		for variant in filename_variants:
			var resource_path = "res://resources/textures/" + variant
			var user_resource_path = "user://resources/textures/" + variant

			if ResourceLoader.exists(resource_path):
				texture = ResourceLoader.load(resource_path)
				break
			elif ResourceLoader.exists(user_resource_path):
				texture = ResourceLoader.load(user_resource_path)
				break

	# PRELOADER FALLBACK
	if texture == null:
		if preloader.has_resource(texture_filename.to_lower()):
			texture = preloader.get_resource(texture_filename.to_lower())

	_texture_cache[texture_filename] = texture
	_perf_texture_load_time += (OS.get_ticks_msec() - t_start)
	
	return texture

func load_texture_from_list(texture_id: int, texture_list: Array) -> Texture:
	if texture_id < 0 or texture_id >= texture_list.size():
		return null

	var tex_info = texture_list[texture_id]
	if tex_info.has("filename"):
		var texture_filename = tex_info.filename
		return load_texture(texture_filename, preloader)
	return null

func clear_texture_cache_for(filename: String):
	if _texture_cache.has(filename):
		_texture_cache.erase(filename)

func clear_texture_cache():
	_texture_cache.clear()
	print("[STATUS] dog_generator: clear_texture_cache: texture cache cleared for model refresh")

func generate_color_icon(color_index: int) -> ImageTexture:
	if not current_palette_texture:
		return null

	if color_index < 0 or color_index > 255:
		return null

	var img = current_palette_texture.get_data()
	if not img:
		return null

	img.lock()
	var color = img.get_pixel(color_index, 0)
	img.unlock()

	var icon_img = Image.new()
	icon_img.create(16, 16, false, Image.FORMAT_RGBA8)
	icon_img.fill(color)

	var tex = ImageTexture.new()
	tex.create_from_image(icon_img)
	return tex

func load_palette_resource(palette_name, is_babyz_mode: bool) -> Texture:
	var pal_texture: Texture = null
	var default_palette = LnzLiveUtils.DEFAULT_PALETTE

	if is_babyz_mode:
		default_palette = LnzLiveUtils.BABYZ_PALETTE

	if palette_name != null and palette_name != "":
		var user_res_path = "user://resources/palettes".plus_file(palette_name)
		var res_res_path = "res://resources/palettes".plus_file(palette_name)

		if ResourceLoader.exists(user_res_path):
			pal_texture = ResourceLoader.load(user_res_path)
		elif ResourceLoader.exists(res_res_path):
			pal_texture = ResourceLoader.load(res_res_path)
		else:
			var lookup_key = "palette_" + palette_name.to_lower()
			if preloader.has_resource(lookup_key):
				pal_texture = preloader.get_resource(lookup_key)

	if pal_texture == null:
		pal_texture = default_palette

	return pal_texture


### RENDERING & GEOMETRY ###
# generate_balls
# generate_polygons
# generate_lines
# generate_whiskers
# _finish_dependent_geometry
# _update_paintball_transforms
# _update_whisker_position
# _update_eyelids
# restore_ball_visual_states

func generate_balls(all_ball_data: Dictionary, species: int, texture_list: Array, palette, new_create: bool, no_texture_rotate := []):
	var t_start = OS.get_ticks_msec()

	var ball_data = all_ball_data.balls
	var addball_data = all_ball_data.addballs
	var paintball_data = all_ball_data.paintballs
	var omissions = all_ball_data.omissions

	var root = get_root()
	var balls_parent = root.get_node("petholder/balls")
	var paintballs_parent = root.get_node("petholder/paintballs")
	var addballs_parent = root.get_node("petholder/addballs")

	# Figure out belly position
	var belly_position = Vector3.ZERO
	if species == KeyBallsData.Species.DOG and ball_data.has(KeyBallsData.belly_dog):
		belly_position = ball_data[KeyBallsData.belly_dog].position
	elif species == KeyBallsData.Species.CAT and ball_data.has(KeyBallsData.belly_cat):
		belly_position = ball_data[KeyBallsData.belly_cat].position
	elif species == KeyBallsData.Species.BABY and ball_data.has(KeyBallsData.belly_bab):
		belly_position = ball_data[KeyBallsData.belly_bab].position
	elif ball_data.size() > 0:
		belly_position = ball_data[ball_data.keys()[0]].position

	belly_position.y *= -1
	belly_position *= pixel_world_size

	var eyes = {}
	if lnz != null and not lnz.custom_eyes.empty():
		eyes = lnz.custom_eyes
	else:
		if species == KeyBallsData.Species.DOG:
			eyes = KeyBallsData.eyes_dog
		elif species == KeyBallsData.Species.CAT:
			eyes = KeyBallsData.eyes_cat
		else:
			eyes = KeyBallsData.eyes_bab

	# --- INITIALIZE ---
	if new_create:
		for c in balls_parent.get_children(): c.queue_free()
		for c in paintballs_parent.get_children(): c.queue_free()
		for c in addballs_parent.get_children(): c.queue_free()

		ball_map.clear()
		paintball_map.clear()
		eyelid_dir_map.clear()

		for key in ball_data:
			ball_map[key] = paintball_scene.instance() if key in eyes else ball_scene.instance()
		
		for key in addball_data:
			ball_map[key] = ball_scene.instance()
		
		for key in paintball_data:
			var p_arr = []
			for i in range(paintball_data[key].size()): 
				p_arr.append(paintball_scene.instance())
			paintball_map[key] = p_arr

	# --- BASE BALLZ ---
	for key in ball_data:
		if key in eyes:
			continue # skip eye balls, handle in paintball loop
			
		var data = ball_data[key]
		var node = ball_map[key] 
		var is_omitted = omissions.has(key)
		
		if new_create:
			node.add_to_group("balls")
			node.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
			node.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
			node.connect("ball_selected", self, "signal_ball_selected")
			
			balls_parent.add_child(node)
			#node.set_owner(root)
			if no_texture_rotate.has(int(key)):
				node.set_tile_texture(false)
				if lnz.quadrant_balls.has(int(key)):
					node.use_quadrants = true
			else:
				node.set_tile_texture(true)

			node.set_species(species, is_babyz_mode)

		node.ball_no = data.ball_no
		node.pet_center = belly_position

		var pos_n = data.position
		pos_n.y *= -1.0
		node.transform.origin = pos_n * pixel_world_size
		node.rotation_degrees = data.rotation

		if new_create:
			node.color_index = data.color_index
			node.outline_color_index = data.outline_color_index
			node.ball_size = get_real_ball_size(data.size)
			node.outline = data.outline
			node.fuzz_amount = clamp(data.fuzz / 2, 0, 5)
			node.palette = palette

			if data.texture_id >= 0 and data.texture_id < texture_list.size():
				var tex_info = texture_list[data.texture_id]
				var tex = load_texture_from_list(data.texture_id, texture_list)
				if tex:
					node.texture = tex
					node.transparent_color = tex_info.transparent_color
					if tex_info.has("texture_size") and tex_info.texture_size != null:
						node.texture_size = tex_info.texture_size

		if is_omitted:
			node.omitted = true
			node.visible_override = draw_omitted_balls
		else:
			if !draw_balls: 
				node.visible_override = false

	# --- ADD BALLZ ---
	for key in addball_data:
		var data = addball_data[key]
		var node = ball_map[key]
		var base_node = ball_map.get(data.base)
		
		if not base_node: continue 

		if new_create:
			base_node.add_child(node)
			#node.set_owner(root)
			node.add_to_group("addballs")
			node.z_add = data.size / 10.0
			node.ball_size = data.size
			node.ball_no = data.ball_no
			node.base_ball_no = data.base

			node.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
			node.connect("ball_selected", self, "signal_ball_selected")
			node.connect("ball_deleted", self, "signal_ball_deleted")

			if no_texture_rotate.has(int(key)):
				node.set_tile_texture(false)
				if lnz.quadrant_balls.has(int(key)):
					node.use_quadrants = true
			else:
				node.set_tile_texture(true)

			node.set_species(species, is_babyz_mode)

			if is_special_ball(species, data.ball_no):
				node.add_to_group("special_balls")

			node.color_index = data.color_index
			node.outline_color_index = data.outline_color_index
			node.outline = data.outline
			node.fuzz_amount = clamp(data.fuzz / 2, 0, 5)
			node.palette = palette

			if data.texture_id >= 0 and data.texture_id < texture_list.size():
				var tex_info = texture_list[data.texture_id]
				var tex = load_texture_from_list(data.texture_id, texture_list)
				if tex:
					node.texture = tex
					node.transparent_color = tex_info.transparent_color
					if tex_info.has("texture_size") and tex_info.texture_size != null:
						node.texture_size = tex_info.texture_size

		var add_pos = data.position
		add_pos.y *= -1.0
		node.transform.origin = add_pos * pixel_world_size

		if omissions.has(key):
			node.omitted = true
			if draw_omitted_balls: node.visible_override = true
			else: 
				node.visible_override = false
				node.call_deferred("set_visible", false)
		else:
			if !draw_addballs: node.visible_override = false
			if node.is_in_group("special_balls"):
				node.call_deferred("set_visible", draw_special_balls)

	# --- EYES ---
	for key in eyes:
		var base_key = eyes[key]
		var node = ball_map.get(key)
		var base_node = ball_map.get(base_key)
		
		var data = ball_data.get(key)
		if not data: data = addball_data.get(key)
		
		var base_data = ball_data.get(base_key) 
		if not base_data: 
			base_data = addball_data.get(base_key)
			
		if not node or not base_node or not data or not base_data: continue 

		var is_omitted = omissions.has(key)
		if omissions.has(base_key): is_omitted = true 
		
		if new_create:
			node.add_to_group("balls")
			node.ball_no = data.ball_no
			
			var base_z = base_node.z_add if "z_add" in base_node else 0.0
			node.z_add = (base_z * 20.0) + 10.0
			
			node.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
			node.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
			node.connect("ball_selected", self, "signal_ball_selected")
			node.set_species(species, is_babyz_mode)

			base_node.add_child(node)
			
			node.set_surface_normal(Vector3(0, 0, -1))
			#node.set_owner(root)

			if no_texture_rotate.has(int(key)):
				node.set_tile_texture(false)
				if lnz.quadrant_balls.has(int(key)):
					node.use_quadrants = true
				# node.set_tile_texture(!no_texture_rotate.has(int(key)))

			var eye_dir = -1.0 if base_data.position.x < 0 else 1.0
			eyelid_dir_map[base_key] = eye_dir

			if eyelid_mode == 1:
				base_node.set_eyelid_color(-1)
			else:
				base_node.set_eyelid_color(lnz.eyelid_color)
				base_node.set_eyelid_rotation(eye_dir * deg2rad(EYELID_TILTS[eyelid_mode]))

			if lnz.eyelash_lengths.size() > 0:
				base_node.set_eyelash_lengths(lnz.eyelash_lengths)
				base_node.set_eyelash_angle(lnz.eyelash_angle)
				base_node.set_eyelash_spacing(lnz.eyelash_spacing)
				base_node.set_eyelash_color(lnz.eyelash_color if lnz.eyelash_color != -1 else lnz.eyelid_color)

		node.base_ball_size = base_data.size
		
		var base_pos = base_data.position
		base_pos.y *= -1.0
		node.base_ball_position = base_pos * pixel_world_size

		# Lock the iris to the front of the eyeball
		var radius = (base_data.size / 2.0) * pixel_world_size
		node.transform.origin = Vector3(0, 0, -radius)
		node.rotation_degrees = data.rotation

		# Apply Visuals
		if new_create:
			node.color_index = data.color_index
			node.outline_color_index = data.outline_color_index
			node.ball_size = get_real_ball_size(data.size)
			node.outline = data.outline
			node.fuzz_amount = clamp(data.fuzz / 2, 0, 5)
			node.palette = palette

			if data.texture_id >= 0 and data.texture_id < texture_list.size():
				var tex_info = texture_list[data.texture_id]
				var tex = load_texture_from_list(data.texture_id, texture_list)
				if tex:
					node.texture = tex
					node.transparent_color = tex_info.transparent_color
					if tex_info.has("texture_size") and tex_info.texture_size != null:
						node.texture_size = tex_info.texture_size

		if is_omitted:
			node.omitted = true
			node.visible_override = draw_omitted_balls
		else:
			if !draw_balls: 
				node.call_deferred("set_visible", false)

	# --- PAINTBALLS ---
	for key in paintball_data:
		var base_node = ball_map.get(key)
		var base_data = ball_data.get(key)
		if not base_data: base_data = addball_data.get(key)
		
		if not base_node or not base_data: 
			for pb in paintball_map[key]:
				if is_instance_valid(pb):
					pb.queue_free()
			continue

		var paint_list = paintball_data[key].duplicate()
		paint_list.invert() 

		var count = 0
		var is_omitted = omissions.has(key)
		var base_z = base_node.z_add if "z_add" in base_node else 0.0

		for pb_data in paint_list:
			var node = paintball_map[key][count]
			var final_size = base_data.size * (pb_data.size / 100.0)
			final_size -= 1 - fmod(final_size, 2)

			if new_create:
				base_node.add_child(node)
				#node.set_owner(root)
				node.add_to_group("paintballs")
				
				node.connect("paintball_mouse_enter", self, "signal_paintball_mouse_enter")
				node.connect("paintball_mouse_exit", self, "signal_paintball_mouse_exit")
				node.set_species(species, is_babyz_mode)

				var pb_normal = pb_data.normalised_position
				pb_normal.y *= -1.0
				node.set_surface_normal(pb_normal)

				node.color_index = pb_data.color_index
				node.outline_color_index = pb_data.outline_color_index
				node.outline = pb_data.outline
				node.fuzz_amount = clamp(pb_data.fuzz / 2, 0, 5)
				node.palette = palette

				if pb_data.texture_id >= 0 and pb_data.texture_id < texture_list.size():
					var tex_info = texture_list[pb_data.texture_id]
					var tex = load_texture_from_list(pb_data.texture_id, texture_list)
					if tex:
						node.texture = tex
						node.transparent_color = tex_info.transparent_color
						if tex_info.has("texture_size") and tex_info.texture_size != null:
							node.texture_size = tex_info.texture_size

			#node.base_ball_position = base_node.transform.origin
			node.base_ball_position = base_node.global_transform.origin
			
			node.transform.origin = (pb_data.normalised_position * Vector3(1, -1, 1) * (base_data.size / 2.0) * pixel_world_size)
			node.ball_size = final_size
			node.base_ball_size = base_data.size
			node.z_add = (base_z * 20.0) + 10.0 + float(count)
			node.base_ball_no = pb_data.base

			if is_omitted:
				if draw_omitted_balls: node.visible_override = true
				else:
					node.call_deferred("set_visible", false)
					node.call_deferred("set_visible", false)
			elif !draw_paintballs:
				node.call_deferred("set_visible", false)
				
			count += 1

	# Update global positions for ballz in paintballz visual properties
	for key in ball_map.keys():
		var base_node = ball_map[key]
		if is_instance_valid(base_node) and base_node.is_inside_tree():
			var global_pos = base_node.global_transform.origin
			_orig_world_pos[key] = global_pos
			
			for eye_key in eyes:
				if eyes[eye_key] == key:
					var eye_node = ball_map.get(eye_key)
					if is_instance_valid(eye_node):
						eye_node.base_ball_position = global_pos
			
			if paintball_map.has(key):
				for pb_node in paintball_map[key]:
					if is_instance_valid(pb_node):
						pb_node.base_ball_position = global_pos
	# print("[TIME] dog_generator: generate_balls took " + str(OS.get_ticks_msec() - t_start) + "ms")

func generate_polygons(polygon_data: Array, species: int, palette, new_create: bool, texture_list: Array):
	var t_start = OS.get_ticks_msec()

	#print("[INFO] dog_generator: generate_polygons: generating polygons")
	#print("[INFO] dog_generator: generate_polygons: polygon data size:", polygon_data.size())
	var root = get_root()
	var parent = root.get_node("petholder/polygons")
	#print("[INFO] dog_generator: generate_polygons: parent node found:", parent)

	if new_create:
		for c in parent.get_children():
			# parent.remove_child(c)
			c.queue_free()
		polygons_map = {}

	var i = 0
	for polygon in polygon_data:
		var point1 = ball_map.get(polygon.ball1)
		var point2 = ball_map.get(polygon.ball2)
		var point3 = ball_map.get(polygon.ball3)
		var point4 = ball_map.get(polygon.ball4)

		# Check if the points exist
		if point1 == null or point2 == null or point3 == null or point4 == null or not is_instance_valid(point1) or not is_instance_valid(point2) or not is_instance_valid(point3) or not is_instance_valid(point4):
			print(
				(
					"Could not make a polygon between "
					+ str(polygon.ball1)
					+ ", "
					+ str(polygon.ball2)
					+ ", "
					+ str(polygon.ball3)
					+ ", "
					+ str(polygon.ball4)
				)
			)
			continue

		#print("[INFO] dog_generator: generate_polygons: creating polygon between points:", polygon.ball1, polygon.ball2, polygon.ball3, polygon.ball4)

		# Create or retrieve the visual polygon
		var visual_polygon
		if new_create:
			visual_polygon = polygon_scene.instance()
			visual_polygon.add_to_group("polygons")
			parent.add_child(visual_polygon)
			visual_polygon.set_owner(root)
		else:
			visual_polygon = polygons_map[i]

		# Set positions for the polygon's 4 vertices
		#print("[INFO] dog_generator: generate_polygons: positioning polygon with vertices at: ", point1.global_transform.origin, point2.global_transform.origin, point3.global_transform.origin, point4.global_transform.origin)
		visual_polygon.ball_world_pos1 = point1.global_transform.origin
		visual_polygon.ball_world_pos2 = point2.global_transform.origin
		visual_polygon.ball_world_pos3 = point3.global_transform.origin
		visual_polygon.ball_world_pos4 = point4.global_transform.origin

		if new_create:
			# Check for texture
			if (
				"texture_id" in polygon
				and polygon.texture_id != null
				and not str(polygon.texture_id).empty()
			):
				visual_polygon.texture = load_texture_from_list(polygon.texture_id, texture_list)
			else:
				# If no texture is defined, default to first ball
				visual_polygon.texture = point1.texture
			#visual_polygon.species = species
			visual_polygon.set_species(species, is_babyz_mode)
			visual_polygon.set_render_flat_colors(render_flat_colors_global)
			visual_polygon.transparent_color = point1.transparent_color
			#print("[INFO] dog_generator: generate_polygons: polygon color and texture set")

			visual_polygon.palette = point1.palette

			if polygon.color == -1:
				visual_polygon.color_index = point1.color_index
			else:
				visual_polygon.color_index = polygon.color
			#print("[INFO] dog_generator: generate_polygons: polygon color set to: ", visual_polygon.color_index)

			# Log left and right edge colors
			#print("[INFO] dog_generator: generate_polygons: setting edge colors for polygon")
			if polygon.l_edge_color == -1:
				visual_polygon.l_edge_color = point1.color_index
			else:
				visual_polygon.l_edge_color = polygon.l_edge_color
			#print("[INFO] dog_generator: generate_polygons: Left edge color: ", visual_polygon.l_edge_color)

			if polygon.r_edge_color == -1:
				visual_polygon.r_edge_color = point1.color_index
			else:
				visual_polygon.r_edge_color = polygon.r_edge_color
			#print("[INFO] dog_generator: generate_polygons: Right edge color: ", visual_polygon.r_edge_color)

		# Set other polygon properties like fuzz
		visual_polygon.fuzz_amount = clamp(polygon.fuzz / 2, 0, 5)
		#print("[INFO] dog_generator: generate_polygons: polygon fuzz amount set to:", visual_polygon.fuzz_amount)

		var special_poly = (
			is_special_ball(species, polygon.ball1)
			or is_special_ball(species, polygon.ball2)
			or is_special_ball(species, polygon.ball3)
			or is_special_ball(species, polygon.ball4)
		)
		if special_poly:
			visual_polygon.add_to_group("special_balls")
			visual_polygon.visible = draw_special_balls
		else:
			visual_polygon.visible = draw_polygons

		polygons_map[i] = visual_polygon

		var poly_balls = [polygon.ball1, polygon.ball2, polygon.ball3, polygon.ball4]
		for b_no in poly_balls:
			if not _ball_to_polygons_map.has(b_no):
				_ball_to_polygons_map[b_no] = []
			_ball_to_polygons_map[b_no].append(i)

		i += 1
	# print("[TIME] dog_generator: generate_polygons took " + str(OS.get_ticks_msec() - t_start) + "ms")

func generate_lines(line_data: Array, species: int, palette, new_create: bool):
	var t_start = OS.get_ticks_msec()

	var root = get_root()
	var parent = root.get_node("petholder/lines")
	if new_create:
		for c in parent.get_children():
			# parent.remove_child(c)
			c.queue_free()
		lines_map = {}

	var i = 0
	for line in line_data:
		var start = ball_map.get(line.start)
		var end = ball_map.get(line.end)

		if start == null or end == null or not is_instance_valid(start) or not is_instance_valid(end):
			print("[WARNING] dog_generator: generate_lines: could not make a line between " + str(line.start) + " and " + str(line.end))
			continue

		var omissions = lnz.omissions as Dictionary
		if omissions.has(line.start) or omissions.has(line.end):
			continue

		var visual_line
		if new_create:
			visual_line = line_scene.instance()
			visual_line.add_to_group("lines")
		else:
			visual_line = lines_map[i]

		var start_pos = start.global_transform.origin
		var target_pos = end.global_transform.origin
		var distance = (target_pos - start_pos).length()
		var middle_point = lerp(start.global_transform.origin, end.global_transform.origin, 0.5)

		# This check handles zero-length lines (start_pos == target_pos)
		if target_pos == middle_point:
			visual_line.global_transform.origin = middle_point
			visual_line.rotation_degrees.x += 90
			visual_line.scale.y = distance
		else:
			# Check if the line is vertical to avoid error with Vector3.UP
			var look_at_direction = (target_pos - middle_point).normalized()
			var up_vector = Vector3.UP
			var dot = look_at_direction.dot(Vector3.UP)

			if abs(dot) > 0.9999:
				up_vector = Vector3.FORWARD

			visual_line.look_at_from_position(middle_point, target_pos, up_vector)

			visual_line.rotation_degrees.x += 90
			visual_line.scale.y = distance

		if new_create:
			visual_line.texture = start.texture
			#visual_line.species = species
			visual_line.set_species(species, is_babyz_mode)
			visual_line.set_render_flat_colors(render_flat_colors_global)
			visual_line.transparent_color = start.transparent_color
			visual_line.palette = start.palette

			visual_line.full_outline = line.full_outline
			visual_line.draw_order = line.draw_order

			if line.color_index == -1:
				visual_line.color_index = start.color_index
			else:
				visual_line.color_index = line.color_index
			if line.r_color_index == -1:
				visual_line.r_color_index = start.color_index
			else:
				visual_line.r_color_index = line.r_color_index
			if line.l_color_index == -1:
				visual_line.l_color_index = start.color_index
			else:
				visual_line.l_color_index = line.l_color_index

		visual_line.ball_world_pos1 = start_pos
		visual_line.ball_world_pos2 = target_pos
		visual_line.fuzz_amount = clamp(line.fuzz / 2, 0, 5)
		var final_line_width = Vector2(start.ball_size, end.ball_size)
		final_line_width = final_line_width * (Vector2(line.s_thick, line.e_thick) / 100)
		visual_line.line_widths = final_line_width

		lines_map[i] = visual_line

		for b_no in [line.start, line.end]:
			if not _ball_to_lines_map.has(b_no):
				_ball_to_lines_map[b_no] = []
			_ball_to_lines_map[b_no].append(i)

		var special_line = (
			is_special_ball(species, line.start)
			or is_special_ball(species, line.end)
		)
		if special_line:
			visual_line.add_to_group("special_balls")
			visual_line.visible = draw_special_balls
		else:
			visual_line.visible = draw_lines

		if new_create:
			parent.add_child(visual_line)
			visual_line.set_owner(root)

		i += 1
	# print("[TIME] dog_generator: generate_lines took " + str(OS.get_ticks_msec() - t_start) + "ms")

func generate_whiskers(new_create: bool):
	if lnz.species != KeyBallsData.Species.CAT:
		# print("[STATUS] Node: generate_whiskers: skipping, species is not CAT")
		return

	var root = get_root()
	var parent = root.get_node("petholder/lines")

	if new_create:
		for c in get_tree().get_nodes_in_group("whisker_lines"):
			c.queue_free()

	var used_whiskers = {}
	for connection in lnz.whisker_connections:
		used_whiskers[int(connection.start)] = true

	var cat_whiskers = KeyBallsData.cat_body_part_symmetry.Head.Whiskers
	var default_whisker_indices = cat_whiskers.left + cat_whiskers.right

	for b_no in default_whisker_indices:
		if not used_whiskers.has(b_no):
			hide_ball(b_no)

	if lnz.whisker_connections.empty():
		return

	var i = 0
	for connection in lnz.whisker_connections:
		var start_node = ball_map.get(connection.start)
		var end_node = ball_map.get(connection.end)

		if not start_node or not end_node:
			continue

		var visual_line
		if new_create:
			visual_line = line_scene.instance()
			visual_line.add_to_group("lines")
			visual_line.add_to_group("whisker_lines")
			parent.add_child(visual_line)
			visual_line.set_owner(root)

			visual_line.texture = start_node.texture
			visual_line.palette = start_node.palette
			visual_line.color_index = start_node.color_index
			visual_line.l_color_index = start_node.color_index
			visual_line.r_color_index = start_node.color_index
			visual_line.line_widths = Vector2(start_node.ball_size, 1.0)
		else:
			var whiskers = get_tree().get_nodes_in_group("whisker_lines")
			if i < whiskers.size():
				visual_line = whiskers[i]

		if visual_line:
			_update_whisker_position(visual_line, start_node, end_node)
		i += 1

func _finish_dependent_geometry(new_create: bool):
	apply_projections()
	_update_paintball_transforms()
	generate_polygons(lnz.polygons, lnz.species, lnz.palette, new_create, lnz.texture_list)
	generate_lines(lnz.lines, lnz.species, lnz.palette, new_create)
	generate_whiskers(new_create)
	_restore_hidden_states()

func _update_paintball_transforms():
	for key in paintball_map:
		var base_node = ball_map.get(key)
		if not is_instance_valid(base_node): continue
		
		var new_global_pos = base_node.global_transform.origin
		
		for pb_node in paintball_map[key]:
			if is_instance_valid(pb_node):
				pb_node.base_ball_position = new_global_pos

func _update_whisker_position(visual_line: Spatial, start_node: Spatial, end_node: Spatial):
	var start_pos = start_node.global_transform.origin
	var target_pos = end_node.global_transform.origin
	var middle_point = lerp(start_pos, target_pos, 0.5)

	visual_line.ball_world_pos1 = start_pos
	visual_line.ball_world_pos2 = target_pos

	visual_line.look_at_from_position(middle_point, target_pos, Vector3.UP)
	visual_line.rotation_degrees.x += 90
	visual_line.scale.y = (target_pos - start_pos).length()

func _update_eyelids(tilt_deg: float):
	var tilt = deg2rad(tilt_deg)
	for base_no in eyelid_dir_map.keys():
		var node = ball_map.get(base_no)
		if is_instance_valid(node) and node.has_method("set_eyelid_color"):
			if eyelid_mode == 1:
				node.set_eyelid_color(-1)
				node.set_eyelash_lengths([])
			else:
				node.set_eyelid_color(lnz.eyelid_color)

				if lnz.eyelash_lengths.size() > 0:
					node.set_eyelash_lengths(lnz.eyelash_lengths)
					node.set_eyelash_angle(lnz.eyelash_angle)
					node.set_eyelash_spacing(lnz.eyelash_spacing)

					var lash_col = (
						lnz.eyelash_color
						if lnz.eyelash_color != -1
						else lnz.eyelid_color
					)
					node.set_eyelash_color(lash_col)

			var angle = eyelid_dir_map[base_no] * tilt
			node.set_eyelid_rotation(angle)

func restore_ball_visual_states(ball_nos: Array):
	if lnz == null:
		return

	for b_no in ball_nos:
		var visual_node = ball_map.get(b_no)
		if not is_instance_valid(visual_node):
			continue

		var data = lnz.balls.get(b_no)
		if data == null:
			data = lnz.addballs.get(b_no)
		if data == null:
			continue

		visual_node.color_index = data.color_index
		visual_node.outline_color_index = data.outline_color_index
		visual_node.outline = data.outline
		visual_node.fuzz_amount = clamp(data.fuzz / 2, 0, 5)

		if data.texture_id >= 0 and lnz.texture_list.size() > data.texture_id:
			visual_node.texture = load_texture_from_list(data.texture_id, lnz.texture_list)
		else:
			visual_node.texture = null

		if visual_node.has_method("update_ball"):
			visual_node.update_ball()

### TRANSFORMATIONS ###
# apply_extensions
# munge_balls
# apply_movement_with_rotation
# apply_projections
# apply_sizes
# get_real_ball_size

func apply_extensions(all_ball_dict: Dictionary, lnz: LnzParser):
	var base_ball_dict = all_ball_dict.balls
	var addball_dict = all_ball_dict.addballs
	var addballs_by_base = {}
	for ab in addball_dict.values():
		var ar = addballs_by_base.get(ab.base, [])
		ar.append(ab)
		addballs_by_base[ab.base] = ar

	var legs
	var body_ext
	var face_ext
	var head_ext
	var foot_ext
	var ear_ext

	if lnz.species == KeyBallsData.Species.DOG:
		legs = KeyBallsData.legs_dog
		body_ext = KeyBallsData.body_ext_dog
		face_ext = KeyBallsData.face_ext_dog
		head_ext = KeyBallsData.head_ext_dog
		foot_ext = KeyBallsData.foot_ext_dog
		ear_ext = KeyBallsData.ear_ext_dog
	elif lnz.species == KeyBallsData.Species.CAT:
		legs = KeyBallsData.legs_cat
		body_ext = KeyBallsData.body_ext_cat
		face_ext = KeyBallsData.face_ext_cat
		head_ext = KeyBallsData.head_ext_cat.duplicate()
		foot_ext = KeyBallsData.foot_ext_cat
		ear_ext = KeyBallsData.ear_ext_cat

		for b in KeyBallsData.eyes_cat:
			head_ext.erase(b)
	elif lnz.species == KeyBallsData.Species.BABY:
		legs = KeyBallsData.legs_bab
		body_ext = KeyBallsData.body_ext_bab
		face_ext = KeyBallsData.face_ext_bab
		head_ext = KeyBallsData.head_ext_bab
		foot_ext = KeyBallsData.foot_ext_bab
		ear_ext = KeyBallsData.ear_ext_bab
	else:
		# Unknown species, assume no extensions
		return all_ball_dict

	# legs
	# for ball_no in legs[0]:
	# 	var ball = base_ball_dict[ball_no]
	# 	if ball_no in [legs[0][0], legs[0][1]]:
	# 		ball.position.y += abs(ball.position.y * (lnz.leg_extensions.x / 100.0))
	# 	else:
	# 		ball.position.y += lnz.leg_extensions.x
	# for ball_no in legs[1]:
	# 	var ball = base_ball_dict[ball_no]
	# 	if ball_no in [legs[1][0], legs[1][1]]:
	# 		ball.position.y += abs(ball.position.y * abs(lnz.leg_extensions.y / 100.0))
	# 	else:
	# 		ball.position.y += lnz.leg_extensions.y

	# legs
	var front_legs = legs[0]
	var back_legs = legs[1]

	var front_legs_set = {}
	for b in front_legs:
		front_legs_set[b] = true

	var back_legs_set = {}
	for b in back_legs:
		back_legs_set[b] = true

	var ext_front = lnz.leg_extensions.x
	var ext_back = lnz.leg_extensions.y

	if lnz.species == KeyBallsData.Species.BABY:
		pass
	else:
		# tilt/raise head+body
		# var z_front = 0.0
		# var z_back = 0.0

		# if front_legs.size() > 0:
		# 	z_front = base_ball_dict[front_legs[0]].position.z
		# if back_legs.size() > 0:
		# 	z_back = base_ball_dict[back_legs[0]].position.z

		# for ball_no in base_ball_dict:
		# 	var ball = base_ball_dict[ball_no]

		# 	if front_legs_set.has(ball_no) or back_legs_set.has(ball_no):
		# 		# plant legs
		# 		pass
		# 	else:
		# 		# tilt body
		# 		var t = 0.5
		# 		if abs(z_back - z_front) > 0.001:
		# 			t = (ball.position.z - z_front) / (z_back - z_front)
		# 		# lift body
		# 		var lift = lerp(ext_front, ext_back, t)
		# 		ball.position.y -= lift

		# tilt/raise body, raise head
		var z_front = 0.0
		var z_back = 0.0

		if front_legs.size() > 0:
			z_front = base_ball_dict[front_legs[0]].position.z
		if back_legs.size() > 0:
			z_back = base_ball_dict[back_legs[0]].position.z

		var head_set = {}
		for b in head_ext:
			head_set[b] = true

		for ball_no in base_ball_dict:
			var ball = base_ball_dict[ball_no]

			if front_legs_set.has(ball_no) or back_legs_set.has(ball_no):
				# plant legs
				pass
			else:
				var t = 0.5
				if abs(z_back - z_front) > 0.001:
					t = (ball.position.z - z_front) / (z_back - z_front)

				if head_set.has(ball_no) or ball.position.z < z_front:
					t = 0.0
				else:
					t = clamp(t, 0.0, 1.0)

				var lift = lerp(ext_front, ext_back, t)
				ball.position.y -= lift

	# body
	var special_ball = body_ext[0]
	for ball_no in body_ext:
		if ball_no == special_ball:
			continue
		var ball = base_ball_dict[ball_no]
		ball.position.z += lnz.body_extension * 2
	base_ball_dict[special_ball].position.z += lnz.body_extension

	# face
	var head_ball_key = head_ext[0]
	var head_rot = base_ball_dict[head_ball_key].rotation
	for ball_no in face_ext:
		var ball = base_ball_dict[ball_no]
		ball.position.z -= lnz.face_extension

	# head enlargement
	var head_pos = base_ball_dict[head_ball_key].position
	for ball_no in head_ext:
		var ball = base_ball_dict[ball_no]
		var addballs = addballs_by_base.get(ball_no, [])
		if ball_no != head_ball_key:
			var mod_v = ball.position - head_pos
			mod_v = mod_v * (lnz.head_enlargement.x / 100.0)
			mod_v += head_pos
			ball.position = Vector3(floor(mod_v.x), floor(mod_v.y), floor(mod_v.z))
		ball.size = floor(ball.size * (lnz.head_enlargement.x / 100.0))
		ball.size += lnz.head_enlargement.y

	# feet
	for foot_group in foot_ext:
		var foot_pos = base_ball_dict[foot_group[0]].position
		for ball_no in foot_group:
			var ball = base_ball_dict[ball_no]
			if ball_no != foot_group[0]:
				var mod_v = ball.position - foot_pos
				mod_v = mod_v * (lnz.foot_enlargement.x / 100.0)
				mod_v += foot_pos
				ball.position = Vector3(
					floor(ball.position.x), floor(ball.position.y), floor(ball.position.z)
				)
			ball.size = floor(ball.size * (lnz.foot_enlargement.x / 100.0))
			ball.size += lnz.foot_enlargement.y

	# ears
	for base_ball_no in ear_ext:
		var base_ball = base_ball_dict[base_ball_no]
		for k in ear_ext[base_ball_no]:
			var ear_ball = base_ball_dict[k]
			var vector_from_base = ear_ball.position - base_ball.position
			vector_from_base *= (lnz.ear_extension / 100.0)
			ear_ball.position = base_ball.position + vector_from_base
		#for addball in addballs_by_base.get(ball_no, []):
		#	addball.position *= (lnz.ear_extension / 100.0)

	return {balls = base_ball_dict, addballs = addball_dict, paintballs = all_ball_dict.paintballs}

func munge_balls(all_ball_dict: Dictionary, lnz: LnzParser):
	var base_ball_dict = all_ball_dict.balls
	var lnz_balls = lnz.balls
	for k in base_ball_dict:
		var v: BallData = lnz_balls.get(k)
		var b: BallData = base_ball_dict.get(k)
		if b == null or v == null:
			continue

		_orig_lnz_pos[k] = b.position  # record LNZ positions
		#print("[INFO] dog_generator: munge_balls: saved raw LNZ position for ball %d: %s" % [k, _orig_lnz_pos[k]])

		b.size += v.size
		b.outline_color_index = v.outline_color_index
		b.outline = v.outline
		b.fuzz = v.fuzz

		var q = Quat()
		for m in lnz.moves:
			if m.ball_no == k:
				var move_base = b
				var rot = move_base.rotation
				if m.relative_to:
					rot = base_ball_dict.get(m.relative_to).rotation
				q.set_euler(Vector3(deg2rad(rot.x), deg2rad(rot.y), deg2rad(rot.z)))
				b.position = move_base.position + apply_movement_with_rotation(m.position, rot)
		b.texture_id = v.texture_id
		b.color_index = v.color_index
		base_ball_dict[k] = b

	return {
		balls = base_ball_dict,
		addballs = all_ball_dict.addballs,
		paintballs = all_ball_dict.paintballs
	}

func apply_movement_with_rotation(vec: Vector3, rot_euler: Vector3):
	var q = Quat()
	q.set_euler(Vector3(deg2rad(rot_euler.x), deg2rad(rot_euler.y), deg2rad(rot_euler.z)))
	return q.xform(vec)

func apply_projections():
	# have to apply projections now
	# can't do it earlier because it's hard to calculate
	# the global_position yourself
	# important to process these in order too
	var outputs = {}

	for project_ball_data in lnz.project_ball:
		var visual_ball = ball_map.get(project_ball_data.project_ball) as Spatial
		var static_ball = ball_map.get(project_ball_data.fixed_ball) as Spatial
		
		if not is_instance_valid(visual_ball) or not is_instance_valid(static_ball):
			print("[WARNING] Skipping projection: missing visual_ball or static_ball.")
			continue 

		var vec = visual_ball.global_transform.origin - static_ball.global_transform.origin
		var base_pos = static_ball.global_transform.origin
		var amount = (project_ball_data.min_projection + project_ball_data.max_projection) / 2
		visual_ball.global_transform.origin = base_pos + (vec * amount / 100.0)

func apply_sizes(all_ball_dict: Dictionary, lnz: LnzParser):
	for k in all_ball_dict.balls:
		var ball = all_ball_dict.balls[k]
		ball.size = ball.size - 2
		ball.size = round(ball.size * (lnz.scales[1] / 255.0))
		#ball.size -= 1 - fmod(ball.size, 2)
		ball.size = max(1, ball.size)
		ball.size -= 1 - fmod(ball.size, 2)
		ball.size = max(1, ball.size)
		#ball.fuzz = floor(ball.fuzz * (lnz.scales[1] / 255.0))
		ball.position = (ball.position * (lnz.scales[0] / 255.0))
		all_ball_dict.balls[k] = ball

	for k in all_ball_dict.addballs:
		var ball = all_ball_dict.addballs[k]
		ball.size = ball.size - 2
		ball.size = round(ball.size * (lnz.scales[1] / 255.0))
		ball.size = max(1, ball.size)
		ball.size -= 1 - fmod(ball.size, 2)
		ball.size = max(1, ball.size)
		#ball.fuzz = floor(ball.fuzz * (lnz.scales[1] / 255.0))
		ball.position = (ball.position * (lnz.scales[0] / 255.0))
		all_ball_dict.addballs[k] = ball

	return {
		balls = all_ball_dict.balls,
		addballs = all_ball_dict.addballs,
		paintballs = all_ball_dict.paintballs
	}

func get_real_ball_size(ball_size):
	return ball_size

### ANIMATIONS ###
# set_animation
# set_frame
# symmetrize_skeleton
# _on_AnimPicker_text_entered
# _on_PrevAnim_pressed
# _on_NextAnim_pressed
# _on_TPoseCheckBox_toggled

func set_animation(anim_index: int):
	if t_pose_active and not is_setting_tpose:
		disable_tpose()

	if not bhd or bhd.animation_ranges.empty():
		print("[ERROR] dog_generator: set_animation: No valid BHD loaded.")
		return

	current_animation = clamp(anim_index, 0, bhd.animation_ranges.size() - 1)
	bhd.get_frame_offsets_for(anim_index)

	var anim_frames = bhd.get_frame_offsets_for(anim_index)
	if anim_frames.empty():
		print("[WARNING] dog_generator: set_animation: animation %d has no frames in BHD" % anim_index)
		anim_frames = [0]

	var bdt_filename = current_bdt_prefix + str(anim_index) + ".bdt"
	var new_bdt = BdtParser.new(bdt_filename, anim_frames, bhd.num_balls)

	if new_bdt.frames.empty():
		print("[ERROR] dog_generator: set_animation: failed to load BDT frames for: ", bdt_filename)
		return

	current_bdt = BdtParser.new(bdt_filename, anim_frames, bhd.num_balls)
	set_frame(0)
	emit_signal("animation_loaded", anim_frames.size())
	
	var anim_picker = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/AnimPicker")
	anim_picker.text = str(anim_index)

func set_frame(frame: int):
	if t_pose_active and not is_setting_tpose:
		disable_tpose()

	if not current_bdt or current_bdt.frames.empty():
		return

	current_frame = clamp(frame, 0, current_bdt.frames.size() - 1)

	if balls.empty():
		for n in bhd.num_balls:
			var x = current_bdt.frames[current_frame][n]
			balls.append(BallData.new(bhd.ball_sizes[n], x.position, n, x.rotation))
	else:
		for n in bhd.num_balls:
			var x = current_bdt.frames[current_frame][n]
			var b = balls[n]
			b.position = x.position
			b.rotation = x.rotation

	if t_pose_active:
		symmetrize_skeleton()

	init_visual_balls(lnz, false)

func symmetrize_skeleton():
	var symmetry_data = {}
	if lnz.species == KeyBallsData.Species.DOG:
		symmetry_data = KeyBallsData.dog_body_part_symmetry
	elif lnz.species == KeyBallsData.Species.CAT:
		symmetry_data = KeyBallsData.cat_body_part_symmetry
	elif lnz.species == KeyBallsData.Species.BABY:
		symmetry_data = KeyBallsData.baby_body_part_symmetry
	else:
		return

	for section in symmetry_data.values():
		for part in section.values():
			if part.has("left") and part.has("right"):
				var left_indices = part["left"]
				var right_indices = part["right"]

				var pair_count = min(left_indices.size(), right_indices.size())
				for i in range(pair_count):
					var l_idx = left_indices[i]
					var r_idx = right_indices[i]

					if l_idx < balls.size() and r_idx < balls.size():
						var l_ball = balls[l_idx]
						var r_ball = balls[r_idx]

						r_ball.position.x = -l_ball.position.x
						r_ball.position.y = l_ball.position.y
						r_ball.position.z = l_ball.position.z

						r_ball.rotation.x = l_ball.rotation.x
						r_ball.rotation.y = -l_ball.rotation.y
						r_ball.rotation.z = -l_ball.rotation.z

func disable_tpose():
	if not t_pose_active: 
		return
		
	is_setting_tpose = true
	if t_pose_checkbox:
		t_pose_checkbox.pressed = false
	t_pose_active = false
	is_setting_tpose = false

func _on_AnimPicker_text_entered(new_text):
	var i = int(new_text)
	if i < bhd.animation_ranges.size():
		set_animation(int(new_text))

func _on_PrevAnim_pressed():
	if current_animation > 0:
		set_animation(current_animation - 1)
	else:
		print("[WARNING] dog_generator: _on_PrevAnim_pressed: already at first animation, cannot go back further")

func _on_NextAnim_pressed():
	set_animation(current_animation + 1)

func _on_TPoseCheckBox_toggled(button_pressed):
	if is_setting_tpose:
		return

	t_pose_active = button_pressed

	if t_pose_active:
		_saved_anim_index = current_animation
		_saved_frame_index = current_frame
		
		var play_button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/Button")
		if play_button.pressed:
			play_button.pressed = false
		
		is_setting_tpose = true 
		
		set_animation(0) 
		set_frame(0)
		
		is_setting_tpose = false 

	else:
		is_setting_tpose = true 
		set_animation(_saved_anim_index)
		set_frame(_saved_frame_index)
		is_setting_tpose = false


### VISIBILITY ###
# is_special_ball
# is_hidden_ball
# hide_ball
# unhide_all_balls
# _apply_hidden_state_to_visuals
# _restore_hidden_states
# _on_EyeLidButton_pressed
# _on_ToggleSpecialBalls_toggled
# _on_TransparencyCheckBox_toggled
# set_visibility_for_group
# _on_AddballCheckBox_toggled
# _on_BallCheckBox_toggled
# _on_PaintballCheckBox_toggled
# _on_LineCheckBox_toggled
# _on_PolygonCheckBox_toggled
# _on_OmittedBallCheckBox_toggled


func is_special_ball(species: int, ball_no: int) -> bool:
	if lnz != null and lnz.addballs.has(ball_no):
		if lnz.addballs[ball_no].add_group != 0:
			return true
	return false

func is_hidden_ball(ball_no):
	return _hidden_balls.has(ball_no)

func hide_ball(ball_no):
	print("[STATUS] Node: hide_ball: ball_no %d" % ball_no)
	if not _hidden_balls.has(ball_no):
		_hidden_balls.append(ball_no)

	_apply_hidden_state_to_visuals(ball_no)
	
func unhide_all_balls():
	print("[STATUS] Node: unhide_all_balls: restoring %d balls" % _hidden_balls.size())
	for ball_no in _hidden_balls:
		if ball_map.has(ball_no):
			var node = ball_map[ball_no]
			if node.has_method("set_hidden"):
				node.set_hidden(false)
		
		if _ball_to_lines_map.has(ball_no):
			for line_idx in _ball_to_lines_map[ball_no]:
				if lines_map.has(line_idx):
					lines_map[line_idx].set_hidden(false)
					if line_idx in _hidden_lines:
						_hidden_lines.erase(line_idx)
		
		if _ball_to_polygons_map.has(ball_no):
			for poly_idx in _ball_to_polygons_map[ball_no]:
				if polygons_map.has(poly_idx):
					polygons_map[poly_idx].set_hidden(false)
					if poly_idx in _hidden_polygons:
						_hidden_polygons.erase(poly_idx)

	for line_idx in _hidden_lines:
		if lines_map.has(line_idx):
			lines_map[line_idx].set_hidden(false)
	_hidden_lines.clear()

	for poly_idx in _hidden_polygons:
		if polygons_map.has(poly_idx):
			polygons_map[poly_idx].set_hidden(false)
	_hidden_polygons.clear()

	for pb in _hidden_paintballs:
		if is_instance_valid(pb) and pb.has_method("set_hidden"):
			pb.set_hidden(false)
	_hidden_paintballs.clear()

	_hidden_balls.clear()

func _apply_hidden_state_to_visuals(ball_no):
	if ball_map.has(ball_no):
		var node = ball_map[ball_no]
		if node.has_method("set_hidden"):
			node.set_hidden(true)

	if paintball_map.has(ball_no):
		for pb in paintball_map[ball_no]:
			if pb.has_method("set_hidden"):
				pb.set_hidden(true)
				if not _hidden_paintballs.has(pb):
					_hidden_paintballs.append(pb)

	if _ball_to_lines_map.has(ball_no):
		for line_idx in _ball_to_lines_map[ball_no]:
			if lines_map.has(line_idx):
				var line = lines_map[line_idx]
				if line.has_method("set_hidden"):
					line.set_hidden(true)
				if not _hidden_lines.has(line_idx):
					_hidden_lines.append(line_idx)
			else:
				if line_idx in _hidden_lines:
					_hidden_lines.erase(line_idx)

	if _ball_to_polygons_map.has(ball_no):
		for poly_idx in _ball_to_polygons_map[ball_no]:
			if polygons_map.has(poly_idx):
				var poly = polygons_map[poly_idx]
				if poly.has_method("set_hidden"):
					poly.set_hidden(true)
				if not _hidden_polygons.has(poly_idx):
					_hidden_polygons.append(poly_idx)
			else:
				if poly_idx in _hidden_polygons:
					_hidden_polygons.erase(poly_idx)

func _restore_hidden_states():
	for ball_no in _hidden_balls:
		_apply_hidden_state_to_visuals(ball_no)

	for line_idx in _hidden_lines:
		if lines_map.has(line_idx):
			lines_map[line_idx].set_hidden(true)

	for poly_idx in _hidden_polygons:
		if polygons_map.has(poly_idx):
			polygons_map[poly_idx].set_hidden(true)

	for pb in _hidden_paintballs:
		if is_instance_valid(pb) and pb.has_method("set_hidden"):
			pb.set_hidden(true)

func _on_EyeLidButton_pressed():
	eyelid_mode = (eyelid_mode + 1) % EYELID_LABELS.size()
	eyelid_button.icon = EYELID_ICONS[eyelid_mode]
	_update_eyelids(EYELID_TILTS[eyelid_mode])

func _on_ToggleSpecialBalls_toggled(button_pressed):
	draw_special_balls = button_pressed
	set_visibility_for_group("special_balls", button_pressed)

func _on_TransparencyCheckBox_toggled(button_pressed):
	var balls = get_tree().get_nodes_in_group("balls")
	for ball in balls:
		if ball is Spatial:
			ball.set_transparency(button_pressed)
	var addballs = get_tree().get_nodes_in_group("addballs")
	for addball in addballs:
		if addball is Spatial:
			addball.set_transparency(button_pressed)
	var lines = get_tree().get_nodes_in_group("lines")
	for line in lines:
		if line is Spatial:
			line.set_transparency(button_pressed)
	var paintballs = get_tree().get_nodes_in_group("paintballs")
	for paintball in paintballs:
		if paintball.has_method("set_transparency"):
			paintball.set_transparency(button_pressed)
		elif paintball.get_parent().has_method("set_transparency"):
			paintball.get_parent().set_transparency(button_pressed)

func set_visibility_for_group(group_name: String, is_visible: bool):
	var nodes = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		if node is Spatial:
			if is_visible and node.get("omitted") and not draw_omitted_balls:
				node.set_visible(false)
			elif is_visible and node.is_in_group("special_balls") and not draw_special_balls:
				node.set_visible(false)
			elif is_visible and node.is_in_group("addballs") and not draw_addballs:
				node.set_visible(false)
			elif is_visible and node.is_in_group("balls") and not draw_balls:
				node.set_visible(false)
			else:
				node.set_visible(is_visible)

func _on_AddballCheckBox_toggled(button_pressed):
	print("[STATUS] Node: _on_AddballCheckBox_toggled: setting addballs visibility to %s" % button_pressed)
	draw_addballs = button_pressed
	set_visibility_for_group("addballs", button_pressed)

func _on_BallCheckBox_toggled(button_pressed):
	print("[STATUS] Node: _on_BallCheckBox_toggled: setting balls visibility to %s" % button_pressed)
	draw_balls = button_pressed
	set_visibility_for_group("balls", button_pressed)

func _on_PaintballCheckBox_toggled(button_pressed):
	print("[STATUS] Node: _on_PaintballCheckBox_toggled: setting paintballs visibility to %s" % button_pressed)
	draw_paintballs = button_pressed
	set_visibility_for_group("paintballs", button_pressed)

func _on_LineCheckBox_toggled(button_pressed):
	print("[STATUS] Node: _on_LineCheckBox_toggled: setting lines visibility to %s" % button_pressed)
	draw_lines = button_pressed
	set_visibility_for_group("lines", button_pressed)

func _on_PolygonCheckBox_toggled(button_pressed):
	print("[STATUS] Node: _on_PolygonCheckBox_toggled: setting polygons visibility to %s" % button_pressed)
	draw_polygons = button_pressed
	set_visibility_for_group("polygons", button_pressed)

func _on_OmittedBallCheckBox_toggled(button_pressed):
	print("[STATUS] Node: _on_OmittedBallCheckBox_toggled: setting omitted balls visibility to %s" % button_pressed)
	draw_omitted_balls = button_pressed
	var count = 0

	for ball_no in ball_map:
		var node = ball_map[ball_no]

		if node.get("omitted") == true:
			count += 1
			if draw_omitted_balls:
				node.visible_override = true

				if node.is_in_group("balls"):
					node.visible = draw_balls
				elif node.is_in_group("addballs"):
					node.visible = draw_addballs

				if paintball_map.has(ball_no):
					for pb in paintball_map[ball_no]:
						pb.visible_override = true
						pb.visible = draw_paintballs
			else:
				node.visible_override = false

				if not node.is_in_group("balls"):
					node.call_deferred("set_visible", false)

				if paintball_map.has(ball_no):
					for pb in paintball_map[ball_no]:
						pb.visible_override = false
						pb.visible = false
	print("[STATUS] Node: _on_OmittedBallCheckBox_toggled: updated %d omitted balls" % count)


### PAINTBALLZ ###
# _create_paintball_instance
# _setup_paintball_node
# add_pending_paintball
# remove_last_pending_paintball
# remove_specific_pending_paintball
# get_pending_paintballs_data
# get_pending_paintball_nodes
# clear_pending_paintballz
# _on_clear_pending_paintballz
# clear_auto_paintballz
# _on_clear_auto_paintballz
# _on_randomize_auto_paintballz
# _on_clear_auto_paintballz
# _on_apply_auto_paintballz

func _create_paintball_instance(base_ball_node):
	var pb = paintball_scene.instance()
	base_ball_node.add_child(pb)
	pb.set_owner(get_root())
	pb.add_to_group("paintballs")
	return pb

func _setup_paintball_node(pb_visual_ball, pb_data, base_ball_node, pb_pos, pb_diameter, existing_count, list_size):
	var target_layer = 1
	var base_mesh = base_ball_node.get_node_or_null("MeshInstance")
	if base_mesh and base_mesh is VisualInstance:
		target_layer = base_mesh.layers
	
	var pb_mesh = pb_visual_ball.get_node_or_null("MeshInstance")
	if pb_mesh and pb_mesh is VisualInstance:
		pb_mesh.layers = target_layer

	var final_size = base_ball_node.ball_size * (float(pb_diameter) / 100.0)
	final_size -= 1 - fmod(final_size, 2)
	pb_visual_ball.ball_size = final_size
	pb_visual_ball.transform.origin = pb_pos
	pb_visual_ball.set_surface_normal(pb_pos.normalized())

	pb_visual_ball.set_species(lnz.species, is_babyz_mode)
	pb_visual_ball.set_render_flat_colors(render_flat_colors_global)
	pb_visual_ball.base_ball_no = base_ball_node.name.to_int() # Ensure consistent naming
	pb_visual_ball.base_ball_position = base_ball_node.global_transform.origin
	pb_visual_ball.base_ball_size = base_ball_node.ball_size
	pb_visual_ball.color_index = pb_data.color
	pb_visual_ball.outline_color_index = pb_data.outline_color
	pb_visual_ball.outline = pb_data.outline
	pb_visual_ball.group = pb_data.group
	pb_visual_ball.fuzz_amount = clamp(pb_data.fuzz / 2, 0, 5)
	pb_visual_ball.palette = base_ball_node.palette

	if pb_data.texture > -1:
		var tex_pb = load_texture_from_list(pb_data.texture, lnz.texture_list)
		if tex_pb:
			pb_visual_ball.texture = tex_pb
			if pb_data.texture < lnz.texture_list.size():
				pb_visual_ball.transparent_color = lnz.texture_list[pb_data.texture].transparent_color
	else:
		print("[WARNING] Node: _setup_paintball_node: failed to load texture %d" % pb_data.texture)

	var base_z = base_ball_node.z_add if "z_add" in base_ball_node else 0.0
	pb_visual_ball.z_add = (base_z * 20.0) + 10.0 + float(existing_count) + float(list_size)

	return pb_visual_ball

func add_pending_paintball(paintball_info):
	_pending_paintballs_data.append(paintball_info)
	var base_ball_node = ball_map[paintball_info.base_ball_no]
	var pb_visual_ball = _create_paintball_instance(base_ball_node)
	
	var pb_data = {
		"color": paintball_info.color, "outline_color": paintball_info.outline_color,
		"outline": paintball_info.outline_type, "fuzz": paintball_info.fuzz,
		"texture": paintball_info.texture, "group": paintball_info.group
	}

	_setup_paintball_node(pb_visual_ball, pb_data, base_ball_node, 
						paintball_info.relative_pos_local, paintball_info.diameter,
						paintball_map.get(paintball_info.base_ball_no, []).size(),
						_pending_paintballs_data.size())
	
	_pending_paintball_nodes.append(pb_visual_ball)
	print("[STATUS] Node: add_pending_paintball: successfully added visual paintball to base ball %d" % paintball_info.base_ball_no)

func remove_last_pending_paintball():
	print("[STATUS] Node: remove_last_pending_paintball: request received")
	if _pending_paintballs_data.size() > 0 and _pending_paintball_nodes.size() > 0:
		var last_visual_node = _pending_paintball_nodes.pop_back()

		if is_instance_valid(last_visual_node):
			last_visual_node.queue_free()
			print("[STATUS] Node: remove_last_pending_paintball: visual node freed")

		_pending_paintballs_data.pop_back()
	else:
		print("[WARNING] Node: remove_last_pending_paintball: no pending paintballs to remove")

func remove_specific_pending_paintball(paintball_node):
	print("[STATUS] Node: remove_specific_pending_paintball: called for node %s" % paintball_node)
	var index = _pending_paintball_nodes.find(paintball_node)
	if index != -1:
		_pending_paintball_nodes.remove(index)
		_pending_paintballs_data.remove(index)
		if is_instance_valid(paintball_node):
			paintball_node.queue_free()
			print("[STATUS] Node: remove_specific_pending_paintball: node freed")
	else:
		print("[WARNING] Node: remove_specific_pending_paintball: node not found in pending list")

func get_pending_paintballs_data():
	return _pending_paintballs_data

func get_pending_paintball_nodes():
	return _pending_paintball_nodes

func clear_pending_paintballz():
	print("[STATUS] Node: clear_pending_paintballz: clearing %d paintballz" % _pending_paintball_nodes.size())
	for node in _pending_paintball_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_pending_paintball_nodes.clear()
	_pending_paintballs_data.clear()

func _on_clear_pending_paintballz():
	clear_pending_paintballz()

func clear_auto_paintballz():
	print("[STATUS] Node: clear_auto_paintballz: clearing %d paintballz" % _auto_paintball_nodes.size())
	for node in _auto_paintball_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_auto_paintball_nodes.clear()
	_auto_paintballs_data.clear()

func _on_clear_auto_paintballz():
	clear_auto_paintballz()

func _on_randomize_auto_paintballz(paintballz):
	print("[STATUS] Node: _on_randomize_auto_paintballz: clearing and generating %d auto-paintballs" % paintballz.size())
	_on_clear_auto_paintballz()
	_auto_paintballs_data = paintballz

	for pb_data in _auto_paintballs_data:
		var base_ball_node = ball_map.get(pb_data.base)
		
		if not is_instance_valid(base_ball_node):
			print("[WARNING] Node: _on_randomize_auto_paintballz: base_ball_no %d not found or invalid" % pb_data.base)
			continue

		var pb_visual_ball = _create_paintball_instance(base_ball_node)
		
		var pb_pos = pb_data.position * (base_ball_node.ball_size / 2.0) * pixel_world_size

		var adapter = {
			"color": pb_data.color_index,
			"outline_color": pb_data.outline_color_index,
			"outline": pb_data.outline,
			"fuzz": pb_data.fuzz,
			"texture": pb_data.texture_id,
			"group": pb_data.group
		}

		_setup_paintball_node(
			pb_visual_ball, 
			adapter, 
			base_ball_node, 
			pb_pos, 
			pb_data.size,
			paintball_map.get(pb_data.base, []).size(),
			_auto_paintball_nodes.size()
		)

		_auto_paintball_nodes.append(pb_visual_ball)

func _on_apply_auto_paintballz():
	print("[STATUS] Node: _on_apply_auto_paintballz: attempting to apply auto paintballs")
	var processed_paintballs = {}
	var processed_count = 0
	var cap = 1000

	for pb_data in _auto_paintballs_data:
		if processed_count >= cap:
			print("[WARNING] Node: _on_apply_auto_paintballz: hit cap of %d auto paintballs" % cap)
			break

		var base_ball_node = ball_map.get(pb_data.base)
		if not is_instance_valid(base_ball_node):
			continue

		var local_pos = pb_data.position * (base_ball_node.ball_size / 2.0) * pixel_world_size
		var world_relative_pos = (
			base_ball_node.to_global(local_pos)
			- base_ball_node.global_transform.origin
		)

		var lnz_scale = lnz.scales.x / 255.0
		var relative_pos_lnz = world_relative_pos / (pixel_world_size * lnz_scale)
		relative_pos_lnz.y *= -1

		var key = hash([pb_data.base, relative_pos_lnz, pb_data.size])

		if processed_paintballs.has(key):
			continue

		processed_paintballs[key] = true

		var paintball_info = {
			"base_ball_no": pb_data.base,
			"relative_pos_local": local_pos,
			"relative_pos_lnz": relative_pos_lnz,
			"diameter": pb_data.size,
			"color": pb_data.color_index,
			"outline_color": pb_data.outline_color_index,
			"outline_type": pb_data.outline,
			"fuzz": pb_data.fuzz,
			"texture": pb_data.texture_id,
			"group": pb_data.group,
			"anchored": pb_data.anchored == 1
		}
		_pending_paintballs_data.append(paintball_info)

		processed_count += 1
		
	print("[STATUS] Node: _on_apply_auto_paintballz: appended %d paintballs to pending queue" % processed_count)

	var lnz_text_edit = get_tree().root.get_node(
		"Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit"
	)
	if lnz_text_edit:
		print("[STATUS] Node: _on_apply_auto_paintballz: passing apply command to LnzTextEdit")
		lnz_text_edit.apply_paintballz()
	else:
		print("[ERROR] Node: _on_apply_auto_paintballz: could not locate LnzTextEdit node")

	_on_clear_auto_paintballz()

### ADD BALLZ ###

func inject_single_addball(props: Dictionary, ball_no: int, reference_ball: Spatial = null) -> bool:
	var addball_data = apply_extensions_for_addball(props, ball_no)
	
	var base_node = ball_map.get(addball_data.base)
	if not base_node:
		printerr("[ERROR] inject_single_addball: base ball %d not found" % addball_data.base)
		return false
	
	var node = ball_scene.instance()
	
	node.species = lnz.species
	
	node.ball_no = ball_no
	node.base_ball_no = addball_data.base
	node.z_add = addball_data.size / 10.0
	node.ball_size = addball_data.size
	node.color_index = addball_data.color_index if addball_data.color_index != -1 else 0
	node.outline_color_index = addball_data.outline_color_index
	node.outline = addball_data.outline
	node.fuzz_amount = clamp(addball_data.fuzz / 2, 0, 5)
	node.palette = current_palette_texture
	
	if addball_data.texture_id >= 0:
		var tex = load_texture_from_list(addball_data.texture_id, lnz.texture_list)
		if tex:
			node.texture = tex
	else:
		if base_node and base_node.has_method("get") and base_node.get("texture"):
			node.texture = base_node.texture
	
	if lnz.no_texture_rotate.has(ball_no):
		node.set_tile_texture(false)
		if lnz.quadrant_balls.has(ball_no):
			node.use_quadrants = true
	else:
		node.set_tile_texture(true)
	
	node.set_species(lnz.species, is_babyz_mode)
	
	base_node.add_child(node)
	node.add_to_group("addballs")
	
	var source_node = reference_ball if reference_ball and reference_ball.has_node("MeshInstance") and reference_ball.get_node("MeshInstance").material_override else base_node
	if source_node and source_node.has_node("MeshInstance") and source_node.get_node("MeshInstance").material_override:
		node.get_node("MeshInstance").material_override = source_node.get_node("MeshInstance").material_override.duplicate()
		node.get_node("MeshInstance").material_override.set_shader_param("ball_size", addball_data.size)
	
	var world_pos = base_node.global_transform.origin
	world_pos += LnzLiveUtils.lnz_to_world_delta(addball_data.position, pixel_world_size, lnz.scales.x)
	node.global_transform.origin = world_pos
	
	node.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
	node.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
	node.connect("ball_selected", self, "signal_ball_selected")
	
	_orig_world_pos[ball_no] = node.global_transform.origin
	
	if not draw_addballs:
		node.visible_override = false
	
	ball_map[ball_no] = node
	
	print("[STATUS] Node: inject_single_addball: created addball #%d on base ball %d" % [ball_no, addball_data.base])
	return true

func apply_extensions_for_addball(props: Dictionary, ball_no: int) -> AddBallData:
	var addball = AddBallData.new(
		props.target_base_ball, ball_no, props.size, Vector3(props.position),
		props.color, props.outline_color, props.outline,
		props.fuzz, 0.0, -1, props.bodyarea, props.texture_id
	)
	
	var base_positions = {}
	for b in balls:
		if b.ball_no >= KeyBallsData.max_base_ball_num:
			continue
		base_positions[b.ball_no] = b.position
	
	if lnz.species != KeyBallsData.Species.BABY:
		var legs = KeyBallsData.legs_dog if lnz.species == KeyBallsData.Species.DOG else KeyBallsData.legs_cat
		var front_legs = legs[0]
		var back_legs = legs[1]
		var ext_front = lnz.leg_extensions.x
		var ext_back = lnz.leg_extensions.y

		var z_front = 0.0
		var z_back = 0.0
		if front_legs.size() > 0 and base_positions.has(front_legs[0]):
			z_front = base_positions[front_legs[0]].z
		if back_legs.size() > 0 and base_positions.has(back_legs[0]):
			z_back = base_positions[back_legs[0]].z
		
		var head_ext = KeyBallsData.head_ext_dog if lnz.species == KeyBallsData.Species.DOG else KeyBallsData.head_ext_cat
		var head_set = {}
		for b in head_ext:
			head_set[b] = true
		
		var t = 0.5
		if abs(z_back - z_front) > 0.001:
			t = (addball.position.z - z_front) / (z_back - z_front)
		if head_set.has(addball.base) or addball.position.z < z_front:
			t = 0.0
		else:
			t = clamp(t, 0.0, 1.0)
		var lift = lerp(ext_front, ext_back, t)
		addball.position.y -= lift
	
	var body_ext = KeyBallsData.body_ext_dog if lnz.species == KeyBallsData.Species.DOG else KeyBallsData.body_ext_cat
	var special_ball = body_ext[0]
	if addball.base == special_ball:
		addball.position.z += lnz.body_extension
	elif addball.base in body_ext:
		addball.position.z += lnz.body_extension * 2
	
	var face_ext = KeyBallsData.face_ext_dog if lnz.species == KeyBallsData.Species.DOG else KeyBallsData.face_ext_cat
	if addball.base in face_ext:
		addball.position.z -= lnz.face_extension
	
	var head_ext = KeyBallsData.head_ext_dog if lnz.species == KeyBallsData.Species.DOG else KeyBallsData.head_ext_cat
	var head_ball_key = head_ext[0]
	if base_positions.has(head_ball_key):
		var head_pos = base_positions[head_ball_key]
		if addball.base != head_ball_key:
			var mod_v = addball.position - head_pos
			mod_v = mod_v * (lnz.head_enlargement.x / 100.0)
			mod_v += head_pos
			addball.position = Vector3(floor(mod_v.x), floor(mod_v.y), floor(mod_v.z))
		addball.size = floor(addball.size * (lnz.head_enlargement.x / 100.0))
		addball.size += lnz.head_enlargement.y
	
	var foot_ext = KeyBallsData.foot_ext_dog if lnz.species == KeyBallsData.Species.DOG else KeyBallsData.foot_ext_cat
	for foot_group in foot_ext:
		if addball.base in foot_group:
			var foot_pos = base_positions[foot_group[0]]
			if addball.base != foot_group[0]:
				var mod_v = addball.position - foot_pos
				mod_v = mod_v * (lnz.foot_enlargement.x / 100.0)
				mod_v += foot_pos
				addball.position = Vector3(floor(mod_v.x), floor(mod_v.y), floor(mod_v.z))
			addball.size = floor(addball.size * (lnz.foot_enlargement.x / 100.0))
			addball.size += lnz.foot_enlargement.y
			break
	
	var ear_ext = KeyBallsData.ear_ext_dog if lnz.species == KeyBallsData.Species.DOG else KeyBallsData.ear_ext_cat
	if addball.base in ear_ext:
		var base_ball_pos = base_positions[addball.base]
		var vector_from_base = addball.position - base_ball_pos
		vector_from_base *= (lnz.ear_extension / 100.0)
		addball.position = base_ball_pos + vector_from_base
	
	addball.size = addball.size - 2
	addball.size = round(addball.size * (lnz.scales[1] / 255.0))
	addball.size = max(1, addball.size)
	addball.size -= 1 - fmod(addball.size, 2)
	addball.size = max(1, addball.size)
	addball.position = addball.position * (lnz.scales[0] / 255.0)
	
	return addball
