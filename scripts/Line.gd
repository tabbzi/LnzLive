extends Spatial

export var line_widths = Vector2(10, 10) setget set_line_width
export var fuzz_amount = 0 setget set_fuzz_amount
export var color_index = 0 setget set_color_index
export var l_color_index = 0 setget set_l_color_index
export var r_color_index = 0 setget set_r_color_index
export var ball_world_pos1 = Vector3.ZERO setget set_ball_world_pos1
export var ball_world_pos2 = Vector3.ZERO setget set_ball_world_pos2
export var texture: Texture setget set_texture
export var transparent_color = 0 setget set_transparent_color
export var transparency_on = true setget set_transparency

var petz_palette = preload("res://resources/textures/petzpalette.png")
#var petz_palette = preload("res://resources/palettes/petz_palette.png")
var babyz_palette = preload("res://resources/palettes/babyz_palette.png")

func _ready():
	$MeshInstance.material_override.set_shader_param("palette", petz_palette)
	$MeshInstance.material_override.set_shader_param("transparency_on", transparency_on)

func _on_palette_change(new_palette):
	set_palette(new_palette)

func set_palette(new_palette):
	var new_material = $MeshInstance.material_override.duplicate()

	if new_palette == "PETZ":
		new_material.set_shader_param("palette", petz_palette)
		#print("Set Petz palette")
	elif new_palette == "BABYZ":
		new_material.set_shader_param("palette", babyz_palette)
		#print("Set Babyz palette")
	else:
		new_material.set_shader_param("palette", petz_palette)
		#print("Set default Petz palette")
	
	new_material.set_shader_param("transparency_on", transparency_on)

	$MeshInstance.material_override = new_material


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

func set_texture(new_value):
	texture = new_value
	$MeshInstance.material_override.set_shader_param("line_texture", new_value)
	$MeshInstance.material_override.set_shader_param("has_texture", true)
	if new_value != null:
		$MeshInstance.material_override.set_shader_param("texture_size", new_value.get_size())
	else:
		$MeshInstance.material_override.set_shader_param("has_texture", false)

func set_transparent_color(new_value):
	transparent_color = new_value
	$MeshInstance.material_override.set_shader_param("transparent_index", new_value)

func set_transparency(new_value):
	transparency_on = new_value
	$MeshInstance.material_override.set_shader_param("transparency_on", new_value)
