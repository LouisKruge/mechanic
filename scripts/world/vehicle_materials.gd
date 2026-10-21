class_name VehicleMaterials
extends RefCounted
## Per-vehicle PBR materials (paint colour, rim finish) plus shared ones.
##
## Surface detail comes from procedurally generated noise textures (metallic
## flake normal map for paint, tread grain for tyres): no external textures.

static var _shared: Dictionary = {}


static func build(profile: VehicleBodyProfile) -> Dictionary:
	var m := {}
	var paint := StandardMaterial3D.new()
	paint.albedo_color = profile.paint_color
	paint.metallic = 0.65
	paint.roughness = 0.32
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0
	paint.clearcoat_roughness = 0.04
	paint.normal_enabled = true
	paint.normal_texture = _shared_tex(&"flake", 900.0, 0.08)
	paint.normal_scale = 0.08
	paint.uv1_scale = Vector3(6, 6, 6)
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED  # the bay and arches show the inner skin
	m["paint"] = paint
	var rim := StandardMaterial3D.new()
	rim.albedo_color = profile.rim_color
	rim.metallic = 0.85
	rim.roughness = 0.28
	m["rim"] = rim
	var caliper := StandardMaterial3D.new()
	caliper.albedo_color = profile.caliper_color
	caliper.roughness = 0.35
	caliper.metallic = 0.2
	caliper.clearcoat_enabled = true
	m["caliper"] = caliper
	paint.resource_name = "MAT_paint"
	rim.resource_name = "MAT_rim"
	caliper.resource_name = "MAT_caliper"
	for k: String in ["glass", "lens", "tail_lens", "tail_glow", "drl", "chrome", "chrome_dark", "plastic_black", "tyre", "disc", "liner", "shut", "bay", "trim", "leather", "carpet"]:
		m[k] = shared(StringName(k))
	return m


static func shared(name: StringName) -> StandardMaterial3D:
	if _shared.has(name):
		return _shared[name]
	var m := StandardMaterial3D.new()
	match name:
		&"glass":
			m.albedo_color = Color(0.06, 0.07, 0.08, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.9
			m.roughness = 0.02
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"lens":
			m.albedo_color = Color(0.85, 0.88, 0.9, 0.18)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.3
			m.roughness = 0.02
		&"tail_lens":
			m.albedo_color = Color(0.5, 0.02, 0.02, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.2
		&"tail_glow":
			m.albedo_color = Color(1, 0.1, 0.08)
			m.emission_enabled = true
			m.emission = Color(1, 0.08, 0.05)
			m.emission_energy_multiplier = 1.4
		&"drl":
			m.albedo_color = Color(1, 1, 1)
			m.emission_enabled = true
			m.emission = Color(0.92, 0.95, 1.0)
			m.emission_energy_multiplier = 2.0
		&"chrome":
			m.albedo_color = Color(0.9, 0.9, 0.92)
			m.metallic = 1.0
			m.roughness = 0.08
		&"chrome_dark":
			m.albedo_color = Color(0.18, 0.18, 0.2)
			m.metallic = 1.0
			m.roughness = 0.18
		&"plastic_black":
			m.albedo_color = Color(0.035, 0.035, 0.04)
			m.roughness = 0.55
			m.normal_enabled = true
			m.normal_texture = _shared_tex(&"grain", 400.0, 0.3)
			m.normal_scale = 0.25
			m.uv1_scale = Vector3(4, 4, 4)
		&"tyre":
			m.albedo_color = Color(0.045, 0.045, 0.048)
			m.roughness = 0.86
			m.normal_enabled = true
			m.normal_texture = _shared_tex(&"tread", 120.0, 0.6)
			m.normal_scale = 0.5
			m.uv1_scale = Vector3(30, 2, 1)
		&"disc":
			m.albedo_color = Color(0.36, 0.36, 0.37)
			m.metallic = 0.85
			m.roughness = 0.42
		&"liner":
			m.albedo_color = Color(0.02, 0.02, 0.022)
			m.roughness = 0.95
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"shut":
			m.albedo_color = Color(0.01, 0.01, 0.012)
			m.roughness = 0.9
		&"bay":
			m.albedo_color = Color(0.09, 0.09, 0.1)
			m.roughness = 0.7
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"trim":
			m.albedo_color = Color(0.06, 0.06, 0.065)
			m.roughness = 0.6
		&"leather":
			m.albedo_color = Color(0.09, 0.08, 0.075)
			m.roughness = 0.55
			m.normal_enabled = true
			m.normal_texture = _shared_tex(&"leather", 300.0, 0.4)
			m.normal_scale = 0.3
			m.uv1_scale = Vector3(3, 3, 3)
		&"carpet":
			m.albedo_color = Color(0.05, 0.05, 0.055)
			m.roughness = 1.0
	m.resource_name = "MAT_" + String(name)
	_shared[name] = m
	return m


## Tileable noise normal map. [param freq] in cycles per texture.
static func _shared_tex(name: StringName, freq: float, _strength: float) -> Texture2D:
	var key := StringName("tex_" + name)
	if _shared.has(key):
		return _shared[key]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR if name == &"leather" else FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = freq / 256.0 / 8.0
	noise.fractal_octaves = 2
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 4.0
	tex.noise = noise
	_shared[key] = tex
	return tex
