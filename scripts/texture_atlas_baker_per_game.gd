tool
extends EditorScript

const TEXTURE_PATH = "res://resources/textures/"
const OUTPUT_DIR = "res://resources/texture_atlas/"
const BABYZ_PAL_PATH = "res://resources/palettes/babyz_palette.png"

const TRANSPARENT_INDEX = 253

var _babyz_cache = {}
var _l8_colors = []

func _run():
	var t_start = OS.get_ticks_msec()
	
	var dir = Directory.new()
	if dir.open(TEXTURE_PATH) != OK:
		print("Error: Could not open directory " + TEXTURE_PATH)
		return

	# Only need to load Babyz palette for RGB quantization
	var babyz_palette = _load_palette_colors(BABYZ_PAL_PATH)
	
	if babyz_palette.size() == 0:
		print("Error: Could not load babyz_palette.png.")
		return
		
	_l8_colors.clear()
	for i in range(256):
		var float_val = i / 255.0
		_l8_colors.append(Color(float_val, float_val, float_val, 1.0))
		
	_babyz_cache.clear()

	var groups = {}
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".bmp") and not file_name.ends_with("_thumb.bmp") and not file_name.begins_with("atlas_"):
			var full_path = TEXTURE_PATH + file_name
			
			# HYBRID LOAD: Get BOTH the Godot RGB Image and the Raw Binary Data
			var img = Image.new()
			var err = img.load(full_path, false, false)
			var raw_bmp_data = LnzLiveUtils.load_raw_8bit_bmp(full_path)
			
			if err == OK and raw_bmp_data.has("data"):
				var size_key = str(img.get_width()) + "x" + str(img.get_height())
				if not groups.has(size_key):
					groups[size_key] = []
				groups[size_key].append({"name": file_name, "img": img, "raw_data": raw_bmp_data})
			else:
				print("Failed to load hybrid data for: " + file_name)
				
		file_name = dir.get_next()
	dir.list_dir_end()

	if groups.keys().size() == 0:
		print("No valid BMPs found to process.")
		return

	var master_manifest = {}

	for size_key in groups.keys():
		var textures = groups[size_key]
		
		PaletteCache.rebuild_palette_lookup_table(babyz_palette)
		
		var size_parts = size_key.split("x")
		var tex_w = int(size_parts[0])
		var tex_h = int(size_parts[1])
		
		var count = textures.size()
		var grid_cols = int(ceil(sqrt(count)))
		var grid_rows = int(ceil(float(count) / grid_cols))
		
		var petz_atlas = Image.new()
		petz_atlas.create(grid_cols * tex_w, grid_rows * tex_h, false, Image.FORMAT_L8)
		
		var babyz_atlas = Image.new()
		babyz_atlas.create(grid_cols * tex_w, grid_rows * tex_h, false, Image.FORMAT_L8)
		
		print("Processing Atlas: %s (%d files)" % [size_key, count])

		petz_atlas.lock()
		babyz_atlas.lock()

		for i in range(count):
			var tex_data = textures[i]
			
			# For Babyz (Godot RGB)
			var source_img = tex_data["img"]
			source_img.lock()
			
			# For Petz (Raw Binary)
			var raw = tex_data["raw_data"]
			var index_array = raw["data"]
			
			var col = i % grid_cols
			var row = i / grid_cols
			var x_pos = col * tex_w
			var y_pos = row * tex_h
			
			for y in range(tex_h):
				for x in range(tex_w):
					# 1. PETZ: Get the exact authored index from the binary
					var petz_idx = index_array[y * tex_w + x]
					
					# 2. BABYZ: Get Godot's translated RGB and quantize to Babyz palette
					var pixel_color = source_img.get_pixel(x, y)
					var color_key = pixel_color.to_rgba32()
					
					var babyz_idx = 0
					if _babyz_cache.has(color_key):
						babyz_idx = _babyz_cache[color_key]
					else:
						babyz_idx = PaletteCache.get_palette_index_fast(babyz_palette, pixel_color)
						_babyz_cache[color_key] = babyz_idx
					
					# Write both
					petz_atlas.set_pixel(x_pos + x, y_pos + y, _l8_colors[petz_idx])
					babyz_atlas.set_pixel(x_pos + x, y_pos + y, _l8_colors[babyz_idx])
			
			source_img.unlock()
			
			master_manifest[tex_data["name"].get_basename()] = {
				"petz_atlas": "petz_atlas_" + size_key + ".png",
				"babyz_atlas": "babyz_atlas_" + size_key + ".png",
				"x": x_pos,
				"y": y_pos,
				"w": tex_w,
				"h": tex_h
			}

		petz_atlas.unlock()
		babyz_atlas.unlock()
		
		var petz_save_path = OUTPUT_DIR + "petz_atlas_" + size_key + ".png"
		var babyz_save_path = OUTPUT_DIR + "babyz_atlas_" + size_key + ".png"
		
		petz_atlas.save_png(petz_save_path)
		babyz_atlas.save_png(babyz_save_path)
		print("Saved Atlases for size: " + size_key)

	var file = File.new()
	if file.open(OUTPUT_DIR + "atlas_manifest.json", File.WRITE) == OK:
		file.store_string(JSON.print(master_manifest, "\t"))
		file.close()
		print("Manifest saved to: " + OUTPUT_DIR + "atlas_manifest.json")
	
	var time_taken = (OS.get_ticks_msec() - t_start) / 1000.0
	print("--- Done! Completed in " + str(time_taken) + " seconds ---")


func _load_palette_colors(path: String) -> Array:
	var colors = []
	var img = Image.new()
	if img.load(path, false, false) == OK:
		img.lock()
		for i in range(256):
			if i < img.get_width():
				colors.append(img.get_pixel(i, 0))
			else:
				colors.append(Color(0,0,0,1))
		img.unlock()
	return colors


func _get_closest_index(color: Color, palette: Array) -> int:
	if color.a < 0.1 or (color.r > 0.99 and color.g < 0.01 and color.b > 0.99):
		return TRANSPARENT_INDEX
		
	var best_dist = 100000.0
	var best_idx = 0
	
	for i in range(256):
		if i == TRANSPARENT_INDEX: continue
		
		var p_col = palette[i]
		var dr = color.r - p_col.r
		var dg = color.g - p_col.g
		var db = color.b - p_col.b
		var dist = (dr * dr) + (dg * dg) + (db * db)
		
		if dist < best_dist:
			best_dist = dist
			best_idx = i
			
	return best_idx
