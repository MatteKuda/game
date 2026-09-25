class_name DaySky
extends Node3D
## Sun, sky, ambient and post-processing. set_time(hour) drives the whole day/night cycle.

var env: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var night := 0.0 # 0 day .. 1 night
var overcast := 0.0 # 0 clear .. 1 grey (eased towards _oc_target)
var _oc_target := 0.0
var weather := "gunes"
var rain: GPUParticles3D
var snow: GPUParticles3D
var _hour := 9.0

func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.35
	env.ambient_light_color = Color("b9cdf0")
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.7
	env.ssil_enabled = true
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color("f6dcc2")
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.light_color = Color("9fc2ff")
	fill.light_energy = 0.18
	fill.rotation_degrees = Vector3(-35, 150, 0)
	add_child(fill)
	rain = _precip(false); snow = _precip(true)
	set_time(9.0)

## falling rain streaks / snow flakes in a box that follows the camera target
func _precip(is_snow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 900 if is_snow else 1800
	p.lifetime = 5.0 if is_snow else 1.1
	p.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 0.5, 18)
	pm.direction = Vector3(0.15 if is_snow else 0.08, -1, 0)
	pm.spread = 12.0 if is_snow else 2.0
	pm.initial_velocity_min = 1.2 if is_snow else 16.0
	pm.initial_velocity_max = 2.0 if is_snow else 19.0
	pm.gravity = Vector3(0, -0.6 if is_snow else -9.0, 0)
	if is_snow:
		pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.6; pm.turbulence_noise_scale = 3.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09) if is_snow else Vector2(0.025, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.9) if is_snow else Color(0.8, 0.88, 1.0, 0.38)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if is_snow else BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	p.draw_pass_1 = q
	p.emitting = false
	p.visible = false
	add_child(p)
	return p

func set_weather(kind: String) -> void:
	weather = kind
	_oc_target = {"gunes": 0.0, "sicak": -0.15, "bulut": 0.45, "yagmur": 0.8, "kar": 0.65}.get(kind, 0.0)
	rain.emitting = kind == "yagmur"; rain.visible = rain.emitting
	snow.emitting = kind == "kar"; snow.visible = snow.emitting

## keep the precipitation above what the camera looks at and ease the sky colour
func follow(target: Vector3, dt: float) -> void:
	rain.position = target + Vector3(0, 14, 0)
	snow.position = target + Vector3(0, 12, 0)
	if absf(overcast - _oc_target) > 0.001:
		overcast = move_toward(overcast, _oc_target, dt * 0.25)
		set_time(_hour)

func set_quality(q: String) -> void:
	env.ssil_enabled = q == "high"
	env.ssao_enabled = q != "low"
	env.glow_enabled = q != "low"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == "low" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

func set_time(h: float) -> void:
	_hour = h
	# sun arc: rises ~6:30 east, sets ~20:30 west
	var t := clampf((h - 6.0) / 15.0, 0.0, 1.0)
	var elev := sin(t * PI) * 58.0
	var az := lerpf(-110.0, 110.0, t)
	sun.rotation_degrees = Vector3(-maxf(elev, 6.0), az + 180.0 - 30.0, 0)
	var dusk := clampf(1.0 - absf(h - 13.0) / 7.5, 0.0, 1.0)
	night = clampf((h - 19.5) / 1.5, 0.0, 1.0) + clampf((6.8 - h) / 1.0, 0.0, 1.0)
	night = clampf(night, 0.0, 1.0)
	var warm := Color("ffb878").lerp(Color("ffe6c4"), dusk)
	sun.light_color = warm.lerp(Color("8fa6ff"), night)
	sun.light_energy = lerpf(0.9, 2.1, dusk) * (1.0 - night * 0.8)
	sky_mat.sky_top_color = Color("5d9fd6").lerp(Color("0f1a36"), night).lerp(Color("5b86c4"), (1.0 - dusk) * (1.0 - night) * 0.4)
	sky_mat.sky_horizon_color = Color("f7e0c4").lerp(Color("f39a6b"), (1.0 - dusk) * (1.0 - night)).lerp(Color("2a2f52"), night)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color("6b6158").lerp(Color("141828"), night)
	sky_mat.sun_curve = 0.12
	env.ambient_light_energy = lerpf(0.62, 0.3, night)
	env.fog_light_color = sky_mat.sky_horizon_color
	env.tonemap_exposure = lerpf(0.95, 1.25, night)
	# weather: grey the sky, soften the sun, thicken the haze (a hot day goes the other way)
	var oc := clampf(overcast, 0.0, 1.0) * (1.0 - night * 0.5)
	var grey := Color("9aa3b0") if weather != "kar" else Color("c9d2dc")
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(grey.darkened(0.15), oc)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(grey, oc)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sun.light_energy *= 1.0 - oc * 0.62
	env.ambient_light_energy += oc * 0.12
	env.fog_light_color = sky_mat.sky_horizon_color
	env.fog_density = 0.0022 + oc * 0.006
	if overcast < 0.0:
		sun.light_color = sun.light_color.lerp(Color("ffcf8a"), -overcast * 2.0)
		sun.light_energy *= 1.0 - overcast * 0.6
