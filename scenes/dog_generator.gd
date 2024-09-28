extends Node

export var pixel_world_size = 0.002

var balls = []
var lines = []
var polygons = []
var ball_map = {}
var paintball_map = {}
var lines_map = {}
var polygons_map = {}

export var draw_balls = true
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

onready var preloader = get_tree().root.get_node("Root/ResourcePreloader") as ResourcePreloader

signal animation_loaded(num_of_frames)
signal bhd_loaded(num_of_animations)
signal ball_mouse_enter(ball_info)
signal ball_mouse_exit(ball_no)
signal ball_selected(ball_no, is_addball)
signal addball_deleted(ball_no)
signal ball_translation_changed(ball_no, new_position)
signal ball_translations_done
signal palette_change(new_palette)

func set_animation(anim_index: int):
	current_animation = anim_index
	bhd.get_frame_offsets_for(anim_index)
	var species = "CAT"
	if lnz.species == KeyBallsData.Species.DOG:
		species = "DOG"
	if lnz.species == KeyBallsData.Species.BABY:
		species = "BABY"
	var anim_frames = bhd.get_frame_offsets_for(anim_index)
	current_bdt = BdtParser.new(species + str(anim_index) + ".bdt", anim_frames, bhd.num_balls)
	set_frame(0)
	emit_signal("animation_loaded", anim_frames.size())

func set_frame(frame: int):
	current_frame = frame
	balls = []
	for n in bhd.num_balls:
		var x = current_bdt.frames[frame][n]
		balls.append(BallData.new(bhd.ball_sizes[n], x.position, n, x.rotation))
	init_visual_balls(lnz, false)

var line_instance = null

func clear_ball_data():
	for ball in balls:
		if ball.instance_exists():
			ball.queue_free()
	balls.clear()
	ball_map.clear()
	paintball_map.clear()
	polygons_map.clear()
	lines_map.clear()

func cleanup_balls():
	for ball in balls:
		if ball != null:
			ball.queue_free()
	balls.clear()

func init_ball_data(species):
	cleanup_balls()

	print("Species:", species)

	if species == KeyBallsData.Species.DOG:
		bhd = BhdParser.new("res://resources/animations/DOG.bhd")
		emit_signal("bhd_loaded", bhd.animation_ranges.size())
		var first_anim_frames = bhd.get_frame_offsets_for(current_animation)
		var bdt = BdtParser.new("DOG" + str(current_animation) + ".bdt", first_anim_frames, bhd.num_balls)
		emit_signal("animation_loaded", first_anim_frames.size())
		current_bdt = bdt
		for n in bhd.num_balls:
			balls.append(BallData.new(bhd.ball_sizes[n], bdt.frames[current_frame][n].position, n, bdt.frames[current_frame][n].rotation))

	elif species == KeyBallsData.Species.CAT:
		bhd = BhdParser.new("res://resources/animations/CAT.bhd")
		emit_signal("bhd_loaded", bhd.animation_ranges.size())
		var first_anim_frames = bhd.get_frame_offsets_for(current_animation)
		var bdt = BdtParser.new("CAT" + str(current_animation) + ".bdt", first_anim_frames, bhd.num_balls)
		emit_signal("animation_loaded", first_anim_frames.size())
		current_bdt = bdt
		for n in bhd.num_balls:
			balls.append(BallData.new(bhd.ball_sizes[n], bdt.frames[current_frame][n].position, n, bdt.frames[current_frame][n].rotation))

	elif species == KeyBallsData.Species.BABY:
		bhd = BhdParser.new("res://resources/animations/BABY.bhd")
		emit_signal("bhd_loaded", bhd.animation_ranges.size())
		var first_anim_frames = bhd.get_frame_offsets_for(current_animation)
		var bdt = BdtParser.new("BABY" + str(current_animation) + ".bdt", first_anim_frames, bhd.num_balls)
		emit_signal("animation_loaded", first_anim_frames.size())
		current_bdt = bdt
		for n in bhd.num_balls:
			balls.append(BallData.new(bhd.ball_sizes[n], bdt.frames[current_frame][n].position, n, bdt.frames[current_frame][n].rotation))

	KeyBallsData.max_base_ball_num = bhd.num_balls

func generate_pet(file_path):
	var lnz_info = LnzParser.new(file_path)
	lnz = lnz_info
	KeyBallsData.species = lnz_info.species
	init_ball_data(lnz_info.species)
	init_visual_balls(lnz_info, true)

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
	generate_balls(collated_data, lnz_info.species, lnz_info.texture_list, new_create)
	apply_projections()
	generate_polygons(lnz_info.polygons, lnz_info.species, new_create)
	generate_lines(lnz_info.lines, lnz_info.species, new_create)

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
	else:
		legs = KeyBallsData.legs_bab
		body_ext = KeyBallsData.body_ext_bab
		face_ext = KeyBallsData.face_ext_bab
		head_ext = KeyBallsData.head_ext_bab
		foot_ext = KeyBallsData.foot_ext_bab
		ear_ext = KeyBallsData.ear_ext_bab
		
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
		b.size += v.size
		b.outline_color_index = v.outline_color_index
		b.outline = v.outline
		b.fuzz = v.fuzz
		var moves = lnz.moves.get(k, [])
		var q = Quat()
		for m in moves:
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
		var visual_ball = ball_map[project_ball_data.ball] as Spatial
		var static_ball = ball_map[project_ball_data.base] as Spatial
		var vec = visual_ball.global_transform.origin - static_ball.global_transform.origin
		var base_pos = static_ball.global_transform.origin
		visual_ball.global_transform.origin = base_pos + (vec * project_ball_data.amount / 100.0)
		
func apply_sizes(all_ball_dict: Dictionary, lnz: LnzParser):
	for k in all_ball_dict.balls:
		var ball = all_ball_dict.balls[k]
		ball.size = ball.size - 2
		ball.size = round(ball.size * (lnz.scales[1] / 255.0))
		ball.size -= 1 - fmod(ball.size, 2)
#		ball.fuzz = floor(ball.fuzz * (lnz.scales[1] / 255.0))
		ball.position = (ball.position * (lnz.scales[0] / 255.0))
		all_ball_dict.balls[k] = ball
		
	for k in all_ball_dict.addballs:
		var ball = all_ball_dict.addballs[k]
		ball.size = ball.size - 2
		ball.size = round(ball.size * (lnz.scales[1] / 255.0))
		ball.size -= 1 - fmod(ball.size, 2)
#		ball.fuzz = floor(ball.fuzz * (lnz.scales[1] / 255.0))
		ball.position = (ball.position * (lnz.scales[0] / 255.0))
		all_ball_dict.addballs[k] = ball
		
	return {balls = all_ball_dict.balls, addballs = all_ball_dict.addballs, paintballs = all_ball_dict.paintballs}

func get_root():
	if Engine.is_editor_hint():
		return get_tree().get_edited_scene_root().get_node("PetRoot")
	else:
		return get_tree().root.get_node("Root/PetRoot")

func generate_balls(all_ball_data: Dictionary, species: int, texture_list: Array, new_create: bool):
	var ball_data = all_ball_data.balls
	var addball_data = all_ball_data.addballs
	var paintball_data = all_ball_data.paintballs
	var omissions = all_ball_data.omissions
	var root = get_root()
	var parent = root.get_node("petholder/balls")
	var pb_parent = root.get_node("petholder/paintballs")
	var ab_parent = root.get_node("petholder/addballs")
	
	# Clear existing visual balls
	if new_create:
		for c in parent.get_children():
			parent.remove_child(c)
			c.queue_free()
		for c in pb_parent.get_children():
			pb_parent.remove_child(c)
			c.queue_free()
		for c in ab_parent.get_children():
			ab_parent.remove_child(c)
			c.queue_free()
		ball_map = {}
		paintball_map = {}
	
	# Determine belly position and palette name
	var belly_position
	
	var palette_name = "PETZ"
	if species == KeyBallsData.Species.DOG:
		belly_position = ball_data[KeyBallsData.belly_dog].position
		palette_name = "PETZ"
	elif species == KeyBallsData.Species.CAT:
		belly_position = ball_data[KeyBallsData.belly_cat].position
		palette_name = "PETZ"
	else:
		belly_position = ball_data[KeyBallsData.belly_bab].position
		palette_name = "BABYZ"
	
	print("Using palette for Ballz:", palette_name)
	
	belly_position.y *= -1
	belly_position *= pixel_world_size
	
	# Process eyes
	var eyes: Dictionary
	if species == KeyBallsData.Species.DOG:
		eyes = KeyBallsData.eyes_dog
	elif species == KeyBallsData.Species.CAT:
		eyes = KeyBallsData.eyes_cat
	else:
		eyes = KeyBallsData.eyes_bab
	
	for key in ball_data:
		var ball = ball_data[key]
		var visual_ball
		
		if(key in eyes.keys()): # treat irises like paintballs
			if new_create:
				visual_ball = paintball_scene.instance()
				visual_ball.add_to_group("balls")
				visual_ball.z_add = 10
				visual_ball.override_ball_no = ball.ball_no
				visual_ball.color_index = ball.color_index
				visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
				visual_ball.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
				visual_ball.connect("ball_selected", self, "signal_ball_selected")
				
				parent.add_child(visual_ball)
				visual_ball.set_owner(root)
				
				visual_ball.update_palette_after_added(palette_name)
			
			else:
				visual_ball = ball_map[key]
				
			var base_ball = ball_data[eyes[key]]
			visual_ball.base_ball_size = base_ball.size
			var bbp = base_ball.position
			bbp.y *= -1
			bbp *= pixel_world_size
			visual_ball.base_ball_position = bbp
			var rotated_pos = ball.position
			rotated_pos.y *= -1.0
			visual_ball.transform.origin = rotated_pos * pixel_world_size
			
		else:
			if new_create:
				visual_ball = ball_scene.instance()
				visual_ball.add_to_group("balls")
				visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
				visual_ball.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
				visual_ball.connect("ball_selected", self, "signal_ball_selected")
				
				parent.add_child(visual_ball)
				visual_ball.set_owner(root)
				
				visual_ball.update_palette_after_added(palette_name)
				
			else:
				visual_ball = ball_map[key]
			visual_ball.pet_center = belly_position
			var rotated_pos = ball.position
			rotated_pos.y *= -1.0
			visual_ball.transform.origin = rotated_pos * pixel_world_size
			visual_ball.ball_no = ball.ball_no
			
			# Apply texture to ball
			if new_create:
				if ball.texture_id > -1:
					var tex_info = texture_list[ball.texture_id]
					var texture_filename = tex_info.filename
					visual_ball.transparent_color = tex_info.transparent_color
					var resource_path = "res://resources/textures/"+texture_filename
					var user_resource_path = "user://resources/textures/"+texture_filename
					var texture = null
					if ResourceLoader.exists(resource_path):
						texture = ResourceLoader.load(resource_path)
					else:
						texture = preloader.get_resource(texture_filename)
						
					visual_ball.texture = texture
				visual_ball.color_index = ball.color_index
				visual_ball.outline_color_index = ball.outline_color_index
				
		# Ball properties
		if new_create:
			visual_ball.ball_size = get_real_ball_size(ball.size)
			visual_ball.outline = ball.outline
			visual_ball.outline_color_index = ball.outline_color_index
			visual_ball.fuzz_amount = clamp(ball.fuzz / 2, 0, 5)
		visual_ball.rotation_degrees = ball.rotation
		
		# Finalize creation
		if new_create:
			parent.add_child(visual_ball)
			visual_ball.set_owner(root)
		ball_map[ball.ball_no] = visual_ball
		
		# Handle visibility and omissions
		if !draw_balls:
			visual_ball.visible_override = false
		if omissions.get(key, false):
			visual_ball.visible_override = false
			visual_ball.omitted = true
			
	for key in addball_data:
		var ball = addball_data[key]
		var visual_ball
		if new_create:
			visual_ball = ball_scene.instance()
		else:
			visual_ball = ball_map[key]
		if new_create:
			ball_map[ball.base].add_child(visual_ball)
			visual_ball.set_owner(root)
			visual_ball.add_to_group("addballs")
			visual_ball.z_add = ball.size / 10.0
			visual_ball.ball_size = ball.size
			visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
			visual_ball.connect("ball_selected", self, "signal_ball_selected")
			visual_ball.connect("ball_deleted", self, "signal_ball_deleted")
		var total_pos = ball.position
		total_pos.y *= -1.0
		visual_ball.transform.origin = total_pos * pixel_world_size
		if new_create:
			visual_ball.outline = ball.outline
			visual_ball.fuzz_amount = clamp(ball.fuzz / 2, 0, 5)
			visual_ball.ball_no = ball.ball_no
			visual_ball.base_ball_no = ball.base
			visual_ball.outline_color_index = ball.outline_color_index
			visual_ball.update_palette_after_added(palette_name)
		visual_ball.scale = Vector3(1,1,1)
		if new_create:
			if ball.texture_id > -1:
				var tex_info = texture_list[ball.texture_id]
				var texture_filename = tex_info.filename
				visual_ball.transparent_color = tex_info.transparent_color
				var texture = null
				var resource_path = "res://resources/textures/"+texture_filename
				var user_resource_path = "user://resources/textures/"+texture_filename
				if ResourceLoader.exists(resource_path):
					texture = ResourceLoader.load(resource_path)
				else:
					texture = preloader.get_resource(texture_filename)
				visual_ball.texture = texture
			visual_ball.color_index = ball.color_index
		ball_map[ball.ball_no] = visual_ball
		if !draw_addballs:
			visual_ball.visible_override = false
		if omissions.get(key, false):
			visual_ball.visible_override = false
			visual_ball.omitted = true
			
	for key in paintball_data:
		if ball_map[key].omitted:
			continue
		var merged_dict = {}
		for v in ball_data:
			merged_dict[v] = ball_data[v]
		for v in addball_data:
			merged_dict[v] = addball_data[v]
		var base_ball = merged_dict[key]
		var paintballs_for_base_ball: Array = paintball_data[key]
		paintballs_for_base_ball.invert()
		var count = 0
		for paintball in paintballs_for_base_ball:
			var final_size = base_ball.size * (paintball.size / 100.0)
			final_size -= 1 - fmod(final_size, 2)
			var visual_ball: Spatial
			if new_create:
				visual_ball = paintball_scene.instance()
			else:
				visual_ball = paintball_map[key][count]
			if new_create:
				ball_map[key].add_child(visual_ball)
				visual_ball.set_owner(root)
				visual_ball.add_to_group("paintballs")
				visual_ball.connect("paintball_mouse_enter", self, "signal_paintball_mouse_enter")
				visual_ball.connect("paintball_mouse_exit", self, "signal_paintball_mouse_exit")
				if paintball.texture_id > -1:
					var tex_info = texture_list[paintball.texture_id]
					var texture_filename = tex_info.filename
					visual_ball.transparent_color = tex_info.transparent_color
					var texture = null
					var resource_path = "res://resources/textures/"+texture_filename
					var user_resource_path = "user://resources/textures/"+texture_filename
					if ResourceLoader.exists(resource_path):
						texture = ResourceLoader.load(resource_path)
					else:
						texture = preloader.get_resource(texture_filename)
					visual_ball.texture = texture
				else:
					visual_ball.transparent_color = paintball.color_index
				visual_ball.color_index = paintball.color_index

				# Update palette for paintballs
				visual_ball.update_palette_after_added(palette_name)

			visual_ball.base_ball_position = ball_map[key].global_transform.origin
			visual_ball.transform.origin = paintball.normalised_position * Vector3(1, -1, 1) * (base_ball.size / 2.0) * pixel_world_size
			visual_ball.ball_size = final_size
			visual_ball.base_ball_size = base_ball.size
			visual_ball.outline_color_index = paintball.outline_color_index
			visual_ball.outline = paintball.outline
			visual_ball.fuzz_amount = clamp(paintball.fuzz / 2, 0, 5)
			visual_ball.z_add = count * 1.0
			visual_ball.base_ball_no = paintball.base
			count += 1
			var ar = paintball_map.get(key, [])
			ar.append(visual_ball)
			paintball_map[key] = ar
			if !draw_paintballs:
				visual_ball.visible_override = false

func get_real_ball_size(ball_size):
	return ball_size

func generate_polygons(polygon_data: Array, species: int, new_create: bool):
	print("Generating polygons")
	print("Polygon data size:", polygon_data.size())
	var root = get_root()
	var parent = root.get_node("petholder/polygons")
	print("Parent node found:", parent)

	if new_create:
		for c in parent.get_children():
			parent.remove_child(c)
			c.queue_free()
		polygons_map = {}

	# Set palette based on species
	var palette_name = "PETZ"
	if species == KeyBallsData.Species.DOG:
		palette_name = "PETZ"
	elif species == KeyBallsData.Species.CAT:
		palette_name = "PETZ"
	else:
		palette_name = "BABYZ"
		
	print("Using palette for Polygonz:", palette_name)
	
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

		print("Creating polygon between points:", polygon.ball1, polygon.ball2, polygon.ball3, polygon.ball4)
		
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
		print("Positioning polygon with vertices at: ", point1.global_transform.origin, point2.global_transform.origin, point3.global_transform.origin, point4.global_transform.origin)
		visual_polygon.ball_world_pos1 = point1.global_transform.origin
		visual_polygon.ball_world_pos2 = point2.global_transform.origin
		visual_polygon.ball_world_pos3 = point3.global_transform.origin
		visual_polygon.ball_world_pos4 = point4.global_transform.origin

		if new_create:
			# Update palette for polygons
			visual_polygon.update_palette_after_added(palette_name)
			print("Updated polygon palette to:", palette_name)
			
			# Use the first point's texture
			visual_polygon.texture = point1.texture  
			visual_polygon.transparent_color = point1.transparent_color
			print("Polygon color and texture set.")

			if polygon.color == -1:
				visual_polygon.color_index = point1.color_index
			else:
				visual_polygon.color_index = polygon.color
			print("Polygon color set to: ", visual_polygon.color_index)
		
			# Log left and right edge colors
			print("Setting edge colors for polygon")
			if polygon.l_edge_color == -1:
				visual_polygon.l_edge_color = point1.color_index
			else:
				visual_polygon.l_edge_color = polygon.l_edge_color
			print("Left edge color: ", visual_polygon.l_edge_color)

			if polygon.r_edge_color == -1:
				visual_polygon.r_edge_color = point1.color_index
			else:
				visual_polygon.r_edge_color = polygon.r_edge_color
			print("Right edge color: ", visual_polygon.r_edge_color)

		# Set other polygon properties like fuzz
		visual_polygon.fuzz_amount = clamp(polygon.fuzz / 2, 0, 5)
		print("Polygon fuzz amount set to:", visual_polygon.fuzz_amount)

		if !draw_polygons:
			visual_polygon.hide()
			print("Polygon hidden as draw_polygons is false.")
		
		visual_polygon.update_palette_after_added(palette_name)
		print("Updated polygon palette to:", palette_name)
		
		polygons_map[i] = visual_polygon
		i += 1


func generate_lines(line_data: Array, species: int, new_create: bool):
	var root = get_root()
	var parent = root.get_node("petholder/lines")
	if new_create:
		for c in parent.get_children():
			parent.remove_child(c)
			c.queue_free()
		lines_map = {}
	
	var palette_name = "PETZ"
	if species == KeyBallsData.Species.DOG:
		palette_name = "PETZ"
	elif species == KeyBallsData.Species.CAT:
		palette_name = "PETZ"
	else:
		palette_name = "BABYZ"
		
	print("Using palette for Linez:", palette_name)
	
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

		if target_pos == middle_point:
			visual_line.global_transform.origin = middle_point
			visual_line.rotation_degrees.x += 90
			visual_line.scale.y = distance
		else:
			visual_line.look_at_from_position(middle_point, target_pos, Vector3.UP)
			visual_line.rotation_degrees.x += 90
			visual_line.scale.y = distance
		if new_create:
			# Update palette for lines
			visual_line.update_palette_after_added(palette_name)
			
			visual_line.texture = start.texture
			visual_line.transparent_color = start.transparent_color
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
		if !draw_lines:
			visual_line.hide()
		if new_create:
			parent.add_child(visual_line)
			visual_line.set_owner(root)
		
		# Update palette for lines
		visual_line.update_palette_after_added(palette_name)		
		i += 1

func _on_OptionButton_file_selected(file_name):
	generate_pet(file_name)
	
func _on_OptionButton_file_saved(file_name):
	generate_pet(file_name)
	
func _on_AnimPicker_text_entered(new_text):
	var i = int(new_text)
	if i < bhd.animation_ranges.size():
		set_animation(int(new_text))

func _on_ToggleSpecialBalls_toggled(button_pressed):
	for key in ball_map:
		var visual_ball = ball_map[key]
		if visual_ball.base_ball_no >= 120 and visual_ball.base_ball_no <= 137:
			visual_ball.set_visible(button_pressed)

func _on_BallCheckBox_toggled(button_pressed):
	get_tree().call_group("balls", "set_visible", button_pressed)
	draw_balls = button_pressed
	
func _on_AddballCheckBox_toggled(button_pressed):
	get_tree().call_group("addballs", "set_visible", button_pressed)
	draw_addballs = button_pressed
	
func _on_PaintballCheckBox_toggled(button_pressed):
	get_tree().call_group("paintballs", "set_visible", button_pressed)
	draw_paintballs = button_pressed
	
func _on_PolygonCheckBox_toggled(button_pressed):
	get_tree().call_group("polygons", "set_visible", button_pressed)
	draw_polygons = button_pressed
	
func _on_LineCheckBox_toggled(button_pressed):
	get_tree().call_group("lines", "set_visible", button_pressed)
	draw_lines = button_pressed

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
			print(this_ball_string)
	OS.set_clipboard(ball_map_string)
