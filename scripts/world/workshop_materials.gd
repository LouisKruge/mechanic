class_name WorkshopMaterials
extends RefCounted
## Shared, cached materials for procedural placeholder geometry.
##
## Centralising materials keeps the neutral workshop palette consistent and
## lets production assets replace placeholders without touching gameplay code.

static var _cache: Dictionary = {}


## Returns a cached StandardMaterial3D for a named palette entry.
static func get_mat(name: StringName) -> StandardMaterial3D:
	if _cache.has(name):
		return _cache[name]
	var m := StandardMaterial3D.new()
	match name:
		&"concrete":
			m.albedo_color = Color(0.36, 0.36, 0.37)
			m.roughness = 0.92
			m.albedo_texture = _noise_texture(0.035, 0.84, 1.0)
			m.uv1_scale = Vector3(6, 6, 6)
		&"wall":
			m.albedo_color = Color(0.20, 0.205, 0.215)
			m.roughness = 0.85
		&"wall_lower":
			m.albedo_color = Color(0.13, 0.135, 0.14)
			m.roughness = 0.8
		&"roof":
			m.albedo_color = Color(0.11, 0.11, 0.115)
			m.roughness = 0.9
		&"steel_dark":
			m.albedo_color = Color(0.16, 0.165, 0.17)
			m.metallic = 0.7
			m.roughness = 0.45
		&"steel":
			m.albedo_color = Color(0.55, 0.56, 0.58)
			m.metallic = 0.85
			m.roughness = 0.35
		&"aluminium":
			m.albedo_color = Color(0.72, 0.73, 0.74)
			m.metallic = 0.8
			m.roughness = 0.3
		&"aluminium_burnt":
			m.albedo_color = Color(0.48, 0.42, 0.36)
			m.metallic = 0.7
			m.roughness = 0.55
		&"zinc":
			m.albedo_color = Color(0.68, 0.66, 0.55)
			m.metallic = 0.9
			m.roughness = 0.3
		&"cast_iron":
			m.albedo_color = Color(0.23, 0.23, 0.24)
			m.metallic = 0.6
			m.roughness = 0.7
		&"rubber":
			m.albedo_color = Color(0.05, 0.05, 0.055)
			m.roughness = 0.95
		&"plastic_black":
			m.albedo_color = Color(0.07, 0.07, 0.075)
			m.roughness = 0.6
		&"plastic_grey":
			m.albedo_color = Color(0.3, 0.3, 0.31)
			m.roughness = 0.6
		&"copper":
			m.albedo_color = Color(0.72, 0.45, 0.3)
			m.metallic = 0.9
			m.roughness = 0.35
		&"wood":
			m.albedo_color = Color(0.42, 0.33, 0.24)
			m.roughness = 0.75
		&"paint_body":
			m.albedo_color = Color(0.62, 0.64, 0.66)
			m.metallic = 0.55
			m.roughness = 0.28
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
		&"paint_dark":
			m.albedo_color = Color(0.1, 0.1, 0.11)
			m.metallic = 0.3
			m.roughness = 0.4
		&"glass":
			m.albedo_color = Color(0.05, 0.06, 0.07, 0.72)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.2
			m.roughness = 0.05
		&"lift_paint":
			m.albedo_color = Color(0.25, 0.26, 0.28)
			m.metallic = 0.4
			m.roughness = 0.5
		&"safety_line":
			m.albedo_color = Color(0.78, 0.72, 0.45)
			m.roughness = 0.8
		&"floor_marking":
			m.albedo_color = Color(0.82, 0.82, 0.82)
			m.roughness = 0.8
		&"mat":
			m.albedo_color = Color(0.06, 0.06, 0.065)
			m.roughness = 1.0
		&"light_fixture":
			m.albedo_color = Color(0.9, 0.9, 0.9)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.97, 0.92)
			m.emission_energy_multiplier = 2.5
		&"lamp_off":
			m.albedo_color = Color(0.15, 0.05, 0.03)
			m.roughness = 0.3
		&"lamp_on":
			m.albedo_color = Color(1.0, 0.2, 0.1)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.15, 0.05)
			m.emission_energy_multiplier = 4.0
		&"led_green":
			m.albedo_color = Color(0.1, 0.9, 0.3)
			m.emission_enabled = true
			m.emission = Color(0.1, 1.0, 0.3)
			m.emission_energy_multiplier = 3.0
		&"ghost":
			m.albedo_color = Color(0.85, 0.9, 1.0, 0.18)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"highlight":
			# Applied as material_overlay on targeted parts.
			m.albedo_color = Color(1, 1, 1, 0.12)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.emission_enabled = true
			m.emission = Color(1, 1, 1)
			m.emission_energy_multiplier = 0.4
			m.grow = true
			m.grow_amount = 0.002
		_:
			m.albedo_color = Color(1, 0, 1)
	_cache[name] = m
	return m


static func _noise_texture(freq: float, lo: float, hi: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = freq
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(lo, lo, lo))
	ramp.set_color(1, Color(hi, hi, hi))
	tex.color_ramp = ramp
	return tex
