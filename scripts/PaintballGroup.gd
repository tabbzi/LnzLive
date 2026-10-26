## PaintballGroup.gd
## Batched paintball mesh builder to replace Paintball.gd when stored in paintball_map[key]
## Packs per-paintball state into vertex attributes via ArrayMesh.add_surface_from_arrays()
## Modeled after approach designed by Ziv for OpenPetz (thank you!)

extends Spatial

signal paintball_mouse_enter(paintball_info)
signal paintball_mouse_exit()

export var base_ball_no: int = 0
export var base_ball_position: Vector3 = Vector3.ZERO setget set_base_ball_position
export var base_ball_size: int = 10 setget set_base_ball_size
export var visible_override: bool = true setget set_visible
export var omitted: bool = false
export var paint_layer_id: int = -1
export var species: int = 0 setget set_species
export var is_babyz_mode: bool = false
export var palette = LnzLiveUtils.DEFAULT_PALETTE setget set_palette
export var transparency_on: bool = true setget set_transparency
export var render_flat_colors: bool = false setget set_render_flat_colors
export var tile_texture: bool = true setget set_tile_texture

var entries: Array = []
var _surface_materials: Array = []

const DEFAULT_PALETTE = LnzLiveUtils.DEFAULT_PALETTE
const BABYZ_PALETTE = LnzLiveUtils.BABYZ_PALETTE

func _exit_tree() -> void:
	entries.clear()
	_surface_materials.clear()

func _ready():
	if has_node("MeshInstance") and is_instance_valid(get_node("MeshInstance")):
		set_species(species, is_babyz_mode)
		if $MeshInstance.material_override:
			$MeshInstance.material_override.set_shader_param("petz_palette", DEFAULT_PALETTE)
			$MeshInstance.material_override.set_shader_param("transparency_on", transparency_on)
			$MeshInstance.material_override.set_shader_param("tile_texture", tile_texture)
			$MeshInstance.material_override.set_shader_param("render_flat_colors", render_flat_colors)

func build_mesh(entries_list: Array) -> void:
	entries = entries_list.duplicate()

	if not has_node("MeshInstance"):
		return

	var mesh_instance = get_node("MeshInstance") as MeshInstance
	if not is_instance_valid(mesh_instance):
		return

	_surface_materials.clear()
	if entries.empty():
		mesh_instance.mesh = null
		return

	# Group entries into buckets by texture key
	var buckets: Dictionary = {}
	for entry in entries:
		var key = null
		if entry.has_texture and is_instance_valid(entry.texture):
			key = [entry.texture, entry.texture_size]
		if not key in buckets:
			buckets[key] = []
		buckets[key].append(entry)

	# Build one surface per texture bucket
	var mesh = ArrayMesh.new()
	var surface_idx: int = 0

	for key in buckets:
		var bucket_entries: Array = buckets[key]
		if bucket_entries.empty():
			continue
		_build_bucket_surface(mesh, bucket_entries)

		var mat = preload("res://shaders/paintball_group.tres").duplicate()
		_configure_surface_material(mat, key)
		mesh.surface_set_material(surface_idx, mat)
		_surface_materials.append(mat)
		surface_idx += 1

	mesh_instance.mesh = mesh


func _build_bucket_surface(mesh: ArrayMesh, bucket_entries: Array) -> void:
	var count: int = bucket_entries.size()
	var vert_count: int = count * 4
	var idx_count: int = count * 6

	var verts := PoolVector3Array()
	var normals := PoolVector3Array()
	var colors := PoolColorArray()
	var uvs := PoolVector2Array()
	var uvs2 := PoolVector2Array()
	var indices := PoolIntArray()

	verts.resize(vert_count)
	normals.resize(vert_count)
	colors.resize(vert_count)
	uvs.resize(vert_count)
	uvs2.resize(vert_count)
	indices.resize(idx_count)

	for i in range(count):
		var entry = bucket_entries[i]
		var v_base: int = i * 4
		var idx_base: int = i * 6

		var packed_color := Color(
			float(entry.color_index + 1) / 255.0,
			float(entry.outline_color_index + 1) / 255.0,
			float(entry.outline + 4) / 255.0,
			float(entry.fuzz_amount) / 255.0
		)
		var has_tex: int = 1 if entry.has_texture else 0
		var tile_tex: int = 1 if entry.tile_texture else 0
		var hi_flag: int = 1 if entry.highlight else 0
		var flags: float = float(has_tex + (tile_tex * 2) + (hi_flag * 4))
		var mag_x: float = 1.0 + float(entry.transparent_color)
		var mag_y: float = 1.0 + flags
		var uv2_val := Vector2(float(entry.ball_size), entry.z_add)
		var origin: Vector3 = entry.local_origin
		var normal: Vector3 = entry.pb_normal

		verts[v_base] = origin
		verts[v_base + 1] = origin
		verts[v_base + 2] = origin
		verts[v_base + 3] = origin

		normals[v_base] = normal
		normals[v_base + 1] = normal
		normals[v_base + 2] = normal
		normals[v_base + 3] = normal

		colors[v_base] = packed_color
		colors[v_base + 1] = packed_color
		colors[v_base + 2] = packed_color
		colors[v_base + 3] = packed_color

		uvs[v_base] = Vector2(-mag_x, -mag_y)
		uvs[v_base + 1] = Vector2(-mag_x, mag_y)
		uvs[v_base + 2] = Vector2(mag_x, mag_y)
		uvs[v_base + 3] = Vector2(mag_x, -mag_y)

		uvs2[v_base] = uv2_val
		uvs2[v_base + 1] = uv2_val
		uvs2[v_base + 2] = uv2_val
		uvs2[v_base + 3] = uv2_val

		indices[idx_base] = v_base
		indices[idx_base + 1] = v_base + 1
		indices[idx_base + 2] = v_base + 2
		indices[idx_base + 3] = v_base
		indices[idx_base + 4] = v_base + 3
		indices[idx_base + 5] = v_base + 2

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _configure_surface_material(mat: ShaderMaterial, key) -> void:
	mat.set_shader_param("petz_palette", DEFAULT_PALETTE)
	mat.set_shader_param("is_babyz_mode", is_babyz_mode)
	mat.set_shader_param("palette_size", 256)
	mat.set_shader_param("palette", palette if palette != null else (BABYZ_PALETTE if is_babyz_mode else DEFAULT_PALETTE))
	mat.set_shader_param("transparency_on", transparency_on)
	mat.set_shader_param("render_flat_colors", render_flat_colors)
	mat.set_shader_param("base_world_position", base_ball_position)
	mat.set_shader_param("base_ball_size", base_ball_size)

	if key != null:
		var tex_info = key as Array
		var tex: Texture = tex_info[0] as Texture
		var tex_size: Vector2 = tex_info[1] as Vector2
		mat.set_shader_param("ball_texture", tex)
		if tex is AtlasTexture:
			var atlas_tex: AtlasTexture = tex
			var rect: Rect2 = atlas_tex.region
			mat.set_shader_param("is_atlas", true)
			mat.set_shader_param("atlas_rect", Plane(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
			mat.set_shader_param("atlas_size", atlas_tex.atlas.get_size())
			var raw_size: Vector2 = rect.size
			var eff_size: Vector2 = tex_size if (tex_size != Vector2.ZERO and !tile_texture) else raw_size
			mat.set_shader_param("texture_size", eff_size)
			mat.set_shader_param("texture_size_raw", raw_size)
		else:
			var raw_size: Vector2 = tex.get_size()
			var eff_size: Vector2 = tex_size if (tex_size != Vector2.ZERO and !tile_texture) else raw_size
			mat.set_shader_param("is_atlas", false)
			mat.set_shader_param("texture_size", eff_size)
			mat.set_shader_param("texture_size_raw", raw_size)
	else:
		mat.set_shader_param("ball_texture", null)
		mat.set_shader_param("is_atlas", false)
func set_hidden(is_hidden: bool) -> void:
	if has_node("MeshInstance") and is_instance_valid(get_node("MeshInstance")):
		$MeshInstance.visible = not is_hidden

func set_visible(new_value: bool) -> void:
	visible_override = new_value
	if has_node("MeshInstance") and is_instance_valid(get_node("MeshInstance")):
		$MeshInstance.visible = new_value

func set_base_ball_position(new_value: Vector3) -> void:
	base_ball_position = new_value
	for mat in _surface_materials:
		if is_instance_valid(mat):
			mat.set_shader_param("base_world_position", new_value)

func set_base_ball_size(new_value: int) -> void:
	base_ball_size = new_value
	for mat in _surface_materials:
		if is_instance_valid(mat):
			mat.set_shader_param("base_ball_size", new_value)

func set_palette(new_value) -> void:
	if new_value != null:
		palette = new_value
		for mat in _surface_materials:
			if is_instance_valid(mat):
				mat.set_shader_param("palette", new_value)
	else:
		palette = DEFAULT_PALETTE
		for mat in _surface_materials:
			if is_instance_valid(mat):
				mat.set_shader_param("palette", DEFAULT_PALETTE)

func set_species(new_value: int, is_babyz_flag: bool = false) -> void:
	species = new_value
	is_babyz_mode = is_babyz_flag
	for mat in _surface_materials:
		if is_instance_valid(mat):
			mat.set_shader_param("is_babyz_mode", is_babyz_flag)
			if is_babyz_flag:
				mat.set_shader_param("palette", BABYZ_PALETTE)
			else:
				mat.set_shader_param("palette", DEFAULT_PALETTE)
			mat.set_shader_param("palette_size", 256)

func set_transparency(new_value: bool) -> void:
	transparency_on = new_value
	for mat in _surface_materials:
		if is_instance_valid(mat):
			mat.set_shader_param("transparency_on", new_value)

func set_render_flat_colors(new_value: bool) -> void:
	render_flat_colors = new_value
	for mat in _surface_materials:
		if is_instance_valid(mat):
			mat.set_shader_param("render_flat_colors", new_value)

func set_tile_texture(enabled: bool) -> void:
	tile_texture = enabled
	for mat in _surface_materials:
		if is_instance_valid(mat):
			mat.set_shader_param("tile_texture", enabled)

func update_base_ball_size_and_origins(new_size: int, new_entries: Array) -> void:
	if new_size != base_ball_size:
		base_ball_size = new_size
		entries = new_entries.duplicate()
		if has_node("MeshInstance") and is_instance_valid(get_node("MeshInstance")):
			build_mesh(entries)

func get_paintball_count() -> int:
	return entries.size()
