extends Button

func _ready():
	var popup = $PopupPanel
	popup.hide()
	connect("pressed", self, "_on_button_pressed")

func _on_button_pressed():
	var popup = $PopupPanel

	if popup.visible:
		popup.hide()
	else:
		var button_pos = rect_global_position
		var button_size = rect_size

		popup.set_position(Vector2(button_pos.x, button_pos.y + button_size.y))
		popup.show()
