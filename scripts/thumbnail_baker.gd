tool
extends EditorScript

# TO RUN THIS:
# 1. Open this script in the Script Editor.
# 2. Go to File > Run (or press Ctrl+Shift+X).
# 3. Check the Output dock at the bottom for "Done!".

func _run():
	var path = "res://resources/textures/"
	var dir = Directory.new()
	
	if dir.open(path) != OK:
		print("Error: Could not open directory " + path)
		return
	
	print("--- Starting Thumbnail Bake ---")
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".bmp"):
			var full_path = path + file_name
			var thumb_path = path + file_name.get_basename() + "_thumb.png"
			
			var img = Image.new()

			var err = img.load(full_path, false, false)
			
			if err == OK:
				img.resize(32, 32, Image.INTERPOLATE_NEAREST)
				img.save_png(thumb_path)
				print("Baked: " + file_name)
			else:
				print("Failed to load: " + file_name)
				
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("--- Done! You may need to wait for Godot to re-scan the folder. ---")
