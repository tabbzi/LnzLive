extends "res://addons/gut/test.gd"

func test_polygon_shader_links_and_renders_palette_color():
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

	var palette_image: Image = Image.new()
	palette_image.create(256, 1, false, Image.FORMAT_RGB8)
	palette_image.fill(Color(1, 0, 0))
	var palette: ImageTexture = ImageTexture.new()
	palette.create_from_image(palette_image, 0)
	var material: ShaderMaterial = load("res://shaders/polygon.tres").duplicate()
	material.set_shader_param("palette", palette)
	material.set_shader_param("color_index", 40)
	material.set_shader_param("l_edge_color", -1)
	material.set_shader_param("r_edge_color", -1)
	material.set_shader_param("ball_world_pos1", Vector3(-0.5, 0.5, 0))
	material.set_shader_param("ball_world_pos2", Vector3(0.5, 0.5, 0))
	material.set_shader_param("ball_world_pos3", Vector3(0.5, -0.5, 0))
	material.set_shader_param("ball_world_pos4", Vector3(-0.5, -0.5, 0))
	var mesh: MeshInstance = MeshInstance.new()
	mesh.mesh = QuadMesh.new()
	mesh.material_override = material
	viewport.add_child(mesh)
	yield(VisualServer, "frame_post_draw")
	yield(VisualServer, "frame_post_draw")
	var image: Image = viewport.get_texture().get_data()
	image.lock()
	var color: Color = image.get_pixel(32, 32)
	image.unlock()
	assert_almost_eq(color.r, 1.0, 0.01)
	assert_almost_eq(color.g, 0.0, 0.01)
	assert_almost_eq(color.b, 0.0, 0.01)
	assert_almost_eq(color.a, 1.0, 0.01)
	viewport.queue_free()
	yield(get_tree(), "idle_frame")
