extends VBoxContainer

const REPO_OWNER: String = "tabbzi"
const REPO_NAME: String = "LnzLive"
const GAME_EXE_NAME: String = "LnzLive.exe"
const VERSION_FILE_NAME: String = "version.txt"
const TEMP_FILE_NAME: String = "download_cache.tmp"
const SETTINGS_FILE: String = "user://launcher_settings.cfg"

const GITHUB_API_URL: String = "https://api.github.com/repos/%s/%s/releases" % [REPO_OWNER, REPO_NAME]

onready var status_label: Label = $StatusLabel
onready var progress_bar: ProgressBar = $ProgressBar
onready var version_selector: OptionButton = $ChannelSelector 
onready var btn_launch: Button = $BtnLaunch
onready var btn_update: Button = $BtnUpdate
onready var btn_install: Button = $BtnInstall
onready var btn_open_folder: Button = $BtnOpenFolder 

var texture_rect: TextureRect
var notes_scroll
var notes_text: RichTextLabel
var executable_selector: OptionButton
var btn_notes: Button
var btn_appdata: Button
var btn_change_path: Button
var lbl_path_display: Label
var file_dialog: FileDialog

var http_api: HTTPRequest
var http_download: HTTPRequest
var local_version: String = ""
var local_asset_name: String = ""
var target_remote_version: String = ""
var target_download_url: String = ""
var target_asset_name: String = ""
var install_dir: String = "" 
var game_install_path: String = "" 
var version_file_path: String = "" 

var all_releases_data: Array = [] 
var current_release_assets: Array = []

func _ready() -> void:
	texture_rect = get_node("../../TextureRect") as TextureRect
	
	call_deferred("setup_dynamic_ui")
	
	load_install_config()
	ensure_directory_exists()
	update_paths_and_label()
	setup_http_requests()
	setup_version_selector()
	
	btn_launch.connect("pressed", self, "_on_BtnLaunch_pressed")
	btn_update.connect("pressed", self, "_on_BtnUpdate_pressed")
	btn_install.connect("pressed", self, "_on_BtnInstall_pressed")
	
	if has_node("BtnOpenFolder"):
		btn_open_folder.connect("pressed", self, "_on_BtnOpenFolder_pressed")
	
	progress_bar.value = 0
	disable_all_buttons()
	status_label.text = "Checking local files..."
	
	check_local_version()
	status_label.text = "Checking for updates..."
	
	check_launch_readiness()
	check_github_updates()

func setup_dynamic_ui() -> void:
	var hbox: Control = texture_rect.get_parent() as Control
	
	notes_scroll = ScrollContainer.new()
	notes_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	notes_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	notes_scroll.visible = false
	hbox.add_child(notes_scroll)
	hbox.move_child(notes_scroll, texture_rect.get_index() + 1)
	
	notes_text = RichTextLabel.new()
	notes_text.size_flags_horizontal = SIZE_EXPAND_FILL
	notes_text.size_flags_vertical = SIZE_EXPAND_FILL
	notes_text.bbcode_enabled = true
	
	if status_label.has_font_override("font"):
		var base_font: Font = status_label.get_font("font")
		notes_text.add_font_override("normal_font", base_font)
		notes_text.add_font_override("bold_font", base_font)
		notes_text.add_font_override("italics_font", base_font)
		notes_text.add_font_override("bold_italics_font", base_font)
		notes_text.add_font_override("mono_font", base_font)
		
	notes_scroll.add_child(notes_text)

	executable_selector = OptionButton.new()
	executable_selector.rect_min_size = Vector2(0, 25)
	_copy_button_style(version_selector, executable_selector)
	executable_selector.align = Button.ALIGN_CENTER
	executable_selector.connect("item_selected", self, "_on_executable_changed")
	add_child(executable_selector)
	move_child(executable_selector, version_selector.get_index() + 1)

	btn_notes = Button.new()
	btn_notes.text = "See Release Notes"
	btn_notes.rect_min_size = Vector2(0, 25)
	_copy_button_style(btn_install, btn_notes)
	btn_notes.connect("pressed", self, "_on_BtnNotes_pressed")
	add_child(btn_notes)
	move_child(btn_notes, executable_selector.get_index() + 1)

	var folder_hbox = HBoxContainer.new()
	folder_hbox.add_constant_override("separation", 10)
	
	var folder_index: int = btn_open_folder.get_index()
	add_child(folder_hbox)
	move_child(folder_hbox, folder_index)
	
	remove_child(btn_open_folder)
	folder_hbox.add_child(btn_open_folder)
	btn_open_folder.size_flags_horizontal = SIZE_EXPAND_FILL
	
	btn_appdata = Button.new()
	btn_appdata.text = "Open User Folder"
	btn_appdata.rect_min_size = Vector2(0, 25)
	btn_appdata.size_flags_horizontal = SIZE_EXPAND_FILL
	_copy_button_style(btn_install, btn_appdata)
	btn_appdata.connect("pressed", self, "_on_BtnAppData_pressed")
	folder_hbox.add_child(btn_appdata)

	file_dialog = FileDialog.new()
	file_dialog.mode = FileDialog.MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.rect_min_size = Vector2(600, 400)
	file_dialog.connect("dir_selected", self, "_on_dir_selected")
	get_tree().current_scene.call_deferred("add_child", file_dialog)
	
	btn_change_path = Button.new()
	btn_change_path.text = "Change Install Location"
	btn_change_path.rect_min_size = Vector2(0, 25)
	_copy_button_style(btn_install, btn_change_path)
	btn_change_path.connect("pressed", self, "_on_BtnChangePath_pressed")
	add_child(btn_change_path)
	move_child(btn_change_path, folder_hbox.get_index() + 1)
	
	lbl_path_display = Label.new()
	lbl_path_display.align = Label.ALIGN_CENTER
	lbl_path_display.valign = Label.VALIGN_CENTER
	lbl_path_display.autowrap = true
	lbl_path_display.size_flags_horizontal = SIZE_FILL 
	lbl_path_display.rect_min_size = Vector2(100, 0)
	lbl_path_display.add_color_override("font_color", Color(0.5, 0.8, 0.8))
	if status_label.has_font_override("font"):
		lbl_path_display.add_font_override("font", status_label.get_font("font"))
	add_child(lbl_path_display)
	update_paths_and_label()

func _copy_button_style(source: Control, target: Control) -> void:
	var states: Array = ["normal", "hover", "pressed", "disabled", "focus"]
	for state in states:
		var state_str: String = state as String
		if source.has_stylebox_override(state_str):
			target.add_stylebox_override(state_str, source.get_stylebox(state_str))
	if source.has_font_override("font"):
		target.add_font_override("font", source.get_font("font"))

func load_install_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_FILE)
	var default_docs: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).plus_file("LnzLive")
	
	if err == OK:
		install_dir = config.get_value("General", "install_path", default_docs) as String
	else:
		install_dir = default_docs

func save_install_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("General", "install_path", install_dir)
	config.save(SETTINGS_FILE)

func update_paths_and_label() -> void:
	version_file_path = install_dir.plus_file(VERSION_FILE_NAME)
	game_install_path = install_dir.plus_file(GAME_EXE_NAME) 
		
	if lbl_path_display:
		lbl_path_display.text = "Install Location:\n" + install_dir

func ensure_directory_exists() -> void:
	var dir: Directory = Directory.new()
	if not dir.dir_exists(install_dir):
		dir.make_dir_recursive(install_dir)

func _on_BtnChangePath_pressed() -> void:
	file_dialog.current_dir = install_dir
	file_dialog.popup_centered()

func _on_dir_selected(path: String) -> void:
	install_dir = path
	save_install_config()
	check_local_version()
	update_paths_and_label()
	check_launch_readiness()
	update_ui_state()

func check_launch_readiness() -> void:
	var file: File = File.new()
	if file.file_exists(game_install_path):
		btn_launch.disabled = false
		if status_label.text == "Checking local files...":
			status_label.text = "Ready!"
	else:
		btn_launch.disabled = true

func setup_http_requests() -> void:
	http_api = HTTPRequest.new()
	add_child(http_api)
	http_api.connect("request_completed", self, "_on_api_request_completed")
	
	http_download = HTTPRequest.new()
	add_child(http_download)
	http_download.connect("request_completed", self, "_on_download_request_completed")
	http_download.use_threads = true

func setup_version_selector() -> void:
	version_selector.clear()
	version_selector.add_item("Fetching releases...")
	version_selector.disabled = true
	version_selector.connect("item_selected", self, "_on_version_changed")

func _process(_delta: float) -> void:
	if http_download.get_http_client_status() == HTTPClient.STATUS_BODY:
		var downloaded: int = http_download.get_downloaded_bytes()
		var total: int = http_download.get_body_size()
		if total > 0:
			progress_bar.value = (float(downloaded) / float(total)) * 100.0
			status_label.text = "Downloading: %d%%" % int(progress_bar.value)

func check_local_version() -> void:
	var file: File = File.new()
	if file.file_exists(version_file_path):
		file.open(version_file_path, File.READ)
		var content: String = file.get_as_text().strip_edges()
		file.close()
		
		var json_res: JSONParseResult = JSON.parse(content)
		if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
			var dict: Dictionary = json_res.result as Dictionary
			local_version = dict.get("tag", "Unknown") as String
			local_asset_name = dict.get("asset", "") as String
		else:
			local_version = content
			local_asset_name = ""
	else:
		local_version = "None"
		local_asset_name = ""
		
	update_paths_and_label()

func check_github_updates() -> void:
	var error: int = http_api.request(GITHUB_API_URL)
	if error != OK:
		status_label.text = "Error connecting to GitHub API."

func _on_api_request_completed(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "Failed to fetch updates."
		check_launch_readiness()
		return

	var json_result: JSONParseResult = JSON.parse(body.get_string_from_utf8())
	if json_result.error != OK:
		status_label.text = "Error parsing GitHub JSON."
		return
		
	if typeof(json_result.result) == TYPE_ARRAY:
		all_releases_data = []
		var releases: Array = json_result.result as Array
		for release in releases:
			var rel_dict: Dictionary = release as Dictionary
			if rel_dict.has("tag_name") and not str(rel_dict["tag_name"]).begins_with("launcher"):
				all_releases_data.append(rel_dict)
		all_releases_data.sort_custom(self, "_sort_releases_desc")
		populate_version_list()
	else:
		status_label.text = "Unexpected API format."

func _sort_releases_desc(a: Dictionary, b: Dictionary) -> bool:
	var ver_a: Array = _parse_version_string(a["tag_name"] as String)
	var ver_b: Array = _parse_version_string(b["tag_name"] as String)
	for i in range(3):
		if ver_a[i] > ver_b[i]: return true
		elif ver_a[i] < ver_b[i]: return false
	return str(a["published_at"]) > str(b["published_at"])

func _parse_version_string(tag_string: String) -> Array:
	var clean_tag: String = tag_string.to_lower()
	var numbers: Array = []
	var current_num: String = ""
	var found_digit: bool = false
	
	for i in range(clean_tag.length()):
		var char_code: int = clean_tag.ord_at(i)
		if char_code >= 48 and char_code <= 57:
			current_num += clean_tag[i]
			found_digit = true
		elif clean_tag[i] == "." and found_digit:
			if current_num != "":
				numbers.append(int(current_num))
				current_num = ""
		elif found_digit:
			break
			
	if current_num != "": numbers.append(int(current_num))
	while numbers.size() < 3: numbers.append(0)
	return numbers

func populate_version_list() -> void:
	version_selector.clear()
	version_selector.disabled = false
	
	if all_releases_data.size() == 0:
		version_selector.add_item("No releases found")
		version_selector.disabled = true
		return

	for release in all_releases_data:
		var rel_dict: Dictionary = release as Dictionary
		var item_text: String = rel_dict["tag_name"] as String
		if rel_dict.has("prerelease") and rel_dict["prerelease"]:
			item_text += " [Preview]"
		version_selector.add_item(item_text)
	
	update_target_from_selection()

func _on_version_changed(_index: int) -> void:
	update_target_from_selection()
	
func _markdown_to_bbcode(md_text: String) -> String:
	var bbcode: String = md_text.replace("\r", "")
	
	var patterns: Array = [
		{"pattern": "(?s)`{3}(.*?)`{3}", "replace": "---$1---"},
		{"pattern": "(?m)^### (.*)$", "replace": "[b][u]$1[/u][/b]"},
		{"pattern": "(?m)^## (.*)$", "replace": "[b][u]$1[/u][/b]"},
		{"pattern": "(?m)^# (.*)$", "replace": "[b][u]$1[/u][/b]"},
		{"pattern": "\\[(.*?)\\]\\((.*?)\\)", "replace": "[url=$2]$1[/url]"},
		{"pattern": "\\*\\*(.*?)\\*\\*", "replace": "[b]$1[/b]"},
		{"pattern": "__(.*?)__", "replace": "[b]$1[/b]"},
		{"pattern": "\\b_(.*?)_\\b", "replace": "[i]$1[/i]"},
		{"pattern": "(?m)^[\\*\\-]\\s(.*)$", "replace": "  • $1"},
	]
	
	var regex: RegEx = RegEx.new()
	for p in patterns:
		var p_dict: Dictionary = p as Dictionary
		var err: int = regex.compile(p_dict["pattern"] as String)
		if err == OK:
			bbcode = regex.sub(bbcode, p_dict["replace"] as String, true)
			
	return bbcode

func update_target_from_selection() -> void:
	var index: int = version_selector.selected
	if index < 0 or index >= all_releases_data.size(): return
		
	var selected_release: Dictionary = all_releases_data[index] as Dictionary
	target_remote_version = selected_release["tag_name"] as String
	
	if notes_text:
		var raw_notes: String = selected_release.get("body", "No release notes provided.") as String
		notes_text.bbcode_text = _markdown_to_bbcode(raw_notes)
	
	current_release_assets = []
	var assets_array: Array = selected_release["assets"] as Array
	for asset in assets_array:
		var asset_dict: Dictionary = asset as Dictionary
		if str(asset_dict["name"]).ends_with(".exe"):
			current_release_assets.append(asset_dict)
			
	executable_selector.clear()
	if current_release_assets.size() == 0:
		executable_selector.add_item("No executables found")
		executable_selector.disabled = true
		target_download_url = ""
		target_asset_name = ""
		update_ui_state()
		return

	executable_selector.disabled = false
	var best_index: int = 0
	var best_date: String = ""
	var found_stable: bool = false

	for i in range(current_release_assets.size()):
		var asset: Dictionary = current_release_assets[i] as Dictionary
		var asset_name: String = asset["name"] as String
		var asset_date: String = str(asset["updated_at"])
		
		executable_selector.add_item(asset_name)
		var is_stable: bool = "stable" in asset_name.to_lower()
		
		if is_stable and not found_stable:
			best_index = i
			best_date = asset_date
			found_stable = true
		elif is_stable and found_stable:
			if asset_date > best_date:
				best_index = i
				best_date = asset_date
		elif not found_stable:
			if best_date == "" or asset_date > best_date:
				best_index = i
				best_date = asset_date
				
	executable_selector.select(best_index)
	_on_executable_changed(best_index)

func _on_executable_changed(index: int) -> void:
	if index < 0 or index >= current_release_assets.size(): return
	var selected_asset: Dictionary = current_release_assets[index] as Dictionary
	target_download_url = selected_asset["browser_download_url"] as String
	target_asset_name = str(selected_asset["name"]).get_file() # Path traversal prevention
	update_ui_state()

func _on_BtnNotes_pressed() -> void:
	if notes_scroll and texture_rect:
		notes_scroll.visible = not notes_scroll.visible
		texture_rect.visible = not notes_scroll.visible
		btn_notes.text = "Hide Release Notes" if notes_scroll.visible else "See Release Notes"

func _on_BtnAppData_pressed() -> void:
	var base_user_dir: String = OS.get_user_data_dir().get_base_dir()
	var appdata_path: String = base_user_dir.plus_file("LnzLive")
	var dir: Directory = Directory.new()
	if not dir.dir_exists(appdata_path):
		dir.make_dir_recursive(appdata_path)
	OS.shell_open(appdata_path)

func update_ui_state() -> void:
	status_label.text = "Local: %s | Target: %s" % [local_version, target_remote_version]
	
	btn_launch.disabled = true
	btn_update.disabled = true
	btn_install.disabled = true
	btn_update.visible = false
	btn_install.visible = false
	
	var file_check: File = File.new()
	var game_exists: bool = file_check.file_exists(game_install_path)
	
	if not game_exists:
		btn_install.disabled = false
		btn_install.visible = true
		btn_install.text = "Install " + target_asset_name
	elif local_version != target_remote_version or (target_asset_name != "" and local_asset_name != target_asset_name):
		btn_update.disabled = false
		btn_update.visible = true
		
		var is_downgrade: bool = false
		
		if local_version != "None" and local_version != "Unknown" and local_version != "":
			var t_arr: Array = _parse_version_string(target_remote_version)
			var l_arr: Array = _parse_version_string(local_version)
			for i in range(3):
				if t_arr[i] < l_arr[i]: 
					is_downgrade = true
					break
				elif t_arr[i] > l_arr[i]: 
					break
		
		if not is_downgrade and local_version == target_remote_version and local_asset_name != target_asset_name:
			var target_date: String = ""
			var local_date: String = ""
			for asset in current_release_assets:
				var asset_dict: Dictionary = asset as Dictionary
				var a_name: String = str(asset_dict["name"]).get_file()
				
				if a_name == target_asset_name:
					target_date = str(asset_dict["updated_at"])
				if a_name == local_asset_name:
					local_date = str(asset_dict["updated_at"])
			
			if local_date != "" and target_date != "" and target_date < local_date:
				is_downgrade = true
				
		var is_stable: bool = "stable" in target_asset_name.to_lower()
		
		if is_downgrade:
			# Differentiate label depending on if it's a version downgrade or asset downgrade
			if local_version == target_remote_version:
				btn_update.text = "Downgrade to " + target_asset_name
			else:
				btn_update.text = "Downgrade to " + target_remote_version
		elif local_version == target_remote_version:
			if not is_stable:
				btn_update.text = "Update to " + target_asset_name + " (Patch)"
			else:
				btn_update.text = "Update to " + target_asset_name
		else:
			btn_update.text = "Update to " + target_remote_version 
			
		btn_launch.disabled = false
	else:
		btn_launch.disabled = false
		status_label.text += " (Ready)"

func start_download() -> void:
	if target_download_url == "":
		status_label.text = "Error: No download URL for this version."
		return
		
	var dir: Directory = Directory.new()
	if not dir.dir_exists(install_dir):
		var err: int = dir.make_dir_recursive(install_dir)
		if err != OK:
			status_label.text = "Error: Cannot create install folder."
			return
			
	btn_launch.disabled = true 
	btn_update.disabled = true
	btn_install.disabled = true
	if btn_change_path: btn_change_path.disabled = true 
	version_selector.disabled = true
	executable_selector.disabled = true
	
	status_label.text = "Starting download..."
	progress_bar.value = 0.0
	
	var temp_path: String = install_dir.plus_file(TEMP_FILE_NAME)
	http_download.set_download_file(temp_path)
	
	var error: int = http_download.request(target_download_url)
	if error != OK:
		status_label.text = "Download request failed."
		version_selector.disabled = false
		executable_selector.disabled = false
		if btn_change_path: btn_change_path.disabled = false
		check_launch_readiness()

func _on_download_request_completed(result: int, response_code: int, _headers: PoolStringArray, _body: PoolByteArray) -> void:
	version_selector.disabled = false
	executable_selector.disabled = false
	if btn_change_path: btn_change_path.disabled = false
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "Download failed! Code: %s" % str(response_code)
		update_ui_state()
		return
		
	status_label.text = "Finalizing..."
	progress_bar.value = 100.0
	
	var dir: Directory = Directory.new()
	var temp_path: String = install_dir.plus_file(TEMP_FILE_NAME)
	var backup_path: String = game_install_path + ".bak"
	
	var file_check: File = File.new()
	if not file_check.file_exists(temp_path):
		status_label.text = "Error: Downloaded file missing."
		return

	if dir.file_exists(game_install_path):
		var backup_err: int = dir.rename(game_install_path, backup_path)
		if backup_err != OK:
			status_label.text = "Error: Close game before updating!"
			dir.remove(temp_path)
			return
			
		var install_err: int = dir.rename(temp_path, game_install_path)
		if install_err != OK:
			status_label.text = "Update failed. Restoring..."
			dir.rename(backup_path, game_install_path) 
			return
		
		dir.remove(backup_path)
	else:
		var ren_err: int = dir.rename(temp_path, game_install_path)
		if ren_err != OK:
			status_label.text = "Error creating file."
			return
	
	var file: File = File.new()
	file.open(version_file_path, File.WRITE)
	
	var save_data: Dictionary = {
		"tag": target_remote_version,
		"asset": target_asset_name
	}
	file.store_string(to_json(save_data))
	file.close()
	
	local_version = target_remote_version
	local_asset_name = target_asset_name
	update_paths_and_label()
	update_ui_state()
	status_label.text = "Ready!"

func _on_BtnInstall_pressed() -> void:
	start_download()

func _on_BtnUpdate_pressed() -> void:
	start_download()

func _on_BtnLaunch_pressed() -> void:
	status_label.text = "Launching..."
	OS.execute(game_install_path, [], false)

func _on_BtnOpenFolder_pressed() -> void:
	var dir: Directory = Directory.new()
	if dir.dir_exists(install_dir):
		OS.shell_open(install_dir)
	else:
		status_label.text = "Error: Install directory not found!"

func disable_all_buttons() -> void:
	btn_launch.disabled = true
	btn_update.disabled = true
	btn_install.disabled = true
