extends Tree
## FileTree.gd
## Manages the Tree UI for organizing and interacting with Petz LNZ files textures and palettes
## This script builds the file structure from two sources: read-only resources (res://) and user resources (user://)
## 1. Loading: Scans directories to populate the tree with LNZ files textures and palettes
## 2. Selection: Handles item activation to load the selected file/palette by emitting example_file_selected user_file_selected or palette_selected
## 3. Import: Manages file uploading for both desktop and web builds copying LNZ BMP and PNG files to user resource storage
## 4. Management: Provides a right-click context menu for user-stored files allowing for renaming deleting and backing up the currently active LNZ file
## 5. Rescan: Provides dedicated methods to refresh the LNZ texture and palette sections of the tree

signal example_file_selected(filepath)
signal user_file_selected(filepath)
signal palette_selected(fileprefix)
signal backup_file

enum ImportType { NONE, LNZ, TEXTURE, PALETTE }
var current_import_type: int = ImportType.NONE

enum SortMode { ALPHABETICAL, MODIFIED_DATE }
var current_sort_mode: int = SortMode.ALPHABETICAL

const MAX_RECURSION_DEPTH: int = 3

const INDEX_EXAMPLE: int = 0
const INDEX_BASE_LNZ: int = 1
const INDEX_USER_LNZ: int = 2
const INDEX_GAME_TEXTURES: int = 3
const INDEX_USER_TEXTURES: int = 4
const INDEX_USER_PALETTES: int = 5

onready var pet_view_container: Control = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
onready var lnz_text_edit: Control = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")

var examples: TreeItem
var local_storage: TreeItem
var root: TreeItem
var local_storage_textures: TreeItem
var res_textures: TreeItem
var local_storage_palettes: TreeItem
var local_storage_bases: TreeItem

var new_folder_dialog: ConfirmationDialog
var new_folder_input

var move_dialog: ConfirmationDialog
var move_dropdown: OptionButton

export var example_file_location: String = "res://resources/"
export var user_file_location: String = "user://resources/"

onready var rename_dialog: AcceptDialog = get_tree().root.get_node("Root/SceneRoot/RenameDialog") as AcceptDialog
onready var upload_popup: AcceptDialog = get_tree().root.get_node("Root/SceneRoot/WebFileUploadPopup") as AcceptDialog
onready var preloader: ResourcePreloader = get_tree().root.get_node("Root/ResourcePreloader") as ResourcePreloader

onready var import_lnz_button: Button = get_node("../FileNavHBox2/ImportButtonLNZ")
onready var import_tex_button: Button = get_node("../FileNavHBox1/ImportButtonTexBMP")
onready var import_pal_button: Button = get_node("../FileNavHBox1/ImportButtonPalPNG")
onready var open_user_folder_button: Button = get_node("../FileNavHBox2/OpenUserFolder")

onready var menu_import_lnz: Button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/MenuImportLNZ")
onready var menu_import_tex: Button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/MenuImportTexture")
onready var menu_import_pal: Button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/MenuImportPalette")
onready var menu_open_user_folder: Button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/MenuOpenUserFolder")

onready var file_dialog: FileDialog = get_node("./ItemPopupMenu/FileDialog")

var saved_subfolder_states: Dictionary = {}

func _ready() -> void:
	var user_path: String = ProjectSettings.globalize_path("user://")
	print("Your local LnzLive user directory located at: ", user_path)
	print(" If you experience issues starting LnzLive or loading files:")
	print("1. Try removing the 'settings.cfg' file in this folder")
	print("2. Try removing files from the 'resources/textures' or 'resources/palettes' folders")

	select_mode = SELECT_MULTI
	root = create_item()
	examples = create_item(root, INDEX_EXAMPLE)
	examples.set_text(0, "Example LNZ")
	
	local_storage_bases = create_item(root, INDEX_BASE_LNZ)
	local_storage_bases.set_text(0, "Base LNZ")
	
	local_storage = create_item(root, INDEX_USER_LNZ)
	local_storage.set_text(0, "User LNZ")
	
	res_textures = create_item(root, INDEX_GAME_TEXTURES)
	res_textures.set_text(0, "Game Textures")
	
	local_storage_textures = create_item(root, INDEX_USER_TEXTURES)
	local_storage_textures.set_text(0, "User Textures")
	
	local_storage_palettes = create_item(root, INDEX_USER_PALETTES)
	local_storage_palettes.set_text(0, "User Palettes")
	
	scan_local_bases()
	scan_local_storage(null)
	scan_res_textures()
	scan_local_textures()
	scan_local_palettes()
	
	import_lnz_button.connect("pressed", self, "_on_ImportLNZ_pressed")
	import_tex_button.connect("pressed", self, "_on_ImportTexture_pressed")
	import_pal_button.connect("pressed", self, "_on_ImportPalette_pressed")
	open_user_folder_button.connect("pressed", self, "_on_OpenUserFolder_pressed")

	menu_import_lnz.connect("pressed", self, "_on_ImportLNZ_pressed")
	menu_import_tex.connect("pressed", self, "_on_ImportTexture_pressed")
	menu_import_pal.connect("pressed", self, "_on_ImportPalette_pressed")
	menu_open_user_folder.connect("pressed", self, "_on_OpenUserFolder_pressed")

	file_dialog.connect("files_selected", self, "_on_FileDialog_files_selected")
	file_dialog.connect("popup_hide", self, "_on_FileDialog_popup_hide")
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.rect_min_size = Vector2(400, 400)
	
	file_dialog.popup_exclusive = true
	
	if rename_dialog:
		rename_dialog.popup_exclusive = true
		rename_dialog.connect("about_to_show", self, "_on_RenameDialog_about_to_show")
		rename_dialog.connect("popup_hide", self, "_on_RenameDialog_popup_hide")

	if upload_popup:
		upload_popup.connect("about_to_show", self, "_on_FileDialog_about_to_show")
		upload_popup.connect("popup_hide", self, "_on_FileDialog_popup_hide")

	var popup: PopupMenu = $ItemPopupMenu
	if popup.get_item_count() < 9: # Increased count to accommodate new items
		popup.add_item("New Folder", 5)
		popup.add_item("Move To...", 6)
		popup.add_item("Duplicate", 7)
		popup.add_item("Add to Bases", 8)

	var dir: Directory = Directory.new()
	var lnz_dir_path: String = example_file_location + "lnz/"
	if dir.open(lnz_dir_path) == OK:
		dir.list_dir_begin(true, true)
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var subdir_path: String = lnz_dir_path + file_name
				var subdir: Directory = Directory.new()
				if subdir.open(subdir_path) == OK:
					var sub_item: TreeItem = create_item(examples)
					sub_item.set_text(0, file_name)
					sub_item.set_collapsed(true)
					subdir.list_dir_begin(true, true)
					var sub_file: String = subdir.get_next()
					while sub_file != "":
						if sub_file.ends_with(".lnz"):
							var new_item: TreeItem = create_item(sub_item)
							new_item.set_text(0, sub_file)
							new_item.set_metadata(0, subdir_path + "/" + sub_file)
						sub_file = subdir.get_next()
					subdir.list_dir_end()
			file_name = dir.get_next()
		dir.list_dir_end()

	_setup_dynamic_dialogs()

	var config: ConfigFile = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		current_sort_mode = config.get_value("Display", "file_tree_sort_mode", SortMode.ALPHABETICAL)

	_setup_sort_ui()

	# rescan(null)
	# rescan_textures(true)
	# rescan_res_textures()
	# rescan_palettes()
	# rescan_bases()

func is_valid_filepath(meta) -> bool:
	if typeof(meta) == TYPE_NIL:
		return false
	var meta_str: String = str(meta)
	return meta_str != "Null" and meta_str != ""

func _on_FileDialog_popup_hide() -> void:
	if pet_view_container:
		pet_view_container.input_is_paused = false
	release_focus()

func _on_RenameDialog_about_to_show() -> void:
	if pet_view_container:
		pet_view_container.input_is_paused = true

func _on_RenameDialog_popup_hide() -> void:
	if pet_view_container:
		pet_view_container.input_is_paused = false
	release_focus()

func _setup_dynamic_dialogs() -> void:
	new_folder_dialog = ConfirmationDialog.new()
	new_folder_dialog.window_title = "Create New Folder"
	
	var vbox1 = VBoxContainer.new()
	var label1: Label = Label.new()
	label1.text = "Enter folder name:"
	new_folder_input = LineEdit.new()
	
	vbox1.add_child(label1)
	vbox1.add_child(new_folder_input)
	new_folder_dialog.add_child(vbox1)
	
	new_folder_dialog.connect("confirmed", self, "_on_NewFolderDialog_confirmed")
	add_child(new_folder_dialog)
	
	move_dialog = ConfirmationDialog.new()
	move_dialog.window_title = "Move To..."
	
	var vbox2 = VBoxContainer.new()
	var label2: Label = Label.new()
	label2.text = "Select Destination Folder:"
	move_dropdown = OptionButton.new()
	
	vbox2.add_child(label2)
	vbox2.add_child(move_dropdown)
	move_dialog.add_child(vbox2)
	
	move_dialog.connect("confirmed", self, "_on_MoveFileDialog_confirmed")
	add_child(move_dialog)

func _setup_sort_ui() -> void:
	var sort_hbox = HBoxContainer.new()
	sort_hbox.alignment = BoxContainer.ALIGN_END
	
	var sort_label: Label = Label.new()
	sort_label.text = "Sort LNZ: "
	
	var sort_dropdown: OptionButton = OptionButton.new()
	sort_dropdown.add_item("Alphabetical (A-Z)")
	sort_dropdown.add_item("Modified (Newest)")

	sort_dropdown.select(current_sort_mode)
	sort_dropdown.connect("item_selected", self, "_on_sort_mode_changed")
	
	var custom_font: Font = import_lnz_button.get_font("font")
	if custom_font:
		sort_label.add_font_override("font", custom_font)
		sort_dropdown.add_font_override("font", custom_font)
	
	sort_hbox.add_child(sort_label)
	sort_hbox.add_child(sort_dropdown)
	
	call_deferred("_inject_sort_ui", sort_hbox)

func _inject_sort_ui(sort_hbox) -> void:
	var parent: Node = get_parent()
	parent.add_child(sort_hbox)
	parent.move_child(sort_hbox, 0)

func _on_sort_mode_changed(index: int) -> void:
	current_sort_mode = index 

	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load("user://settings.cfg") 
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("[ERROR] FileTree: _on_sort_mode_changed: error loading config to save sort mode: ", err)
		
	config.set_value("Display", "file_tree_sort_mode", current_sort_mode)
	config.save("user://settings.cfg")
	
	var selected_path = null
	var selected: TreeItem = get_selected()
	if selected:
		var meta = selected.get_metadata(0)
		if is_valid_filepath(meta):
			selected_path = str(meta)
		
	rescan(selected_path)

func _on_ImportLNZ_pressed() -> void:
	current_import_type = ImportType.LNZ
	if (!OS.has_feature("HTML5")):
		pet_view_container.input_is_paused = true
		file_dialog.clear_filters()
		file_dialog.add_filter("*.lnz ; LNZ Files")
		file_dialog.add_filter("*.txt ; Text Files")
		file_dialog.mode = FileDialog.MODE_OPEN_FILES
		file_dialog.popup_centered()
	else:
		web_file_dialog(".lnz,.txt,text/plain")

func _on_ImportTexture_pressed() -> void:
	current_import_type = ImportType.TEXTURE
	if (!OS.has_feature("HTML5")):
		pet_view_container.input_is_paused = true
		file_dialog.clear_filters()
		file_dialog.add_filter("*.bmp ; BMP Textures")
		file_dialog.mode = FileDialog.MODE_OPEN_FILES
		file_dialog.popup_centered()
	else:
		web_file_dialog(".bmp,image/bmp")

func _on_ImportPalette_pressed() -> void:
	current_import_type = ImportType.PALETTE
	if (!OS.has_feature("HTML5")):
		pet_view_container.input_is_paused = true
		file_dialog.clear_filters()
		file_dialog.add_filter("*.png,*.bmp ; All Palette Files")
		file_dialog.add_filter("*.png ; PNG Files")
		file_dialog.add_filter("*.bmp ; BMP Files")
		file_dialog.mode = FileDialog.MODE_OPEN_FILES
		file_dialog.popup_centered()
	else:
		web_file_dialog(".png,.bmp,image/png,image/bmp")

func _on_OpenUserFolder_pressed() -> void:
	var path: String = ProjectSettings.globalize_path("user://")
	OS.shell_open(path)

func _on_FileDialog_files_selected(paths: Array) -> void:
	var imported_types: Dictionary = {"lnz": false, "bmp": false, "png": false}
	var last_lnz_path: String = ""
	
	for p in paths:
		var dest_path: String = _on_FileDialog_file_selected(p, true) 
		
		if dest_path != "":
			var ext: String = dest_path.get_extension().to_lower()
			if imported_types.has(ext):
				imported_types[ext] = true
			if ext == "lnz":
				last_lnz_path = dest_path
				
	if imported_types["lnz"]:
		rescan(last_lnz_path)
		emit_signal("user_file_selected", last_lnz_path)
		
	if imported_types["bmp"]:
		rescan_textures(true)
		
	if imported_types["png"]:
		rescan_palettes()

func _on_FileDialog_file_selected(selected_path: String, skip_rescan: bool = false) -> String:
	var file_extension: String = selected_path.get_extension().to_lower()
	var dest_dir: String = ""
	
	if current_import_type == ImportType.LNZ:
		dest_dir = user_file_location
	elif current_import_type == ImportType.TEXTURE:
		dest_dir = user_file_location.plus_file("textures")
	elif current_import_type == ImportType.PALETTE:
		dest_dir = user_file_location.plus_file("palettes")
	else:
		print("[ERROR] FileTree: _on_FileDialog_file_selected: unknown import type")
		return ""

	var dest_filename: String = selected_path.get_file()
	if current_import_type == ImportType.LNZ and file_extension == "txt":
		dest_filename = dest_filename.get_basename() + ".lnz"
	
	var dest_path: String = dest_dir.plus_file(dest_filename)

	var dir: Directory = Directory.new()
	if not dir.dir_exists(dest_dir):
		var err: int = dir.make_dir_recursive(dest_dir)
		if err != OK:
			print("[ERROR] FileTree: _on_FileDialog_file_selected: error creating directory: ", err)
			return ""

	if current_import_type == ImportType.PALETTE and file_extension == "bmp":
		var success: bool = convert_bmp_to_palette_png(selected_path, dest_dir)
		if success:
			if not skip_rescan:
				rescan_palettes()
			return dest_dir.plus_file(dest_filename.get_basename() + ".png")
		return ""

	if current_import_type == ImportType.PALETTE:
		var img: Image = Image.new()
		var err: int = img.load(selected_path, false, false)
		if err == OK:
			if img.get_height() != 1:
				print("[ERROR] FileTree: _on_FileDialog_file_selected: palette PNG " + selected_path.get_file() + " is not 1 pixel high, skipping")
				return ""
		else:
			print("[ERROR] FileTree: _on_FileDialog_file_selected: failed to load PNG at: ", selected_path, " error: ", err)
			return ""

	var copy_success: bool = false
	if file_extension == "txt" and current_import_type == ImportType.LNZ:
		var f_in: File = File.new()
		if f_in.open(selected_path, File.READ) == OK:
			var content: String = f_in.get_as_text()
			f_in.close()

			var f_out: File = File.new()
			if f_out.open(dest_path, File.WRITE) == OK:
				f_out.store_string(content)
				f_out.close()
				copy_success = true
			else:
				print("[ERROR] FileTree: _on_FileDialog_file_selected: error writing to destination file: ", dest_path)
		else:
			print("[ERROR] FileTree: _on_FileDialog_file_selected: error reading source file: ", selected_path)
	else:
		var err: int = dir.copy(selected_path, dest_path)
		if err == OK:
			copy_success = true
		else:
			print("[ERROR] FileTree: _on_FileDialog_file_selected: error copying file: ", err)

	if copy_success:
		if not skip_rescan:
			rescan_with_extension(dest_path.get_extension().to_lower(), dest_path)
		return dest_path
		
	return ""
		
func web_file_dialog(accept_extensions: String) -> void:
	JavaScript.eval("""
	window.fileUploadData = {}

	let el = document.createElement("input");
	el.type = "file"
	el.accept = '""" + accept_extensions + """'
	el.addEventListener("change", (e) => {
	  if (e.target.files.length > 0) {
		let file = e.target.files[0]
		window.fileUploadData.name = file.name

		let reader = new FileReader()
		reader.readAsArrayBuffer(file)
		reader.onloadend = (ev) => {
		  window.fileUploadData.blob = ev.target.result
		}
	  }
	})
	el.click()
	""")
	upload_popup.visible = true
	
func _on_web_file_upload_popup_confirmed() -> void:
	var file_blob = JavaScript.eval("window.fileUploadData.blob")
	if (file_blob == null):
		print("[ERROR] FileTree: _on_web_file_upload_popup_confirmed: File is empty.")
		return
		
	var file_name: String = JavaScript.eval("window.fileUploadData.name")
	var file_extension: String = file_name.get_extension().to_lower()
	

	var dest_dir: String = ""
	if current_import_type == ImportType.LNZ:
		dest_dir = user_file_location
	elif current_import_type == ImportType.TEXTURE:
		dest_dir = user_file_location + "/textures"
	elif current_import_type == ImportType.PALETTE:
		dest_dir = user_file_location + "/palettes"
	else:
		return
	
	var dest_filename: String = file_name
	if current_import_type == ImportType.LNZ and file_extension == "txt":
		dest_filename = file_name.get_basename() + ".lnz"

	var dest_path: String = dest_dir.plus_file(dest_filename)

	var dir: Directory = Directory.new()
	if not dir.dir_exists(dest_dir):
		var err: int = dir.make_dir_recursive(dest_dir)
		if err != OK:
			print("[ERROR] FileTree: _on_web_file_upload_popup_confirmed: error creating directory: ", err)
			return

	if current_import_type == ImportType.PALETTE:
		if file_extension == "bmp":
			var temp_path: String = dest_dir.plus_file("temp_upload_" + str(OS.get_unix_time()) + ".bmp")
			var temp_file: File = File.new()
			if temp_file.open(temp_path, File.WRITE) == OK:
				temp_file.store_buffer(file_blob)
				temp_file.close()
				
				var target_filename: String = file_name.get_basename() + ".png"
				var success: bool = convert_bmp_to_palette_png(temp_path, dest_dir, target_filename)
				
				dir.remove(temp_path)
				
				if success:
					var final_path: String = dest_dir.plus_file(target_filename)
					rescan_with_extension(final_path.get_extension(), final_path)
			else:
				print("[ERROR] FileTree: _on_web_file_upload_popup_confirmed: could not write temp bmp file")
			return
		else:
			var img: Image = Image.new()
			var png_err: int = img.load_png_from_buffer(file_blob)
			if png_err == OK:
				if img.get_height() != 1:
					print("[WARNING] FileTree: _on_web_file_upload_popup_confirmed: palette " + file_name + " is not 1 pixel high, skipping")
			else:
				print("[ERROR] FileTree: _on_web_file_upload_popup_confirmed: error loading PNG from buffer")
				return

	var file: File = File.new()
	var err: int = file.open(dest_path, File.WRITE)
	if err != OK:
		print("[ERROR] FileTree: _on_web_file_upload_popup_confirmed: error creating file: ", err)
		return
	file.store_buffer(file_blob)
	file.close()

	rescan_with_extension(dest_path.get_extension(), dest_path)

func rescan_with_extension(file_extension: String, dest_path: String) -> void:
	if file_extension == "lnz":
		rescan(dest_path)
		emit_signal("user_file_selected", dest_path)
	elif file_extension == "bmp":
		rescan_textures(true)
	elif file_extension == "png":
		rescan_palettes()

func _on_Tree_item_activated() -> void:
	var selected: TreeItem = get_selected() as TreeItem
	if not selected: return
	
	var meta = selected.get_metadata(0)
	
	if not is_valid_filepath(meta):
		return
	
	var filepath: String = str(meta)
	
	if filepath.ends_with("/"):
		return
		
	var parent: TreeItem = selected.get_parent() as TreeItem
	var is_user_file: bool = false
	var is_bases_file: bool = false
	var current_parent: TreeItem = parent
	while current_parent:
		if current_parent == local_storage:
			is_user_file = true
		if current_parent == local_storage_bases:
			is_bases_file = true
			break
		current_parent = current_parent.get_parent()

	if parent == examples or parent.get_parent() == examples:
		emit_signal("example_file_selected", filepath)
	elif is_bases_file:
		emit_signal("example_file_selected", filepath)
	elif is_user_file:
		emit_signal("user_file_selected", filepath)
	elif parent == local_storage_palettes:
		var filename: String = selected.get_text(0)
		var filename_no_ext: String = filename.get_basename()
		emit_signal("palette_selected", filename_no_ext)
		
	release_focus()

func rescan(selected_filepath) -> void:
	var t_start: int = OS.get_ticks_msec()
	var was_collapsed: bool = true
	if local_storage != null:
		was_collapsed = local_storage.collapsed
		_save_subfolder_states(local_storage)
		root.remove_child(local_storage)
		local_storage.free()
	
	local_storage = create_item(root, INDEX_USER_LNZ)
	local_storage.set_text(0, "User LNZ")
	local_storage.collapsed = was_collapsed
	scan_local_storage(selected_filepath)

	print("[TIME] FileTree: rescan took " + str(OS.get_ticks_msec() - t_start) + "ms")

func _save_subfolder_states(item: TreeItem) -> void:
	if not item: return
	var child: TreeItem = item.get_children()
	while child:
		var meta: String = str(child.get_metadata(0))
		if meta.ends_with("/"):
			saved_subfolder_states[meta] = child.collapsed
			_save_subfolder_states(child)
		child = child.get_next()
	
func rescan_textures(reload_model: bool = false) -> void:
	var was_collapsed: bool = true
	if local_storage_textures != null:
		was_collapsed = local_storage_textures.collapsed
		root.remove_child(local_storage_textures)
	local_storage_textures = create_item(root, INDEX_USER_TEXTURES)
	local_storage_textures.set_text(0, "User Textures")
	local_storage_textures.collapsed = was_collapsed
	scan_local_textures()

	if reload_model:
		var pet_node: Node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
		if pet_node and pet_node.has_method("clear_texture_cache"):
			pet_node.clear_texture_cache()
			if pet_node.lnz:
				pet_node.recompose_model()

func rescan_res_textures() -> void:
	var was_collapsed: bool = true
	if res_textures != null:
		was_collapsed = res_textures.collapsed
		root.remove_child(res_textures)
	res_textures = create_item(root, INDEX_GAME_TEXTURES)
	res_textures.set_text(0, "Game Textures")
	res_textures.collapsed = was_collapsed
	scan_res_textures()
	
func rescan_palettes() -> void:
	var was_collapsed: bool = true
	if local_storage_palettes != null:
		was_collapsed = local_storage_palettes.collapsed
		root.remove_child(local_storage_palettes)
	local_storage_palettes = create_item(root, INDEX_USER_PALETTES)
	local_storage_palettes.set_text(0, "User Palettes")
	local_storage_palettes.collapsed = was_collapsed
	scan_local_palettes()

func rescan_bases() -> void:
	var was_collapsed: bool = true
	var bases_dir: String = user_file_location + "/bases"
	
	var dir: Directory = Directory.new()
	if not dir.dir_exists(bases_dir):
		dir.make_dir(bases_dir)
		
	if local_storage_bases != null:
		was_collapsed = local_storage_bases.collapsed
		root.remove_child(local_storage_bases)
	local_storage_bases = create_item(root, INDEX_BASE_LNZ)
	local_storage_bases.set_text(0, "Base LNZ")
	local_storage_bases.collapsed = was_collapsed
	scan_local_bases()
	
func scan_local_bases() -> void:
	print("[STATUS] FileTree: scan_local_bases: running")
	var t_start: int = OS.get_ticks_msec()
	var dir2: Directory = Directory.new()
	var bases_dir: String = user_file_location + "/bases"
	
	if not dir2.dir_exists(bases_dir):
		print("[WARNING] FileTree: scan_local_bases: directory not found")
		return

	dir2.open(bases_dir)
	dir2.list_dir_begin()
	var filename: String = dir2.get_next()
	
	while(!filename.empty()):
		if filename.ends_with(".lnz"):
			var full_path: String = bases_dir + "/" + filename
			
			var new_item: TreeItem = create_item(local_storage_bases)
			new_item.set_text(0, filename)
			new_item.set_metadata(0, full_path)
			
		filename = dir2.get_next()
	dir2.list_dir_end()
	print("[STATUS] FileTree: scan_local_bases: complete")
	print("[TIME] FileTree: scan_local_bases took " + str(OS.get_ticks_msec() - t_start) + "ms")

func scan_local_storage(selected_filepath) -> void:
	print("[STATUS] FileTree: scan_local_storage: running")
	var t_start: int = OS.get_ticks_msec()
	
	var safe_filepath: String = ""
	if is_valid_filepath(selected_filepath):
		safe_filepath = str(selected_filepath)
		
	_scan_dir_recursive(user_file_location, local_storage, safe_filepath, true)
	print("[STATUS] FileTree: scan_local_storage: complete")
	print("[TIME] FileTree: scan_local_storage took " + str(OS.get_ticks_msec() - t_start) + "ms")

func _scan_dir_recursive(path: String, parent_item: TreeItem, selected_filepath: String, is_root: bool = false, depth: int = 0) -> void:
	if depth > MAX_RECURSION_DEPTH:
		return

	var dir: Directory = Directory.new()
	if dir.open(path) != OK:
		return
		
	dir.list_dir_begin(true, true)
	var filename: String = dir.get_next()
	
	var folders: Array = []
	var files: Array = []
	
	var file_checker: File = File.new()
	
	while filename != "":
		if dir.current_is_dir():
			if is_root and (filename == "textures" or filename == "palettes" or filename == "references" or filename == "bases"):
				filename = dir.get_next()
				continue
			folders.append({"name": filename, "time": 0})
		elif filename.ends_with(".lnz"):
			var full_path: String = path.plus_file(filename)
			var mod_time: int = file_checker.get_modified_time(full_path)
			files.append({"name": filename, "path": full_path, "time": mod_time})
			
		filename = dir.get_next()
	dir.list_dir_end()
	
	folders.sort_custom(self, "_sort_by_name")
	
	if current_sort_mode == SortMode.ALPHABETICAL:
		files.sort_custom(self, "_sort_by_name")
	elif current_sort_mode == SortMode.MODIFIED_DATE:
		files.sort_custom(self, "_sort_by_time")
		
	for folder_data in folders:
		var f_name: String = folder_data["name"]
		var sub_path: String = path.plus_file(f_name)
		var sub_item: TreeItem = create_item(parent_item)
		sub_item.set_text(0, f_name)
		
		var meta_path: String = sub_path + "/"
		sub_item.set_metadata(0, meta_path)
		
		if saved_subfolder_states.has(meta_path):
			sub_item.set_collapsed(saved_subfolder_states[meta_path])
		else:
			sub_item.set_collapsed(true)
		
		_scan_dir_recursive(sub_path, sub_item, selected_filepath, false, depth + 1)
		
	for file_data in files:
		var f_name: String = file_data["name"]
		var full_path: String = file_data["path"]
		
		var new_item: TreeItem = create_item(parent_item)
		new_item.set_text(0, f_name)
		new_item.set_metadata(0, full_path)
		
		if full_path == selected_filepath:
			new_item.select(0)

func scan_local_textures() -> void:
	print("[STATUS] FileTree: scan_local_textures: running")
	var t_start: int = OS.get_ticks_msec()

	var dir: Directory = Directory.new()
	var textures_dir: String = user_file_location + "/textures"
	if dir.open(textures_dir) != OK:
		print("[WARNING] FileTree: scan_local_textures: directory not found, will create on texture import")
		return
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	var file: File = File.new()

	while filename != "":
		if filename.to_lower().ends_with(".bmp"):
			var full_path: String = textures_dir.plus_file(filename)
			var new_item: TreeItem = create_item(local_storage_textures)
			new_item.set_text(0, filename)
			new_item.set_metadata(0, full_path)

			# Validate texture BMP file
			var validation: Dictionary = LnzLiveUtils.validate_8bit_bmp(full_path)
			
			if not validation["valid"]:
				new_item.set_text(0, filename + " (INVALID: " + validation["reason"] + ")")
			else:
				# Load full texture for the UI
				var img: Image = Image.new()
				var err: int = img.load(full_path, true, true)
				
				if err == OK and img.get_width() > 0:
					# Create texture for model generation
					var full_tex: ImageTexture = ImageTexture.new()
					full_tex.create_from_image(img, ImageTexture.FLAG_REPEAT)
					
					var res_name: String = filename.to_lower()
					if preloader.has_resource(res_name):
						preloader.remove_resource(res_name)
					preloader.add_resource(res_name, full_tex)

					# Load image for thumbnail
					if file.open(full_path, File.READ) == OK:
						var buf: PoolByteArray = file.get_buffer(file.get_len())
						file.close()

						var icon_img: Image = Image.new()
						var icon_err: int = icon_img.load_bmp_from_buffer(buf)
						
						if icon_err == OK and icon_img.get_width() > 0:
							var w: int = icon_img.get_width()
							var h: int = icon_img.get_height()

							icon_img.convert(Image.FORMAT_RGBA8)
							icon_img.resize(32, 32, Image.INTERPOLATE_NEAREST)

							var icon_tex: ImageTexture = ImageTexture.new()
							icon_tex.create_from_image(icon_img, ImageTexture.FLAG_FILTER)
							new_item.set_icon(0, icon_tex)
							
						buf.resize(0)
					
					new_item.set_text(0, filename + " (" + str(img.get_width()) + "x" + str(img.get_height()) + ")")
				else:
					new_item.set_text(0, filename + " (LOAD FAILED)")

		filename = dir.get_next()
	dir.list_dir_end()
	print("[STATUS] FileTree: scan_local_textures: complete")
	print("[TIME] FileTree: scan_local_textures took " + str(OS.get_ticks_msec() - t_start) + "ms")

func scan_res_textures() -> void:
	print("[STATUS] FileTree: scan_res_textures: running")
	var t_start: int = OS.get_ticks_msec()
	var processed: Array = []
	var textures_dir: String = "res://resources/textures"
	
	var atlas_manifest_path: String = "res://resources/texture_atlas/atlas_manifest.json"
	var f: File = File.new()
	if f.open(atlas_manifest_path, File.READ) == OK:
		var result = JSON.parse(f.get_as_text())
		f.close()
		if result.error == OK:
			var manifest: Dictionary = result.result
			print("[STATUS] FileTree: scan_res_textures: loading texture atlas")

			var sorted_keys: Array = manifest.keys()
			sorted_keys.sort()
			
			for key in sorted_keys:
				var entry: Dictionary = manifest[key]
				var texture_name: String = key
				if !texture_name.to_lower().ends_with(".bmp"):
					texture_name += ".bmp"
				
				processed.append(texture_name)
				
				var new_item: TreeItem = create_item(res_textures)
				new_item.set_text(0, texture_name)
				new_item.set_metadata(0, textures_dir.plus_file(texture_name))
				
				var thumb_path: String = textures_dir.plus_file(texture_name.get_basename() + "_thumb.png")
				
				if ResourceLoader.exists(thumb_path):
					var thumb: StreamTexture = ResourceLoader.load(thumb_path)
					new_item.set_icon(0, thumb)
				else:
					var atlas_file: String = entry["atlas"]
					if atlas_file.to_lower().ends_with(".bmp"):
						atlas_file = atlas_file.get_basename() + ".png"
					var atlas_path: String = "res://resources/texture_atlas/" + atlas_file
					
					if ResourceLoader.exists(atlas_path):
						var atlas_tex: ImageTexture = ResourceLoader.load(atlas_path)
						var region: Rect2 = Rect2(entry["x"], entry["y"], entry["w"], entry["h"])
						var icon_tex: AtlasTexture = AtlasTexture.new()
						icon_tex.atlas = atlas_tex
						icon_tex.region = region
						new_item.set_icon(0, icon_tex)

	var dir: Directory = Directory.new()
	if dir.open(textures_dir) == OK:
		dir.list_dir_begin()
		var filename: String = dir.get_next()

		while filename != "":
			var final_filename: String = ""
			
			if filename.to_lower().ends_with(".bmp"):
				final_filename = filename
			elif filename.to_lower().ends_with(".bmp.import"):
				final_filename = filename.get_basename()

			if final_filename != "" and not final_filename in processed:
				processed.append(final_filename)
				var full_path: String = textures_dir.plus_file(final_filename)

				var new_item: TreeItem = create_item(res_textures)
				new_item.set_text(0, final_filename)
				new_item.set_metadata(0, full_path)

				var thumb_path: String = full_path.get_basename() + "_thumb.png"
				
				if ResourceLoader.exists(thumb_path):
					var thumb_tex: ImageTexture = load(thumb_path)
					if thumb_tex:
						new_item.set_icon(0, thumb_tex)

			filename = dir.get_next()
		dir.list_dir_end()
	print("[STATUS] FileTree: scan_res_textures: complete")
	print("[TIME] FileTree: scan_res_textures took " + str(OS.get_ticks_msec() - t_start) + "ms")

func scan_local_palettes() -> void:
	print("[STATUS] FileTree: scan_local_palettes: running")
	var t_start: int = OS.get_ticks_msec()
	var dir2: Directory = Directory.new()
	if not dir2.dir_exists(user_file_location + "/palettes"):
		print("[WARNING] FileTree: scan_local_palettes: directory not found")
		return

	dir2.open(user_file_location + "/palettes")
	dir2.list_dir_begin()
	var filename: String = dir2.get_next()
	
	while(!filename.empty()):
		if filename.ends_with(".png"):
			var full_path: String = user_file_location + "/palettes/" + filename
			
			var new_item: TreeItem = create_item(local_storage_palettes)
			new_item.set_text(0, filename)
			new_item.set_metadata(0, full_path)
			
			var img: Image = Image.new()
			var err: int = img.load(full_path, true, true)
			
			if err == OK:
				var tex: ImageTexture = ImageTexture.new()
				tex.create_from_image(img, 0)
				var clean_key: String = "palette_" + filename.strip_edges().to_lower()
				preloader.add_resource(clean_key, tex)
				
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				
				var w: int = img.get_width()
				var h: int = img.get_height()
				
				if w >= 200:
					img.lock()
					
					var preview_img: Image = Image.new()
					preview_img.create(32, 20, false, Image.FORMAT_RGBA8)
					preview_img.lock()
					
					var color_index: int = 0
					
					for i in range(10, 200, 10):
						var pos_start: Vector2 = Vector2(0, i) if h > w else Vector2(i, 0)
						var pos_end: Vector2 = Vector2(0, i + 8) if h > w else Vector2(i + 8, 0)
						
						var c1: Color = img.get_pixel(pos_start.x, pos_start.y)
						var c2: Color = img.get_pixel(pos_end.x, pos_end.y)
						
						var row: int = color_index / 8
						var col: int = color_index % 8
						var x_base: int = col * 4
						var y_base: int = row * 4

						for y in range(4):
							for x in range(4):
								if x_base + x < 32 and y_base + y < 20:
									preview_img.set_pixel(x_base + x, y_base + y, c1)
						color_index += 1
						
						row = color_index / 8
						col = color_index % 8
						x_base = col * 4
						y_base = row * 4
						for y in range(4):
							for x in range(4):
								if x_base + x < 32 and y_base + y < 20:
									preview_img.set_pixel(x_base + x, y_base + y, c2)
						color_index += 1
					
					preview_img.unlock()
					img.unlock()
					
					var icon_tex: ImageTexture = ImageTexture.new()
					icon_tex.create_from_image(preview_img, 0)
					new_item.set_icon(0, icon_tex)
					
				else:
					var fallback: Image = img.duplicate()
					fallback.resize(32, 32, Image.INTERPOLATE_NEAREST)
					var icon_tex: ImageTexture = ImageTexture.new()
					icon_tex.create_from_image(fallback, 0)
					new_item.set_icon(0, icon_tex)

		filename = dir2.get_next()
	dir2.list_dir_end()
	print("[STATUS] FileTree: scan_local_palettes: complete")
	print("[TIME] FileTree: scan_local_palettes took " + str(OS.get_ticks_msec() - t_start) + "ms")

func convert_bmp_to_palette_png(source_path: String, dest_dir: String, custom_dest_filename: String = "") -> bool:
	print("[STATUS] FileTree: convert_bmp_to_palette_png: converting BMP palette to PNG: " + source_path)
	var t_start: int = OS.get_ticks_msec()
	
	var f: File = File.new()
	if f.open(source_path, File.READ) != OK:
		print("[ERROR] FileTree: convert_bmp_to_palette_png: could not read BMP file")
		return false
	
	if f.get_len() < 54:
		print("[ERROR] FileTree: convert_bmp_to_palette_png: file too small to be a valid BMP")
		f.close()
		return false
		
	f.seek(10)
	var pixel_offset: int = f.get_32()
	
	f.seek(14)
	var header_size: int = f.get_32()
	
	f.seek(28)
	var bpp: int = f.get_16()
	
	if bpp != 8:
		print("[ERROR] FileTree: convert_bmp_to_palette_png: BMP is " + str(bpp) + "-bit, only 8-bit BMPs allowed")
		f.close()
		return false
	
	var palette_offset: int = 14 + header_size
	
	f.seek(palette_offset)
	
	var img: Image = Image.new()
	img.create(256, 1, false, Image.FORMAT_RGBA8)
	img.lock()
	
	var buffer: PoolByteArray = f.get_buffer(1024) # 256 colors * 4 bytes per color
	
	for i in range(256):
		var current_byte_pos: int = palette_offset + (i * 4) 
		
		if current_byte_pos >= pixel_offset or (i * 4 + 3) >= buffer.size():
			break
			
		var b: float = buffer[i * 4] / 255.0
		var g: float = buffer[i * 4 + 1] / 255.0
		var r: float = buffer[i * 4 + 2] / 255.0
		
		img.set_pixel(i, 0, Color(r, g, b, 1.0))
		
	img.unlock()
	f.close()
	buffer.resize(0)
	
	var dest_filename: String = custom_dest_filename
	if dest_filename == "":
		dest_filename = source_path.get_file().get_basename() + ".png"
	var dest_path: String = dest_dir.plus_file(dest_filename)
	
	var err: int = img.save_png(dest_path)
	if err == OK:
		print("[STATUS] FileTree: convert_bmp_to_palette_png: Converted BMP palette to: " + dest_path)
		print("[TIME] FileTree: convert_bmp_to_palette_png took " + str(OS.get_ticks_msec() - t_start) + "ms")
		return true
	else:
		print("[ERROR] FileTree: convert_bmp_to_palette_png: error saving palette ramp as PNG")
		return false

func get_all_selected() -> Array:
	var selected_items: Array = []
	var current: TreeItem = get_next_selected(null)
	while current:
		selected_items.append(current)
		current = get_next_selected(current)
	return selected_items

func _on_Tree_item_rmb_selected(position: Vector2) -> void:
	var items: Array = get_all_selected()
	if items.size() == 0: return
	
	$ItemPopupMenu.rect_global_position = position

	if items.size() > 1:
		for i in range($ItemPopupMenu.get_item_count()):
			var id: int = $ItemPopupMenu.get_item_id(i)
			var allowed_multi: bool = (id == 0 or id == 5 or id == 6)
			$ItemPopupMenu.set_item_disabled(i, !allowed_multi)
	else:
		var item: TreeItem = get_selected()
		if not item: return
		
		var p: TreeItem = item.get_parent()
		var meta = item.get_metadata(0)
		var is_dir: bool = is_valid_filepath(meta) and str(meta).ends_with("/")
		
		var is_local_content: bool = false
		var is_local_file: bool = false
		var is_bases_file: bool = false
		
		var curr: TreeItem = p
		while curr:
			if curr == local_storage or curr == local_storage_textures or curr == local_storage_palettes or curr == local_storage_bases:
				is_local_content = true
			if curr == local_storage or curr == local_storage_bases:
				is_local_file = true
			if curr == local_storage_bases:
				is_bases_file = true
			curr = curr.get_parent()

		for i in range($ItemPopupMenu.get_item_count()):
			var id: int = $ItemPopupMenu.get_item_id(i)
			if id == 0: $ItemPopupMenu.set_item_disabled(i, !is_local_content) # Delete
			elif id == 1: $ItemPopupMenu.set_item_disabled(i, !is_local_content) # Rename
			elif id == 2: $ItemPopupMenu.set_item_disabled(i, !is_local_file or is_dir) # Backup
			elif id == 3: $ItemPopupMenu.set_item_disabled(i, false) # Copy Filename
			elif id == 4: $ItemPopupMenu.set_item_disabled(i, !is_local_file or is_dir) # Export File
			elif id == 5: $ItemPopupMenu.set_item_disabled(i, !is_local_file) # New Folder
			elif id == 6: $ItemPopupMenu.set_item_disabled(i, !is_local_file) # Move To...
			elif id == 7: $ItemPopupMenu.set_item_disabled(i, !is_local_file or is_dir) # Duplicate
			elif id == 8: $ItemPopupMenu.set_item_disabled(i, !is_local_file or is_dir) # Add to Bases

	$ItemPopupMenu.popup()
	
func _on_ItemPopupMenu_id_pressed(id: int) -> void:
	if id == 0: # delete file/folder
		var items: Array = get_all_selected()
		if items.size() == 0: return
		
		var dir: Directory = Directory.new()
		for item in items:
			var item_meta = item.get_metadata(0)
			
			if not is_valid_filepath(item_meta):
				continue
				
			var filepath: String = str(item_meta)
			
			if filepath.ends_with("/"):
				var file_count: int = _count_files_in_dir(filepath.trim_suffix("/"))
				if file_count > 50:
					printerr("[ERROR] FileTree: Cannot delete '%s': contains %d files (exceeds 50 limit). Aborting entire batch." % [filepath, file_count])
					return
				elif file_count > 20:
					print("[WARNING] FileTree: Deleting '%s' contains %d files." % [filepath, file_count])
				_delete_dir_recursive(filepath.trim_suffix("/"))
			elif dir.file_exists(filepath):
				var err: int = dir.remove(filepath)
				if err != OK:
					print("[ERROR] FileTree: _on_ItemPopupMenu_id_pressed: Failed to delete ", filepath, " Error: ", err)

		rescan(null)
		rescan_textures()
		rescan_palettes()
		rescan_bases()

	elif id == 1: # rename file
		var item: TreeItem = get_selected()
		if not item: return
		
		var meta = item.get_metadata(0)
		if not is_valid_filepath(meta):
			return
		
		var filepath: String = str(meta)
		rename_dialog.popup()
		rename_dialog.get_node("LineEdit").text = filepath.get_file()
		
	elif id == 2: # backup
		emit_signal("backup_file")
		
	elif id == 3: # copy file name
		var item: TreeItem = get_selected()
		if not item: return
		var meta = item.get_metadata(0)
		if is_valid_filepath(meta):
			var filename: String = str(meta).get_file()
			OS.set_clipboard(filename)
			
	elif id == 4: # export file
		var item: TreeItem = get_selected()
		if not item: return
		
		var item_meta = item.get_metadata(0)
		if not is_valid_filepath(item_meta): return
		
		var item_filepath: String = str(item_meta)
		if item_filepath.ends_with("/"): return
		
		var filename: String = item.get_text(0)
		var file: File = File.new()
		if file.open(item_filepath, File.READ) != OK:
			print("[ERROR] FileTree: _on_ItemPopupMenu_id_pressed: could not open file for reading: " + item_filepath)
			return
		var content_bytes: PoolByteArray = file.get_buffer(file.get_len())
		file.close()
		
		_save_file_as(filename, content_bytes)
		
	elif id == 5: # New Folder
		var timestamp: String = str(OS.get_unix_time())
		new_folder_input.text = "new_folder_" + timestamp 
		new_folder_dialog.popup_centered(Vector2(250, 100))
		
	elif id == 6: # Move To
		_populate_move_dropdown()
		move_dialog.popup_centered(Vector2(300, 100))
		
	elif id == 7: # Duplicate
		var items: Array = get_all_selected()
		if items.size() != 1: return
		
		var item: TreeItem = items[0]
		var item_meta = item.get_metadata(0)
		if not is_valid_filepath(item_meta): return
		
		var item_filepath: String = str(item_meta)
		if item_filepath.ends_with("/"): return
		
		var filename: String = item.get_text(0)
		var ext: String = filename.get_extension()
		var base_name: String = filename.get_basename()
		var timestamp: String = str(OS.get_unix_time())
		var new_filename: String = base_name + "_" + timestamp + "." + ext
		var base_dir: String = item_filepath.get_base_dir()
		var new_filepath: String = base_dir.plus_file(new_filename)
		
		var dir: Directory = Directory.new()
		if not dir.file_exists(new_filepath):
			var err: int = dir.copy(item_filepath, new_filepath)
			if err == OK:
				print("[STATUS] FileTree: Duplicated file to ", new_filepath)
				rescan(null)
				rescan_textures()
				rescan_palettes()
				rescan_bases()
			else:
				print("[ERROR] FileTree: Failed to duplicate file: ", err)
		else:
			print("[WARNING] FileTree: Duplicate name already exists: ", new_filepath)
		
	elif id == 8: # Add to Bases
		var items: Array = get_all_selected()
		if items.size() != 1: return
		
		var item: TreeItem = items[0]
		var item_meta = item.get_metadata(0)
		if not is_valid_filepath(item_meta): return
		
		var item_filepath: String = str(item_meta)
		if item_filepath.ends_with("/"): return
		
		var bases_dir: String = user_file_location + "/bases/"
		if not bases_dir.ends_with("/"):
			bases_dir += "/"
			
		var dir: Directory = Directory.new()
		if not dir.dir_exists(bases_dir):
			print("[STATUS] FileTree: Creating missing Bases directory: " + bases_dir)
			var err: int = dir.make_dir_recursive(bases_dir)
			if err != OK:
				print("[ERROR] FileTree: Failed to create Bases directory at: " + bases_dir + " Error: " + str(err))
				return

		var filename: String = item.get_text(0)
		var new_filepath: String = bases_dir + filename
		
		if dir.file_exists(new_filepath):
			print("[WARNING] FileTree: File already exists in Bases: " + new_filepath)
			return
				
		var err: int = dir.copy(item_filepath, new_filepath)
		
		if err == OK:
			print("[STATUS] FileTree: Added file to Bases: " + new_filepath)
			rescan(null)
			rescan_textures()
			rescan_palettes()
			rescan_bases()
		else:
			if err == ERR_FILE_NOT_FOUND:
				print("[ERROR] FileTree: Failed to copy. Source file not found: " + item_filepath)
			elif err == ERR_CANT_CREATE:
				print("[ERROR] FileTree: Failed to copy. Destination path invalid or permission denied.")
			else:
				print("[ERROR] FileTree: Failed to copy to Bases: " + str(err))

func _delete_dir_recursive(path: String, depth: int = 0) -> void:
	if depth > MAX_RECURSION_DEPTH:
		print("[WARNING] FileTree: _delete_dir_recursive: max deletion depth reached at: ", path)
		return
		
	var dir: Directory = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name: String = dir.get_next()
		while file_name != "":
			var full_path: String = path.plus_file(file_name)
			if dir.current_is_dir():
				_delete_dir_recursive(full_path, depth + 1)
			else:
				var err: int = dir.remove(full_path)
				if err != OK:
					print("[ERROR] FileTree: _delete_dir_recursive: Failed to delete file ", full_path, " Error: ", err)
			file_name = dir.get_next()
		dir.list_dir_end()
		
		var dir_err: int = dir.remove(path)
		if dir_err != OK:
			print("[ERROR] FileTree: _delete_dir_recursive: Failed to delete directory ", path, " Error: ", dir_err)

func _count_files_in_dir(path: String) -> int:
	var dir: Directory = Directory.new()
	if dir.open(path) != OK:
		return 0
	dir.list_dir_begin(true, true)
	var file_name: String = dir.get_next()
	var count: int = 0
	while file_name != "":
		if dir.current_is_dir():
			count += _count_files_in_dir(path.plus_file(file_name))
		else:
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	return count

func _on_SaveDialog_file_selected(path: String, content_bytes: PoolByteArray) -> void:
	var file: File = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_buffer(content_bytes)
		file.close()
		print("[STATUS] FileTree: _on_SaveDialog_file_selected: file saved successfully to: " + path)
	else:
		print("[ERROR] FileTree: _on_SaveDialog_file_selected: error saving file to: " + path)

func _save_file_as(filename: String, content_bytes: PoolByteArray) -> void:	
	if OS.has_feature("HTML5"):		
		var escaped_filename: String = filename.replace("'", "\\'")
		var base64_content: String = Marshalls.raw_to_base64(content_bytes)
		
		var mime_type: String = "application/octet-stream"
		if filename.ends_with(".lnz"): mime_type = "text/plain"
		elif filename.ends_with(".bmp"): mime_type = "image/bmp"
		elif filename.ends_with(".png"): mime_type = "image/png"
		
		var js_code: String = """
		var element = document.createElement('a');
		element.setAttribute('href', 'data:""" + mime_type + """;base64,' + '""" + base64_content + """');
		element.setAttribute('download', '""" + escaped_filename + """');
		
		element.style.display = 'none';
		document.body.appendChild(element);
		element.click();
		document.body.removeChild(element);
		"""
		JavaScript.eval(js_code)
		
	else:
		var save_dialog: FileDialog = FileDialog.new()
		
		save_dialog.connect("file_selected", self, "_on_SaveDialog_file_selected", [content_bytes])
		save_dialog.connect("popup_hide", save_dialog, "queue_free")
		
		save_dialog.add_filter("*.lnz, *.bmp, *.png, *.* ; All Files")
		save_dialog.mode = FileDialog.MODE_SAVE_FILE
		save_dialog.access = FileDialog.ACCESS_FILESYSTEM
		save_dialog.window_title = "Save File As"
		save_dialog.current_file = filename
		save_dialog.rect_min_size = Vector2(400, 400)
		save_dialog.popup_exclusive = true
		
		add_child(save_dialog)
		save_dialog.popup_centered()

func _on_RenameDialog_confirmed() -> void:
	var items: Array = get_all_selected()
	if items.size() != 1: 
		return
		
	var item: TreeItem = items[0]
	var filepath = item.get_metadata(0)
	
	if not is_valid_filepath(filepath):
		return
	
	var filepath_str: String = str(filepath)
	var dir: Directory = Directory.new()
	var new_filename: String = rename_dialog.get_node("LineEdit").text.strip_edges()
	
	if new_filename == "" or new_filename == filepath_str.get_file():
		return

	var base_dir: String = filepath_str.get_base_dir()
	var new_filepath: String = base_dir.plus_file(new_filename)
	
	if filepath_str.ends_with("/"):
		new_filepath += "/"

	if dir.file_exists(new_filepath) or dir.dir_exists(new_filepath):
		print("[ERROR] FileTree: _on_RenameDialog_confirmed: Name already exists: ", new_filepath)
		return

	if dir.rename(filepath_str, new_filepath) == OK:
		rescan(null)
		rescan_textures()
		rescan_palettes()
		rescan_bases()

		if new_filepath.ends_with(".lnz"):
			emit_signal("user_file_selected", new_filepath)

	release_focus()

func _on_ItemPopupMenu_about_to_show() -> void:
	var items: Array = get_all_selected()
	if items.size() > 1: return

	var clicked_item: TreeItem = get_selected() as TreeItem
	if not clicked_item: return

	var clicked_filepath = clicked_item.get_metadata(0)
	
	if is_valid_filepath(clicked_filepath):
		if lnz_text_edit:
			$ItemPopupMenu.set_item_disabled(2, !(lnz_text_edit.filepath == str(clicked_filepath)))

func _on_LnzTextEdit_file_backed_up() -> void:
	var item: TreeItem = get_selected()
	var path = null
	if item and is_valid_filepath(item.get_metadata(0)):
		path = str(item.get_metadata(0))
	rescan(path)

func get_expanded_states() -> Dictionary:
	_save_subfolder_states(local_storage)
	return {
		"Example LNZ": examples.collapsed == false if examples else true,
		"Base LNZ": local_storage_bases.collapsed == false if local_storage_bases else false,
		"User LNZ": local_storage.collapsed == false if local_storage else true,
		"Game Textures": res_textures.collapsed == false if res_textures else false,
		"User Textures": local_storage_textures.collapsed == false if local_storage_textures else false,
		"User Palettes": local_storage_palettes.collapsed == false if local_storage_palettes else false,
		"Subfolders": saved_subfolder_states
	}

func set_expanded_states(states: Dictionary) -> void:
	if examples: examples.collapsed = !states.get("Example LNZ", true)
	if local_storage_bases: local_storage_bases.collapsed = !states.get("Base LNZ", false)
	if local_storage: local_storage.collapsed = !states.get("User LNZ", true)
	if res_textures: res_textures.collapsed = !states.get("Game Textures", false)
	if local_storage_textures: local_storage_textures.collapsed = !states.get("User Textures", false)
	if local_storage_palettes: local_storage_palettes.collapsed = !states.get("User Palettes", false)
	if states.has("Subfolders"):
		saved_subfolder_states = states.get("Subfolders")

func _populate_move_dropdown() -> void:
	move_dropdown.clear()
	move_dropdown.add_item("Root (user://resources/)")
	move_dropdown.set_item_metadata(0, user_file_location) 
	
	var dirs: Array = []
	_get_all_subdirs(user_file_location, dirs)
	
	var idx: int = 1
	for d in dirs:
		var display_name: String = d.replace(user_file_location, "")
		move_dropdown.add_item(display_name)
		move_dropdown.set_item_metadata(idx, d)
		idx += 1

func _get_all_subdirs(path: String, out_array: Array, depth: int = 0) -> void:
	if depth > MAX_RECURSION_DEPTH:
		return

	var dir: Directory = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if path == user_file_location and (file_name == "textures" or file_name == "palettes" or file_name == "references" or file_name == "bases"):
					file_name = dir.get_next()
					continue
					
				var full_path: String = path.plus_file(file_name)
				out_array.append(full_path + "/")
				_get_all_subdirs(full_path, out_array, depth + 1)
			file_name = dir.get_next()
		dir.list_dir_end()

func _on_NewFolderDialog_confirmed() -> void:
	var items: Array = get_all_selected()
	if items.size() == 0: return
	
	var folder_name: String = new_folder_input.text.strip_edges()
	if folder_name == "": return
	
	var protected_names: Array = ["textures", "palettes", "references", "bases"]
	if folder_name.to_lower() in protected_names:
		print("[WARNING] FileTree: Cannot create folder with protected name: ", folder_name)
		return
	
	var first_item: TreeItem = items[0]
	var first_meta: String = str(first_item.get_metadata(0))
	var base_is_dir: bool = first_meta.ends_with("/")
	var base_dir: String = first_meta if base_is_dir else first_meta.get_base_dir() + "/"
	
	var new_dir_path: String = base_dir.plus_file(folder_name)
	var dir: Directory = Directory.new()
	
	if not dir.dir_exists(new_dir_path):
		dir.make_dir(new_dir_path)
		
	for item in items:
		var raw_meta = item.get_metadata(0)
		
		if not is_valid_filepath(raw_meta):
			continue
			
		var item_meta: String = str(raw_meta)
		
		if item_meta == base_dir:
			continue 
		
		var clean_meta: String = item_meta.trim_suffix("/")
		var item_name: String = clean_meta.get_file()
		
		dir.rename(clean_meta, new_dir_path.plus_file(item_name))
			
	rescan(null)

func _on_MoveFileDialog_confirmed() -> void:
	var items: Array = get_all_selected()
	if items.size() == 0: return
	
	var target_dir: String = move_dropdown.get_selected_metadata()
	if not target_dir: return
	
	var dir: Directory = Directory.new()
	var any_moved: bool = false
	var last_lnz_path: String = ""
	
	for item in items:
		var raw_meta = item.get_metadata(0)
		
		if not is_valid_filepath(raw_meta):
			continue
			
		var current_path: String = str(raw_meta)
		
		var clean_path: String = current_path.trim_suffix("/")
		var file_name: String = clean_path.get_file()
		
		var norm_current: String = current_path if current_path.ends_with("/") else current_path + "/"
		var norm_target: String = target_dir if target_dir.ends_with("/") else target_dir + "/"
		
		if norm_current.ends_with("/") and norm_target.begins_with(norm_current):
			print("[WARNING] FileTree: _on_MoveFileDialog_confirmed: cannot move a folder into itself: ", current_path, " -> ", target_dir)
			continue
		
		var new_path: String = target_dir.plus_file(file_name)
		
		if dir.rename(clean_path, new_path) == OK:
			any_moved = true
			if new_path.ends_with(".lnz"):
				last_lnz_path = new_path
			
	if any_moved:
		rescan(null)

func _sort_by_name(a: Dictionary, b: Dictionary) -> bool:
	return a["name"].to_lower() < b["name"].to_lower()

func _sort_by_time(a: Dictionary, b: Dictionary) -> bool:
	return a["time"] > b["time"]
