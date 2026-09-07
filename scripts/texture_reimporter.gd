tool
extends EditorScript

# TO RUN THIS:
# 1. Open this script in the Script Editor.
# 2. Go to File > Run (or press Ctrl+Shift+X).
# 3. Check the Output dock at the bottom for "Done!".

const TEXTURE_PATH = "res://resources/textures/"

func _run():
	var dir = Directory.new()
	if dir.open(TEXTURE_PATH) != OK:
		print("Error: Could not open directory " + TEXTURE_PATH)
		return

	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	var processed_count = 0
	
	while file_name != "":
		# We are looking for the .import files of BMPs, excluding thumbnails
		if file_name.ends_with(".bmp.import") and not file_name.ends_with("_thumb.bmp.import"):
			_process_import_file(TEXTURE_PATH + file_name)
			processed_count += 1
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("--- Done! Processed %d .import files. ---" % processed_count)
	print("Note: You may need to restart Godot for the custom importer to take over.")

func _process_import_file(path):
	var file = File.new()
	if file.open(path, File.READ) != OK:
		print("Could not read: " + path)
		return

	var lines = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	# Check if we actually need to convert this file
	var needs_update = false
	for line in lines:
		if 'importer="texture"' in line:
			needs_update = true
			break
	
	if not needs_update:
		return

	var new_lines = []
	var skipping_metadata = false
	var reached_params = false

	for line in lines:
		if reached_params:
			break # (3) Stop adding anything after the [params] header
			
		# (1) Handle metadata removal
		if "metadata={" in line:
			skipping_metadata = true
			continue
		if skipping_metadata:
			if "}" in line:
				skipping_metadata = false
			continue

		# (2) Change importer to PetzTexture
		if 'importer="texture"' in line:
			line = line.replace('importer="texture"', 'importer="PetzTexture"')
		
		# (3) Check for [params]
		if "[params]" in line:
			reached_params = true
			new_lines.append(line)
			continue

		new_lines.append(line)

	# Write the cleaned file back out
	if file.open(path, File.WRITE) == OK:
		for i in range(new_lines.size()):
			# Avoid adding an extra newline at the very end
			if i == new_lines.size() - 1:
				file.store_string(new_lines[i])
			else:
				file.store_line(new_lines[i])
		file.close()
		print("Updated: " + path.get_file())
