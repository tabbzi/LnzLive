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
onready var _randomize_button: Button = find_node("RandomizeButton")
onready var _affected_ballz: Control = find_node("AffectedBallz")
onready var _unselect_button: Button = find_node("UnselectButton")
onready var _apply_button: Button = find_node("ApplyButton")
onready var _clear_button: Button = find_node("ClearButton")
onready var _surprise_button: Button = find_node("SurpriseButton")
onready var _distribution: OptionButton = find_node("Distribution")
onready var _use_seed: CheckBox = find_node("UseSeed")
onready var _seed_edit: LineEdit = find_node("Seed")
onready var _fractal_preset: OptionButton = find_node("FractalPreset")
onready var _fractal_axiom: LineEdit = find_node("FractalAxiom")
onready var _fractal_rules: TextEdit = find_node("FractalRules")
onready var _fractal_angle: SpinBox = find_node("FractalAngle")
onready var _random_system_button: Button = find_node("RandomSystemButton")
onready var _spiral_turns: SpinBox = find_node("SpiralTurns")
onready var _star_points: SpinBox = find_node("StarPoints")
onready var _star_point_size: SpinBox = find_node("StarPointSize")
onready var _ray_length: SpinBox = find_node("RayLength")
onready var _num_bands: SpinBox = find_node("NumBands")
onready var _band_spacing: SpinBox = find_node("BandSpacing")
onready var _band_offset: SpinBox = find_node("BandOffset")
onready var _band_angle: SpinBox = find_node("BandAngle")
onready var _band_direction: OptionButton = find_node("BandDirection")
onready var _noise_scale: SpinBox = find_node("NoiseScale")
onready var _noise_threshold: SpinBox = find_node("NoiseThreshold")
onready var _noise_octaves: SpinBox = find_node("NoiseOctaves")
onready var _grid_size: SpinBox = find_node("GridSize")
onready var _num_clusters: SpinBox = find_node("NumClusters")
onready var _num_rings: SpinBox = find_node("NumRings")
onready var _voronoi_cells: SpinBox = find_node("VoronoiCells")
onready var _voronoi_edge_size: SpinBox = find_node("VoronoiEdgeSize")
onready var _wave_degree_l: SpinBox = find_node("WaveDegreeL")
onready var _wave_order_m: SpinBox = find_node("WaveOrderM")
onready var _wave_threshold: SpinBox = find_node("WaveThreshold")
onready var _stripe_feed_rate: SpinBox = find_node("StripeFeedRate")
onready var _stripe_kill_rate: SpinBox = find_node("StripeKillRate")
onready var _stripe_timestep: SpinBox = find_node("StripeTimestep")
onready var _diffusion_activator: SpinBox = find_node("DiffusionActivator")
onready var _diffusion_inhibitor: SpinBox = find_node("DiffusionInhibitor")
onready var _size_adaptive: CheckButton = find_node("SizeAdaptive")
onready var _leopard_radius_min: SpinBox = find_node("LeopardRadiusMin")
onready var _leopard_radius_max: SpinBox = find_node("LeopardRadiusMax")
onready var _leopard_irregularity: SpinBox = find_node("LeopardIrregularity")
onready var _leopard_completeness: SpinBox = find_node("LeopardCompleteness")
onready var _leopard_paired_colors: CheckBox = find_node("LeopardPairedColors")
onready var _rainbow_angle: SpinBox = find_node("RainbowAngle")
onready var _rainbow_curvature: SpinBox = find_node("RainbowCurvature")
onready var _rainbow_width: SpinBox = find_node("RainbowWidth")
onready var _rainbow_length: SpinBox = find_node("RainbowLength")
onready var _fractal_iterations: SpinBox = find_node("FractalIterations")
onready var _halfie_axis: OptionButton = find_node("HalfieAxis")
onready var _halfie_side: OptionButton = find_node("HalfieSide")
onready var _size_min: SpinBox = find_node("SizeMin")
onready var _size_max: SpinBox = find_node("SizeMax")
onready var _outline_type_min: SpinBox = find_node("OutlineTypeMin")
onready var _outline_type_max: SpinBox = find_node("OutlineTypeMax")
onready var _fuzz_min: SpinBox = find_node("FuzzMin")
onready var _fuzz_max: SpinBox = find_node("FuzzMax")
onready var _texture_list: Control = find_node("TextureList")
onready var _group: SpinBox = find_node("Group")
onready var _anchored: CheckBox = find_node("Anchored")
onready var _ordered: CheckBox = find_node("Ordered")
onready var _description_label: RichTextLabel = find_node("DescriptionLabel")
onready var _num_spots: SpinBox = find_node("NumSpots")
onready var _color_list: Control = find_node("ColorList", true, false)
var _color_list_preview: Control = null
onready var _outline_color_list: Control = find_node("OutlineColorList", true, false)
var _outline_color_list_preview: Control = null
onready var _reset_defaults: Button = find_node("ResetDefaultsButton")
onready var _export_settings: Button = find_node("ExportSettingsButton")
onready var _import_settings: Button = find_node("ImportSettingsButton")
onready var _pixel_mode: CheckBox = find_node("PixelMode")
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
	
	_randomize_button.connect("pressed", self, "_on_RandomizeButton_pressed")
	_affected_ballz.connect("text_changed", self, "_on_AffectedBallz_text_changed")
	_unselect_button.connect("pressed", self, "_on_UnselectButton_pressed")
	_apply_button.connect("pressed", self, "_on_ApplyButton_pressed")
	_clear_button.connect("pressed", self, "_on_ClearButton_pressed")
	_surprise_button.connect("pressed", self, "_on_SurpriseButton_pressed")
	_distribution.connect("item_selected", self, "_on_Distribution_item_selected")
	_use_seed.connect("toggled", self, "_on_UseSeed_toggled")
 
	_fractal_preset.connect("item_selected", self, "_on_FractalPreset_item_selected")
	_fractal_axiom.connect("text_changed", self, "_on_FractalAxiom_text_changed")
 
	_random_system_button.connect("pressed", self, "_on_RandomSystemButton_pressed")
	
	_on_Distribution_item_selected(0)
	_on_FractalPreset_item_selected(_fractal_preset.selected)

	_setup_color_previews()
	_connect_settings_signals()
	load_settings()
	call_deferred("_on_palette_changed")

func _setup_color_previews() -> void:
	_setup_preview_wrapper("ColorList")
	_setup_preview_wrapper("OutlineColorList")
	
	_color_list_preview = find_node("ColorList_Preview", true, false)
	_outline_color_list_preview = find_node("OutlineColorList_Preview", true, false)

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
	if _color_list and _color_list_preview:
		_update_previews_inner(_color_list.text, _color_list_preview)
		
	if _outline_color_list and _outline_color_list_preview:
		_update_previews_inner(_outline_color_list.text, _outline_color_list_preview)

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
	_seed_edit.editable = button_pressed

func _on_RandomSystemButton_pressed() -> void:
	var random_system: Dictionary = LnzLiveUtils.generate_random_lsystem()
	_fractal_axiom.text = random_system["axiom"]
	_fractal_rules.text = random_system["rules_text"]
	_fractal_angle.value = [30, 45, 60, 90, 120][randi() % 5]

func _on_FractalPreset_item_selected(index: int) -> void:
	_fractal_axiom.editable = false
	_fractal_rules.readonly = true
	_random_system_button.hide()
	
	match index:
		FractalPreset.DRAGON_CURVE:
			_fractal_axiom.text = "F"
			_fractal_rules.text = "F=F+G\nG=F-G"
			_fractal_angle.value = 90.0
		FractalPreset.SIERPINSKI:
			_fractal_axiom.text = "A"
			_fractal_rules.text = "A=B-A-B\nB=A+B+A"
			_fractal_angle.value = 60.0
		FractalPreset.BARNSLEY_FERN:
			_fractal_axiom.text = "X"
			_fractal_rules.text = "X=F+[[X]-X]-F[-FX]+X\nF=FF"
			_fractal_angle.value = 25.0
		FractalPreset.CUSTOM:
			_fractal_axiom.editable = true
			_fractal_rules.readonly = false
			_random_system_button.show()
			pass

func _on_FractalAxiom_text_changed(new_text: String) -> void:
	var sanitized_text: String = ""
	
	for current_char in new_text:
		if ALLOWED_FRACTAL_CHARS.find(current_char) != -1:
			sanitized_text += current_char
			
	if sanitized_text != new_text:
		var cursor_pos: int = _fractal_axiom.caret_position
		_fractal_axiom.text = sanitized_text
		_fractal_axiom.caret_position = min(cursor_pos, sanitized_text.length())

func _on_AffectedBallz_text_changed(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("affected_list_changed", ids)

func _on_Distribution_item_selected(index: int) -> void:
	for child in params_container.get_children():
		child.hide()

	var description_label: RichTextLabel = _description_label
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

	var num_spots_edit = _num_spots
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
		_affected_ballz.text = "0"

	var color_list: Array = LnzLiveUtils.parse_number_list(properties["color_list"])
	if color_list.empty():
		color_list = [105]
		_color_list.text = "105"

	var outline_color_list: Array = LnzLiveUtils.parse_number_list(properties["outline_color_list"])
	if outline_color_list.empty():
		outline_color_list = [244]
		_outline_color_list.text = "244"

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
	if !properties["use_seed"]: _seed_edit.text = str(base_seed)

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
	properties["affected_ballz"] = _affected_ballz.text
	properties["distribution"] = _distribution.selected
	properties["num_spots"] = _num_spots.value
	properties["spiral_turns"] = _spiral_turns.value
	properties["star_points"] = _star_points.value
	properties["star_point_size"] = _star_point_size.value
	properties["num_bands"] = _num_bands.value
	properties["band_spacing"] = _band_spacing.value
	properties["band_offset"] = _band_offset.value
	properties["band_angle"] = _band_angle.value
	properties["band_direction"] = _band_direction.selected 
	properties["noise_scale"] = _noise_scale.value
	properties["noise_threshold"] = _noise_threshold.value
	properties["noise_octaves"] = _noise_octaves.value
	properties["voronoi_cells"] = _voronoi_cells.value
	properties["voronoi_edge_size"] = _voronoi_edge_size.value
	properties["wave_degree_l"] = _wave_degree_l.value
	properties["wave_order_m"] = _wave_order_m.value
	properties["wave_threshold"] = _wave_threshold.value
	
	properties["grid_size"] = _grid_size.value
	properties["num_clusters"] = _num_clusters.value
	properties["ray_length"] = _ray_length.value
	properties["stripe_feed_rate"] = _stripe_feed_rate.value
	properties["stripe_kill_rate"] = _stripe_kill_rate.value
	properties["diffusion_b"] = _diffusion_activator.value
	properties["diffusion_a"] = _diffusion_inhibitor.value
	properties["stripe_timestep"] = _stripe_timestep.value
	properties["size_adaptive"] = _size_adaptive.pressed
	properties["leopard_radius_min"] = _leopard_radius_min.value
	properties["leopard_radius_max"] = _leopard_radius_max.value
	properties["leopard_irregularity"] = _leopard_irregularity.value
	properties["leopard_completeness"] = _leopard_completeness.value
	properties["leopard_use_paired_colors"] = _leopard_paired_colors.pressed
	properties["rainbow_angle"] = _rainbow_angle.value
	properties["rainbow_curvature"] = _rainbow_curvature.value
	properties["rainbow_width"] = _rainbow_width.value
	properties["rainbow_length"] = _rainbow_length.value
	properties["fractal_iterations"] = _fractal_iterations.value
	properties["fractal_angle"] = _fractal_angle.value
	properties["fractal_preset"] = _fractal_preset.selected
	properties["fractal_axiom"] = _fractal_axiom.text
	properties["fractal_rules"] = _fractal_rules.text
	properties["halfie_axis"] = _halfie_axis.selected
	properties["halfie_side"] = _halfie_side.selected
	properties["num_rings"] = _num_rings.value
	properties["size_min"] = _size_min.value
	properties["size_max"] = _size_max.value
	
	properties["color_list"] = _color_list.text if _color_list else ""
	properties["outline_color_list"] = _outline_color_list.text if _outline_color_list else ""
	
	properties["outline_type_min"] = _outline_type_min.value
	properties["outline_type_max"] = _outline_type_max.value
	properties["fuzz_min"] = _fuzz_min.value
	properties["fuzz_max"] = _fuzz_max.value
	properties["texture_list"] = _texture_list.text
	properties["group"] = _group.value
	properties["anchored"] = _anchored.pressed
	properties["ordered"] = _ordered.pressed
	properties["use_seed"] = _use_seed.pressed
	properties["seed"] = _seed_edit.text
	properties["pixel_mode"] = _pixel_mode.pressed
	return properties

func _apply_settings_dict(data: Dictionary) -> void:
	_is_loading_settings = true
	
	if data.has("affected_ballz"): _affected_ballz.text = str(data["affected_ballz"])
	if data.has("distribution"): _distribution.selected = data["distribution"]
	if data.has("num_spots"): _num_spots.value = data["num_spots"]
	if data.has("spiral_turns"): _spiral_turns.value = data["spiral_turns"]
	if data.has("star_points"): _star_points.value = data["star_points"]
	if data.has("star_point_size"): _star_point_size.value = data["star_point_size"]
	if data.has("num_bands"): _num_bands.value = data["num_bands"]
	if data.has("band_spacing"): _band_spacing.value = data["band_spacing"]
	if data.has("band_offset"): _band_offset.value = data["band_offset"]
	if data.has("band_angle"): _band_angle.value = data["band_angle"]
	if data.has("band_direction"): _band_direction.selected = data["band_direction"]
	
	if data.has("noise_scale"): _noise_scale.value = data["noise_scale"]
	if data.has("noise_threshold"): _noise_threshold.value = data["noise_threshold"]
	if data.has("noise_octaves"): _noise_octaves.value = data["noise_octaves"]
	
	if data.has("voronoi_cells"): _voronoi_cells.value = data["voronoi_cells"]
	if data.has("voronoi_edge_size"): _voronoi_edge_size.value = data["voronoi_edge_size"]
	
	if data.has("wave_degree_l"): _wave_degree_l.value = data["wave_degree_l"]
	if data.has("wave_order_m"): _wave_order_m.value = data["wave_order_m"]
	if data.has("wave_threshold"): _wave_threshold.value = data["wave_threshold"]
	
	if data.has("grid_size"): _grid_size.value = data["grid_size"]
	if data.has("num_clusters"): _num_clusters.value = data["num_clusters"]
	if data.has("ray_length"): _ray_length.value = data["ray_length"]
	
	if data.has("stripe_feed_rate"): _stripe_feed_rate.value = data["stripe_feed_rate"]
	if data.has("stripe_kill_rate"): _stripe_kill_rate.value = data["stripe_kill_rate"]
	if data.has("stripe_timestep"): _stripe_timestep.value = data["stripe_timestep"]
	if data.has("diffusion_b"): _diffusion_activator.value = data["diffusion_b"]
	if data.has("diffusion_a"): _diffusion_inhibitor.value = data["diffusion_a"]
	if data.has("size_adaptive"): _size_adaptive.pressed = data["size_adaptive"]

	
	if data.has("leopard_radius_min"): _leopard_radius_min.value = data["leopard_radius_min"]
	if data.has("leopard_radius_max"): _leopard_radius_max.value = data["leopard_radius_max"]
	if data.has("leopard_irregularity"): _leopard_irregularity.value = data["leopard_irregularity"]
	if data.has("leopard_completeness"): _leopard_completeness.value = data["leopard_completeness"]
	if data.has("leopard_use_paired_colors"): _leopard_paired_colors.pressed = data["leopard_use_paired_colors"]
	
	if data.has("rainbow_angle"): _rainbow_angle.value = data["rainbow_angle"]
	if data.has("rainbow_curvature"): _rainbow_curvature.value = data["rainbow_curvature"]
	if data.has("rainbow_width"): _rainbow_width.value = data["rainbow_width"]
	if data.has("rainbow_length"): _rainbow_length.value = data["rainbow_length"]
	
	if data.has("fractal_iterations"): _fractal_iterations.value = data["fractal_iterations"]
	if data.has("fractal_angle"): _fractal_angle.value = data["fractal_angle"]
	if data.has("fractal_preset"): _fractal_preset.selected = data["fractal_preset"]
	if data.has("fractal_axiom"): _fractal_axiom.text = str(data["fractal_axiom"])
	if data.has("fractal_rules"): _fractal_rules.text = str(data["fractal_rules"])
	
	if data.has("halfie_axis"): _halfie_axis.selected = data["halfie_axis"]
	if data.has("halfie_side"): _halfie_side.selected = data["halfie_side"]
	
	if data.has("num_rings"): _num_rings.value = data["num_rings"]
	if data.has("size_min"): _size_min.value = data["size_min"]
	if data.has("size_max"): _size_max.value = data["size_max"]
	
	if data.has("color_list"): _color_list.text = str(data["color_list"])
	if data.has("outline_color_list"): _outline_color_list.text = str(data["outline_color_list"])
	
	if data.has("outline_type_min"): _outline_type_min.value = data["outline_type_min"]
	if data.has("outline_type_max"): _outline_type_max.value = data["outline_type_max"]
	if data.has("fuzz_min"): _fuzz_min.value = data["fuzz_min"]
	if data.has("fuzz_max"): _fuzz_max.value = data["fuzz_max"]
	if data.has("texture_list"): _texture_list.text = str(data["texture_list"])
	
	if data.has("group"): _group.value = data["group"]
	if data.has("anchored"): _anchored.pressed = data["anchored"]
	if data.has("ordered"): _ordered.pressed = data["ordered"]
	if data.has("use_seed"): _use_seed.pressed = data["use_seed"]
	if data.has("seed"): _seed_edit.text = str(data["seed"])
	if data.has("pixel_mode"): _pixel_mode.pressed = data["pixel_mode"]
	
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
	var current_text: String = _affected_ballz.text
	var current_list: Array = LnzLiveUtils.parse_number_list(current_text)

	if ball_no in current_list:
		return

	if current_text.strip_edges() == "":
		_affected_ballz.text = str(ball_no)
	else:
		_affected_ballz.text += "," + str(ball_no)
		
	_on_AffectedBallz_text_changed(_affected_ballz.text)

func update_selected_balls_text(ball_ids: Array) -> void:
	if not _affected_ballz or _affected_ballz.has_focus():
		return

	if ball_ids.empty():
		_affected_ballz.text = ""
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
	_affected_ballz.text = temp_pool.join(",")
	temp_pool.resize(0)
	
	_on_AffectedBallz_text_changed(_affected_ballz.text)

func _on_UnselectButton_pressed() -> void:
	emit_signal("unselect_all")

func _connect_settings_signals() -> void:
	_affected_ballz.connect("text_changed", self, "_on_setting_changed")
	
	if _color_list: _color_list.connect("text_changed", self, "_on_setting_changed")
	if _outline_color_list: _outline_color_list.connect("text_changed", self, "_on_setting_changed")
	
	if _texture_list: _texture_list.connect("text_changed", self, "_on_setting_changed")
	_fractal_axiom.connect("text_changed", self, "_on_setting_changed")
	_seed_edit.connect("text_changed", self, "_on_setting_changed")

	_fractal_rules.connect("text_changed", self, "_on_setting_changed")

	_distribution.connect("item_selected", self, "_on_setting_changed")
	_band_direction.connect("item_selected", self, "_on_setting_changed")
	_fractal_preset.connect("item_selected", self, "_on_setting_changed")
	_halfie_axis.connect("item_selected", self, "_on_setting_changed")
	_halfie_side.connect("item_selected", self, "_on_setting_changed")

	_ordered.connect("toggled", self, "_on_setting_changed")
	_use_seed.connect("toggled", self, "_on_setting_changed")
	_anchored.connect("toggled", self, "_on_setting_changed")
	_leopard_paired_colors.connect("toggled", self, "_on_setting_changed")

	_connect_spinboxes_recursive(self)

	if _reset_defaults:
		_reset_defaults.connect("pressed", self, "_on_reset_defaults_pressed")

	if _export_settings: _export_settings.connect("pressed", self, "export_autopaintballer_json")
	if _import_settings: _import_settings.connect("pressed", self, "_on_ImportPresetButton_pressed")

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

	_affected_ballz.text = config.get_value("AutoPaintballer", "affected_ballz", "")
	_distribution.selected = config.get_value("AutoPaintballer", "distribution", 0)
	_num_spots.value = config.get_value("AutoPaintballer", "num_spots", 25.0)
	_ordered.pressed = config.get_value("AutoPaintballer", "ordered", false)
	_use_seed.pressed = config.get_value("AutoPaintballer", "use_seed", false)
	_seed_edit.text = config.get_value("AutoPaintballer", "seed", "")

	_size_min.value = config.get_value("AutoPaintballer", "size_min", 10.0)
	_size_max.value = config.get_value("AutoPaintballer", "size_max", 20.0)
	_pixel_mode.pressed = config.get_value("AutoPaintballer", "pixel_mode", false)
	
	if _color_list: _color_list.text = config.get_value("AutoPaintballer", "color_list", "")
	if _outline_color_list: _outline_color_list.text = config.get_value("AutoPaintballer", "outline_color_list", "244")
	
	_texture_list.text = config.get_value("AutoPaintballer", "texture_list", "0")
	_outline_type_min.value = config.get_value("AutoPaintballer", "outline_type_min", -1.0)
	_outline_type_max.value = config.get_value("AutoPaintballer", "outline_type_max", -1.0)
	_fuzz_min.value = config.get_value("AutoPaintballer", "fuzz_min", 0.0)
	_fuzz_max.value = config.get_value("AutoPaintballer", "fuzz_max", 0.0)
	_group.value = config.get_value("AutoPaintballer", "group", 0.0)
	_anchored.pressed = config.get_value("AutoPaintballer", "anchored", true)

	_spiral_turns.value = config.get_value("AutoPaintballer", "spiral_turns", 5.0)
	_star_point_size.value = config.get_value("AutoPaintballer", "star_point_size", 4.0)
	_star_points.value = config.get_value("AutoPaintballer", "star_points", 5.0)
	_ray_length.value = config.get_value("AutoPaintballer", "ray_length", 4.0)
	_rainbow_angle.value = config.get_value("AutoPaintballer", "rainbow_angle", 0.0)
	_rainbow_curvature.value = config.get_value("AutoPaintballer", "rainbow_curvature", 0.0)
	_rainbow_width.value = config.get_value("AutoPaintballer", "rainbow_width", 0.5)
	_rainbow_length.value = config.get_value("AutoPaintballer", "rainbow_length", 1.0)

	_band_direction.selected = config.get_value("AutoPaintballer", "band_direction", 0)
	_num_bands.value = config.get_value("AutoPaintballer", "num_bands", 5.0)
	_band_spacing.value = config.get_value("AutoPaintballer", "band_spacing", 0.5)
	_band_offset.value = config.get_value("AutoPaintballer", "band_offset", 0.0)
	_band_angle.value = config.get_value("AutoPaintballer", "band_angle", 0.0)
	_grid_size.value = config.get_value("AutoPaintballer", "grid_size", 5.0)
	_num_clusters.value = config.get_value("AutoPaintballer", "num_clusters", 3.0)
	_num_rings.value = config.get_value("AutoPaintballer", "num_rings", 3.0)

	_noise_scale.value = config.get_value("AutoPaintballer", "noise_scale", 10.0)
	_noise_threshold.value = config.get_value("AutoPaintballer", "noise_threshold", 0.5)
	_noise_octaves.value = config.get_value("AutoPaintballer", "noise_octaves", 3.0)
	_voronoi_cells.value = config.get_value("AutoPaintballer", "voronoi_cells", 5.0)
	_voronoi_edge_size.value = config.get_value("AutoPaintballer", "voronoi_edge_size", 0.05)
	_wave_degree_l.value = config.get_value("AutoPaintballer", "wave_degree_l", 2.0)
	_wave_order_m.value = config.get_value("AutoPaintballer", "wave_order_m", 1.0)
	_wave_threshold.value = config.get_value("AutoPaintballer", "wave_threshold", 0.6)

	_stripe_feed_rate.value = config.get_value("AutoPaintballer", "stripe_feed_rate", 0.07)
	_stripe_kill_rate.value = config.get_value("AutoPaintballer", "stripe_kill_rate", 0.05)
	_diffusion_activator.value = config.get_value("AutoPaintballer", "diffusion_b", 0.5)
	_diffusion_inhibitor.value = config.get_value("AutoPaintballer", "diffusion_a", 1.0)
	_stripe_timestep.value = config.get_value("AutoPaintballer", "stripe_timestep", 1.0)

	_leopard_radius_min.value = config.get_value("AutoPaintballer", "leopard_radius_min", 0.05)
	_leopard_radius_max.value = config.get_value("AutoPaintballer", "leopard_radius_max", 0.1)
	_leopard_irregularity.value = config.get_value("AutoPaintballer", "leopard_irregularity", 0.3)
	_leopard_completeness.value = config.get_value("AutoPaintballer", "leopard_completeness", 0.75)
	_leopard_paired_colors.pressed = config.get_value("AutoPaintballer", "leopard_use_paired_colors", false)

	_fractal_iterations.value = config.get_value("AutoPaintballer", "fractal_iterations", 5.0)
	_fractal_angle.value = config.get_value("AutoPaintballer", "fractal_angle", 90.0)
	_fractal_preset.selected = config.get_value("AutoPaintballer", "fractal_preset", 0)
	_fractal_axiom.text = config.get_value("AutoPaintballer", "fractal_axiom", "F")
	_fractal_rules.text = config.get_value("AutoPaintballer", "fractal_rules", "")

	_halfie_axis.selected = config.get_value("AutoPaintballer", "halfie_axis", 0)
	_halfie_side.selected = config.get_value("AutoPaintballer", "halfie_side", 0)

	_on_Distribution_item_selected(_distribution.selected)
	_on_FractalPreset_item_selected(_fractal_preset.selected)
	_on_UseSeed_toggled(_use_seed.pressed)

	_is_loading_settings = false
	_refresh_all_previews()

func _on_reset_defaults_pressed() -> void:
	_is_loading_settings = true

	_affected_ballz.text = ""
	_distribution.selected = 0
	_num_spots.value = 25.0
	_ordered.pressed = false
	_use_seed.pressed = false
	_seed_edit.text = ""

	_size_min.value = 10.0
	_size_max.value = 20.0
	
	if _color_list: _color_list.text = ""
	if _outline_color_list: _outline_color_list.text = "244"
	
	_texture_list.text = "0"
	_outline_type_min.value = -1.0
	_outline_type_max.value = -1.0
	_fuzz_min.value = 0.0
	_fuzz_max.value = 0.0
	_group.value = 0.0
	_anchored.pressed = true

	_wave_degree_l.value = 2.0
	_wave_order_m.value = 1.0
	_wave_threshold.value = 0.6
	_voronoi_cells.value = 5.0
	_voronoi_edge_size.value = 0.05

	_noise_scale.value = 10.0
	_noise_threshold.value = 0.5
	_noise_octaves.value = 3.0
	_fractal_preset.selected = 0
	_fractal_axiom.text = ""
	_fractal_rules.text = ""
	_fractal_iterations.value = 5.0
	_fractal_angle.value = 90.0

	_spiral_turns.value = 5.0
	_star_point_size.value = 4.0
	_star_points.value = 5.0
	_ray_length.value = 4.0

	_rainbow_angle.value = 0.0
	_rainbow_curvature.value = 0.0
	_rainbow_width.value = 0.5
	_rainbow_length.value = 1.0
	_band_direction.selected = 0
	_num_bands.value = 5.0
	_band_spacing.value = 0.5
	_band_offset.value = 0.0
	_band_angle.value = 0.0

	_grid_size.value = 5.0
	_num_clusters.value = 3.0
	_num_rings.value = 3.0

	_stripe_feed_rate.value = 0.07
	_stripe_kill_rate.value = 0.05
	_diffusion_activator.value = 0.5
	_diffusion_inhibitor.value = 1.0
	_stripe_timestep.value = 1.0

	_leopard_radius_min.value = 0.05
	_leopard_radius_max.value = 0.1
	_leopard_irregularity.value = 0.3
	_leopard_completeness.value = 0.75
	_leopard_paired_colors.pressed = false

	_halfie_axis.selected = 0
	_halfie_side.selected = 0

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
	_distribution.selected = random_mode
	_on_Distribution_item_selected(random_mode)

	if random_mode == Distribution.RAINBOW or random_mode == Distribution.FRACTAL:
		_num_spots.value = (randi() % 2) + 1
	elif random_mode == Distribution.STAR:
		_num_spots.value = (randi() % 40) + 1
	elif random_mode == Distribution.LEOPARD:
		_num_spots.value = (randi() % 50) + 1
	else:
		_num_spots.value = int(rand_range(20, 150))
	
	var size_base: float = rand_range(2, 12)
	_size_min.value = size_base
	_size_max.value = min(50, size_base + rand_range(5, 25))
	
	_pixel_mode.pressed = randf() > 0.5

	if randf() > 0.6: 
		var fuzz_base: int = randi() % 4
		_fuzz_min.value = fuzz_base
		_fuzz_max.value = int(min(5, fuzz_base + randi() % 3))
	else:
		_fuzz_min.value = 0
		_fuzz_max.value = 0

	if _color_list: _color_list.text = _generate_surprise_color_string()
	if _outline_color_list: _outline_color_list.text = _get_random_static_accent()
	
	_texture_list.text = _generate_surprise_texture_string()
	
	var out_type: int = -1
	if randf() < 0.3:
		out_type = randi() % 4 - 2 
	_outline_type_min.value = out_type
	_outline_type_max.value = out_type

	_randomize_mode_params(random_mode)

	_is_loading_settings = false
	save_settings()
	_refresh_all_previews()
	_on_RandomizeButton_pressed()

func _randomize_mode_params(mode: int) -> void:
	match mode:
		Distribution.FRACTAL:
			if randf() > 0.4:
				_fractal_preset.selected = FractalPreset.CUSTOM
				_on_FractalPreset_item_selected(FractalPreset.CUSTOM)
				_on_RandomSystemButton_pressed()
			else:
				var preset: int = (randi() % 3) + 1
				_fractal_preset.selected = preset
				_on_FractalPreset_item_selected(preset)
			
			_fractal_iterations.value = (randi() % 3) + 2
			
		Distribution.SPIRAL:
			_spiral_turns.value = rand_range(1.0, 15.0) 
		Distribution.STAR:
			_star_points.value = randi() % 7 + 3
			_star_point_size.value = rand_range(2.0, 8.0)
			_ray_length.value = randi() % 6 + 2
		Distribution.BANDS:
			_band_direction.selected = randi() % 2
			_num_bands.value = randi() % 8 + 2
			_band_spacing.value = rand_range(0.1, 0.8)
			_band_offset.value = rand_range(-0.5, 0.5)
			_band_angle.value = [0, 45, 90, 135][randi() % 4]
		Distribution.NOISE_FIELD:
			_noise_scale.value = rand_range(2.0, 20.0)
			_noise_threshold.value = rand_range(0.3, 0.7)
			_noise_octaves.value = randi() % 4 + 1
		Distribution.GRID, Distribution.CHECKERBOARD:
			_grid_size.value = randi() % 10 + 3
		Distribution.CLUSTERED:
			_num_clusters.value = randi() % 5 + 1
		Distribution.BULLSEYE:
			_num_rings.value = randi() % 5 + 2
		Distribution.LEOPARD:
			_leopard_radius_min.value = rand_range(0.02, 0.08)
			_leopard_radius_max.value = rand_range(0.09, 0.2) 
			_leopard_irregularity.value = rand_range(0.1, 0.5)
			_leopard_completeness.value = rand_range(0.4, 1.0) 
			_leopard_paired_colors.pressed = randf() > 0.5
		Distribution.RAINBOW:
			_rainbow_angle.value = rand_range(-180, 180)
			_rainbow_curvature.value = rand_range(0.0, 1.0)
			_rainbow_width.value = rand_range(0.5, 5.0)
			_rainbow_length.value = rand_range(0.5, 2.5)
		Distribution.STRIPES:
			_stripe_feed_rate.value = rand_range(0.01, 0.09) 
			_stripe_kill_rate.value = rand_range(0.03, 0.07) 
			_stripe_timestep.value = 1.0
		Distribution.VORONOI:
			_voronoi_cells.value = randi() % 12 + 3 
			_voronoi_edge_size.value = rand_range(0.01, 0.1) 
		Distribution.WAVE:
			_wave_degree_l.value = randi() % 4 
			_wave_order_m.value = randi() % 4 
			_wave_threshold.value = rand_range(0.4, 0.8)

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

