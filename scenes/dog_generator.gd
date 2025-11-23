extends Node
## dog_generator.gd
## The central controller for generating and managing model from LNZ document data
## This script is the core of LnzLive and coordinates entire process of loading,
## parsing, building, rendering, animating, and updating models generated
## from LNZ document data (ballz, paintballz, linez, polygonz)
## NOTE: Could really use a rename and refactor, script is huge...

export var pixel_world_size = 0.002

var balls = []
var lines = []
var polygons = []
var ball_map = {}
var paintball_map = {}
var lines_map = {}
var polygons_map = {}

export var draw_balls = true
export var draw_special_balls = false
export var draw_addballs = true
export var draw_lines = true
export var draw_paintballs = true
export var draw_polygons = true

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
var _saved_anim_index = 0
var _saved_frame_index = 0

var _pending_paintballs_data = []
var _pending_paintball_nodes = []
var _auto_paintballs_data = []
var _auto_paintball_nodes = []

var _orig_lnz_pos := {}
var _orig_world_pos := {}

var eyelid_dir_map := {}
var eyelid_mode := 0
var bhd_file_list = []
var current_bdt_prefix = "CAT"

onready var eyelid_button := get_tree().get_root().get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer"
	+ "/VBoxContainer/DropDownMenu/EyeLidButton"
) as Button

onready var bhd_option_button = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/ModelSwitcher/ModelOptionButton"
) as OptionButton
onready var bhd_prompt_dialog = get_tree().root.get_node("Root/SceneRoot/BhdPromptDialog") as ConfirmationDialog
onready var bhd_prompt_option = get_tree().root.get_node("Root/SceneRoot/BhdPromptDialog/VBoxContainer/ModelOptionButton") as OptionButton

const EYELID_LABELS = ["neutral", "none", "angry", "scared"]
const EYELID_TILTS  = [  0.0,      0.0,     -30.0,      30.0 ]
const EYELID_ICONS  = [
	preload("res://resources/icons/ico_eyelid_neutral.png"),
	preload("res://resources/icons/ico_eyelid_nolid.png"),
	preload("res://resources/icons/ico_eyelid_angry.png"),
	preload("res://resources/icons/ico_eyelid_scared.png")
]

onready var preloader = get_tree().root.get_node("Root/ResourcePreloader") as ResourcePreloader

signal animation_loaded(num_of_frames)
signal bhd_loaded(num_of_animations)
signal ball_mouse_enter(ball_info)
signal ball_mouse_exit(ball_no)
signal ball_selected(ball_no, is_addball)
signal addball_deleted(ball_no)

signal ball_translation_changed(ball_no, new_position)
signal ball_translations_done

signal ball_resized(ball_no, size_dif)

signal addball_created(reference_ball)
signal line_created(start_ball, end_ball)

signal palette_changed(palette_name)

func _ready():
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

func set_animation(anim_index: int):
	current_animation = clamp(anim_index, 0, bhd.animation_ranges.size() - 1)
	bhd.get_frame_offsets_for(anim_index)

	var anim_frames = bhd.get_frame_offsets_for(anim_index)
	# Construct BDT filename: PREFIX + index + .bdt
	# If a custom BHD is loaded like "MYDOG.bhd", we expect "MYDOG0.bdt" etc.
	var bdt_filename = current_bdt_prefix + str(anim_index) + ".bdt"

	current_bdt = BdtParser.new(bdt_filename, anim_frames, bhd.num_balls)
	set_frame(0)
	emit_signal("animation_loaded", anim_frames.size())
	
	var anim_picker = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/AnimPicker")
	anim_picker.text = str(anim_index)

func set_frame(frame: int):
	current_frame = frame
	balls = []
	for n in bhd.num_balls:
		var x = current_bdt.frames[frame][n]
		balls.append(BallData.new(bhd.ball_sizes[n], x.position, n, x.rotation))
	
	if t_pose_active:
		symmetrize_skeleton()

	init_visual_balls(lnz, false)

func _on_TPoseCheckBox_toggled(button_pressed):
	t_pose_active = button_pressed
	
	if t_pose_active:
		_saved_anim_index = current_animation
		_saved_frame_index = current_frame
		
		var play_button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/Button")
		if play_button.pressed:
			play_button.pressed = false
		
		set_animation(0) 
		set_frame(0)
		
	else:
		set_animation(_saved_anim_index)
		set_frame(_saved_frame_index)

func clear_lnz_data():
	for ball in balls:
		if ball != null:
			ball.queue_free()
	balls.clear()
	ball_map.clear()
	paintball_map.clear()
	polygons_map.clear()
	lines_map.clear()

func init_ball_data(species, custom_bhd_path = ""):
	if t_pose_checkbox:
		t_pose_active = t_pose_checkbox.pressed

	clear_lnz_data()
	
	var bhd_file = ""
	var bdt_prefix = ""
	
	var anim_to_load = current_animation
	var frame_to_use = current_frame
	if t_pose_active:
		anim_to_load = 0
		frame_to_use = 0
	
	if custom_bhd_path != "":
		bhd_file = custom_bhd_path
		# Assume BDT prefix matches BHD filename
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

	if bhd_file == "":
		bhd_file = "res://resources/animations/CAT.bhd"
		bdt_prefix = "CAT"

	current_bdt_prefix = bdt_prefix
	bhd = BhdParser.new(bhd_file)

	# Update dropdown selection to match loaded file
	var filename = bhd_file.get_file()
	for i in range(bhd_option_button.get_item_count()):
		if bhd_option_button.get_item_text(i) == filename:
			bhd_option_button.select(i)
			break

	emit_signal("bhd_loaded", bhd.animation_ranges.size())
	if bhd.animation_ranges.empty():
		print("BHD file has no animations or failed to load.")
		return

	var first_anim_frames = bhd.get_frame_offsets_for(anim_to_load)
	var bdt = BdtParser.new(bdt_prefix + str(anim_to_load) + ".bdt", first_anim_frames, bhd.num_balls)
	emit_signal("animation_loaded", first_anim_frames.size())
	current_bdt = bdt
	for n in bhd.num_balls:
		balls.append(BallData.new(bhd.ball_sizes[n], bdt.frames[frame_to_use][n].position, n, bdt.frames[frame_to_use][n].rotation))

	KeyBallsData.max_base_ball_num = bhd.num_balls

	if t_pose_active:
		symmetrize_skeleton()

func is_special_baby_ball(species: int, ball_no: int) -> bool:
	return species == KeyBallsData.Species.BABY and ball_no >= 120 and ball_no <= 137

func generate_pet(file_path):
	var lnz_info = LnzParser.new(file_path)
	lnz = lnz_info
	KeyBallsData.species = lnz_info.species
	KeyBallsData.build_bodyarea_map()

	if lnz_info.species == 0:
		# Check if we already have a BHD selected from the dropdown/previous load
		var selected_idx = bhd_option_button.selected
		if selected_idx != -1:
			var bhd_name = bhd_option_button.get_item_text(selected_idx)
			init_ball_data(0, "res://resources/animations/" + bhd_name)
			# Continue generation
		else:
			# Prompt user
			bhd_prompt_dialog.popup_centered()
			return # Stop generation until user selects
	else:
		init_ball_data(lnz_info.species)

	init_visual_balls(lnz_info, true)
	emit_signal("palette_changed", lnz.palette)

func _on_BhdSwitcher_item_selected(index):
	var bhd_name = bhd_option_button.get_item_text(index)
	init_ball_data(0, "res://resources/animations/" + bhd_name)
	# Re-run visual generation to apply the new model to the existing LNZ data
	if lnz:
		init_visual_balls(lnz, true)

func _on_BhdPrompt_confirmed():
	var selected_idx = bhd_prompt_option.selected
	if selected_idx != -1:
		var bhd_name = bhd_prompt_option.get_item_text(selected_idx)
		# Set the main switcher too
		for i in range(bhd_option_button.get_item_count()):
			if bhd_option_button.get_item_text(i) == bhd_name:
				bhd_option_button.select(i)
				break

		init_ball_data(0, "res://resources/animations/" + bhd_name)
		init_visual_balls(lnz, true)
		emit_signal("palette_changed", lnz.palette)

func init_visual_balls(lnz_info: LnzParser, new_create: bool = false):
	var collated_data = collate_base_ball_data()
	# dumb code - duplicate the lnz info to prevent movements being applied multiple times
	var addballs = {}
	for k in lnz_info.addballs:
		var a = lnz_info.addballs[k]
		addballs[k] = AddBallData.new(a.base, a.ball_no, a.size, a.position, a.color_index, a.outline_color_index, a.outline, a.fuzz, a.z_add, a.group, a.body_area, a.texture_id)
	
	var paintballs = {}
	
	for k in lnz_info.paintballs:
		var ar = lnz_info.paintballs[k]
		paintballs[k] = ar.duplicate()
		var i = 0
		for a in ar:
			paintballs[k][i] = {base = a.base, size = a.size, normalised_position = a.normalised_position, color_index = a.color_index, outline = a.outline, outline_color_index = a.outline_color_index, fuzz = a.fuzz, z_add = a.z_add, texture_id = a.texture_id, anchored = a.anchored}
			i+=1
	collated_data = {balls = collated_data, addballs = addballs, paintballs = paintballs}
	collated_data = munge_balls(collated_data, lnz_info)
	collated_data = apply_extensions(collated_data, lnz_info)
	collated_data = apply_sizes(collated_data, lnz_info)
	collated_data.omissions = lnz_info.omissions
	generate_balls(collated_data, lnz_info.species, lnz_info.texture_list, lnz_info.palette, new_create, lnz_info.no_texture_rotate)

	if new_create:
		call_deferred("_finish_dependent_geometry", new_create)
	else:
		apply_projections()
		generate_polygons(lnz_info.polygons, lnz_info.species, lnz_info.palette, new_create, lnz_info.texture_list)
		generate_lines(lnz_info.lines, lnz_info.species, lnz_info.palette, new_create)

func _finish_dependent_geometry(new_create: bool):
	apply_projections()
	generate_polygons(lnz.polygons, lnz.species, lnz.palette, new_create, lnz.texture_list)
	generate_lines(lnz.lines, lnz.species, lnz.palette, new_create)

func collate_base_ball_data():
	var ball_data_map = {}
	for ball in balls:
		ball_data_map[ball.ball_no] = ball
	return ball_data_map
	
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
	for ball_no in legs[0]:
		var ball = base_ball_dict[ball_no]
		if ball_no in [legs[0][0], legs[0][1]]:
			ball.position.y += abs(ball.position.y * (lnz.leg_extensions.x / 100.0))
		else:
			ball.position.y += lnz.leg_extensions.x
	for ball_no in legs[1]:
		var ball = base_ball_dict[ball_no]
		if ball_no in [legs[1][0], legs[1][1]]:
			ball.position.y += abs(ball.position.y * abs(lnz.leg_extensions.y / 100.0))
		else:
			ball.position.y += lnz.leg_extensions.y
		
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
				ball.position = Vector3(floor(ball.position.x), floor(ball.position.y), floor(ball.position.z))
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
#		for addball in addballs_by_base.get(ball_no, []):
#			addball.position *= (lnz.ear_extension / 100.0)
	
	return {balls = base_ball_dict, addballs = addball_dict, paintballs = all_ball_dict.paintballs}
	
func munge_balls(all_ball_dict: Dictionary, lnz: LnzParser):
	var base_ball_dict = all_ball_dict.balls
	var lnz_balls = lnz.balls
	for k in base_ball_dict:
		var v: BallData = lnz_balls.get(k)
		var b: BallData = base_ball_dict.get(k)
		if b == null or v == null:
			continue

		_orig_lnz_pos[k] = b.position # record LNZ positions
		#print("Saved raw LNZ position for ball %d: %s" % [k, _orig_lnz_pos[k]])

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
	
	return {balls = base_ball_dict, addballs = all_ball_dict.addballs, paintballs = all_ball_dict.paintballs}

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
		var visual_ball = ball_map[project_ball_data.project_ball] as Spatial
		var static_ball = ball_map[project_ball_data.fixed_ball] as Spatial
		var vec = visual_ball.global_transform.origin - static_ball.global_transform.origin
		var base_pos = static_ball.global_transform.origin
		var amount = (project_ball_data.min_projection + project_ball_data.max_projection) / 2
		visual_ball.global_transform.origin = base_pos + (vec * amount / 100.0)

func apply_sizes(all_ball_dict: Dictionary, lnz: LnzParser):
	var scale0 = 255.0
	var scale1 = 255.0
	if lnz.scales != null:
		scale0 = lnz.scales[0]
		scale1 = lnz.scales[1]

	for k in all_ball_dict.balls:
		var ball = all_ball_dict.balls[k]
		ball.size = ball.size - 2
		ball.size = round(ball.size * (scale1 / 255.0))
		ball.size -= 1 - fmod(ball.size, 2)
#		ball.fuzz = floor(ball.fuzz * (scale1 / 255.0))
		ball.position = (ball.position * (scale0 / 255.0))
		all_ball_dict.balls[k] = ball
		
	for k in all_ball_dict.addballs:
		var ball = all_ball_dict.addballs[k]
		ball.size = ball.size - 2
		ball.size = round(ball.size * (scale1 / 255.0))
		ball.size -= 1 - fmod(ball.size, 2)
#		ball.fuzz = floor(ball.fuzz * (scale1 / 255.0))
		ball.position = (ball.position * (scale0 / 255.0))
		all_ball_dict.addballs[k] = ball
		
	return {balls = all_ball_dict.balls, addballs = all_ball_dict.addballs, paintballs = all_ball_dict.paintballs}

func get_root():
	if Engine.is_editor_hint():
		return get_tree().get_edited_scene_root().get_node("PetRoot")
	else:
		return get_tree().root.get_node("Root/PetRoot")

func load_texture(texture_filename: String, preloader: ResourcePreloader):
	var texture = null
	var base_name = texture_filename.get_basename()
	var extension = texture_filename.get_extension()
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
		if not (v in deduped):
			deduped.append(v)
	filename_variants = deduped

	for variant in filename_variants:
		var resource_path = "res://resources/textures/" + variant
		var user_resource_path = "user://resources/textures/" + variant

		if ResourceLoader.exists(resource_path):
			texture = ResourceLoader.load(resource_path)
			break
		elif ResourceLoader.exists(user_resource_path):
			texture = ResourceLoader.load(user_resource_path)
			break

	if texture == null:
		if preloader.has_resource(texture_filename.to_lower()):
			texture = preloader.get_resource(texture_filename.to_lower())

	return texture

func load_texture_from_list(texture_id: int, texture_list: Array) -> Texture:
	if texture_id < 0 or texture_id >= texture_list.size():
		return null

	var tex_info = texture_list[texture_id]
	if tex_info.has("filename"):
		var texture_filename = tex_info.filename
		return load_texture(texture_filename, preloader)
	return null

func generate_balls(all_ball_data: Dictionary, species: int, texture_list: Array, palette, new_create: bool, no_texture_rotate := []):
	var ball_data = all_ball_data.balls
	var addball_data = all_ball_data.addballs
	var paintball_data = all_ball_data.paintballs
	var omissions = all_ball_data.omissions

	var root = get_root()
	var balls_parent = root.get_node("petholder/balls")
	var paintballs_parent = root.get_node("petholder/paintballs")
	var addballs_parent = root.get_node("petholder/addballs")

	# Figure out belly position and default palette
	var belly_position
	var default_palette = preload("res://resources/palettes/petz_palette.png")
	if species == KeyBallsData.Species.DOG:
		belly_position = ball_data[KeyBallsData.belly_dog].position
	elif species == KeyBallsData.Species.CAT:
		belly_position = ball_data[KeyBallsData.belly_cat].position
	elif species == KeyBallsData.Species.BABY:
		belly_position = ball_data[KeyBallsData.belly_bab].position
		default_palette = preload("res://resources/palettes/babyz_palette.png")
	else:
		# Fallback to first ball if unknown species
		if ball_data.size() > 0:
			belly_position = ball_data[ball_data.keys()[0]].position
		else:
			belly_position = Vector3.ZERO

	belly_position.y *= -1
	belly_position *= pixel_world_size

	var pal_texture: Texture = null
	if palette != null:
		var user_res_path = "user://resources/palettes/" + palette
		var res_res_path = "res://resources/palettes/" + palette
		if ResourceLoader.exists(user_res_path):
			pal_texture = ResourceLoader.load(user_res_path)
		elif ResourceLoader.exists(res_res_path):
			pal_texture = ResourceLoader.load(res_res_path)
		elif preloader.has_resource("palette_" + palette.to_lower()):
			pal_texture = preloader.get_resource("palette_" + palette.to_lower())
	else:
		pal_texture = default_palette

	# If we're creating everything fresh, clear out old visuals
	if new_create:
		for c in balls_parent.get_children():
			balls_parent.remove_child(c)
			c.queue_free()
		for c in paintballs_parent.get_children():
			paintballs_parent.remove_child(c)
			c.queue_free()
		for c in addballs_parent.get_children():
			addballs_parent.remove_child(c)
			c.queue_free()

		ball_map.clear()
		paintball_map.clear()
		eyelid_dir_map.clear()

	# Identify eyes so we can handle them like paintballs if needed
	var eyes = {}
	if species == KeyBallsData.Species.DOG:
		eyes = KeyBallsData.eyes_dog
	elif species == KeyBallsData.Species.CAT:
		eyes = KeyBallsData.eyes_cat
	elif species == KeyBallsData.Species.BABY:
		eyes = KeyBallsData.eyes_bab
	else:
		eyes = {}

	# Generate base ballz
	for key in ball_data:
		var ball = ball_data[key]
		var visual_ball

		# If the ball key is in the "eyes" dictionary, treat it like a paintball
		if key in eyes:
			if new_create:
				visual_ball = paintball_scene.instance()
				visual_ball.add_to_group("paintballs")
				visual_ball.override_ball_no = ball.ball_no
				visual_ball.z_add = 10
				visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
				visual_ball.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
				visual_ball.connect("ball_selected", self, "signal_ball_selected")
				visual_ball.species = species

				paintballs_parent.add_child(visual_ball)
				visual_ball.set_owner(root)
			else:
				visual_ball = ball_map[key]

			# Parent ball so we know its center
			var base_ball = ball_data[eyes[key]]
			visual_ball.base_ball_size = base_ball.size
			var base_pos = base_ball.position
			base_pos.y *= -1
			base_pos *= pixel_world_size
			visual_ball.base_ball_position = base_pos

			var pos = ball.position
			pos.y *= -1.0
			visual_ball.transform.origin = pos * pixel_world_size

			if new_create:
				if ball.texture_id >= 0 and ball.texture_id < texture_list.size():
					var tex_info_eye = texture_list[ball.texture_id]
					var tex_load_eye = load_texture_from_list(ball.texture_id, texture_list)
					if tex_load_eye:
						visual_ball.texture = tex_load_eye
						visual_ball.transparent_color = texture_list[ball.texture_id].transparent_color
						if tex_info_eye.has("texture_size") and tex_info_eye.texture_size != null:
							visual_ball.texture_size = tex_info_eye.texture_size
				visual_ball.color_index = ball.color_index
				visual_ball.outline_color_index = ball.outline_color_index
				visual_ball.ball_size = get_real_ball_size(ball.size)
				visual_ball.outline = ball.outline
				visual_ball.fuzz_amount = clamp(ball.fuzz / 2, 0, 5)
				visual_ball.palette = pal_texture

				if no_texture_rotate.has(int(key)):
					visual_ball.set_tile_texture(false)

			visual_ball.rotation_degrees = ball.rotation

			# Initialize eyelid properties
			var base_key = eyes[key]
			var base_def = ball_data[base_key]
			var base_no  = base_def.ball_no

			var base_node = ball_map.get(base_no)
			if base_node:
				# Mirror sign by world X: left eye x<0 = -1, right = +1
				var eye_dir = 1.0
				if base_node.global_transform.origin.x < 0:
					eye_dir = -1.0
				eyelid_dir_map[base_no] = eye_dir

				# Initialize eyelids
				if eyelid_mode == 1:
					# “none”, turn off the lid
					base_node.set_eyelid_color(-1)
				else:
					# color + tilt by eye_dir * EYELID_TILTS
					base_node.set_eyelid_color(lnz.eyelid_color)
					var tilt_rad = deg2rad(EYELID_TILTS[eyelid_mode])
					base_node.set_eyelid_rotation(eye_dir * tilt_rad)

			ball_map[ball.ball_no] = visual_ball

		else:
			if new_create:
				visual_ball = ball_scene.instance()
				visual_ball.add_to_group("balls")
				visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
				visual_ball.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
				visual_ball.connect("ball_selected", self, "signal_ball_selected")

				balls_parent.add_child(visual_ball)
				visual_ball.set_owner(root)

				var skip_texture_rotation = no_texture_rotate.has(int(key))
				visual_ball.set_tile_texture(!skip_texture_rotation)

				visual_ball.species = species

			else:
				visual_ball = ball_map[key]

			visual_ball.ball_no = ball.ball_no
			visual_ball.pet_center = belly_position

			var pos_n = ball.position
			pos_n.y *= -1.0
			visual_ball.transform.origin = pos_n * pixel_world_size

			if new_create:
				if ball.texture_id >= 0 and ball.texture_id < texture_list.size():
					var tex_info_base = texture_list[ball.texture_id]
					var text_load_base = load_texture_from_list(ball.texture_id, texture_list)
					if text_load_base:
						visual_ball.texture = text_load_base
						visual_ball.transparent_color = tex_info_base.transparent_color
						if tex_info_base.has("texture_size") and tex_info_base.texture_size != null:
							visual_ball.texture_size = tex_info_base.texture_size
				visual_ball.color_index = ball.color_index
				visual_ball.outline_color_index = ball.outline_color_index
				visual_ball.ball_size = get_real_ball_size(ball.size)
				visual_ball.outline = ball.outline
				visual_ball.fuzz_amount = clamp(ball.fuzz / 2, 0, 5)
				visual_ball.palette = pal_texture

			visual_ball.rotation_degrees = ball.rotation
			ball_map[ball.ball_no] = visual_ball

		# Handle omissions
		if omissions.has(key):
			ball_map[ball.ball_no].visible_override = false
			ball_map[ball.ball_no].omitted = true
		else:
			# Respect user toggles
			if !draw_balls:
				ball_map[ball.ball_no].visible_override = false

	# Generate addballz
	for key in addball_data:
		var add_ball = addball_data[key]
		var add_visual_ball

		if new_create:
			add_visual_ball = ball_scene.instance()
		else:
			add_visual_ball = ball_map.get(key, null)

		if new_create:
			# Parent the addball under its base ball to preserve relative offsets
			ball_map[add_ball.base].add_child(add_visual_ball)
			add_visual_ball.set_owner(root)
			add_visual_ball.add_to_group("addballs")
			add_visual_ball.z_add = add_ball.size / 10.0
			add_visual_ball.ball_size = add_ball.size
			add_visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
			add_visual_ball.connect("ball_selected", self, "signal_ball_selected")
			add_visual_ball.connect("ball_deleted", self, "signal_ball_deleted")

			var skip_texture_rotation = no_texture_rotate.has(int(key))
			add_visual_ball.set_tile_texture(!skip_texture_rotation)

			add_visual_ball.species = species

		var add_pos = add_ball.position
		add_pos.y *= -1.0
		add_visual_ball.transform.origin = add_pos * pixel_world_size

		if new_create:
			add_visual_ball.outline = add_ball.outline
			add_visual_ball.fuzz_amount = clamp(add_ball.fuzz / 2, 0, 5)
			add_visual_ball.ball_no = add_ball.ball_no
			add_visual_ball.base_ball_no = add_ball.base
			add_visual_ball.outline_color_index = add_ball.outline_color_index
			if add_ball.texture_id >= 0 and add_ball.texture_id < texture_list.size():
				var tex_info_add = texture_list[add_ball.texture_id]
				var text_load_add = load_texture_from_list(add_ball.texture_id, texture_list)
				if text_load_add:
					add_visual_ball.texture = text_load_add
					add_visual_ball.transparent_color = tex_info_add.transparent_color
					if tex_info_add.has("texture_size") and tex_info_add.texture_size != null:
						add_visual_ball.texture_size = tex_info_add.texture_size
			add_visual_ball.color_index = add_ball.color_index
			add_visual_ball.palette = pal_texture

		ball_map[add_ball.ball_no] = add_visual_ball

		var is_special_ball = is_special_baby_ball(species, add_ball.ball_no)
		if is_special_ball:
			add_visual_ball.add_to_group("special_balls")
			add_visual_ball.visible = draw_special_balls
		else:
			add_visual_ball.visible = draw_addballs

		# If user hid addballs globally or if omitted
		if !draw_addballs:
			add_visual_ball.visible_override = false
		if omissions.has(key):
			add_visual_ball.visible_override = false
			add_visual_ball.omitted = true

	# Generate paintballz
	for key in paintball_data:
		if !ball_map.has(key) or ball_map[key].omitted:
			continue

		# Merge base ball + addball data so we can locate the base size
		var merged_dict = {}
		for v in ball_data:
			merged_dict[v] = ball_data[v]
		for v in addball_data:
			merged_dict[v] = addball_data[v]

		var base_ball = merged_dict[key]
		var paint_list: Array = paintball_data[key]
		paint_list.invert() # preserve layered order

		var count = 0
		for paintball in paint_list:
			var final_size = base_ball.size * (paintball.size / 100.0)
			final_size -= 1 - fmod(final_size, 2)

			var pb_visual_ball: Spatial
			if new_create:
				pb_visual_ball = paintball_scene.instance()
			else:
				pb_visual_ball = paintball_map[key][count]

			if new_create:
				ball_map[key].add_child(pb_visual_ball)
				pb_visual_ball.set_owner(root)
				pb_visual_ball.add_to_group("paintballs")
				pb_visual_ball.connect("paintball_mouse_enter", self, "signal_paintball_mouse_enter")
				pb_visual_ball.connect("paintball_mouse_exit", self, "signal_paintball_mouse_exit")

				pb_visual_ball.species = species

				if paintball.texture_id >= 0 and paintball.texture_id < texture_list.size():
					var tex_info_pb = texture_list[paintball.texture_id]
					var tex_load_pb = load_texture_from_list(paintball.texture_id, texture_list)
					if tex_load_pb:
						pb_visual_ball.texture = tex_load_pb
						pb_visual_ball.transparent_color = tex_info_pb.transparent_color
						if tex_info_pb.has("texture_size") and tex_info_pb.texture_size != null:
							pb_visual_ball.texture_size = tex_info_pb.texture_size
				pb_visual_ball.color_index = paintball.color_index
				pb_visual_ball.palette = pal_texture

			pb_visual_ball.base_ball_position = ball_map[key].global_transform.origin
			pb_visual_ball.transform.origin = paintball.normalised_position * Vector3(1, -1, 1) * (base_ball.size / 2.0) * pixel_world_size
			pb_visual_ball.ball_size = final_size
			pb_visual_ball.base_ball_size = base_ball.size
			pb_visual_ball.outline_color_index = paintball.outline_color_index
			pb_visual_ball.outline = paintball.outline
			pb_visual_ball.fuzz_amount = clamp(paintball.fuzz / 2, 0, 5)
			pb_visual_ball.z_add = float(count)
			pb_visual_ball.base_ball_no = paintball.base


			if !draw_paintballs:
				pb_visual_ball.visible_override = false

			var ar = paintball_map.get(key, [])
			if new_create:
				ar.append(pb_visual_ball)
				paintball_map[key] = ar

			count += 1

	for ball_no in ball_map.keys():
		var node = ball_map[ball_no]
		if node and node is Spatial:
			_orig_world_pos[ball_no] = node.global_transform.origin
			#print("Saved raw WORLD position for ball %d: %s" % [ball_no, _orig_world_pos[ball_no]])

func get_real_ball_size(ball_size):
	return ball_size

func generate_polygons(polygon_data: Array, species: int, palette, new_create: bool, texture_list: Array):
	#print("Generating polygons")
	#print("Polygon data size:", polygon_data.size())
	var root = get_root()
	var parent = root.get_node("petholder/polygons")
	#print("Parent node found:", parent)

	if new_create:
		for c in parent.get_children():
			parent.remove_child(c)
			c.queue_free()
		polygons_map = {}
	
	var i = 0
	for polygon in polygon_data:
		var point1 = ball_map.get(polygon.ball1)
		var point2 = ball_map.get(polygon.ball2)
		var point3 = ball_map.get(polygon.ball3)
		var point4 = ball_map.get(polygon.ball4)

		# Check if the points exist
		if point1 == null or point2 == null or point3 == null or point4 == null:
			print("Could not make a polygon between " + str(polygon.ball1) + ", " + str(polygon.ball2) + ", " + str(polygon.ball3) + ", " + str(polygon.ball4))
			continue

		#print("Creating polygon between points:", polygon.ball1, polygon.ball2, polygon.ball3, polygon.ball4)
		
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
		#print("Positioning polygon with vertices at: ", point1.global_transform.origin, point2.global_transform.origin, point3.global_transform.origin, point4.global_transform.origin)
		visual_polygon.ball_world_pos1 = point1.global_transform.origin
		visual_polygon.ball_world_pos2 = point2.global_transform.origin
		visual_polygon.ball_world_pos3 = point3.global_transform.origin
		visual_polygon.ball_world_pos4 = point4.global_transform.origin

		if new_create:
			# Check for texture
			if "texture_id" in polygon and polygon.texture_id != null and not str(polygon.texture_id).empty():
				visual_polygon.texture = load_texture_from_list(polygon.texture_id, texture_list)
			else:
				# If no texture is defined, default to first ball
				visual_polygon.texture = point1.texture
			visual_polygon.species = species
			visual_polygon.transparent_color = point1.transparent_color
			#print("Polygon color and texture set.")

			visual_polygon.palette = point1.palette

			if polygon.color == -1:
				visual_polygon.color_index = point1.color_index
			else:
				visual_polygon.color_index = polygon.color
			#print("Polygon color set to: ", visual_polygon.color_index)
		
			# Log left and right edge colors
			#print("Setting edge colors for polygon")
			if polygon.l_edge_color == -1:
				visual_polygon.l_edge_color = point1.color_index
			else:
				visual_polygon.l_edge_color = polygon.l_edge_color
			#print("Left edge color: ", visual_polygon.l_edge_color)

			if polygon.r_edge_color == -1:
				visual_polygon.r_edge_color = point1.color_index
			else:
				visual_polygon.r_edge_color = polygon.r_edge_color
			#print("Right edge color: ", visual_polygon.r_edge_color)

		# Set other polygon properties like fuzz
		visual_polygon.fuzz_amount = clamp(polygon.fuzz / 2, 0, 5)
		#print("Polygon fuzz amount set to:", visual_polygon.fuzz_amount)

		var special_poly =  is_special_baby_ball(species, polygon.ball1) or is_special_baby_ball(species, polygon.ball2) or is_special_baby_ball(species, polygon.ball3) or is_special_baby_ball(species, polygon.ball4)
		if special_poly:
			visual_polygon.add_to_group("special_balls")
			visual_polygon.visible = draw_special_balls
		else:
			visual_polygon.visible = draw_polygons
			
		polygons_map[i] = visual_polygon
		i += 1

func generate_lines(line_data: Array, species: int, palette, new_create: bool):
	var root = get_root()
	var parent = root.get_node("petholder/lines")
	if new_create:
		for c in parent.get_children():
			parent.remove_child(c)
			c.queue_free()
		lines_map = {}
		
	# determine the default palette used
	var default_palette = preload("res://resources/palettes/petz_palette.png")
	if (species == KeyBallsData.Species.BABY):
		default_palette = preload("res://resources/palettes/babyz_palette.png")
	
	var pal_texture = null
	if palette != null:
		var user_resource_path = "user://resources/palettes/" + palette
		var res_resource_path = "res://resources/palettes/" + palette
		if ResourceLoader.exists(user_resource_path):
			pal_texture = ResourceLoader.load(user_resource_path)
		elif ResourceLoader.exists(res_resource_path):
			pal_texture = ResourceLoader.load(res_resource_path)
		else:
			pal_texture = preloader.get_resource("palette_"+palette.to_lower())
	else:
		pal_texture = default_palette
	
	var i = 0
	for line in line_data:
		var start = ball_map.get(line.start)
		var end = ball_map.get(line.end)
		
		if start == null or end == null:
			print("Could not make a line between " + str(line.start) + " and " + str(line.end))
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
			visual_line.species = species
			visual_line.transparent_color = start.transparent_color
			visual_line.palette = pal_texture
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

		var special_line = is_special_baby_ball(species, line.start) or is_special_baby_ball(species, line.end)
		if special_line:
			visual_line.add_to_group("special_balls")
			visual_line.visible = draw_special_balls
		else:
			visual_line.visible = draw_lines
			
		if new_create:
			parent.add_child(visual_line)
			visual_line.set_owner(root)
		
		i += 1

func _on_OptionButton_file_selected(file_name):
	generate_pet(file_name)
	
func _on_OptionButton_file_saved(file_name):
	generate_pet(file_name)
	
func _on_AnimPicker_text_entered(new_text):
	var i = int(new_text)
	if i < bhd.animation_ranges.size():
		set_animation(int(new_text))

func _on_PrevAnim_pressed():
	set_animation(current_animation - 1)

func _on_NextAnim_pressed():
	set_animation(current_animation + 1)

func _on_ToggleSpecialBalls_toggled(button_pressed):
	get_tree().call_group("special_balls", "set_visible", button_pressed)
	draw_special_balls = button_pressed

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
		if paintball is Spatial:
			paintball.set_transparency(button_pressed)

func set_visibility_for_group(group_name: String, is_visible: bool):
	var nodes = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		if node is Spatial:
			node.set_visible(is_visible)

func _on_AddballCheckBox_toggled(button_pressed):
	set_visibility_for_group("addballs", button_pressed)
	draw_addballs = button_pressed

func _on_BallCheckBox_toggled(button_pressed):
	set_visibility_for_group("balls", button_pressed)
	draw_balls = button_pressed

func _on_PaintballCheckBox_toggled(button_pressed):
	set_visibility_for_group("paintballs", button_pressed)
	draw_paintballs = button_pressed

func _on_LineCheckBox_toggled(button_pressed):
	set_visibility_for_group("lines", button_pressed)
	draw_lines = button_pressed

func _on_PolygonCheckBox_toggled(button_pressed):
	set_visibility_for_group("polygons", button_pressed)
	draw_polygons = button_pressed

func signal_ball_mouse_enter(ball_info):
	emit_signal("ball_mouse_enter", ball_info)
	
func signal_ball_mouse_exit(ball_no):
	emit_signal("ball_mouse_exit", ball_no)

func signal_paintball_mouse_enter(ball_info):
	emit_signal("ball_mouse_enter", {ball_no = "Paintball on " + str(ball_info.base_ball_no)})
	
func signal_paintball_mouse_exit():
	emit_signal("ball_mouse_exit", 0)

func signal_ball_selected(ball_no, section):
	var ball = ball_map[ball_no]
	var is_addball = false
	if ball.base_ball_no != -1 and !("override_ball_no" in ball):
		is_addball = true
	emit_signal("ball_selected", section, ball_no, is_addball, lnz.balls.keys().max() + 1)

func signal_ball_deleted(ball_no):
	var ball = ball_map[ball_no]
	if ball.base_ball_no != -1:
		emit_signal("addball_deleted", ball_no)

func _on_LnzTextEdit_find_ball(ball_no):
	if ball_map.has(ball_no):
		ball_map[ball_no].flash()

func _on_LnzTextEdit_find_line(line_no):
	if lines_map.has(line_no):
		var line = lines_map[line_no]
		line.flash()
		var line_data = lnz.lines[line_no]
		if ball_map.has(line_data.start):
			ball_map[line_data.start].flash()
		if ball_map.has(line_data.end):
			ball_map[line_data.end].flash()

func _on_LnzTextEdit_find_paintball(line_no):
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


func _on_LnzTextEdit_find_polygon(line_no):
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

func _on_LnzTextEdit_find_move(line_no):
	if line_no < lnz.moves.size():
		var move_data = lnz.moves[line_no]
		if ball_map.has(move_data.ball_no):
			ball_map[move_data.ball_no].flash()

func _on_LnzTextEdit_find_project_ball(line_no):
	if line_no < lnz.project_ball.size():
		var project_data = lnz.project_ball[line_no]
		if ball_map.has(project_data.fixed_ball):
			ball_map[project_data.fixed_ball].flash()
		if ball_map.has(project_data.project_ball):
			ball_map[project_data.project_ball].flash()
	
func _on_ToolsMenu_print_ball_colors():
	var ball_map_string = ""
	for b in ball_map:
		var ball = ball_map[b]
		var d
		if b < 67:
			d = lnz.balls[b]
		else:
			d = lnz.addballs[b]
		if "ball_no" in ball:
			var this_ball_string = str(ball.ball_no) + ",\t\t" + str(ball.color_index) + ",\t\t" + str(d.group) + ",\t\t" + str(d.texture_id).replace('0', '3')
			if ball_map_string != "":
				ball_map_string += "\n"
			ball_map_string += this_ball_string
			#print(this_ball_string)
	OS.set_clipboard(ball_map_string)

func update_eyelids(tilt_deg: float):
	var tilt = deg2rad(tilt_deg)
	for base_no in eyelid_dir_map.keys():
		var node = ball_map.get(base_no)
		if node:
			if eyelid_mode == 1:
				node.set_eyelid_color(-1)
			else:
				node.set_eyelid_color(lnz.eyelid_color)
			var angle = eyelid_dir_map[base_no] * tilt
			node.set_eyelid_rotation(angle)

func _on_EyeLidButton_pressed():
	eyelid_mode = (eyelid_mode + 1) % EYELID_LABELS.size()
	eyelid_button.icon         = EYELID_ICONS[eyelid_mode]
	update_eyelids(EYELID_TILTS[eyelid_mode])

func emit_ball_translation(ball_no: int, new_position: Vector3):
	emit_signal("ball_translation_changed", ball_no, new_position)

func emit_ball_resize(ball_no: int, size_dif: int):
	emit_signal("ball_resized", ball_no, size_dif)

func remove_last_pending_paintball():
	if _pending_paintballs_data.size() > 0 and _pending_paintball_nodes.size() > 0:
		var last_visual_node = _pending_paintball_nodes.pop_back()
		
		if is_instance_valid(last_visual_node):
			last_visual_node.queue_free()
			
		_pending_paintballs_data.pop_back()

func remove_specific_pending_paintball(paintball_node):
	var index = _pending_paintball_nodes.find(paintball_node)
	if index != -1:
		_pending_paintball_nodes.remove(index)
		_pending_paintballs_data.remove(index)
		if is_instance_valid(paintball_node):
			paintball_node.queue_free()

func get_pending_paintball_nodes():
	return _pending_paintball_nodes

func clear_pending_paintballs():
	for node in _pending_paintball_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_pending_paintball_nodes.clear()
	_pending_paintballs_data.clear()

func add_pending_paintball(paintball_info):
	_pending_paintballs_data.append(paintball_info)
	var base_ball_no = paintball_info.base_ball_no
	if !ball_map.has(base_ball_no):
		return

	var base_ball_node = ball_map[base_ball_no]
	var pb_visual_ball = paintball_scene.instance()

	base_ball_node.add_child(pb_visual_ball)
	pb_visual_ball.set_owner(get_root())
	pb_visual_ball.add_to_group("paintballs")

	var final_size = base_ball_node.ball_size * (float(paintball_info.diameter) / 100.0)
	final_size -= 1 - fmod(final_size, 2)
	pb_visual_ball.ball_size = final_size

	pb_visual_ball.species = lnz.species
	pb_visual_ball.base_ball_no = base_ball_no
	pb_visual_ball.base_ball_position = base_ball_node.global_transform.origin
	pb_visual_ball.base_ball_size = base_ball_node.ball_size
	pb_visual_ball.transform.origin = paintball_info.relative_pos_local
	pb_visual_ball.color_index = paintball_info.color
	pb_visual_ball.outline_color_index = paintball_info.outline_color
	pb_visual_ball.outline = paintball_info.outline_type
	pb_visual_ball.fuzz_amount = clamp(paintball_info.fuzz / 2, 0, 5)

	if paintball_info.texture > -1:
		var tex_pb = load_texture_from_list(paintball_info.texture, lnz.texture_list)
		if tex_pb:
			pb_visual_ball.texture = tex_pb
			if paintball_info.texture < lnz.texture_list.size():
				pb_visual_ball.transparent_color = lnz.texture_list[paintball_info.texture].transparent_color

	pb_visual_ball.palette = base_ball_node.palette

	var existing_paintballs_count = 0
	if paintball_map.has(base_ball_no):
		existing_paintballs_count = paintball_map[base_ball_no].size()
	pb_visual_ball.z_add = float(existing_paintballs_count + _pending_paintballs_data.size())

	_pending_paintball_nodes.append(pb_visual_ball)

func _on_clear_paintballz():
	clear_pending_paintballs()

func _on_randomize_auto_paintballz(paintballz):
	_on_clear_auto_paintballz()
	_auto_paintballs_data = paintballz

	for paintball_data in _auto_paintballs_data:
		var base_ball_no = paintball_data.base
		if !ball_map.has(base_ball_no):
			continue

		var base_ball_node = ball_map[base_ball_no]
		var pb_visual_ball = paintball_scene.instance()

		base_ball_node.add_child(pb_visual_ball)
		pb_visual_ball.set_owner(get_root())
		pb_visual_ball.add_to_group("paintballs")

		var final_size = base_ball_node.ball_size * (float(paintball_data.size) / 100.0)
		final_size -= 1 - fmod(final_size, 2)
		pb_visual_ball.ball_size = final_size

		pb_visual_ball.species = lnz.species
		pb_visual_ball.base_ball_no = base_ball_no
		pb_visual_ball.base_ball_position = base_ball_node.global_transform.origin
		pb_visual_ball.base_ball_size = base_ball_node.ball_size
		pb_visual_ball.transform.origin = paintball_data.position * (base_ball_node.ball_size / 2.0) * pixel_world_size
		pb_visual_ball.color_index = paintball_data.color_index
		pb_visual_ball.outline_color_index = paintball_data.outline_color_index
		pb_visual_ball.outline = paintball_data.outline
		pb_visual_ball.fuzz_amount = clamp(paintball_data.fuzz / 2, 0, 5)

		if paintball_data.texture_id > -1:
			var tex_pb = load_texture_from_list(paintball_data.texture_id, lnz.texture_list)
			if tex_pb:
				pb_visual_ball.texture = tex_pb
				if paintball_data.texture_id < lnz.texture_list.size():
					pb_visual_ball.transparent_color = lnz.texture_list[paintball_data.texture_id].transparent_color

		pb_visual_ball.palette = base_ball_node.palette

		var existing_paintballs_count = 0
		if paintball_map.has(base_ball_no):
			existing_paintballs_count = paintball_map[base_ball_no].size()
		pb_visual_ball.z_add = float(existing_paintballs_count + _auto_paintball_nodes.size())

		_auto_paintball_nodes.append(pb_visual_ball)

func _on_clear_auto_paintballz():
	for node in _auto_paintball_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_auto_paintball_nodes.clear()
	_auto_paintballs_data.clear()

func _on_apply_auto_paintballz():
	var processed_paintballs = {}
	var processed_count = 0
	var cap = 1000

	for pb_data in _auto_paintballs_data:
		if processed_count >= cap:
			break

		var base_ball_node = ball_map.get(pb_data.base)
		if not is_instance_valid(base_ball_node):
			continue

		var local_pos = pb_data.position * (base_ball_node.ball_size / 2.0) * pixel_world_size
		var world_relative_pos = base_ball_node.to_global(local_pos) - base_ball_node.global_transform.origin

		var lnz_scale = lnz.scales.x / 255.0
		var relative_pos_lnz = world_relative_pos / (pixel_world_size * lnz_scale)
		relative_pos_lnz.y *= -1

		var key = str(
			pb_data.base, "_",
			relative_pos_lnz.x, "_",
			relative_pos_lnz.y, "_",
			relative_pos_lnz.z, "_",
			pb_data.size
		)
		
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
			"anchored": (pb_data.anchored == 1)
		}
		_pending_paintballs_data.append(paintball_info)

		processed_count += 1

	var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	if lnz_text_edit:
		lnz_text_edit._on_apply_paintballz()

	_on_clear_auto_paintballz()
