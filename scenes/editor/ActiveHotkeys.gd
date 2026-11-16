extends Label
## ActiveHotkeys.gd
## Displays currently active key combinations with a fade-out effect

var display_time: float = 3.0
var fade_speed: float = 1.5

var timer: float = 0.0
var current_alpha: float = 1.0
var active_keys: Array = []

func _ready() -> void:
	text = ""
	mouse_filter = MOUSE_FILTER_IGNORE
	align = Label.ALIGN_RIGHT
	add_color_override("font_color", Color(1, 1, 1, 1.0))

func _process(delta: float) -> void:
	if timer > 0:
		timer -= delta
		
		if timer <= 1.0:
			current_alpha = max(0.0, timer)
			add_color_override("font_color", Color(1, 1, 1, current_alpha))
		
		if timer <= 0:
			text = "" 
	else:
		if text != "":
			text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var input_event_key: InputEventKey = event as InputEventKey
		var scancode: int = input_event_key.scancode
		
		if input_event_key.pressed and not input_event_key.echo:
			if not scancode in active_keys:
				active_keys.append(scancode)
			
			_update_hotkey_text(input_event_key)
				
		elif not input_event_key.pressed:
			if scancode in active_keys:
				active_keys.erase(scancode)
				
				if not active_keys.empty():
					_update_hotkey_text(input_event_key)

func _update_hotkey_text(event: InputEventKey) -> void:
	var key_str: String = _get_combo_string(event)
	
	if key_str != "":
		if _should_display(event, key_str):
			text = key_str
			timer = display_time
			current_alpha = 1.0
			add_color_override("font_color", Color(1, 1, 1, 1.0))

func _should_display(event: InputEventKey, key_str: String) -> bool:
	var focus_owner: Node = get_focus_owner()
	var is_text_input: bool = (focus_owner is TextEdit or focus_owner is LineEdit)
	
	if is_text_input:
		if event.control or event.command or event.meta or event.alt or event.shift:
			return true
			
		return _is_special_key(event.scancode) 
			
	return true

func _is_special_key(scancode: int) -> bool:
	if scancode >= KEY_F1 and scancode <= KEY_F16:
		return true
	
	var special_keys: Array = [
		KEY_ESCAPE, KEY_TAB, KEY_ENTER, KEY_KP_ENTER, 
		KEY_INSERT, KEY_DELETE, KEY_PAUSE, KEY_PRINT, KEY_SYSREQ, KEY_CLEAR,
		KEY_HOME, KEY_END, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, 
		KEY_PAGEUP, KEY_PAGEDOWN
	]
	
	var result: bool = scancode in special_keys
	
	special_keys.resize(0)
	
	return result

func _get_combo_string(event: InputEventKey) -> String:
	var parts: Array = []
	
	if event.control or KEY_CONTROL in active_keys: 
		if not "CTRL" in parts: 
			parts.append("CTRL")
	if event.meta or KEY_META in active_keys:
		parts.append("CMD" if OS.get_name() == "OSX" else "META")
	if event.alt or KEY_ALT in active_keys: 
		if not "ALT" in parts: 
			parts.append("ALT")
	if event.shift or KEY_SHIFT in active_keys: 
		if not "SHIFT" in parts: 
			parts.append("SHIFT")
	
	for code in active_keys:
		if not _is_modifier(code):
			var key_name: String = _get_key_name(code)
			if not key_name in parts:
				parts.append(key_name)
	
	var result: String = ""
	for i in range(parts.size()):
		result += parts[i]
		if i < parts.size() - 1:
			result += " + "
			
	# Clean up temporary array
	parts.resize(0)
	
	return result

func _get_key_name(scancode: int) -> String:
	match scancode:
		KEY_CONTROL: return "CTRL"
		KEY_META: return "CMD" if OS.get_name() == "OSX" else "META"
		KEY_ALT: return "ALT"
		KEY_SHIFT: return "SHIFT"
		KEY_TAB: return "TAB"
		KEY_SPACE: return "SPACE"
		_:
			return OS.get_scancode_string(scancode).to_upper() 

func _is_modifier(scancode: int) -> bool:
	return scancode == KEY_META or scancode == KEY_CONTROL or scancode == KEY_SHIFT or scancode == KEY_ALT
