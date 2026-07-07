extends Spatial
## Line.gd
## Represents linez connecting ballz in the 3D Viewport
## This script manages the visual properties of a line from parsed LNZ document data
## The line is rendered as a simple quad mesh dynamically positioned and oriented
## in the shader based on the world positions of the two connected ballz

export var line_widths            = Vector2(10, 10)    setget set_line_width
export var fuzz_amount            = 0                  setget set_fuzz_amount
export var color_index            = 0                  setget set_color_index
export var l_color_index          = 0                  setget set_l_color_index
export var r_color_index          = 0                  setget set_r_color_index
export var ball_world_pos1        = Vector3.ZERO       setget set_ball_world_pos1
export var ball_world_pos2        = Vector3.ZERO       setget set_ball_world_pos2
export var texture: Texture                            setget set_texture
export var texture_size           = Vector2(256, 256)  setget set_texture_size
export var texture_size_raw       = Vector2.ZERO
export var transparent_color      = 0                  setget set_transparent_color
export var transparency_on        = true               setget set_transparency
export var full_outline           = 0                  setget set_full_outline
export var draw_order             = 0                  setget set_draw_order

export var render_flat_colors     = false              setget set_render_flat_colors

export var species                = 0                  setget set_species

export var palette                = LnzLiveUtils.DEFAULT_PALETTE setget set_palette
const DEFAULT_PALETTE             = LnzLiveUtils.DEFAULT_PALETTE
const BABYZ_PALETTE               = LnzLiveUtils.BABYZ_PALETTE

export var petz_palette           = DEFAULT_PALETTE

var timer_count: int = 0
var is_highlighted = false

func _ready():
	# Duplicate material so each ball can have unique shader params
	$MeshInstance.material_override = $MeshInstance.material_override.duplicate()

	# Set initial shader parameters
	$MeshInstance.material_override.set_shader_param("transparency_on", transparency_on)
	$MeshInstance.material_override.set_shader_param("render_flat_colors", render_flat_colors)

	# Pass the original texture to the shader
	set_texture(texture)

	# Pass the default Petz palette to the shader
	$MeshInstance.material_override.set_shader_param("petz_palette", DEFAULT_PALETTE)

func set_hidden(is_hidden):
	$MeshInstance.visible = not is_hidden

func update_palette_after_added(new_palette):
	call_deferred("set_palette", new_palette)
	#set_deferred("material_override", $MeshInstance.material_override.duplicate())
	#set_palette(new_palette)
	
func set_line_width(new_value):
	line_widths = new_value
	$MeshInstance.material_override.set_shader_param("line_width_in_pixels_start", new_value.x)
	$MeshInstance.material_override.set_shader_param("line_width_in_pixels_end", new_value.y)

func set_fuzz_amount(new_value):
	fuzz_amount = new_value
	$MeshInstance.material_override.set_shader_param("fuzz_amount", new_value)

func set_r_color_index(new_value):
	r_color_index = new_value
	$MeshInstance.material_override.set_shader_param("r_color_index", new_value)

func set_l_color_index(new_value):
	l_color_index = new_value
	$MeshInstance.material_override.set_shader_param("l_color_index", new_value)

func set_ball_world_pos1(new_value):
	ball_world_pos1 = new_value
	$MeshInstance.material_override.set_shader_param("ball_world_pos1", new_value)

func set_ball_world_pos2(new_value):
	ball_world_pos2 = new_value
	$MeshInstance.material_override.set_shader_param("ball_world_pos2", new_value)

func set_color_index(new_value):
	color_index = new_value
	$MeshInstance.material_override.set_shader_param("color_index", new_value)

func set_full_outline(new_value):
	full_outline = new_value
	if has_node("MeshInstance") and $MeshInstance.material_override != null:
		$MeshInstance.material_override.set_shader_param("full_outline", new_value)

func set_draw_order(new_value):
	draw_order = new_value
	if has_node("MeshInstance") and $MeshInstance.material_override != null:
		$MeshInstance.material_override.set_shader_param("draw_order", new_value)

func set_render_flat_colors(new_value):
	render_flat_colors = new_value
	if has_node("MeshInstance") and $MeshInstance.material_override != null:
		$MeshInstance.material_override.set_shader_param("render_flat_colors", new_value)

func set_texture_size(new_value):
	texture_size = new_value

func set_texture(new_value):
	texture = new_value
	
	if $MeshInstance.material_override != null:
		if new_value != null:
			var raw_texture_size = new_value.get_size()

			if new_value is AtlasTexture:
				var atlas_tex = new_value as AtlasTexture
				var rect = atlas_tex.region
				raw_texture_size = rect.size

				$MeshInstance.material_override.set_shader_param("line_texture", atlas_tex.atlas)
				$MeshInstance.material_override.set_shader_param("is_atlas", true)
				$MeshInstance.material_override.set_shader_param("atlas_rect", Plane(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
				$MeshInstance.material_override.set_shader_param("atlas_size", atlas_tex.atlas.get_size())
			else:
				$MeshInstance.material_override.set_shader_param("line_texture", new_value)
				$MeshInstance.material_override.set_shader_param("is_atlas", false)

			var eff_texture_size = texture_size if texture_size != Vector2.ZERO else raw_texture_size

			# print("Declared size from [Texture List]:", texture_size)
			# print("Actual image size:", raw_texture_size)
			# print("Effective texture_size passed to shader:", eff_texture_size)
			# print("Texture resized? ", eff_texture_size != raw_texture_size)
			
			$MeshInstance.material_override.set_shader_param("texture_size", eff_texture_size)
			$MeshInstance.material_override.set_shader_param("texture_size_raw", raw_texture_size)
			$MeshInstance.material_override.set_shader_param("has_texture", true)
		else:
			$MeshInstance.material_override.set_shader_param("line_texture", null)
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

func flash() -> void:
	if is_highlighted:
		return
	timer_count = 0
	is_highlighted = true
	$MeshInstance.material_override.set_shader_param("highlight", true)
	$FlashTimer.start()

func _on_FlashTimer_timeout() -> void:
	timer_count += 1
	if is_highlighted:
		if timer_count % 2 == 1:
			$MeshInstance.material_override.set_shader_param("highlight", false)
		else:
			$MeshInstance.material_override.set_shader_param("highlight", true)
		if timer_count > 4:
			$FlashTimer.stop()
			is_highlighted = false
			$MeshInstance.material_override.set_shader_param("highlight", false)