extends Reference
## texture_cache.gd
## Stateless texture caching manager for dog_generator.gd that handles loading and caching of textures

var _texture_cache = {}
var _atlas_manifest = {}
var _atlas_manifest_normalized = {}
var _atlas_textures = {}
var _perf_texture_load_time = 0
var _path_cache: Dictionary = {}
var _paths_cached: bool = false


func init(atlas_manifest_data):
	_atlas_manifest = atlas_manifest_data if atlas_manifest_data else {}
	_build_atlas_manifest_lookup()


func _build_atlas_manifest_lookup():
	_atlas_manifest_normalized.clear()
	for key in _atlas_manifest.keys():
		var lower_key = str(key).to_lower()
		if not _atlas_manifest_normalized.has(lower_key):
			_atlas_manifest_normalized[lower_key] = _atlas_manifest[key]


func load_texture(texture_filename, preloader, is_babyz_mode: bool, custom_lnz_palette: Array = []) -> Texture:
	var t_start = OS.get_ticks_msec()
	if _texture_cache.has(texture_filename):
		_perf_texture_load_time += (OS.get_ticks_msec() - t_start)
		return _texture_cache[texture_filename]

	var texture = null
	var base_name = texture_filename.get_basename()
	var extension = texture_filename.get_extension()

	# Check atlas manifest first
	var atlas_key = texture_filename.get_basename()

	var manifest_entry = null
	var lookup_key = atlas_key.to_lower()
	if _atlas_manifest_normalized.has(lookup_key):
		manifest_entry = _atlas_manifest_normalized[lookup_key]

	if manifest_entry:
		var atlas_file = manifest_entry["babyz_atlas"] if is_babyz_mode else manifest_entry["petz_atlas"]
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

	if texture == null:
		if not _paths_cached:
			_paths_cached = true
			
			_build_texture_path_cache("user://resources/textures")
			_build_texture_path_cache("res://resources/textures")
			
		var loaded_path = _path_cache.get(texture_filename.to_lower(), "")
		if loaded_path != "":
			var raw_bmp_data = LnzLiveUtils.load_raw_8bit_bmp(loaded_path, is_babyz_mode, false, custom_lnz_palette)
			if raw_bmp_data.has("data"):
				var w = raw_bmp_data["w"]
				var h = raw_bmp_data["h"]
				var data = raw_bmp_data["data"]
				var img = Image.new()
				img.create_from_data(w, h, false, Image.FORMAT_R8, data)
				texture = ImageTexture.new()
				texture.create_from_image(img, 0)
				print("[INFO] dog_generator: CPU-baked exact index map from binary: " + loaded_path)
			
		# FALLBACK: native loader for PNGs, failed BMPs, or virtual res:// files
		if texture == null:
			var user_fallback = "user://resources/textures".plus_file(texture_filename)
			var res_fallback = "res://resources/textures".plus_file(texture_filename)
			
			if ResourceLoader.exists(user_fallback):
				texture = ResourceLoader.load(user_fallback)
			elif ResourceLoader.exists(res_fallback):
				texture = ResourceLoader.load(res_fallback)

	# PRELOADER FALLBACK
	if texture == null and preloader != null:
		if preloader.has_resource(texture_filename.to_lower()):
			texture = preloader.get_resource(texture_filename.to_lower())

	_texture_cache[texture_filename] = texture
	_perf_texture_load_time += (OS.get_ticks_msec() - t_start)

	return texture


func load_texture_from_list(texture_id: int, texture_list: Array, preloader: ResourcePreloader, custom_lnz_palette: Array = [], is_babyz_mode: bool = false) -> Texture:
	if texture_id < 0 or texture_id >= texture_list.size():
		return null

	var tex_info = texture_list[texture_id]
	if tex_info.has("filename"):
		var texture_filename = tex_info.filename
		return load_texture(texture_filename, preloader, is_babyz_mode, custom_lnz_palette)
	return null


func clear_texture_cache_for(filename: String) -> void:
	var exact = filename
	var lower = filename.to_lower()

	if _texture_cache.has(exact):
		_texture_cache.erase(exact)
	if _texture_cache.has(lower):
		_texture_cache.erase(lower)

	# Force a path lookup on the next request
	var base_key = lower.get_file().trim_suffix(".import")
	if _path_cache.has(base_key):
		_path_cache.erase(base_key)


func clear_texture_cache():
	_texture_cache.clear()
	_path_cache.clear()
	_paths_cached = false
	print("[STATUS] dog_generator: clear_texture_cache: texture cache cleared for model refresh")


func _build_texture_path_cache(base_dir: String, depth: int = 0) -> void:
	if depth > 3: return
	var dir = Directory.new()
	if dir.open(base_dir) != OK: return
	
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = base_dir.plus_file(file_name)
		if dir.current_is_dir():
			_build_texture_path_cache(full_path, depth + 1)
		else:
			var clean_filename = file_name.to_lower().trim_suffix(".import")
			if not _path_cache.has(clean_filename):
				_path_cache[clean_filename] = base_dir.plus_file(file_name.trim_suffix(".import"))
		file_name = dir.get_next()
	dir.list_dir_end()
