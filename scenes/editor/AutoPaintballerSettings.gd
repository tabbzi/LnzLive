extends DraggablePanel
## AutoPaintballerSettings.gd
## Manages panel UI and logic for the Auto Paintballer tool
## This script controls procedural generation of paintballz
## 1. Gathers all selected properties
## 2. Generates a list of `PaintBallData` objects
## 3. Emits `randomize_auto_paintballz` signal for the `dog_generator` to queue and display
## 4. Commits to applying and clearing of queued paintballz

enum Distribution {
	UNIFORM,            # 00
	SPIRAL,             # 01
	STAR,               # 02
	BANDS,              # 03
	NOISE_FIELD,        # 04
	GRID,               # 05
	CHECKERBOARD,       # 06
	RANDOM_WALK,        # 07
	CLUSTERED,          # 08
	POLE_FOCUSED,       # 09
	EQUATOR_FOCUSED,    # 10
	HALFIE,             # 11
	BULLSEYE,           # 12
	LEOPARD,            # 13
	RAINBOW,            # 14
	STRIPES,            # 15
	FRACTAL,            # 16
	VORONOI,            # 17
	WAVE                # 18
}

enum FractalPreset { CUSTOM, DRAGON_CURVE, SIERPINSKI, BARNSLEY_FERN }

const ALLOWED_FRACTAL_CHARS: String = "FGABX+-[]"

signal randomize_auto_paintballz(paintballz)
signal apply_auto_paintballz
signal clear_auto_paintballz
signal affected_list_changed(ball_ids)
signal unselect_all

onready var params_container: Control = find_node("ParamsContainer")
var pet_node: Node = null

var _is_loading_settings: bool = false

var cached_palette_colors: Array = []

var _ordered_color_index: int = 0
var _ordered_outline_color_index: int = 0
var _ordered_texture_index: int = 0
var _ordered_ball_index: int = 0

func _ready() -> void:
	if get_tree().root.has_node("Root/PetRoot/Node"):
		pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	elif get_tree().root.has_node("Root/PetRoot"):
		pet_node = get_tree().root.get_node("Root/PetRoot")
		
	if pet_node:
		pet_node.connect("palette_changed", self, "_on_palette_changed")
		
	var viewport_size: Vector2 = get_viewport().size
	var panel: Control = self
	var panel_size: Vector2 = panel.rect_size
	
	var default_x: float = (viewport_size.x - panel_size.x) / 2.0
	var default_y: float = viewport_size.y - panel_size.y - 10.0
	var default_pos: Vector2 = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)
	
	find_node("RandomizeButton").connect("pressed", self, "_on_RandomizeButton_pressed")
	find_node("AffectedBallz").connect("text_changed", self, "_on_AffectedBallz_text_changed")
	find_node("UnselectButton").connect("pressed", self, "_on_UnselectButton_pressed")
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("ClearButton").connect("pressed", self, "_on_ClearButton_pressed")
	find_node("SurpriseButton").connect("pressed", self, "_on_SurpriseButton_pressed")
	find_node("Distribution").connect("item_selected", self, "_on_Distribution_item_selected")
	find_node("UseSeed").connect("toggled", self, "_on_UseSeed_toggled")

	find_node("FractalPreset").connect("item_selected", self, "_on_FractalPreset_item_selected")
	find_node("FractalAxiom").connect("text_changed", self, "_on_FractalAxiom_text_changed")

	find_node("RandomSystemButton").connect("pressed", self, "_on_RandomSystemButton_pressed")
	
	_on_Distribution_item_selected(0)
	_on_FractalPreset_item_selected(find_node("FractalPreset").selected)

	_setup_color_previews()
	_connect_settings_signals()
	load_settings()
	call_deferred("_on_palette_changed")

func _setup_color_previews() -> void:
	_setup_preview_wrapper("ColorList")
	_setup_preview_wrapper("OutlineColorList")

func _setup_preview_wrapper(le_name: String) -> void:
	var le = find_node(le_name, true, false)
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
	_update_previews_inner(new_text, find_node(le_name + "_Preview", true, false))

func _refresh_all_previews() -> void:
	var color_node = find_node("ColorList", true, false)
	var color_prev: Control = find_node("ColorList_Preview", true, false)
	if color_node and color_prev:
		_update_previews_inner(color_node.text, color_prev)
		
	var out_node = find_node("OutlineColorList", true, false)
	var out_prev: Control = find_node("OutlineColorList_Preview", true, false)
	if out_node and out_prev:
		_update_previews_inner(out_node.text, out_prev)

func _update_previews_inner(text: String, container: Container) -> void:
	LnzLiveUtils.update_color_list_previews(container, text, cached_palette_colors)

func _on_palette_changed(palette_name = "") -> void:
	if not is_instance_valid(pet_node) or not "current_palette_texture" in pet_node or not pet_node.current_palette_texture:
		return
		
	var img: Image = pet_node.current_palette_texture.get_data()
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
			
	img.unlock()
	_refresh_all_previews()

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

func get_color_from_index(index: int) -> Color:
	if index >= 0 and index < cached_palette_colors.size():
		return cached_palette_colors[index]
	return Color.white

func _on_UseSeed_toggled(button_pressed: bool) -> void:
	var seed_edit = find_node("Seed")
	seed_edit.editable = button_pressed

func _on_RandomSystemButton_pressed() -> void:
	var axiom_edit = find_node("FractalAxiom")
	var rules_edit: TextEdit = find_node("FractalRules")
	var angle_edit: SpinBox = find_node("FractalAngle")
	
	var random_system: Dictionary = LnzLiveUtils.generate_random_lsystem()
	axiom_edit.text = random_system["axiom"]
	rules_edit.text = random_system["rules_text"]
	angle_edit.value = [30, 45, 60, 90, 120][randi() % 5]

func _on_FractalPreset_item_selected(index: int) -> void:
	var axiom_edit = find_node("FractalAxiom")
	var rules_edit: TextEdit = find_node("FractalRules")
	var angle_edit: SpinBox = find_node("FractalAngle")
	var random_button: Button = find_node("RandomSystemButton")

	axiom_edit.editable = false
	rules_edit.readonly = true
	random_button.hide()
	
	match index:
		FractalPreset.DRAGON_CURVE:
			axiom_edit.text = "F"
			rules_edit.text = "F=F+G\nG=F-G"
			angle_edit.value = 90.0
		FractalPreset.SIERPINSKI:
			axiom_edit.text = "A"
			rules_edit.text = "A=B-A-B\nB=A+B+A"
			angle_edit.value = 60.0
		FractalPreset.BARNSLEY_FERN:
			axiom_edit.text = "X"
			rules_edit.text = "X=F+[[X]-X]-F[-FX]+X\nF=FF"
			angle_edit.value = 25.0
		FractalPreset.CUSTOM:
			axiom_edit.editable = true
			rules_edit.readonly = false
			random_button.show()
			pass

func _on_FractalAxiom_text_changed(new_text: String) -> void:
	var axiom_edit = find_node("FractalAxiom")
	var sanitized_text: String = ""
	
	for current_char in new_text:
		if ALLOWED_FRACTAL_CHARS.find(current_char) != -1:
			sanitized_text += current_char
			
	if sanitized_text != new_text:
		var cursor_pos: int = axiom_edit.caret_position
		axiom_edit.text = sanitized_text
		axiom_edit.caret_position = min(cursor_pos, sanitized_text.length())

func _on_AffectedBallz_text_changed(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("affected_list_changed", ids)

func _on_Distribution_item_selected(index: int) -> void:
	for child in params_container.get_children():
		child.hide()

	var description_label: RichTextLabel = find_node("DescriptionLabel")
	var description: String = ""

	match index:
		Distribution.UNIFORM: # 00
			description = "Randomly places spots over ballz."
		Distribution.SPIRAL: # 01
			description = "Arranges spots in a spiral pattern."
		Distribution.STAR: # 02
			description = "Creates star-shaped patterns. 'Spots' is the number of stars. 'Point Count' and 'Ray Length' control the shape."
		Distribution.BANDS: # 03
			description = "Creates bands of spots. 'Bands' controls the number of bands. Use 'Direction' to choose horizontal or vertical alignment."
		Distribution.NOISE_FIELD: # 04
			description = "Places spots organically based on simplex noise."
		Distribution.GRID: # 05
			description = "Arranges spots in a grid. 'Grid Size' controls the density."
		Distribution.CHECKERBOARD: # 06
			description = "Arranges spots in a checkerboard pattern. 'Grid Size' controls the density."
		Distribution.RANDOM_WALK: # 07
			description = "Creates a meandering path of spots."
		Distribution.CLUSTERED: # 08
			description = "Groups spots into clusters. 'Clusters' controls the number of groups."
		Distribution.POLE_FOCUSED: # 09
			description = "Concentrates spots around the top and bottom of ballz."
		Distribution.EQUATOR_FOCUSED: # 10
			description = "Concentrates spots around the equator of ballz."
		Distribution.HALFIE: # 11
			description = "Restricts spots to one half of the surface. 'Axis' and 'Side' control which half."
		Distribution.BULLSEYE: # 12
			description = "Creates bullseye patterns. 'Spots' is the number of bullseyes. 'Rings' controls the number of rings in each."
		Distribution.LEOPARD: # 13
			description = "Creates leopard-like spots. 'Spots' is the number of leopard spots. Requires at least 2 colors (outer and inner). Parameters control the shape and completeness of the spots."
		Distribution.RAINBOW: # 14
			description = "Creates rainbow arcs. 'Spots' is the number of rainbows. Parameters control the shape of the arcs."
		Distribution.STRIPES: # 15
			description = "Generates natural Turing patterns like stripes and blotches using Gray-Scott reaction-diffusion. Feed/Kill rates determine density and Diffusion controls feature size."
		Distribution.FRACTAL: # 16
			description = "Generates fractal patterns using an L-system."
		Distribution.VORONOI: # 17
			description = "Creates patterns based on cellular boundaries. 'Cells' controls the density of the pattern, and 'Edge Size' controls the thickness of the lines."
		Distribution.WAVE: # 18
			description = "Generates wave-like or banded patterns using spherical harmonics. 'Degree (L)' controls vertical frequency and 'Order (M)' controls horizontal frequency."


	description_label.bbcode_text = description

	match index:
		Distribution.SPIRAL: # 01
			params_container.get_node("SpiralTurnsContainer").show()
		Distribution.STAR: # 02
			params_container.get_node("StarPointsContainer").show()
			params_container.get_node("RayLengthContainer").show()
		Distribution.BANDS: # 03
			params_container.get_node("BandsContainer").show()
		Distribution.NOISE_FIELD: # 04
			params_container.get_node("NoiseContainer").show()
		Distribution.GRID, Distribution.CHECKERBOARD: # 05, 06
			params_container.get_node("GridSizeContainer").show()
		Distribution.CLUSTERED: # 08
			params_container.get_node("NumClustersContainer").show()
		Distribution.HALFIE: # 11
			params_container.get_node("HalfieContainer").show()
		Distribution.BULLSEYE: # 12
			params_container.get_node("BullseyeContainer").show()
		Distribution.LEOPARD: # 13
			params_container.get_node("LeopardContainer").show()
		Distribution.RAINBOW: # 14
			params_container.get_node("RainbowContainer").show()
		Distribution.STRIPES: # 15
			params_container.get_node("StripesContainer").show()
		Distribution.FRACTAL: # 16
			params_container.get_node("FractalContainer").show()
		Distribution.VORONOI: # 17
			params_container.get_node("VoronoiContainer").show()
		Distribution.WAVE: # 18
			params_container.get_node("WaveContainer").show()

	var num_spots_edit = find_node("NumSpots")
	if num_spots_edit:
		var current_val = num_spots_edit.value
		var new_val = 25.0

		match index:
			Distribution.STAR:
				new_val = 5.0
			Distribution.RAINBOW:
				new_val = 3.0
			Distribution.LEOPARD:
				new_val = 10.0
			Distribution.BULLSEYE:
				new_val = 10.0
			Distribution.FRACTAL:
				new_val = 1.0
			_:
				new_val = 25.0

		if current_val > new_val:
			num_spots_edit.value = new_val


func _on_RandomizeButton_pressed() -> void:
	var properties: Dictionary = get_properties()
	
	var affected_ballz: Array = LnzLiveUtils.parse_number_list(properties["affected_ballz"])
	if affected_ballz.empty():
		affected_ballz = [0]
		find_node("AffectedBallz").text = "0"

	var color_list: Array = LnzLiveUtils.parse_number_list(properties["color_list"])
	if color_list.empty():
		color_list = [105]
		find_node("ColorList").text = "105"

	var outline_color_list: Array = LnzLiveUtils.parse_number_list(properties["outline_color_list"])
	if outline_color_list.empty():
		outline_color_list = [244]
		find_node("OutlineColorList").text = "244"

	var texture_list_str: String = properties["texture_list"]
	var texture_list: Array = LnzLiveUtils.parse_number_list(texture_list_str, true) # Allow negatives
	if texture_list.empty() and not texture_list_str.strip_edges().empty():
		push_warning("Could not parse [Texture List] so using default.")
		texture_list.append(-1)
	elif texture_list.empty():
		texture_list.append(-1)

	var paintballz: Array = []
	var distribution_mode: int = properties["distribution"]

	var base_seed: int = int(properties["seed"]) if (properties["use_seed"] and properties["seed"].is_valid_integer()) else OS.get_ticks_usec()
	if !properties["use_seed"]: find_node("Seed").text = str(base_seed)

	var global_data = null
	if distribution_mode == Distribution.STRIPES:
		global_data = LnzLiveUtils.calculate_gray_scott_grid(
			32, 100, properties["diffusion_a"], properties["diffusion_b"], 
			properties["stripe_feed_rate"], properties["stripe_kill_rate"], properties["stripe_timestep"]
		)

	for b_idx in range(affected_ballz.size()):
		var current_ball: int = affected_ballz[b_idx]
		seed(base_seed + (b_idx * 13)) 
		var num_spots: int = int(properties["num_spots"])
		var spots_per_ball: int = 0
		if properties.get("size_adaptive", false) and pet_node and pet_node.lnz and pet_node.lnz.balls:
			var total_w: float = 0.0
			for id in affected_ballz:
				if pet_node.lnz.balls.has(id): total_w += pet_node.lnz.balls[id].size
			var current_w: float = 1.0
			if pet_node.lnz.balls.has(affected_ballz[b_idx]): current_w = pet_node.lnz.balls[affected_ballz[b_idx]].size
			if total_w > 0: spots_per_ball = int(round((current_w / total_w) * num_spots))
			else: spots_per_ball = num_spots / affected_ballz.size()
		else:
			spots_per_ball = num_spots / affected_ballz.size()
			if b_idx < (num_spots % affected_ballz.size()):
				spots_per_ball += 1

		match distribution_mode:
			Distribution.FRACTAL:
				paintballz += _generate_fractal_pattern(properties, current_ball, color_list, outline_color_list, texture_list)
			Distribution.NOISE_FIELD:
				paintballz += _generate_noise_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.VORONOI:
				paintballz += _generate_voronoi_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.WAVE:
				paintballz += _generate_wave_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.STRIPES:
				paintballz += _generate_stripes_pattern(properties, current_ball, spots_per_ball, global_data, color_list, outline_color_list, texture_list)
			Distribution.STAR:
				paintballz += _generate_star_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.LEOPARD:
				paintballz += _generate_leopard_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.BULLSEYE:
				paintballz += _generate_bullseye_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.RAINBOW:
				paintballz += _generate_rainbow_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.RANDOM_WALK:
				paintballz += _generate_random_walk(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.CLUSTERED:
				paintballz += _generate_clustered_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			_: 
				paintballz += _generate_simple_pattern(properties, current_ball, spots_per_ball, b_idx, affected_ballz.size(), color_list, outline_color_list, texture_list)

	emit_signal("randomize_auto_paintballz", paintballz)
# UNIFORM, SPIRAL, BANDS, POLE, EQUATOR, HALFIE, GRID, CHECKERBOARD
func _generate_simple_pattern(p: Dictionary, ball_no: int, spots: int, b_idx: int, total_balls: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	var mode: int = p["distribution"]
	for i in range(spots):
		var pos: Vector3 = Vector3.UP
		var size: float = rand_range(p["size_min"], p["size_max"])
		
		if mode == Distribution.UNIFORM:
			pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		elif mode == Distribution.SPIRAL:
			var angle: float = i * (TAU * p["spiral_turns"] / spots)
			var y: float = lerp(-1, 1, float(i) / spots)
			var r: float = sqrt(max(0, 1 - y*y))
			pos = Vector3(r * cos(angle), y, r * sin(angle))
		elif mode == Distribution.BANDS:
			var band_idx: int = floor(i * p["num_bands"] / spots)
			var y: float = lerp(-p["band_spacing"], p["band_spacing"], float(band_idx)/max(1, p["num_bands"]-1)) + p["band_offset"]
			var r: float = sqrt(max(0, 1 - y*y))
			var a: float = randf() * TAU
			pos = Vector3(r * cos(a), y, r * sin(a))
			if p["band_direction"] == 1: pos = Vector3(pos.y, pos.x, pos.z)
			pos = pos.rotated(Vector3.FORWARD, deg2rad(p["band_angle"]))
		elif mode == Distribution.POLE_FOCUSED:
			var y: float = (1.0 - pow(randf(), 2)) * (1 if randf() > 0.5 else -1)
			var a: float = randf() * TAU
			var r: float = sqrt(max(0, 1-y*y))
			pos = Vector3(r * cos(a), y, r * sin(a))
		elif mode == Distribution.EQUATOR_FOCUSED:
			var y: float = rand_range(-0.15, 0.15)
			var a: float = randf() * TAU
			pos = Vector3(sqrt(1-y*y)*cos(a), y, sqrt(1-y*y)*sin(a))
		elif mode == Distribution.HALFIE:
			pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			pos[p["halfie_axis"]] = abs(pos[p["halfie_axis"]]) * (1 if p["halfie_side"] == 0 else -1)
			pos = pos.normalized()
		elif mode == Distribution.GRID:
			var gs: int = p["grid_size"]
			var u: float = float(i % int(gs)) / gs
			var v: float = float(i / int(gs)) / gs
			var theta: float = u * TAU
			var phi: float = acos(clamp(2 * v - 1, -1, 1))
			pos = Vector3(sin(phi)*cos(theta), cos(phi), sin(phi)*sin(theta))
		elif mode == Distribution.CHECKERBOARD:
			var gs: int = int(p["grid_size"])
			var valid_found: bool = false
			var attempts: int = 0
			while not valid_found and attempts < 100:
				attempts += 1
				var u_idx: int = randi() % gs
				var v_idx: int = randi() % gs
				if (u_idx + v_idx) % 2 == 1:
					var u: float = (u_idx + randf()) / gs
					var v: float = (v_idx + randf()) / gs
					var theta: float = u * TAU
					var phi: float = acos(clamp(2 * v - 1, -1, 1))
					pos = Vector3(sin(phi)*cos(theta), cos(phi), sin(phi)*sin(theta))
					valid_found = true

		paintballz.append(_create_paintball(pos, size, ball_no, p, color_list, outline_color_list, texture_list))
	return paintballz

func _generate_star_pattern(properties: Dictionary, ball_no: int, num_stars: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	var num_points: int = int(properties["star_points"])
	var ray_length: int = int(properties["ray_length"])
	if num_points <= 1 or ray_length <= 0: return []

	for i in range(num_stars):
		var star_center: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var basis: Basis = LnzLiveUtils.get_basis_from_normal(star_center)
		var star_color: Array = [color_list[randi() % color_list.size()]]
		var star_outline: Array = [outline_color_list[randi() % outline_color_list.size()]]
		var base_size: float = rand_range(properties["size_min"], properties["size_max"])

		for p in range(num_points):
			var angle: float = (float(p) / num_points) * TAU
			var tangent_dir: Vector3 = (basis.x * cos(angle) + basis.z * sin(angle))
			var tip: Vector3 = star_center.slerp(star_center + tangent_dir, properties["ray_length"] * 0.1).normalized()

			for j in range(ray_length):
				var pos: Vector3 = star_center.slerp(tip, float(j + 1) / ray_length).normalized()
				var progress: float = float(j) / ray_length
				var final_size: float = lerp(base_size, properties["star_point_size"], progress)

				paintballz.append(_create_paintball(pos, final_size, ball_no, properties, star_color, star_outline, texture_list))
	return paintballz

# XX: Leopard Generator
func _generate_leopard_pattern(properties: Dictionary, ball_no: int, num_spots: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	if color_list.size() < 2: return []

	for i in range(num_spots):
		var spot_center: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var basis: Basis = LnzLiveUtils.get_basis_from_normal(spot_center)
		var spot_radius: float = rand_range(properties["leopard_radius_min"], properties["leopard_radius_max"])
		var pb_size: float = rand_range(properties["size_min"], properties["size_max"])
		
		var c_out: int = color_list[randi() % color_list.size()]
		var c_in: int = color_list[randi() % color_list.size()]
		while c_in == c_out and color_list.size() > 1: c_in = color_list[randi() % color_list.size()]

		# Outline ring
		for j in range(20):
			if randf() > properties["leopard_completeness"]: continue
			var r: float = spot_radius * rand_range(1.0 - properties["leopard_irregularity"], 1.0 + properties["leopard_irregularity"])
			var angle: float = (float(j) / 20.0) * TAU
			var dir: Vector3 = (basis.x * cos(angle) + basis.z * sin(angle))
			var pos: Vector3 = spot_center.slerp(spot_center + dir, r).normalized()
			paintballz.append(_create_paintball(pos, pb_size, ball_no, properties, [c_out], outline_color_list, texture_list))
		
		# Inner fill
		for j in range(15):
			var r: float = sqrt(randf()) * spot_radius * 0.8
			var angle: float = randf() * TAU
			var dir: Vector3 = (basis.x * cos(angle) + basis.z * sin(angle))
			var pos: Vector3 = spot_center.slerp(spot_center + dir, r).normalized()
			paintballz.append(_create_paintball(pos, pb_size * 0.9, ball_no, properties, [c_in], outline_color_list, texture_list))
	return paintballz

func _generate_stripes_pattern(properties: Dictionary, ball_no: int, spots_to_make: int, grid: Array, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	var offset_u: float = randf() # Unique UV offset per ball to vary sampling
	var offset_v: float = randf()
	
	var attempts: int = 0
	while paintballz.size() < spots_to_make and attempts < spots_to_make * 20:
		attempts += 1
		var u: float = fmod(randf() + offset_u, 1.0)
		var v: float = fmod(randf() + offset_v, 1.0)
		var gx: int = int(u * 31)
		var gy: int = int(v * 31)
		if grid[gy * 32 + gx].b > 0.4:
			var theta: float = u * TAU
			var phi: float = acos(clamp(2 * v - 1, -1, 1))
			var pos: Vector3 = Vector3(sin(phi)*cos(theta), cos(phi), sin(phi)*sin(theta))
			paintballz.append(_create_paintball(pos, rand_range(properties["size_min"], properties["size_max"]), ball_no, properties, color_list, outline_color_list, texture_list))
	return paintballz

# XX: Random Walk Generator
func _generate_random_walk(p: Dictionary, ball_no: int, spots: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	var start_pos: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	
	var walk_path: Array = LnzLiveUtils.generate_surface_walk(
		start_pos, Vector3.ZERO, 1.0, spots, 0.3
	)
	
	for dir in walk_path:
		paintballz.append(_create_paintball(
			dir.normalized(), 
			rand_range(p["size_min"], p["size_max"]), 
			ball_no, 
			p, 
			color_list, 
			outline_color_list, 
			texture_list
		))
		
	return paintballz

# XX: Cluster Generator
func _generate_clustered_pattern(p: Dictionary, ball_no: int, spots: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	var clusters: Array = []
	for i in range(int(p["num_clusters"])): clusters.append(Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized())
	for i in range(spots):
		var center: Vector3 = clusters[randi() % clusters.size()]
		var pos: Vector3 = (center + Vector3(rand_range(-0.4, 0.4), rand_range(-0.4, 0.4), rand_range(-0.4, 0.4))).normalized()
		paintballz.append(_create_paintball(pos, rand_range(p["size_min"], p["size_max"]), ball_no, p, color_list, outline_color_list, texture_list))
	return paintballz

# XX: Bullseye Generator
func _generate_bullseye_pattern(p: Dictionary, ball_no: int, num_targets: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	for i in range(num_targets):
		var center: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var base_size: float = rand_range(p["size_min"], p["size_max"])
		for r in range(int(p["num_rings"])):
			var size: float = base_size * (1.0 - float(r) / p["num_rings"])
			var color: Array = [color_list[r % color_list.size()]]
			paintballz.append(_create_paintball(center, size, ball_no, p, color, outline_color_list, texture_list))
	return paintballz

# XX: Rainbow Generator
func _generate_rainbow_pattern(p: Dictionary, ball_no: int, num_rainbows: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	for i in range(num_rainbows):
		var start: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var basis: Basis = LnzLiveUtils.get_basis_from_normal(start)
		var rot_axis: Vector3 = basis.x.slerp(start, p["rainbow_curvature"]).rotated(start, deg2rad(p["rainbow_angle"]))
		var pb_size: float = rand_range(p["size_min"], p["size_max"])
		
		for c_idx in range(color_list.size()):
			var off_dist: float = (float(c_idx) - (color_list.size()-1)/2.0) * p["rainbow_width"]
			var band_start: Vector3 = start.rotated(rot_axis.cross(start).normalized(), atan(off_dist * 0.05))
			var steps: int = int(20 * p["rainbow_length"])
			for s in range(steps):
				var pos: Vector3 = band_start.rotated(rot_axis, (float(s)/steps) * PI * p["rainbow_length"])
				paintballz.append(_create_paintball(pos.normalized(), pb_size, ball_no, p, [color_list[c_idx]], outline_color_list, texture_list))
	return paintballz

# 17: Voronoi / Cell Pattern Generator
func _generate_voronoi_pattern(properties: Dictionary, ball_no: int, spots_to_make: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	var centers: Array = []
	for i in range(int(properties["voronoi_cells"])):
		centers.append(Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized())

	var attempts: int = 0
	while paintballz.size() < spots_to_make and attempts < spots_to_make * 10:
		attempts += 1
		var pos: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var dists: Array = []
		for c in centers: dists.append(pos.distance_squared_to(c))
		dists.sort()
		
		var edge_val: float = (dists[1] - dists[0]) / (dists[0] + dists[1] + 0.001)
		if edge_val < properties["voronoi_edge_size"]:
			var size: float = rand_range(properties["size_min"], properties["size_max"])
			paintballz.append(_create_paintball(pos, size, ball_no, properties, color_list, outline_color_list, texture_list))
	return paintballz

# 18: Wave (Spherical Harmonics) Generator
func _generate_wave_pattern(properties: Dictionary, ball_no: int, spots_to_make: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var paintballz: Array = []
	var L: int = int(properties["wave_degree_l"])
	var M: int = min(int(properties["wave_order_m"]), L)
	
	var attempts: int = 0
	while paintballz.size() < spots_to_make and attempts < spots_to_make * 10:
		attempts += 1
		var pos: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var cos_theta: float = clamp(pos.y, -1.0, 1.0)
		var sin_theta: float = sqrt(max(0.0, 1.0 - cos_theta * cos_theta))
		var phi: float = atan2(pos.z, pos.x)
		
		var p_lm: float = 1.0
		if L == 1: p_lm = cos_theta if M == 0 else sin_theta
		elif L == 2:
			if M == 0: p_lm = 0.5 * (3 * cos_theta * cos_theta - 1)
			elif M == 1: p_lm = 3 * cos_theta * sin_theta
			else: p_lm = 3 * sin_theta * sin_theta
		elif L >= 3:
			if M == 0: p_lm = 0.5 * (5 * pow(cos_theta, 3) - 3 * cos_theta)
			elif M == 1: p_lm = 1.5 * (5 * cos_theta * cos_theta - 1) * sin_theta
			elif M == 2: p_lm = 15 * cos_theta * sin_theta * sin_theta
			else: p_lm = 15 * pow(sin_theta, 3)

		var val: float = (p_lm * cos(M * phi) + 1.0) / 2.0
		if val > properties["wave_threshold"]:
			var size: float = rand_range(properties["size_min"], properties["size_max"])
			paintballz.append(_create_paintball(pos, size, ball_no, properties, color_list, outline_color_list, texture_list))
	return paintballz

# 04: Noise Field Generator
func _generate_noise_pattern(p: Dictionary, ball_no: int, spots: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var pbs: Array = []
	var noise: OpenSimplexNoise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.period = p["noise_scale"]
	var attempts: int = 0
	while pbs.size() < spots and attempts < spots * 15:
		attempts += 1
		var pos: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		if (noise.get_noise_3d(pos.x, pos.y, pos.z) + 1.0) / 2.0 > p["noise_threshold"]:
			var pb: PaintBallData = _create_paintball(pos, rand_range(p["size_min"], p["size_max"]), ball_no, p, color_list, outline_color_list, texture_list)
			if pb: pbs.append(pb)
	return pbs

# 16: L-System Fractal Generator
func _generate_fractal_pattern(p: Dictionary, ball_no: int, color_list: Array, outline_color_list: Array, texture_list: Array) -> Array:
	var axiom: String = p["fractal_axiom"]
	var rules: Dictionary = LnzLiveUtils.parse_lsystem_rules(p["fractal_rules"])
	
	if p["fractal_preset"] == FractalPreset.DRAGON_CURVE:
		axiom = "F"
		rules = {"F": "F+G", "G": "F-G"}
	elif p["fractal_preset"] == FractalPreset.SIERPINSKI:
		axiom = "A"
		rules = {"A": "B-A-B", "B": "A+B+A"}
	elif p["fractal_preset"] == FractalPreset.BARNSLEY_FERN:
		axiom = "X"
		rules = {"X": "F+[[X]-X]-F[-FX]+X", "F": "FF"}
	
	var s: String = LnzLiveUtils.generate_lsystem_string(axiom, rules, int(p["fractal_iterations"]))
	if s.length() > 1024:
		printerr("[ERROR] AutoPaintballerSettings: L-System string length %d exceeds 1024 limit. Aborting fractal pattern." % s.length())
		return []
	var pos: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	var basis: Basis = LnzLiveUtils.get_basis_from_normal(pos)
	var state: Dictionary = {"pos": pos, "heading": basis.x}
	var stack: Array = []
	var pbs: Array = []
	var size: float = rand_range(p["size_min"], p["size_max"])
	var step: float = atan(size * 0.02)
	
	for cmd in s:
		if pbs.size() > 50000:
			printerr("[ERROR] AutoPaintballerSettings: _generate_fractal_pattern: paintball count %d exceeds 50000 limit. Aborting." % pbs.size())
			return []
		match cmd:
			"F", "G", "A", "B":
				var axis: Vector3 = state["heading"].cross(state["pos"]).normalized()
				state["pos"] = state["pos"].rotated(axis, step).normalized()
				state["heading"] = state["heading"].rotated(axis, step).normalized()
				pbs.append(_create_paintball(state["pos"], size, ball_no, p, color_list, outline_color_list, texture_list))
			"+": state["heading"] = state["heading"].rotated(state["pos"], deg2rad(-p["fractal_angle"]))
			"-": state["heading"] = state["heading"].rotated(state["pos"], deg2rad(p["fractal_angle"]))
			"[": stack.append(state.duplicate())
			"]": if !stack.empty(): state = stack.pop_back()
	return pbs

func _on_ApplyButton_pressed() -> void:
	emit_signal("apply_auto_paintballz")

func _on_ClearButton_pressed() -> void:
	emit_signal("clear_auto_paintballz")

func _create_paintball(pos: Vector3, size: float, ball_no: int, properties: Dictionary, color_list: Array, outline_color_list: Array, texture_list: Array) -> PaintBallData:
	if not properties is Dictionary:
		push_error("AutoPaintballer: properties must be a Dictionary.")
		return null

	var color: int
	var outline_color: int
	var texture: int
	var is_ordered: bool = properties.get("ordered", false)

	if is_ordered:
		color = color_list[_ordered_color_index % color_list.size()]
		_ordered_color_index += 1
		outline_color = outline_color_list[_ordered_outline_color_index % outline_color_list.size()]
		_ordered_outline_color_index += 1
		texture = texture_list[_ordered_texture_index % texture_list.size()]
		_ordered_texture_index += 1
	else:
		color = color_list[randi() % color_list.size()]
		outline_color = outline_color_list[randi() % outline_color_list.size()]
		texture = texture_list[randi() % texture_list.size()]

	var final_diameter: float = size

	if properties.get("pixel_mode", false) and is_instance_valid(pet_node) and "ball_map" in pet_node:
		var visual_base: Node = pet_node.ball_map.get(ball_no)
		if visual_base:
			var base_pixel_size: float = visual_base.ball_size 
			final_diameter = (size / base_pixel_size) * 100.0

	var pb: PaintBallData = PaintBallData.new(
		ball_no, int(round(final_diameter)), pos, color, outline_color,
		floor(rand_range(properties["outline_type_min"], properties["outline_type_max"])),
		floor(rand_range(properties["fuzz_min"], properties["fuzz_max"])),
		0, texture, 1 if properties["anchored"] else 0, properties["group"]
	)
	
	if "pixel_mode" in pb:
		pb.pixel_mode = properties.get("pixel_mode", false)
	
	return pb

func get_properties() -> Dictionary:
	var properties: Dictionary = {}
	properties["affected_ballz"] = find_node("AffectedBallz").text
	properties["distribution"] = find_node("Distribution").selected
	properties["num_spots"] = find_node("NumSpots").value
	properties["spiral_turns"] = find_node("SpiralTurns").value
	properties["star_points"] = find_node("StarPoints").value
	properties["star_point_size"] = find_node("StarPointSize").value
	properties["num_bands"] = find_node("NumBands").value
	properties["band_spacing"] = find_node("BandSpacing").value
	properties["band_offset"] = find_node("BandOffset").value
	properties["band_angle"] = find_node("BandAngle").value
	properties["band_direction"] = find_node("BandDirection").selected 
	properties["noise_scale"] = find_node("NoiseScale").value
	properties["noise_threshold"] = find_node("NoiseThreshold").value
	properties["noise_octaves"] = find_node("NoiseOctaves").value
	properties["voronoi_cells"] = find_node("VoronoiCells").value
	properties["voronoi_edge_size"] = find_node("VoronoiEdgeSize").value
	properties["wave_degree_l"] = find_node("WaveDegreeL").value
	properties["wave_order_m"] = find_node("WaveOrderM").value
	properties["wave_threshold"] = find_node("WaveThreshold").value
	
	properties["grid_size"] = find_node("GridSize").value
	properties["num_clusters"] = find_node("NumClusters").value
	properties["ray_length"] = find_node("RayLength").value
	properties["stripe_feed_rate"] = find_node("StripeFeedRate").value
	properties["stripe_kill_rate"] = find_node("StripeKillRate").value
	properties["diffusion_b"] = find_node("DiffusionActivator").value
	properties["diffusion_a"] = find_node("DiffusionInhibitor").value
	properties["stripe_timestep"] = find_node("StripeTimestep").value
	properties["size_adaptive"] = find_node("SizeAdaptive").pressed
	properties["leopard_radius_min"] = find_node("LeopardRadiusMin").value
	properties["leopard_radius_max"] = find_node("LeopardRadiusMax").value
	properties["leopard_irregularity"] = find_node("LeopardIrregularity").value
	properties["leopard_completeness"] = find_node("LeopardCompleteness").value
	properties["leopard_use_paired_colors"] = find_node("LeopardPairedColors").pressed
	properties["rainbow_angle"] = find_node("RainbowAngle").value
	properties["rainbow_curvature"] = find_node("RainbowCurvature").value
	properties["rainbow_width"] = find_node("RainbowWidth").value
	properties["rainbow_length"] = find_node("RainbowLength").value
	properties["fractal_iterations"] = find_node("FractalIterations").value
	properties["fractal_angle"] = find_node("FractalAngle").value
	properties["fractal_preset"] = find_node("FractalPreset").selected
	properties["fractal_axiom"] = find_node("FractalAxiom").text
	properties["fractal_rules"] = find_node("FractalRules").text
	properties["halfie_axis"] = find_node("HalfieAxis").selected
	properties["halfie_side"] = find_node("HalfieSide").selected
	properties["num_rings"] = find_node("NumRings").value
	properties["size_min"] = find_node("SizeMin").value
	properties["size_max"] = find_node("SizeMax").value
	
	var color_list_node: Control = find_node("ColorList", true, false)
	properties["color_list"] = color_list_node.text if color_list_node else ""
	var outline_color_list_node: Control = find_node("OutlineColorList", true, false)
	properties["outline_color_list"] = outline_color_list_node.text if outline_color_list_node else ""
	
	properties["outline_type_min"] = find_node("OutlineTypeMin").value
	properties["outline_type_max"] = find_node("OutlineTypeMax").value
	properties["fuzz_min"] = find_node("FuzzMin").value
	properties["fuzz_max"] = find_node("FuzzMax").value
	properties["texture_list"] = find_node("TextureList").text
	properties["group"] = find_node("Group").value
	properties["anchored"] = find_node("Anchored").pressed
	properties["ordered"] = find_node("Ordered").pressed
	properties["use_seed"] = find_node("UseSeed").pressed
	properties["seed"] = find_node("Seed").text
	properties["pixel_mode"] = find_node("PixelMode").pressed
	return properties

func _apply_settings_dict(data: Dictionary) -> void:
	_is_loading_settings = true
	
	if data.has("affected_ballz"): find_node("AffectedBallz").text = str(data["affected_ballz"])
	if data.has("distribution"): find_node("Distribution").selected = data["distribution"]
	if data.has("num_spots"): find_node("NumSpots").value = data["num_spots"]
	if data.has("spiral_turns"): find_node("SpiralTurns").value = data["spiral_turns"]
	if data.has("star_points"): find_node("StarPoints").value = data["star_points"]
	if data.has("star_point_size"): find_node("StarPointSize").value = data["star_point_size"]
	if data.has("num_bands"): find_node("NumBands").value = data["num_bands"]
	if data.has("band_spacing"): find_node("BandSpacing").value = data["band_spacing"]
	if data.has("band_offset"): find_node("BandOffset").value = data["band_offset"]
	if data.has("band_angle"): find_node("BandAngle").value = data["band_angle"]
	if data.has("band_direction"): find_node("BandDirection").selected = data["band_direction"]
	
	if data.has("noise_scale"): find_node("NoiseScale").value = data["noise_scale"]
	if data.has("noise_threshold"): find_node("NoiseThreshold").value = data["noise_threshold"]
	if data.has("noise_octaves"): find_node("NoiseOctaves").value = data["noise_octaves"]
	
	if data.has("voronoi_cells"): find_node("VoronoiCells").value = data["voronoi_cells"]
	if data.has("voronoi_edge_size"): find_node("VoronoiEdgeSize").value = data["voronoi_edge_size"]
	
	if data.has("wave_degree_l"): find_node("WaveDegreeL").value = data["wave_degree_l"]
	if data.has("wave_order_m"): find_node("WaveOrderM").value = data["wave_order_m"]
	if data.has("wave_threshold"): find_node("WaveThreshold").value = data["wave_threshold"]
	
	if data.has("grid_size"): find_node("GridSize").value = data["grid_size"]
	if data.has("num_clusters"): find_node("NumClusters").value = data["num_clusters"]
	if data.has("ray_length"): find_node("RayLength").value = data["ray_length"]
	
	if data.has("stripe_feed_rate"): find_node("StripeFeedRate").value = data["stripe_feed_rate"]
	if data.has("stripe_kill_rate"): find_node("StripeKillRate").value = data["stripe_kill_rate"]
	if data.has("stripe_timestep"): find_node("StripeTimestep").value = data["stripe_timestep"]
	if data.has("diffusion_b"): find_node("DiffusionActivator").value = data["diffusion_b"]
	if data.has("diffusion_a"): find_node("DiffusionInhibitor").value = data["diffusion_a"]
	if data.has("size_adaptive"): find_node("SizeAdaptive").pressed = data["size_adaptive"]

	
	if data.has("leopard_radius_min"): find_node("LeopardRadiusMin").value = data["leopard_radius_min"]
	if data.has("leopard_radius_max"): find_node("LeopardRadiusMax").value = data["leopard_radius_max"]
	if data.has("leopard_irregularity"): find_node("LeopardIrregularity").value = data["leopard_irregularity"]
	if data.has("leopard_completeness"): find_node("LeopardCompleteness").value = data["leopard_completeness"]
	if data.has("leopard_use_paired_colors"): find_node("LeopardPairedColors").pressed = data["leopard_use_paired_colors"]
	
	if data.has("rainbow_angle"): find_node("RainbowAngle").value = data["rainbow_angle"]
	if data.has("rainbow_curvature"): find_node("RainbowCurvature").value = data["rainbow_curvature"]
	if data.has("rainbow_width"): find_node("RainbowWidth").value = data["rainbow_width"]
	if data.has("rainbow_length"): find_node("RainbowLength").value = data["rainbow_length"]
	
	if data.has("fractal_iterations"): find_node("FractalIterations").value = data["fractal_iterations"]
	if data.has("fractal_angle"): find_node("FractalAngle").value = data["fractal_angle"]
	if data.has("fractal_preset"): find_node("FractalPreset").selected = data["fractal_preset"]
	if data.has("fractal_axiom"): find_node("FractalAxiom").text = str(data["fractal_axiom"])
	if data.has("fractal_rules"): find_node("FractalRules").text = str(data["fractal_rules"])
	
	if data.has("halfie_axis"): find_node("HalfieAxis").selected = data["halfie_axis"]
	if data.has("halfie_side"): find_node("HalfieSide").selected = data["halfie_side"]
	
	if data.has("num_rings"): find_node("NumRings").value = data["num_rings"]
	if data.has("size_min"): find_node("SizeMin").value = data["size_min"]
	if data.has("size_max"): find_node("SizeMax").value = data["size_max"]
	
	var color_list_node: Control = find_node("ColorList", true, false)
	if data.has("color_list") and color_list_node: color_list_node.text = str(data["color_list"])
	var outline_color_list_node: Control = find_node("OutlineColorList", true, false)
	if data.has("outline_color_list") and outline_color_list_node: outline_color_list_node.text = str(data["outline_color_list"])
	
	if data.has("outline_type_min"): find_node("OutlineTypeMin").value = data["outline_type_min"]
	if data.has("outline_type_max"): find_node("OutlineTypeMax").value = data["outline_type_max"]
	if data.has("fuzz_min"): find_node("FuzzMin").value = data["fuzz_min"]
	if data.has("fuzz_max"): find_node("FuzzMax").value = data["fuzz_max"]
	if data.has("texture_list"): find_node("TextureList").text = str(data["texture_list"])
	
	if data.has("group"): find_node("Group").value = data["group"]
	if data.has("anchored"): find_node("Anchored").pressed = data["anchored"]
	if data.has("ordered"): find_node("Ordered").pressed = data["ordered"]
	if data.has("use_seed"): find_node("UseSeed").pressed = data["use_seed"]
	if data.has("seed"): find_node("Seed").text = str(data["seed"])
	if data.has("pixel_mode"): find_node("PixelMode").pressed = data["pixel_mode"]
	
	_is_loading_settings = false
	_on_setting_changed()
	_refresh_all_previews()

func export_autopaintballer_json() -> void:
	var settings_dict: Dictionary = get_properties()
	var json_string: String = JSON.print(settings_dict, "  ")
	var filename: String = "LnzLive_autopaintballer_settings_" + str(OS.get_unix_time()) + ".json"

	if OS.has_feature("HTML5"):
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
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.window_title = "Export Auto Paintballer Preset"
		file_dialog.mode = FileDialog.MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Preset"]
		file_dialog.rect_min_size = Vector2(400, 400)
		file_dialog.current_file = filename
		file_dialog.connect("file_selected", self, "_save_settings_file")
		file_dialog.connect("popup_hide", file_dialog, "queue_free")
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _save_settings_file(path: String) -> void:
	var settings_dict: Dictionary = get_properties()
	var json_string: String = JSON.print(settings_dict, "  ")
	var file: File = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(json_string)
		file.close()

func _on_ImportPresetButton_pressed() -> void:
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
			   window.godotAutoPaintballImport(content);
		   }
		}
		input.click();
		"""
		var callback = JavaScript.create_callback(self, "_on_web_import_completed")
		JavaScript.get_interface("window").godotAutoPaintballImport = callback
		JavaScript.eval(js_code)
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.window_title = "Import Auto Paintballer Preset"
		file_dialog.mode = FileDialog.MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Preset"]
		file_dialog.rect_min_size = Vector2(400, 400)
		file_dialog.connect("file_selected", self, "_load_preset_file")
		file_dialog.connect("popup_hide", file_dialog, "queue_free")
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _on_web_import_completed(args: Array) -> void:
	var content: String = args[0]
	var json_res = JSON.parse(content)
	if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
		_apply_settings_dict(json_res.result)

func _load_preset_file(path: String) -> void:
	var file: File = File.new()
	if file.open(path, File.READ) == OK:
		var text: String = file.get_as_text()
		var json_res = JSON.parse(text)
		if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
			_apply_settings_dict(json_res.result)
		file.close()

func add_affected_ball(ball_no: int) -> void:
	var line_edit: Control = find_node("AffectedBallz")
	var current_text: String = line_edit.text
	var current_list: Array = LnzLiveUtils.parse_number_list(current_text)

	if ball_no in current_list:
		return

	if current_text.strip_edges() == "":
		line_edit.text = str(ball_no)
	else:
		line_edit.text += "," + str(ball_no)
		
	_on_AffectedBallz_text_changed(line_edit.text)

func update_selected_balls_text(ball_ids: Array) -> void:
	var affected_edit: Control = find_node("AffectedBallz")
	if not affected_edit or affected_edit.has_focus():
		return

	if ball_ids.empty():
		affected_edit.text = ""
		return

	ball_ids.sort()
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
		
	var temp_pool: PoolStringArray = PoolStringArray(ranges)
	affected_edit.text = temp_pool.join(",")
	temp_pool.resize(0)
	
	_on_AffectedBallz_text_changed(affected_edit.text)

func _on_UnselectButton_pressed() -> void:
	emit_signal("unselect_all")

func _connect_settings_signals() -> void:
	find_node("AffectedBallz").connect("text_changed", self, "_on_setting_changed")
	
	var color_list_node: Control = find_node("ColorList", true, false)
	if color_list_node: color_list_node.connect("text_changed", self, "_on_setting_changed")
	var outline_color_list_node: Control = find_node("OutlineColorList", true, false)
	if outline_color_list_node: outline_color_list_node.connect("text_changed", self, "_on_setting_changed")
	
	find_node("TextureList").connect("text_changed", self, "_on_setting_changed")
	find_node("FractalAxiom").connect("text_changed", self, "_on_setting_changed")
	find_node("Seed").connect("text_changed", self, "_on_setting_changed")

	find_node("FractalRules").connect("text_changed", self, "_on_setting_changed")

	find_node("Distribution").connect("item_selected", self, "_on_setting_changed")
	find_node("BandDirection").connect("item_selected", self, "_on_setting_changed")
	find_node("FractalPreset").connect("item_selected", self, "_on_setting_changed")
	find_node("HalfieAxis").connect("item_selected", self, "_on_setting_changed")
	find_node("HalfieSide").connect("item_selected", self, "_on_setting_changed")

	find_node("Ordered").connect("toggled", self, "_on_setting_changed")
	find_node("UseSeed").connect("toggled", self, "_on_setting_changed")
	find_node("Anchored").connect("toggled", self, "_on_setting_changed")
	find_node("LeopardPairedColors").connect("toggled", self, "_on_setting_changed")

	_connect_spinboxes_recursive(self)

	var reset_btn: Button = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

	find_node("ExportSettingsButton").connect("pressed", self, "export_autopaintballer_json")
	find_node("ImportSettingsButton").connect("pressed", self, "_on_ImportPresetButton_pressed")

func _connect_spinboxes_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is SpinBox:
			child.connect("value_changed", self, "_on_setting_changed")
		_connect_spinboxes_recursive(child)

func _on_setting_changed(_arg = null) -> void:
	if _is_loading_settings:
		return
	save_settings()

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		return

	var p: Dictionary = get_properties()
	
	for key in p.keys():
		config.set_value("AutoPaintballer", key, p[key])

	var save_err: int = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving AutoPaintballerSettings: ", save_err)

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		return

	_is_loading_settings = true

	find_node("AffectedBallz").text = config.get_value("AutoPaintballer", "affected_ballz", "")
	find_node("Distribution").selected = config.get_value("AutoPaintballer", "distribution", 0)
	find_node("NumSpots").value = config.get_value("AutoPaintballer", "num_spots", 25.0)
	find_node("Ordered").pressed = config.get_value("AutoPaintballer", "ordered", false)
	find_node("UseSeed").pressed = config.get_value("AutoPaintballer", "use_seed", false)
	find_node("Seed").text = config.get_value("AutoPaintballer", "seed", "")

	find_node("SizeMin").value = config.get_value("AutoPaintballer", "size_min", 10.0)
	find_node("SizeMax").value = config.get_value("AutoPaintballer", "size_max", 20.0)
	find_node("PixelMode").pressed = config.get_value("AutoPaintballer", "pixel_mode", false)
	
	var color_list_node: Control = find_node("ColorList", true, false)
	if color_list_node: color_list_node.text = config.get_value("AutoPaintballer", "color_list", "")
	var outline_color_list_node: Control = find_node("OutlineColorList", true, false)
	if outline_color_list_node: outline_color_list_node.text = config.get_value("AutoPaintballer", "outline_color_list", "244")
	
	find_node("TextureList").text = config.get_value("AutoPaintballer", "texture_list", "0")
	find_node("OutlineTypeMin").value = config.get_value("AutoPaintballer", "outline_type_min", -1.0)
	find_node("OutlineTypeMax").value = config.get_value("AutoPaintballer", "outline_type_max", -1.0)
	find_node("FuzzMin").value = config.get_value("AutoPaintballer", "fuzz_min", 0.0)
	find_node("FuzzMax").value = config.get_value("AutoPaintballer", "fuzz_max", 0.0)
	find_node("Group").value = config.get_value("AutoPaintballer", "group", 0.0)
	find_node("Anchored").pressed = config.get_value("AutoPaintballer", "anchored", true)

	find_node("SpiralTurns").value = config.get_value("AutoPaintballer", "spiral_turns", 5.0)
	find_node("StarPointSize").value = config.get_value("AutoPaintballer", "star_point_size", 4.0)
	find_node("StarPoints").value = config.get_value("AutoPaintballer", "star_points", 5.0)
	find_node("RayLength").value = config.get_value("AutoPaintballer", "ray_length", 4.0)
	find_node("RainbowAngle").value = config.get_value("AutoPaintballer", "rainbow_angle", 0.0)
	find_node("RainbowCurvature").value = config.get_value("AutoPaintballer", "rainbow_curvature", 0.0)
	find_node("RainbowWidth").value = config.get_value("AutoPaintballer", "rainbow_width", 0.5)
	find_node("RainbowLength").value = config.get_value("AutoPaintballer", "rainbow_length", 1.0)

	find_node("BandDirection").selected = config.get_value("AutoPaintballer", "band_direction", 0)
	find_node("NumBands").value = config.get_value("AutoPaintballer", "num_bands", 5.0)
	find_node("BandSpacing").value = config.get_value("AutoPaintballer", "band_spacing", 0.5)
	find_node("BandOffset").value = config.get_value("AutoPaintballer", "band_offset", 0.0)
	find_node("BandAngle").value = config.get_value("AutoPaintballer", "band_angle", 0.0)
	find_node("GridSize").value = config.get_value("AutoPaintballer", "grid_size", 5.0)
	find_node("NumClusters").value = config.get_value("AutoPaintballer", "num_clusters", 3.0)
	find_node("NumRings").value = config.get_value("AutoPaintballer", "num_rings", 3.0)

	find_node("NoiseScale").value = config.get_value("AutoPaintballer", "noise_scale", 10.0)
	find_node("NoiseThreshold").value = config.get_value("AutoPaintballer", "noise_threshold", 0.5)
	find_node("NoiseOctaves").value = config.get_value("AutoPaintballer", "noise_octaves", 3.0)
	find_node("VoronoiCells").value = config.get_value("AutoPaintballer", "voronoi_cells", 5.0)
	find_node("VoronoiEdgeSize").value = config.get_value("AutoPaintballer", "voronoi_edge_size", 0.05)
	find_node("WaveDegreeL").value = config.get_value("AutoPaintballer", "wave_degree_l", 2.0)
	find_node("WaveOrderM").value = config.get_value("AutoPaintballer", "wave_order_m", 1.0)
	find_node("WaveThreshold").value = config.get_value("AutoPaintballer", "wave_threshold", 0.6)

	find_node("StripeFeedRate").value = config.get_value("AutoPaintballer", "stripe_feed_rate", 0.07)
	find_node("StripeKillRate").value = config.get_value("AutoPaintballer", "stripe_kill_rate", 0.05)
	find_node("DiffusionActivator").value = config.get_value("AutoPaintballer", "diffusion_b", 0.5)
	find_node("DiffusionInhibitor").value = config.get_value("AutoPaintballer", "diffusion_a", 1.0)
	find_node("StripeTimestep").value = config.get_value("AutoPaintballer", "stripe_timestep", 1.0)

	find_node("LeopardRadiusMin").value = config.get_value("AutoPaintballer", "leopard_radius_min", 0.05)
	find_node("LeopardRadiusMax").value = config.get_value("AutoPaintballer", "leopard_radius_max", 0.1)
	find_node("LeopardIrregularity").value = config.get_value("AutoPaintballer", "leopard_irregularity", 0.3)
	find_node("LeopardCompleteness").value = config.get_value("AutoPaintballer", "leopard_completeness", 0.75)
	find_node("LeopardPairedColors").pressed = config.get_value("AutoPaintballer", "leopard_use_paired_colors", false)

	find_node("FractalIterations").value = config.get_value("AutoPaintballer", "fractal_iterations", 5.0)
	find_node("FractalAngle").value = config.get_value("AutoPaintballer", "fractal_angle", 90.0)
	find_node("FractalPreset").selected = config.get_value("AutoPaintballer", "fractal_preset", 0)
	find_node("FractalAxiom").text = config.get_value("AutoPaintballer", "fractal_axiom", "F")
	find_node("FractalRules").text = config.get_value("AutoPaintballer", "fractal_rules", "")

	find_node("HalfieAxis").selected = config.get_value("AutoPaintballer", "halfie_axis", 0)
	find_node("HalfieSide").selected = config.get_value("AutoPaintballer", "halfie_side", 0)

	_on_Distribution_item_selected(find_node("Distribution").selected)
	_on_FractalPreset_item_selected(find_node("FractalPreset").selected)
	_on_UseSeed_toggled(find_node("UseSeed").pressed)

	_is_loading_settings = false
	_refresh_all_previews()

func _on_reset_defaults_pressed() -> void:
	_is_loading_settings = true

	find_node("AffectedBallz").text = ""
	find_node("Distribution").selected = 0
	find_node("NumSpots").value = 25.0
	find_node("Ordered").pressed = false
	find_node("UseSeed").pressed = false
	find_node("Seed").text = ""

	find_node("SizeMin").value = 10.0
	find_node("SizeMax").value = 20.0
	
	var color_list_node: Control = find_node("ColorList", true, false)
	if color_list_node: color_list_node.text = ""
	var outline_color_list_node: Control = find_node("OutlineColorList", true, false)
	if outline_color_list_node: outline_color_list_node.text = "244"
	
	find_node("TextureList").text = "0"
	find_node("OutlineTypeMin").value = -1.0
	find_node("OutlineTypeMax").value = -1.0
	find_node("FuzzMin").value = 0.0
	find_node("FuzzMax").value = 0.0
	find_node("Group").value = 0.0
	find_node("Anchored").pressed = true

	find_node("WaveDegreeL").value = 2.0
	find_node("WaveOrderM").value = 1.0
	find_node("WaveThreshold").value = 0.6
	find_node("VoronoiCells").value = 5.0
	find_node("VoronoiEdgeSize").value = 0.05

	find_node("NoiseScale").value = 10.0
	find_node("NoiseThreshold").value = 0.5
	find_node("NoiseOctaves").value = 3.0
	find_node("FractalPreset").selected = 0
	find_node("FractalAxiom").text = ""
	find_node("FractalRules").text = ""
	find_node("FractalIterations").value = 5.0
	find_node("FractalAngle").value = 90.0

	find_node("SpiralTurns").value = 5.0
	find_node("StarPointSize").value = 4.0
	find_node("StarPoints").value = 5.0
	find_node("RayLength").value = 4.0

	find_node("RainbowAngle").value = 0.0
	find_node("RainbowCurvature").value = 0.0
	find_node("RainbowWidth").value = 0.5
	find_node("RainbowLength").value = 1.0
	find_node("BandDirection").selected = 0
	find_node("NumBands").value = 5.0
	find_node("BandSpacing").value = 0.5
	find_node("BandOffset").value = 0.0
	find_node("BandAngle").value = 0.0

	find_node("GridSize").value = 5.0
	find_node("NumClusters").value = 3.0
	find_node("NumRings").value = 3.0

	find_node("StripeFeedRate").value = 0.07
	find_node("StripeKillRate").value = 0.05
	find_node("DiffusionActivator").value = 0.5
	find_node("DiffusionInhibitor").value = 1.0
	find_node("StripeTimestep").value = 1.0

	find_node("LeopardRadiusMin").value = 0.05
	find_node("LeopardRadiusMax").value = 0.1
	find_node("LeopardIrregularity").value = 0.3
	find_node("LeopardCompleteness").value = 0.75
	find_node("LeopardPairedColors").pressed = false

	find_node("HalfieAxis").selected = 0
	find_node("HalfieSide").selected = 0

	_on_Distribution_item_selected(0)
	_on_FractalPreset_item_selected(0)
	_on_UseSeed_toggled(false)

	_is_loading_settings = false
	save_settings()
	_refresh_all_previews()

func _on_SurpriseButton_pressed() -> void:
	_is_loading_settings = true

	var total_modes: int = Distribution.size()
	var random_mode: int = randi() % total_modes
	find_node("Distribution").selected = random_mode
	_on_Distribution_item_selected(random_mode)

	if random_mode == Distribution.RAINBOW or random_mode == Distribution.FRACTAL:
		find_node("NumSpots").value = (randi() % 2) + 1
	elif random_mode == Distribution.STAR:
		find_node("NumSpots").value = (randi() % 40) + 1
	elif random_mode == Distribution.LEOPARD:
		find_node("NumSpots").value = (randi() % 50) + 1
	else:
		find_node("NumSpots").value = int(rand_range(20, 150))
	
	var size_base: float = rand_range(2, 12)
	find_node("SizeMin").value = size_base
	find_node("SizeMax").value = min(50, size_base + rand_range(5, 25))
	
	find_node("PixelMode").pressed = randf() > 0.5

	if randf() > 0.6: 
		var fuzz_base: int = randi() % 4
		find_node("FuzzMin").value = fuzz_base
		find_node("FuzzMax").value = int(min(5, fuzz_base + randi() % 3))
	else:
		find_node("FuzzMin").value = 0
		find_node("FuzzMax").value = 0

	var color_list_node: Control = find_node("ColorList", true, false)
	if color_list_node: color_list_node.text = _generate_surprise_color_string()
	var outline_color_list_node: Control = find_node("OutlineColorList", true, false)
	if outline_color_list_node: outline_color_list_node.text = _get_random_static_accent()
	
	find_node("TextureList").text = _generate_surprise_texture_string()
	
	var out_type: int = -1
	if randf() < 0.3:
		out_type = randi() % 4 - 2 
	find_node("OutlineTypeMin").value = out_type
	find_node("OutlineTypeMax").value = out_type

	_randomize_mode_params(random_mode)

	_is_loading_settings = false
	save_settings()
	_refresh_all_previews()
	_on_RandomizeButton_pressed()

func _randomize_mode_params(mode: int) -> void:
	match mode:
		Distribution.FRACTAL:
			if randf() > 0.4:
				find_node("FractalPreset").selected = FractalPreset.CUSTOM
				_on_FractalPreset_item_selected(FractalPreset.CUSTOM)
				_on_RandomSystemButton_pressed()
			else:
				var preset: int = (randi() % 3) + 1
				find_node("FractalPreset").selected = preset
				_on_FractalPreset_item_selected(preset)
			
			find_node("FractalIterations").value = (randi() % 3) + 2
			
		Distribution.SPIRAL:
			find_node("SpiralTurns").value = rand_range(1.0, 15.0) 
		Distribution.STAR:
			find_node("StarPoints").value = randi() % 7 + 3
			find_node("StarPointSize").value = rand_range(2.0, 8.0)
			find_node("RayLength").value = randi() % 6 + 2
		Distribution.BANDS:
			find_node("BandDirection").selected = randi() % 2
			find_node("NumBands").value = randi() % 8 + 2
			find_node("BandSpacing").value = rand_range(0.1, 0.8)
			find_node("BandOffset").value = rand_range(-0.5, 0.5)
			find_node("BandAngle").value = [0, 45, 90, 135][randi() % 4]
		Distribution.NOISE_FIELD:
			find_node("NoiseScale").value = rand_range(2.0, 20.0)
			find_node("NoiseThreshold").value = rand_range(0.3, 0.7)
			find_node("NoiseOctaves").value = randi() % 4 + 1
		Distribution.GRID, Distribution.CHECKERBOARD:
			find_node("GridSize").value = randi() % 10 + 3
		Distribution.CLUSTERED:
			find_node("NumClusters").value = randi() % 5 + 1
		Distribution.BULLSEYE:
			find_node("NumRings").value = randi() % 5 + 2
		Distribution.LEOPARD:
			find_node("LeopardRadiusMin").value = rand_range(0.02, 0.08)
			find_node("LeopardRadiusMax").value = rand_range(0.09, 0.2) 
			find_node("LeopardIrregularity").value = rand_range(0.1, 0.5)
			find_node("LeopardCompleteness").value = rand_range(0.4, 1.0) 
			find_node("LeopardPairedColors").pressed = randf() > 0.5
		Distribution.RAINBOW:
			find_node("RainbowAngle").value = rand_range(-180, 180)
			find_node("RainbowCurvature").value = rand_range(0.0, 1.0)
			find_node("RainbowWidth").value = rand_range(0.5, 5.0)
			find_node("RainbowLength").value = rand_range(0.5, 2.5)
		Distribution.STRIPES:
			find_node("StripeFeedRate").value = rand_range(0.01, 0.09) 
			find_node("StripeKillRate").value = rand_range(0.03, 0.07) 
			find_node("StripeTimestep").value = 1.0
		Distribution.VORONOI:
			find_node("VoronoiCells").value = randi() % 12 + 3 
			find_node("VoronoiEdgeSize").value = rand_range(0.01, 0.1) 
		Distribution.WAVE:
			find_node("WaveDegreeL").value = randi() % 4 
			find_node("WaveOrderM").value = randi() % 4 
			find_node("WaveThreshold").value = rand_range(0.4, 0.8)

func _generate_surprise_color_string() -> String:
	if cached_palette_colors.empty() and is_instance_valid(pet_node) and "current_palette_texture" in pet_node:
		_on_palette_changed()
		
	var base_index: int = randi() % 256
	var base_color: Color = get_color_from_index(base_index)
	
	var p_type: int = randi() % 5
	var generated_colors: Array = []
	var h: float = base_color.h
	var s: float = base_color.s
	var v: float = base_color.v
	
	generated_colors.append(base_color)
	
	match p_type:
		0: # Monochromatic (Value & Saturation)
			for _i in range(1, 5):
				var nv: float = clamp(v + rand_range(-0.4, 0.4), 0.1, 1.0)
				var ns: float = clamp(s + rand_range(-0.4, 0.4), 0.0, 1.0)
				generated_colors.append(Color.from_hsv(h, ns, nv))
		1: # Analogous
			generated_colors.append(Color.from_hsv(fmod(h + rand_range(0.05, 0.12), 1.0), clamp(s+rand_range(-0.2,0.2), 0, 1), clamp(v+rand_range(-0.2,0.2), 0, 1)))
			generated_colors.append(Color.from_hsv(fmod(h - rand_range(0.05, 0.12) + 1.0, 1.0), clamp(s+rand_range(-0.2,0.2), 0, 1), clamp(v+rand_range(-0.2,0.2), 0, 1)))
			generated_colors.append(Color.from_hsv(fmod(h + rand_range(0.13, 0.20), 1.0), clamp(s+rand_range(-0.2,0.2), 0, 1), clamp(v+rand_range(-0.2,0.2), 0, 1)))
			generated_colors.append(Color.from_hsv(fmod(h - rand_range(0.13, 0.20) + 1.0, 1.0), clamp(s+rand_range(-0.2,0.2), 0, 1), clamp(v+rand_range(-0.2,0.2), 0, 1)))
		2: # Complementary
			var comp_h: float = fmod(h + 0.5 + rand_range(-0.05, 0.05), 1.0)
			generated_colors.append(Color.from_hsv(comp_h, s, v))
			generated_colors.append(Color.from_hsv(h, clamp(s * rand_range(0.5, 0.9), 0.0, 1.0), clamp(v * rand_range(0.6, 1.2), 0.0, 1.0)))
			generated_colors.append(Color.from_hsv(comp_h, clamp(s * rand_range(0.5, 0.9), 0.0, 1.0), clamp(v * rand_range(0.6, 1.2), 0.0, 1.0)))
		3: # Triadic 
			var t1: float = fmod(h + 0.333 + rand_range(-0.05, 0.05), 1.0)
			var t2: float = fmod(h + 0.666 + rand_range(-0.05, 0.05), 1.0)
			generated_colors.append(Color.from_hsv(t1, clamp(s+rand_range(-0.2,0.2), 0, 1), clamp(v+rand_range(-0.2,0.2), 0, 1)))
			generated_colors.append(Color.from_hsv(t2, clamp(s+rand_range(-0.2,0.2), 0, 1), clamp(v+rand_range(-0.2,0.2), 0, 1)))
			generated_colors.append(Color.from_hsv(t1, clamp(s * rand_range(0.4, 0.8), 0.0, 1.0), clamp(v * rand_range(0.6, 1.1), 0.0, 1.0)))
			generated_colors.append(Color.from_hsv(t2, clamp(s * rand_range(0.4, 0.8), 0.0, 1.0), clamp(v * rand_range(0.6, 1.1), 0.0, 1.0)))
		4: # Split Complementary
			var sc1: float = fmod(h + 0.416 + rand_range(-0.05, 0.05), 1.0)
			var sc2: float = fmod(h + 0.583 + rand_range(-0.05, 0.05), 1.0)
			generated_colors.append(Color.from_hsv(sc1, clamp(s+rand_range(-0.2,0.2), 0, 1), clamp(v+rand_range(-0.2,0.2), 0, 1)))
			generated_colors.append(Color.from_hsv(sc2, clamp(s+rand_range(-0.2,0.2), 0, 1), clamp(v+rand_range(-0.2,0.2), 0, 1)))
			generated_colors.append(Color.from_hsv(sc1, clamp(s * 0.7, 0.0, 1.0), clamp(v * rand_range(0.8, 1.2), 0.0, 1.0)))
			generated_colors.append(Color.from_hsv(sc2, clamp(s * 0.7, 0.0, 1.0), clamp(v * rand_range(0.8, 1.2), 0.0, 1.0)))

	var new_indices: Array = []
	for c in generated_colors:
		var idx: int = get_closest_palette_index(c)
		if not new_indices.has(idx):
			new_indices.append(idx)
			
	var res_str: PoolStringArray = PoolStringArray()
	for idx in new_indices:
		res_str.append(str(idx))
		
	var result: String = res_str.join(",")
	res_str.resize(0)
	return result

func _generate_surprise_texture_string() -> String:
	var parts: Array = []
	var max_tex: int = 0
	if pet_node and pet_node.lnz and pet_node.lnz.texture_list:
		max_tex = int(pet_node.lnz.texture_list.size())
	if randf() > 0.6: 
		parts.append("-1")
	if max_tex > 0:
		if randf() > 0.3:
			var tex_start: int = randi() % max_tex
			if randf() > 0.7 and tex_start < max_tex - 1:
				var remaining: int = int(max_tex - 1 - tex_start)
				var range_width: int = (randi() % int(min(3, remaining))) + 1
				parts.append(str(tex_start) + "-" + str(tex_start + range_width))
			else:
				parts.append(str(tex_start))
	else:
		if parts.empty(): 
			parts.append("0")
			
	var temp_pool: PoolStringArray = PoolStringArray(parts)
	var result = temp_pool.join(",")
	temp_pool.resize(0)
	return result

func _get_random_static_accent() -> String:
	if randf() > 0.4:
		return "244"
	return str(randi() % (214 - 150 + 1) + 150)

