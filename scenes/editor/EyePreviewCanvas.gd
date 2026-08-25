extends Control

var eye_outline_left = Color(0.0, 0.0, 0.0, 1.0)
var eye_outline_right = Color(0.0, 0.0, 0.0, 1.0)
var eye_color_left = Color(1.0, 1.0, 1.0, 1.0)
var eye_color_right = Color(1.0, 1.0, 1.0, 1.0)
var iris_outline_left = Color(1.0, 0.5, 1.0, 1.0)
var iris_outline_right = Color(1.0, 0.5, 1.0, 1.0)
var iris_color_left = Color(0.0, 0.0, 0.0, 1.0)
var iris_color_right = Color(0.0, 0.0, 0.0, 1.0)
var eyelid_color = Color(0.0, 0.0, 0.0, 1.0)

func _draw() -> void:
	var size = rect_size
	if size.x <= 0 or size.y <= 0:
		return
	
	var eye_radius = min(size.x, size.y) * 0.35
	
	var left_center = Vector2(size.x * 0.25, size.y * 0.5)
	var right_center = Vector2(size.x * 0.75, size.y * 0.5)
	
	_draw_mock_eye(right_center, eye_radius, eye_outline_left, eye_color_left, iris_outline_left, iris_color_left, eyelid_color)
	_draw_mock_eye(left_center, eye_radius, eye_outline_right, eye_color_right, iris_outline_right, iris_color_right, eyelid_color)


func _draw_mock_eye(center: Vector2, radius: float, eye_outline: Color, eye_fill: Color, iris_outline: Color, iris_fill: Color, eyelid: Color) -> void:
	draw_circle(center, radius + 1.5, eye_outline)
	draw_circle(center, radius, eye_fill)

	var iris_radius = radius * 0.65
	draw_circle(center, iris_radius, iris_outline)
	draw_circle(center, iris_radius - 6.0, iris_fill)
	
	var eyelid_points = PoolVector2Array()
	var num_points = 32
	
	for i in range(num_points + 1):
		var angle = PI + (i * PI / num_points)
		eyelid_points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		
	draw_polygon(eyelid_points, PoolColorArray([eyelid]))
