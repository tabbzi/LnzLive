tool
extends EditorScript

# TO RUN THIS:
# 1. Open this script in the Script Editor.
# 2. Go to File > Run (or press Ctrl+Shift+X).
# 3. Check the Output dock at the bottom for "Done!".

const TEXTURE_PATH = "res://resources/textures/"
const OUTPUT_DIR = "res://resources/texture_atlas/"

func _run():
	var dir = Directory.new()
	if dir.open(TEXTURE_PATH) != OK:
		print("Error: Could not open directory " + TEXTURE_PATH)
		return

	var groups = {}
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".bmp") and not file_name.ends_with("_thumb.bmp") and not file_name.begins_with("atlas_"):
			var img = Image.new()
			var full_path = TEXTURE_PATH + file_name
			
			var err = preload("res://scripts/petz_image.gd").load_image(img, full_path, false, false)
			
			if err == OK:
				var size_key = str(img.get_width()) + "x" + str(img.get_height())
				if not groups.has(size_key):
					groups[size_key] = []
				groups[size_key].append({"name": file_name, "img": img})
			else:
				print("Failed to load: " + file_name + " Error code: " + str(err))
				
		file_name = dir.get_next()

	if groups.empty():
		print("No valid BMPs found to process.")
		return

	var master_manifest = {}

	for size_key in groups.keys():
		var textures = groups[size_key]
		var size_parts = size_key.split("x")
		var tex_w = int(size_parts[0])
		var tex_h = int(size_parts[1])
		
		var count = textures.size()
		var grid_cols = int(ceil(sqrt(count)))
		var grid_rows = int(ceil(float(count) / grid_cols))
		
		var atlas_image = Image.new()
		atlas_image.create(grid_cols * tex_w, grid_rows * tex_h, false, Image.FORMAT_RGBA8)
		
		print("Processing Atlas: %s (%d files)" % [size_key, count])

		for i in range(count):
			var tex_data = textures[i]
			var img = tex_data["img"]
			
			var col = i % grid_cols
			var row = i / grid_cols
			var x_pos = col * tex_w
			var y_pos = row * tex_h
			
			atlas_image.blit_rect(img, Rect2(0, 0, tex_w, tex_h), Vector2(x_pos, y_pos))
			
			master_manifest[tex_data["name"].get_basename()] = {
				"atlas": "atlas_" + size_key + ".bmp",
				"x": x_pos,
				"y": y_pos,
				"w": tex_w,
				"h": tex_h
			}

		var save_path = OUTPUT_DIR + "atlas_" + size_key + ".png"
		atlas_image.save_png(save_path)
		print("Saved Atlas: " + save_path)

	var file = File.new()
	if file.open(OUTPUT_DIR + "atlas_manifest.json", File.WRITE) == OK:
		file.store_string(JSON.print(master_manifest, "\t"))
		file.close()
		print("Manifest saved to: " + OUTPUT_DIR + "atlas_manifest.json")
	
	print("--- Done! ---")
