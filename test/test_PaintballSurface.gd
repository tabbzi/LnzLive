extends GutTest

func test_optional_surface_flag_keeps_gill_markings_flat():
	var path: String = "user://test_paintball_surface.lnz"
	var file: File = File.new()
	assert_eq(file.open(path, File.WRITE), OK)
	file.store_string("[Paint Ballz]\n95, 200, -80, -4, 18, 10, -1, 3, -1, -1, 7, 0\n96, 200, -76, 25, 0, 10, -1, 3, -1, -1, 8, 0\n52, 15, -0.3, -0.8, -0.6, 5, 5, 0, -1, -1, -1\n")
	file.close()
	var parser: LnzParser = LnzParser.new(path)
	parser.parse_paintballs(parser.compile_section("Paint Ballz", [0]))
	assert_eq(parser.paintballs[95][0].texture_id, 7)
	assert_eq(parser.paintballs[95][0].anchored, 0)
	assert_eq(parser.paintballs[96][0].texture_id, 8)
	assert_eq(parser.paintballs[96][0].anchored, 0)
	assert_eq(parser.paintballs[52][0].anchored, 1, "An omitted flag retains the game's surface-mode default.")
	Directory.new().remove(path)

func test_flat_paint_is_visible_when_its_normal_points_away_from_camera():
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
	var paint: Spatial = preload("res://Paintball.tscn").instance()
	viewport.add_child(paint)
	paint.base_ball_position = Vector3.ZERO
	paint.base_ball_size = 40
	paint.ball_size = 40
	paint.color_index = 206
	paint.surface_normal = Vector3(0, 0, -1)
	for surface in [false, true]:
		paint.surface_mode = surface
		yield(VisualServer, "frame_post_draw")
		yield(VisualServer, "frame_post_draw")
		var image: Image = viewport.get_texture().get_data()
		image.lock()
		var alpha: float = image.get_pixel(32, 32).a
		image.unlock()
		if surface:
			assert_almost_eq(alpha, 0.0, 0.01, "Surface paint must still be hidden on the far side.")
		else:
			assert_almost_eq(alpha, 1.0, 0.01, "Flat gill markings must not be discarded by the surface-normal test.")
	viewport.queue_free()
	yield(get_tree(), "idle_frame")

func test_gill_texture_samples_stay_centered_on_the_marking():
	# Like GILLRAD textures: a small cream detail in a large yellow bitmap.
	var indices: PoolByteArray = PoolByteArray()
	indices.resize(256 * 256)
	for y in range(256):
		for x in range(256):
			indices[y * 256 + x] = 202 if abs(x - 128) < 16 and abs(y - 128) < 16 else 206
	var image: Image = Image.new()
	image.create_from_data(256, 256, false, Image.FORMAT_L8, indices)
	var texture: ImageTexture = ImageTexture.new()
	texture.create_from_image(image, 0)
	var palette: Array = LnzLiveUtils.extract_palette_from_image(LnzLiveUtils.DEFAULT_PALETTE)
	var viewport: Viewport = Viewport.new()
	viewport.transparent_bg = true
	viewport.own_world = true
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	var camera: Camera = Camera.new()
	camera.projection = Camera.PROJECTION_ORTHOGONAL
	camera.translation = Vector3(0, 0, -1)
	camera.rotation_degrees.y = 180
	camera.current = true
	viewport.add_child(camera)
	var paint: Spatial = preload("res://Paintball.tscn").instance()
	viewport.add_child(paint)
	paint.base_ball_position = Vector3.ZERO
	paint.base_ball_size = 48
	paint.ball_size = 96
	paint.translation = Vector3(-0.24, 0, 0)
	paint.color_index = 40
	paint.surface_mode = false
	paint.texture = texture
	paint.transparent_color = 2
	for size in [128, 192]:
		viewport.size = Vector2(size, size)
		camera.size = size * 0.01
		yield(VisualServer, "frame_post_draw")
		yield(VisualServer, "frame_post_draw")
		var rendered: Image = viewport.get_texture().get_data()
		rendered.lock()
		# This point lies in the cream detail and inside the host's clipping circle.
		var pixel: Color = rendered.get_pixel(size / 2 + 16, size / 2)
		rendered.unlock()
		assert_almost_eq(pixel.r, palette[202].r, 0.01, "The marking must sample its cream detail at viewport size " + str(size))
		assert_almost_eq(pixel.g, palette[202].g, 0.01)
		assert_almost_eq(pixel.b, palette[202].b, 0.01)
		assert_almost_eq(pixel.a, 1.0, 0.01)
	# Viewing either side must preserve the centered bitmap sample.
	for direction in [Vector3.LEFT, Vector3.RIGHT]:
		paint.surface_normal = direction
		paint.translation = direction * 0.24
		camera.translation = direction
		camera.look_at(Vector3.ZERO, Vector3.UP)
		yield(VisualServer, "frame_post_draw")
		yield(VisualServer, "frame_post_draw")
		var rendered: Image = viewport.get_texture().get_data()
		rendered.lock()
		var pixel: Color = rendered.get_pixel(96, 96)
		rendered.unlock()
		assert_almost_eq(pixel.r, palette[202].r, 0.01, "Cream must face outward on side " + str(direction))
		assert_almost_eq(pixel.g, palette[202].g, 0.01)
		assert_almost_eq(pixel.b, palette[202].b, 0.01)
		assert_almost_eq(pixel.a, 1.0, 0.01)
	# A side-facing marking seen from the front must keep the same bitmap window.
	# Its placement and host clipping, rather than an extra UV turn, reveal the detail.
	paint.surface_normal = Vector3.RIGHT
	paint.translation = Vector3.RIGHT * 0.24
	camera.translation = Vector3(0, 0, -1)
	camera.rotation_degrees = Vector3(0, 180, 0)
	yield(VisualServer, "frame_post_draw")
	yield(VisualServer, "frame_post_draw")
	var rendered: Image = viewport.get_texture().get_data()
	rendered.lock()
	var pixel: Color = rendered.get_pixel(80, 96)
	rendered.unlock()
	assert_almost_eq(pixel.r, palette[202].r, 0.01, "Side-facing paint must retain its cream bitmap detail when viewed from the front.")
	assert_almost_eq(pixel.g, palette[202].g, 0.01)
	assert_almost_eq(pixel.b, palette[202].b, 0.01)
	assert_almost_eq(pixel.a, 1.0, 0.01)
	viewport.queue_free()
	yield(get_tree(), "idle_frame")

func test_textured_flat_marking_on_an_untextured_addball():
	var path: String = "user://test_flat_paint_addball.lnz"
	var source: String = "[Species]\n2\n[Texture List]\nhair10.bmp 1\n[Ballz Info]\n"
	var header: BhdParser = BhdParser.new("res://resources/animations/DOG.bhd")
	for _i in range(header.num_balls):
		source += "10, 45, -1, 0, -1, 0, 4, -1\n"
	source += "[Add Ball]\n52, -80, -4, 18, 206, 45, 0, 0, -1, -1, 45, 0, 0, -1\n"
	source += "[Color Info Override]\n67, 206, -1, -1\n"
	source += "[Fuzz Override]\n67, 3\n[Paint Ballz]\n67, 200, -80, -4, 18, 10, -1, 3, -1, -1, 0, 0\n"
	var file: File = File.new()
	assert_eq(file.open(path, File.WRITE), OK)
	file.store_string(source)
	file.close()
	var editor: Node = load("res://scenes/editor/editor.tscn").instance()
	editor.name = "Root"
	get_tree().root.add_child(editor)
	yield(get_tree(), "idle_frame")
	var generator: Node = editor.get_node("PetRoot/Node")
	generator.generate_pet(path)
	assert_eq(generator.lnz.addballs[67].texture_id, -1)
	var marking: Spatial = generator.paintball_map[67][0]
	assert_eq(generator.ball_map[67].fuzz_amount, 3)
	assert_eq(marking.fuzz_amount, 3)
	assert_eq(marking.base_ball_fuzz, 3)
	assert_false(marking.surface_mode)
	assert_true(marking.texture is AtlasTexture, "A flat marking must retain its stock texture on an untextured host.")
	assert_true(marking.get_node("MeshInstance").material_override.get_shader_param("has_texture"))
	Directory.new().remove(path)
	editor.queue_free()
	yield(get_tree(), "idle_frame")
