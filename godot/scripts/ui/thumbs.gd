class_name Thumbs
extends Node
## Renders fixture and product models to small textures (for build cards and product rows).

signal ready_all
var fixtures := {}
var products := {}
var vp: SubViewport
var cam: Camera3D
var holder: Node3D

func build() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(220, 180)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff1e0"); e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e; vp.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -30, 0); sun.light_energy = 1.3; vp.add_child(sun)
	cam = Camera3D.new(); cam.fov = 30; vp.add_child(cam)
	holder = Node3D.new(); vp.add_child(holder)
	_run()

func _run() -> void:
	if DisplayServer.get_name() == "headless": # balance runs: no renderer, no thumbnails
		await get_tree().process_frame
		ready_all.emit(); return
	for d in DB.FIXTURES:
		UIKit.clear(holder)
		var m := Props.build(d)
		holder.add_child(m["root"])
		Art.stylize(m["root"], false)
		var h: float = m["height"]
		var span := maxf(float(d["w"]), h * 0.8)
		cam.position = Vector3(span * 0.9, h * 0.75 + span * 0.35, span * 1.6 + 0.8)
		cam.look_at(Vector3(0, h * 0.45, 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		fixtures[d["id"]] = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.size = Vector2i(128, 128)
	for p in DB.PRODUCTS:
		UIKit.clear(holder)
		var mi := MeshInstance3D.new(); mi.mesh = Products3D.mesh(p["id"]); mi.material_override = Art.vcol_mat(); holder.add_child(mi)
		mi.scale = Vector3.ONE * 2.2
		mi.rotation.y = -0.5
		cam.position = Vector3(0.0, 0.55, 1.1)
		cam.look_at(Vector3(0, 0.2, 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		products[p["id"]] = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	ready_all.emit()
