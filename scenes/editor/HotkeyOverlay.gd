extends Control

func _ready():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.focus_mode = Control.FOCUS_NONE
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel/Label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hide()
	
#	$Panel/Label.text = """HOTKEYS
#
#Viewport:
#Rotate: Left Click Drag | Pan: Space + Drag | Zoom: Scroll | Views: 1-0
#
#Edit:
#Undo: Ctrl+Z | Redo: Ctrl+Y | Save/Apply Changes: Ctrl+S
#Mini-Undo/Redo (Move/Paint): Ctrl+Shift+Z/X
#
#Move Mode:
#Move: Drag | Scale: Shift+Alt+Drag
#Lock Axis: Hold X/Y/Z
#
#Paintball:
#Draw: Click | Freeline: Shift+Drag | Erase: Ctrl+Click
#
#Toggle Overlay: F1"""

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_F1:
		visible = not visible
