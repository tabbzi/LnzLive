extends Control

const SETTINGS_PATH = "user://settings.cfg"

func _ready():
	print("Booting up LnzLive... debug mode is enabled, and messages will appear here, usually in the following format:")

	print("- [STATUS]: nothing wrong! just informational messages")
	print("- [WARNING]: non-critical issue, should still work but may cause other issues")
	print("- [ERROR]: critical failure, might cause crash")

	print("Please copy and share these messages if you run into any issues running LnzLive!")

	print("\n--- System Information ---")
	print("OS Name: ", OS.get_name())
	print("OS Model: ", OS.get_model_name())
	print("CPU Count: ", OS.get_processor_count())
	print("RAM Usage (Static Godot): ", OS.get_static_memory_usage())
	print("RAM Usage (Dynamic Godot): ", OS.get_dynamic_memory_usage())
	print("GPU Adapter: ", VisualServer.get_video_adapter_name())
	print("GPU Vendor: ", VisualServer.get_video_adapter_vendor())
	print("--------------------------\n")

	load_settings()

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err == OK:
		if config.has_section_key("Display", "window_size"):
			OS.window_size = config.get_value("Display", "window_size")

		if config.has_section_key("Display", "window_position"):
			var screen_pos = config.get_value("Display", "window_position")
			var is_valid_position = false
			
			for i in range(OS.get_screen_count()):
				var s_pos = OS.get_screen_position(i)
				var s_size = OS.get_screen_size(i)
				
				if screen_pos.x >= s_pos.x and screen_pos.x < (s_pos.x + s_size.x) and \
				   screen_pos.y >= s_pos.y and screen_pos.y < (s_pos.y + s_size.y):
					is_valid_position = true
					break
			
			if is_valid_position:
				OS.window_position = screen_pos
			else:
				OS.center_window()
		else:
			OS.center_window()

	elif err == ERR_FILE_NOT_FOUND:
		OS.center_window()
	
	else:
		print("Error loading window settings: ", err)
		OS.center_window()

func _on_Timer_timeout() -> void:
	get_tree().change_scene("res://scenes/editor/editor.tscn")
