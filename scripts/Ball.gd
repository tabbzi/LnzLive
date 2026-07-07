extends Spatial
## Ball.gd
## Represents ballz in the 3D Viewport
## This script manages the visual properties of a ball from parsed LNZ document data
## and handles user interactions like mouse-over highlighting and selection events

export var ball_no                = 0
export var base_ball_no           = -1

export var ball_size              = 10                 setget set_ball_size
export var fuzz_amount            = 0                  setget set_fuzz_amount
export var outline                = -1                 setget set_outline
export var color_index            = 0                  setget set_color_index
export var outline_color_index    = 0                  setget set_outline_color_index
export var z_add                  = 0.0                setget set_z_add
export var pet_center             = Vector3(0, 0, 0)   setget set_pet_center

export var visible_override       = true               setget set_visible
export var omitted                = false

var select_mode_active            = false              setget set_select_mode_active

func set_select_mode_active(v: bool) -> void:
	select_mode_active = v

export var tile_texture           = true               setget set_tile_texture
export var texture                : Texture            setget set_texture
export var texture_size           = Vector2(256, 256)  setget set_texture_size
export var texture_size_raw       = Vector2.ZERO

export var use_quadrants          = false              setget set_use_quadrants
export var render_flat_colors     = false              setget set_render_flat_colors

export var transparent_color      = 0                  setget set_transparent_color
export var transparency_on        = true               setget set_transparency

export var eyelid_rotation        = 0.0                setget set_eyelid_rotation
export(int) var eyelid_color      = -1                 setget set_eyelid_color
		   
export var eyelash_lengths        = []                 setget set_eyelash_lengths
export var eyelash_angle          = 15                 setget set_eyelash_angle
export var eyelash_spacing        = 50                 setget set_eyelash_spacing
export var eyelash_color          = 244                setget set_eyelash_color

export var species                = 0                  setget set_species

export var palette                = LnzLiveUtils.DEFAULT_PALETTE setget set_palette
const DEFAULT_PALETTE             = LnzLiveUtils.DEFAULT_PALETTE
const BABYZ_PALETTE               = LnzLiveUtils.BABYZ_PALETTE

export var petz_palette           = DEFAULT_PALETTE

var timer_count: int = 0

enum OutlineState {
	NONE,
	ACTIVE_SELECTED,
	LINEZ_START,
	LINEZ_TARGET,
	HOVER,
	MODIFIED,
	PIVOT
}

var current_outline_state: int = OutlineState.NONE setget , get_outline_state

var old_outline: int = outline
var old_outline_color: int = outline_color_index

var is_over: bool = false

signal ball_mouse_enter(ball_info)
signal ball_mouse_exit(ball_no)
signal ball_selected(ball_no, section)
signal ball_deleted(ball_no)

func _ready() -> void:
	old_outline = outline
	old_outline_color = outline_color_index

	# Duplicate material so each ball can have unique shader params
	$MeshInstance.material_override = $MeshInstance.material_override.duplicate()

	# Set the initial species, which will configure the shader
	set_species(species)

	# Set initial shader parameters
	$MeshInstance.material_override.set_shader_param("transparency_on", transparency_on)
	$MeshInstance.material_override.set_shader_param("rotation", rotation)
	$MeshInstance.material_override.set_shader_param("tiling_unit", 128.0)
	$MeshInstance.material_override.set_shader_param("texture_size", texture_size)
	$MeshInstance.material_override.set_shader_param("tile_texture", tile_texture)
	$MeshInstance.material_override.set_shader_param("use_quadrants", use_quadrants)
	$MeshInstance.material_override.set_shader_param("render_flat_colors", render_flat_colors)
	$MeshInstance.material_override.set_shader_param("eyelid_rotation", eyelid_rotation)
	$MeshInstance.material_override.set_shader_param("eyelid_color",    eyelid_color)
	
	set_eyelash_lengths(eyelash_lengths)
	set_eyelash_angle(eyelash_angle)
	set_eyelash_spacing(eyelash_spacing)
	set_eyelash_color(eyelash_color)

	# Pass the original texture to the shader
	set_texture(texture)

	# Pass the default Petz palette to the shader
	$MeshInstance.material_override.set_shader_param("petz_palette", DEFAULT_PALETTE)

func set_hidden(is_hidden: bool) -> void:
	$MeshInstance.visible = not is_hidden
	$Area/CollisionShape.disabled = is_hidden

func set_visible(new_value: bool) -> void:
	visible_override = new_value
	$MeshInstance.visible = new_value
	$Area/CollisionShape.disabled = not new_value
	$Area/CollisionShape.visible = new_value

func set_render_flat_colors(new_value: bool) -> void:
	render_flat_colors = new_value
	if has_node("MeshInstance") and $MeshInstance.material_override != null:
		$MeshInstance.material_override.set_shader_param("render_flat_colors", new_value)

func set_tile_texture(new_value: bool) -> void:
	tile_texture = new_value
	$MeshInstance.material_override = $MeshInstance.material_override.duplicate()
	$MeshInstance.material_override.set_shader_param("tile_texture", new_value)

func set_use_quadrants(new_value: bool) -> void:
	use_quadrants = new_value
	if $MeshInstance.material_override:
		$MeshInstance.material_override.set_shader_param("use_quadrants", new_value)

func set_ball_size(new_value: float) -> void:
	ball_size = new_value
	$MeshInstance.material_override.set_shader_param("ball_size", new_value)
	var a: float = ball_size * 0.05
	$Area/CollisionShape.shape.radius = a * 0.02
	$Area/CollisionShape.shape.margin = 0.0001

func set_eyelid_rotation(rad: float) -> void:
	eyelid_rotation = rad
	$MeshInstance.material_override.set_shader_param("eyelid_rotation", rad)

func set_eyelid_color(col: int) -> void:
	eyelid_color = col
	$MeshInstance.material_override.set_shader_param("eyelid_color", col)

func set_eyelash_lengths(new_value: Array) -> void:
	eyelash_lengths = new_value
	if $MeshInstance.material_override:
		$MeshInstance.material_override.set_shader_param("has_eyelashes", new_value.size() > 0)
		$MeshInstance.material_override.set_shader_param("eyelash_count", new_value.size())
		
		var l1: Array = [0.0, 0.0, 0.0, 0.0]
		var l2: Array = [0.0, 0.0, 0.0, 0.0]
		
		# Fill first vec4 (lashes 0-3)
		for i in range(min(new_value.size(), 4)):
			l1[i] = float(new_value[i])
			
		# Fill second vec4 (lashes 4-7)
		for i in range(4, min(new_value.size(), 8)):
			l2[i-4] = float(new_value[i])
		
		$MeshInstance.material_override.set_shader_param("eyelash_lengths_1", Plane(l1[0], l1[1], l1[2], l1[3]))
		$MeshInstance.material_override.set_shader_param("eyelash_lengths_2", Plane(l2[0], l2[1], l2[2], l2[3]))
	
func set_eyelash_angle(new_value: int) -> void:
	eyelash_angle = new_value
	if $MeshInstance.material_override:
		var angle_rad: float = (float(new_value) / 64.0) * PI
		$MeshInstance.material_override.set_shader_param("eyelash_angle_rad", angle_rad)

func set_eyelash_spacing(new_value: int) -> void:
	eyelash_spacing = new_value
	if $MeshInstance.material_override:
		$MeshInstance.material_override.set_shader_param("eyelash_spacing_norm", float(new_value) / 100.0)

func set_eyelash_color(new_value: int) -> void:
	eyelash_color = new_value
	if $MeshInstance.material_override:
		$MeshInstance.material_override.set_shader_param("eyelash_color_index", new_value)

func set_fuzz_amount(new_value: int) -> void:
	fuzz_amount = new_value
	$MeshInstance.material_override.set_shader_param("fuzz_amount", new_value)
	
func set_outline(new_value: int) -> void:
	outline = new_value
	if $MeshInstance.material_override:
		$MeshInstance.material_override.set_shader_param("outline", new_value)
		_update_visibility_params()

func set_color_index(new_value: int) -> void:
	color_index = new_value
	$MeshInstance.material_override.set_shader_param("color_index", new_value)
	
func set_outline_color_index(new_value: int) -> void:
	$MeshInstance.material_override.set_shader_param("outline_color_index", new_value)
	outline_color_index = new_value
	
func set_z_add(new_value: float) -> void:
	z_add = new_value
	$MeshInstance.material_override.set_shader_param("z_add", new_value)

func set_texture_size(new_value: Vector2) -> void:
	texture_size = new_value
	_update_shader_texture_params()

func set_texture(new_value):
#func set_texture(new_value: Texture) -> void:
	texture = new_value
	_update_shader_texture_params()

func _update_shader_texture_params() -> void:
	if not is_inside_tree() or $MeshInstance.material_override == null:
		return

	if texture != null:
		var raw_texture_size: Vector2 = texture.get_size()

		if texture is AtlasTexture:
			var atlas_tex: AtlasTexture = texture as AtlasTexture
			var rect: Rect2 = atlas_tex.region
			raw_texture_size = rect.size

			$MeshInstance.material_override.set_shader_param("ball_texture", atlas_tex.atlas)
			$MeshInstance.material_override.set_shader_param("is_atlas", true)
			# Pass rect as Plane (x,y,w,h) to ensure it maps to vec4 correctly in shader
			$MeshInstance.material_override.set_shader_param("atlas_rect", Plane(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
			$MeshInstance.material_override.set_shader_param("atlas_size", atlas_tex.atlas.get_size())
		else:
			$MeshInstance.material_override.set_shader_param("ball_texture", texture)
			$MeshInstance.material_override.set_shader_param("is_atlas", false)

		var eff_texture_size: Vector2 = texture_size if (texture_size != Vector2.ZERO and !tile_texture) else raw_texture_size

		# print("Declared size from [Texture List]:", texture_size)
		# print("Actual image size:", raw_texture_size)
		# print("Effective texture_size passed to shader:", eff_texture_size)
		# print("Texture resized? ", eff_texture_size != raw_texture_size)
		
		$MeshInstance.material_override.set_shader_param("texture_size", eff_texture_size)
		$MeshInstance.material_override.set_shader_param("texture_size_raw", raw_texture_size)
		$MeshInstance.material_override.set_shader_param("has_texture", true)
	else:
		$MeshInstance.material_override.set_shader_param("ball_texture", null)
		$MeshInstance.material_override.set_shader_param("has_texture", false)
		$MeshInstance.material_override.set_shader_param("is_atlas", false)

func set_palette(new_value):
	if new_value != null:
		palette = new_value
		$MeshInstance.material_override.set_shader_param("palette", new_value)
	else:
		palette = DEFAULT_PALETTE
		$MeshInstance.material_override.set_shader_param("palette", DEFAULT_PALETTE)

# func set_species(new_value: int) -> void:
# 	species = new_value
# 	if $MeshInstance.material_override != null:
# 		if species == 3:
# 			# For Babyz species, use the Babyz palette and enable quantization
# 			$MeshInstance.material_override.set_shader_param("palette", BABYZ_PALETTE)
# 			$MeshInstance.material_override.set_shader_param("should_quantize", true)
# 			$MeshInstance.material_override.set_shader_param("palette_size", 256)
# 		else:
# 			# For other species, use the default palette and disable quantization
# 			$MeshInstance.material_override.set_shader_param("palette", DEFAULT_PALETTE)
# 			$MeshInstance.material_override.set_shader_param("should_quantize", false)
# 			$MeshInstance.material_override.set_shader_param("palette_size", 256)

func set_species(new_value: int, is_babyz_mode: bool = false) -> void:
	species = new_value
	if $MeshInstance.material_override != null:
		$MeshInstance.material_override.set_shader_param("is_babyz_mode", is_babyz_mode)
		
		if is_babyz_mode:
			$MeshInstance.material_override.set_shader_param("palette", BABYZ_PALETTE)
		else:
			$MeshInstance.material_override.set_shader_param("palette", DEFAULT_PALETTE)
		
		$MeshInstance.material_override.set_shader_param("palette_size", 256)

func set_transparent_color(new_value) -> void:
	transparent_color = new_value
	$MeshInstance.material_override.set_shader_param("transparent_index", new_value)

func set_transparency(new_value: bool) -> void:
	transparency_on = new_value
	$MeshInstance.material_override.set_shader_param("transparency_on", new_value)

func set_pet_center(new_value: Vector3) -> void:
	pet_center = new_value
	$MeshInstance.material_override.set_shader_param("z_center_pet_world", new_value)

func _on_Area_mouse_entered() -> void:
	is_over = true
	turn_on_highlight()
	emit_signal("ball_mouse_enter", {ball_no = ball_no})

func apply_outline_state(state: int) -> void:
	current_outline_state = state
	var highlight_idx: int = -1 # -1 hides the extra ring

	match state:
		OutlineState.HOVER:
			highlight_idx = 0  # WHITE
		OutlineState.ACTIVE_SELECTED:
			highlight_idx = 2  # GREEN
		OutlineState.LINEZ_START:
			highlight_idx = 1  # RED
		OutlineState.LINEZ_TARGET:
			highlight_idx = 4  # BLUE
		OutlineState.MODIFIED:
			highlight_idx = 248 # GRAY
		OutlineState.PIVOT:
			highlight_idx = 1 # RED
		OutlineState.NONE:
			highlight_idx = -1

	if $MeshInstance.material_override:
		$MeshInstance.material_override.set_shader_param("highlight_color_index", highlight_idx)
	
	_update_visibility_params()

func _update_visibility_params() -> void:
	if not $MeshInstance.material_override: return
	
	var is_currently_invisible: bool = (outline == -4)

	$MeshInstance.material_override.set_shader_param("hide_fill", is_currently_invisible)
	$MeshInstance.material_override.set_shader_param("hide_outline", is_currently_invisible)

func turn_on_highlight() -> void:
	apply_outline_state(OutlineState.HOVER)
	
func turn_off_highlight() -> void:
	if get_tree() == null or get_tree().root == null:
		apply_outline_state(OutlineState.NONE)
		return

	var pet_container: Node = get_tree().root.get_node_or_null("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	if pet_container and pet_container.has_method("get_visual_state_for_ball"):
		var new_state: int = pet_container.get_visual_state_for_ball(self)
		apply_outline_state(new_state)
	else:
		apply_outline_state(OutlineState.NONE)

func get_outline_state() -> int:
	return current_outline_state

func _on_Area_mouse_exited() -> void:
	is_over = false
	turn_off_highlight()
	emit_signal("ball_mouse_exit", ball_no)
	
func selected() -> void:
		emit_signal("ball_selected", ball_no, Section.Section.BALL)

func _on_Area_input_event(camera: Node, event: InputEvent, click_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.doubleclick and select_mode_active:
		selected()

func _input(event: InputEvent) -> void:
	var handled: bool = false
	if event is InputEventKey and event.pressed and is_over and select_mode_active:
		if event.scancode == KEY_SPACE and event.control:
			return
		if (event.scancode == KEY_B or event.scancode == KEY_Z) and not event.alt and not event.control:
			get_tree().set_input_as_handled()
			emit_signal("ball_selected", ball_no, Section.Section.BALL)
		elif (event.scancode == KEY_M or event.scancode == KEY_X) and not event.alt and not event.control:
			get_tree().set_input_as_handled()
			emit_signal("ball_selected", ball_no, Section.Section.MOVE)
		elif (event.scancode == KEY_P or event.scancode == KEY_C) and not event.alt and not event.control:
			get_tree().set_input_as_handled()
			emit_signal("ball_selected", ball_no, Section.Section.PROJECT)
		elif (event.scancode == KEY_L or event.scancode == KEY_V) and not event.alt and not event.control:
			get_tree().set_input_as_handled()
			emit_signal("ball_selected", ball_no, Section.Section.LINE)
		elif event.scancode == KEY_DELETE:
			get_tree().set_input_as_handled()
			emit_signal("ball_deleted", ball_no)

func flash() -> void:
	timer_count = 0
	if !is_over:
		turn_on_highlight()
		$FlashTimer.start()

func _on_FlashTimer_timeout() -> void:
	timer_count += 1
	if !is_over:
		if timer_count % 2 == 1:
			turn_off_highlight()
		else:
			turn_on_highlight()
		if timer_count > 4:
			$FlashTimer.stop()
