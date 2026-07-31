extends Spatial
## Paintball.gd
## Represents paintballz parented to ballz
## This script manages the visual properties of a paintball from parsed LNZ document data
## It uses a shader to project the paintball onto the surface of its base ball

export var base_ball_no           = 0
export var base_ball_position     = Vector3.ZERO       setget set_base_ball_position
export var base_ball_size         = 10                 setget set_base_ball_size

export var ball_size              = 10                 setget set_ball_size
export var fuzz_amount            = 0                  setget set_fuzz_amount
export var outline                = -1                 setget set_outline
export var group                  = -1                 setget set_group
export var color_index            = -1                 setget set_color_index
export var outline_color_index    = 0                  setget set_outline_color_index
export var z_add                  = 0.0                setget set_z_add

export var ball_no                = -1
export var visible_override       = true               setget set_visible
export var omitted                = false

var select_mode_active            = false

export var tile_texture           = true               setget set_tile_texture
export var texture                : Texture            setget set_texture

export var texture_size           = Vector2(256, 256)  setget set_texture_size
export var texture_size_raw       = Vector2(256, 256)

export var transparent_color      = 0                  setget set_transparent_color
export var transparency_on        = true               setget set_transparency

export var render_flat_colors     = false              setget set_render_flat_colors

export var species                = 0                  setget set_species

export var palette                = LnzLiveUtils.DEFAULT_PALETTE setget set_palette
const DEFAULT_PALETTE             = LnzLiveUtils.DEFAULT_PALETTE
const BABYZ_PALETTE               = LnzLiveUtils.BABYZ_PALETTE

export var petz_palette           = DEFAULT_PALETTE

export var surface_normal         = Vector3.FORWARD setget set_surface_normal

enum OutlineState {
	NONE,
	ACTIVE_SELECTED,
	LINEZ_START,
	LINEZ_TARGET,
	HOVER,
	MODIFIED,
	PIVOT
}

var current_outline_state         = OutlineState.NONE  setget , get_outline_state

var old_outline                   = outline
var old_outline_color             = outline_color_index

var is_over                       = false

signal paintball_mouse_enter(paintball_info)
signal paintball_mouse_exit()

# only used if iris:
signal ball_mouse_enter(ball_info)
signal ball_mouse_exit(ball_no)
signal ball_selected(ball_no, section)
signal delete_ball(ball_no)

func _ready():
	old_outline = outline
	old_outline_color = outline_color_index

	# Duplicate material so each ball can have unique shader params
	$MeshInstance.material_override = $MeshInstance.material_override.duplicate()

	# Set the initial species, which will configure the shader
	set_species(species)

	# Set initial shader parameters
	$MeshInstance.material_override.set_shader_param("transparency_on", transparency_on)
	$MeshInstance.material_override.set_shader_param("tile_texture", tile_texture)
	$MeshInstance.material_override.set_shader_param("render_flat_colors", render_flat_colors)

	# Pass the original texture to the shader
	set_texture(texture)

	# Pass the default Petz palette to the shader
	$MeshInstance.material_override.set_shader_param("petz_palette", DEFAULT_PALETTE)

func set_hidden(is_hidden):
	$MeshInstance.visible = not is_hidden

func _on_palette_change(new_palette):
	set_palette(new_palette)
	
func set_visible(new_value):
	visible_override = new_value
	$Area/CollisionShape.disabled = not new_value
	$Area/CollisionShape.visible  = new_value
	$MeshInstance.visible         = new_value

func set_z_add(new_value):
	z_add = new_value
	$MeshInstance.material_override.set_shader_param("z_add", new_value)

func set_surface_normal(new_normal: Vector3):
	surface_normal = new_normal
	if is_inside_tree() and $MeshInstance.material_override:
		$MeshInstance.material_override.set_shader_param("pb_normal", surface_normal)

func set_tile_texture(enabled):
	tile_texture = enabled
	$MeshInstance.material_override = $MeshInstance.material_override.duplicate()
	$MeshInstance.material_override.set_shader_param("tile_texture", tile_texture)

func set_render_flat_colors(new_value):
	render_flat_colors = new_value
	if has_node("MeshInstance") and $MeshInstance.material_override != null:
		$MeshInstance.material_override.set_shader_param("render_flat_colors", new_value)

func set_texture_size(new_value):
	texture_size = new_value
	_update_shader_texture_params()

func set_texture(new_value):
	texture = new_value
	_update_shader_texture_params()

func _update_shader_texture_params():
	if not is_inside_tree() or $MeshInstance.material_override == null:
		return

	if texture != null:
		var raw_texture_size = texture.get_size()

		if texture is AtlasTexture:
			var atlas_tex = texture as AtlasTexture
			var rect = atlas_tex.region
			raw_texture_size = rect.size

			$MeshInstance.material_override.set_shader_param("ball_texture", atlas_tex.atlas)
			$MeshInstance.material_override.set_shader_param("is_atlas", true)
			$MeshInstance.material_override.set_shader_param("atlas_rect", Plane(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
			$MeshInstance.material_override.set_shader_param("atlas_size", atlas_tex.atlas.get_size())
		else:
			$MeshInstance.material_override.set_shader_param("ball_texture", texture)
			$MeshInstance.material_override.set_shader_param("is_atlas", false)

		var eff_texture_size = texture_size if (texture_size != Vector2.ZERO and !tile_texture) else raw_texture_size

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

func set_transparent_color(new_value):
	transparent_color = new_value
	$MeshInstance.material_override.set_shader_param("transparent_index", new_value)

func set_transparency(new_value):
	transparency_on = new_value
	$MeshInstance.material_override.set_shader_param("transparency_on", new_value)

func set_base_ball_position(new_value):
	base_ball_position = new_value
	$MeshInstance.material_override.set_shader_param("base_world_position", new_value)

func set_base_ball_size(new_value):
	base_ball_size = new_value
	$MeshInstance.material_override.set_shader_param("base_ball_size", new_value)

func set_ball_size(new_value):
	ball_size = new_value
	$MeshInstance.material_override.set_shader_param("ball_size", new_value)
	var a = ball_size * 0.25
	$Area/CollisionShape.shape.radius = a * 0.008
#	scale = Vector3(a,a,a)
	
func set_fuzz_amount(new_value):
	fuzz_amount = new_value
	$MeshInstance.material_override.set_shader_param("fuzz_amount", new_value)
	
func set_outline(new_value):
	outline = new_value
	$MeshInstance.material_override.set_shader_param("outline", new_value)
	
func set_group(new_value):
	group = new_value

func set_color_index(new_value):
	color_index = new_value
	$MeshInstance.material_override.set_shader_param("color_index", new_value)
	
func set_outline_color_index(new_value):
	outline_color_index = new_value
	$MeshInstance.material_override.set_shader_param("outline_color_index", new_value)

func selected():
	if ball_no != -1:
		emit_signal("ball_selected", ball_no, Section.Section.BALL)

func _on_Area_mouse_entered():
	is_over = true
	turn_on_highlight()

	# old_outline = outline
	# old_outline_color = outline_color_index
	# set_outline(3)
	# set_outline_color_index(0)
	
	if ball_no != -1:
		emit_signal("ball_mouse_enter", {ball_no = ball_no})
	else:
		emit_signal("paintball_mouse_enter", {base_ball_no = base_ball_no})

func apply_outline_state(state: int):
	if current_outline_state == OutlineState.NONE:
		old_outline = outline
		old_outline_color = outline_color_index

	current_outline_state = state

	match state:
		OutlineState.HOVER:
			set_outline(3)
			set_outline_color_index(0)  # WHITE
		OutlineState.ACTIVE_SELECTED:
			set_outline(3)
			set_outline_color_index(2)  # GREEN
		OutlineState.LINEZ_START:
			set_outline(3)
			set_outline_color_index(1)  # RED
		OutlineState.LINEZ_TARGET:
			set_outline(3)
			set_outline_color_index(4)  # BLUE
		OutlineState.MODIFIED:
			set_outline(3)
			set_outline_color_index(248) # GRAY
		OutlineState.PIVOT:
			set_outline(3)
			set_outline_color_index(1) # RED
		OutlineState.NONE:
			set_outline(old_outline)
			set_outline_color_index(old_outline_color)

func turn_on_highlight():
	apply_outline_state(OutlineState.HOVER)
	
func turn_off_highlight():
	if get_tree() == null or get_tree().root == null:
		apply_outline_state(OutlineState.NONE)
		return

	var pet_container = get_tree().root.get_node_or_null("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	if pet_container and pet_container.has_method("get_visual_state_for_ball"):
		var new_state = pet_container.get_visual_state_for_ball(self)
		apply_outline_state(new_state)
	else:
		apply_outline_state(OutlineState.NONE)

func get_outline_state():
	return current_outline_state

func _on_Area_mouse_exited():
	is_over = false
	turn_off_highlight()

	if ball_no != -1:
		emit_signal("ball_mouse_exit", ball_no)
	else:
		emit_signal("paintball_mouse_exit")

	# set_outline(old_outline)
	# set_outline_color_index(old_outline_color)
	# if ball_no != -1:
	# 	emit_signal("ball_mouse_exit", ball_no)
	# else:
	# 	emit_signal("paintball_mouse_exit")
	# is_over = false
	
func _input(event):
	if event is InputEventKey and event.pressed and is_over and select_mode_active:
		if event.scancode == KEY_SPACE and event.control:
			return
			
		if (event.scancode == KEY_B or event.scancode == KEY_Z) and not event.alt and not event.control:
			get_tree().set_input_as_handled()
			if ball_no != -1:
				emit_signal("ball_selected", ball_no, Section.Section.BALL)
		elif (event.scancode == KEY_M or event.scancode == KEY_X) and not event.alt and not event.control:
			get_tree().set_input_as_handled()
			if ball_no != -1:
				emit_signal("ball_selected", ball_no, Section.Section.MOVE)
		elif (event.scancode == KEY_P or event.scancode == KEY_C) and not event.alt and not event.control:
			get_tree().set_input_as_handled()
			if ball_no != -1:
				emit_signal("ball_selected", ball_no, Section.Section.PROJECT)
		elif (event.scancode == KEY_L or event.scancode == KEY_V) and not event.alt and not event.control:
			get_tree().set_input_as_handled()
			if ball_no != -1:
				emit_signal("ball_selected", ball_no, Section.Section.LINE)
		elif event.scancode == KEY_DELETE:
			get_tree().set_input_as_handled()
			if ball_no != -1:
				emit_signal("delete_ball", ball_no)

var timer_count = 0

func flash():
	timer_count = 0
	if !is_over:
		turn_on_highlight()
		$FlashTimer.start()

func _on_FlashTimer_timeout():
	timer_count += 1
	if !is_over:
		if timer_count % 2 == 1:
			turn_off_highlight()
		else:
			turn_on_highlight()
		if timer_count > 4:
			$FlashTimer.stop()
