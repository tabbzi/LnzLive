extends GutTest

# Pinned offsets from the native circle-table reference (diameter 21, fuzz 3).
const CHEEK_SHIFTS = [2, 1, 2, -1, 0, 2, 2, 2, 0, -1, 0, 1, 0, 2, 2, 1, -1, 1, -1, 0, -1]

func test_circle_fuzz_table_matches_native_rows():
	var texture: ImageTexture = LnzLiveUtils.circle_fuzz_texture()
	assert_eq(texture, LnzLiveUtils.circle_fuzz_texture(), "All circles share the same lookup texture.")
	var bytes: PoolByteArray = texture.get_data().get_data()
	for row in range(21):
		assert_eq(int(bytes[3 * 8385 + 210 + row]) - 7, CHEEK_SHIFTS[row])
	for fuzz in range(8):
		assert_eq(int(bytes[fuzz * 8385]) - 7, 0, "A one-pixel circle has no room for fuzz.")
		assert_eq(int(bytes[fuzz * 8385 + 1]) - 7, 0, "A two-pixel circle has no room for fuzz.")
		assert_eq(int(bytes[fuzz * 8385 + 2]) - 7, 0)

func _viewport() -> Viewport:
	var viewport: Viewport = Viewport.new()
	viewport.size = Vector2(64, 64)
	viewport.transparent_bg = true
	viewport.own_world = true
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	var camera: Camera = Camera.new()
	camera.projection = Camera.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.translation = Vector3(0, 0, 1)
	camera.current = true
	viewport.add_child(camera)
	return viewport

func _row_bounds(image: Image, row: int) -> Vector2:
	var left: int = 64
	var right: int = -1
	for x in range(64):
		if image.get_pixel(x, row).a > 0.9:
			left = min(left, x)
			right = max(right, x)
	return Vector2(left, right)

func _alpha_mask(image: Image) -> PoolByteArray:
	var mask: PoolByteArray = PoolByteArray()
	image.lock()
	for y in range(64):
		for x in range(64): mask.append(1 if image.get_pixel(x, y).a > 0.9 else 0)
	image.unlock()
	return mask

func test_gpu_fuzz_three_preserves_width_and_uses_native_row_shifts():
	var viewport: Viewport = _viewport()
	var ball: Spatial = preload("res://Ball.tscn").instance()
	viewport.add_child(ball)
	ball.ball_size = 21
	ball.outline = -1
	ball.color_index = 206
	var baseline: Array = []
	var shifts: Array = []
	for fuzz in [0, 3]:
		ball.fuzz_amount = fuzz
		yield(VisualServer, "frame_post_draw")
		yield(VisualServer, "frame_post_draw")
		var image: Image = viewport.get_texture().get_data()
		image.flip_y() # Viewport readback is bottom-up; native row zero is the top.
		image.lock()
		for row in range(64):
			var bounds: Vector2 = _row_bounds(image, row)
			if bounds.y < 0: continue
			if fuzz == 0:
				baseline.append(bounds)
			else:
				var original: Vector2 = baseline[shifts.size()]
				assert_eq(bounds.y - bounds.x, original.y - original.x, "Fuzz shifts a row without changing its width.")
				shifts.append(int(bounds.x - original.x))
		image.unlock()
	assert_eq(shifts, CHEEK_SHIFTS, "The GPU must use the same fuzz-3 row offsets as Petz.")
	viewport.queue_free()
	yield(get_tree(), "idle_frame")

func test_paint_is_clipped_by_the_hosts_own_fuzz():
	var viewport: Viewport = _viewport()
	var host: Spatial = preload("res://Ball.tscn").instance()
	viewport.add_child(host)
	host.ball_size = 21
	host.outline = -1
	host.color_index = 206
	host.fuzz_amount = 3
	yield(VisualServer, "frame_post_draw")
	yield(VisualServer, "frame_post_draw")
	var host_mask: PoolByteArray = _alpha_mask(viewport.get_texture().get_data())
	host.get_node("MeshInstance").hide()
	var paint: Spatial = preload("res://Paintball.tscn").instance()
	host.add_child(paint)
	paint.base_ball_position = Vector3.ZERO
	paint.base_ball_size = 21
	paint.base_ball_fuzz = 3
	paint.ball_size = 42
	paint.color_index = 202
	paint.surface_mode = false
	for paint_fuzz in [0, 7]:
		paint.fuzz_amount = paint_fuzz
		yield(VisualServer, "frame_post_draw")
		yield(VisualServer, "frame_post_draw")
		assert_eq(_alpha_mask(viewport.get_texture().get_data()), host_mask, "A covering marking must follow the fuzzy host edge, independently of its own fuzz.")
	viewport.queue_free()
	yield(get_tree(), "idle_frame")
