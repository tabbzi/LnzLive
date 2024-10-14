extends Control

onready var camera_holder = get_tree().root.get_node("Root/SceneRoot/ViewportContainer/Viewport/CameraHolder") as Spatial
onready var camera = camera_holder.get_node("Camera") as Camera
onready var label = get_tree().root.get_node("Root/SceneRoot/Label")
onready var cube = get_tree().root.get_node("Root/PetRoot/MeshInstance") as Spatial
onready var tex = get_tree().root.get_node("Root/SceneRoot/ViewportContainer") as ViewportContainer
onready var popup = get_tree().root.get_node("Root/SceneRoot/PopupDialog") as WindowDialog

var last_selected
var selecting_on = false

func _ready():
	flip_camera_view()

func flip_camera_view():
	var camera_transform = camera.transform
	camera_transform.basis.x *= -1
	camera.transform = camera_transform

func _gui_input(event):
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(BUTTON_LEFT):
			var motion = event.relative as Vector2
			camera_holder.rotation.x += motion.y * 0.01
			
			# inverted view:
			camera_holder.rotation.y += motion.x * 0.01
			
			# uninverted view:
			# camera_holder.rotation.y += motion.x * -0.01
		if Input.is_mouse_button_pressed(BUTTON_RIGHT) or Input.is_mouse_button_pressed(BUTTON_MIDDLE):
			var motion = event.relative as Vector2
			# inverted view:
			camera.transform.origin.x -= motion.x * 0.001 / tex.rect_scale.x
			
			# uninverted view:
			#camera.transform.origin.x += motion.x * 0.001 / tex.rect_scale.x
			
			camera.transform.origin.y += motion.y * 0.001 / tex.rect_scale.x

		label.rect_global_position = event.global_position

		# try and do a raycast
		# the center of the actual texture == (500,500)
		if selecting_on:
			var real_center = rect_position + rect_size / 2.0
			var real_mouse_pos = event.position
			var offset = real_mouse_pos - real_center
			offset /= tex.rect_scale
			var final_pos = Vector2(500,500) + offset

			var from = camera.project_ray_origin(final_pos)
			var to = from + camera.project_ray_normal(final_pos) * 950
			var space_state = camera.get_world().direct_space_state
			var result = space_state.intersect_ray(from, to, [], 0x7FFFFFFF, false, true)
			if !result.empty():
				label.show()
				deal_with_last_selected()
				result.collider.get_parent()._on_Area_mouse_entered()
				last_selected = result.collider.get_parent()
			else:
				deal_with_last_selected()
				last_selected = null
				label.hide()

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_WHEEL_DOWN:
			tex.rect_pivot_offset = tex.rect_size / 2.0
			tex.rect_scale = tex.rect_scale / 2.0
		elif event.button_index == BUTTON_WHEEL_UP:
			tex.rect_pivot_offset = tex.rect_size / 2.0
			tex.rect_scale = tex.rect_scale * 2.0
		elif event.doubleclick and event.button_index == BUTTON_LEFT and last_selected_is_valid():
			last_selected.selected()
	pass
			
func _unhandled_key_input(event):
	if event.pressed and last_selected_is_valid():
		last_selected._input(event)
		
func last_selected_is_valid():
	return last_selected != null and is_instance_valid(last_selected)

func deal_with_last_selected():
	if last_selected != null and is_instance_valid(last_selected):
		last_selected._on_Area_mouse_exited()
				
func _on_Node_ball_mouse_enter(ball_info):
	label.text = str(ball_info.ball_no)

func _on_SelectCheckBox_toggled(button_pressed):
	selecting_on = button_pressed
	if !selecting_on:
		if last_selected_is_valid():
			last_selected._on_Area_mouse_exited()
		last_selected = null
		label.hide()

func _on_HelpButton_pressed():
	popup.popup_centered()

func _on_LnzTextEdit_mouse_entered():
	if last_selected_is_valid():
		last_selected._on_Area_mouse_exited()
	last_selected = null
	label.hide()

func _on_PetViewContainer_resized():
	var size_diff = tex.rect_size / 2.0 - self.rect_size / 2.0
	tex.rect_global_position = self.rect_global_position - size_diff

func _on_PetViewContainer_sort_children():
	_on_PetViewContainer_resized()
