class_name Materials
extends RefCounted
## Procedural PBR materials (albedo + roughness + normal) so no binary textures need shipping.

static func _noise(freq: float, seed_: int, octaves: int = 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_
	return n

static func _tex(freq: float, seed_: int, normal: bool, ramp: Gradient = null) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = _noise(freq, seed_)
	if normal:
		t.as_normal_map = true
		t.bump_strength = 4.0
	if ramp:
		t.color_ramp = ramp
	return t

static func _ramp(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([a, b])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	return g

static func make(kind: String, seed_: int = 1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2, 2, 2)
	match kind:
		"stone":
			m.albedo_texture = _tex(0.02, seed_, false, _ramp(Color(0.38, 0.37, 0.35), Color(0.62, 0.60, 0.56)))
			m.roughness = 0.92
			m.normal_enabled = true
			m.normal_texture = _tex(0.05, seed_ + 7, true)
			m.normal_scale = 0.8
		"wood":
			m.albedo_texture = _tex(0.015, seed_, false, _ramp(Color(0.33, 0.21, 0.11), Color(0.58, 0.40, 0.22)))
			m.uv1_scale = Vector3(1, 6, 1)
			m.roughness = 0.75
			m.normal_enabled = true
			m.normal_texture = _tex(0.03, seed_ + 3, true)
			m.normal_scale = 0.5
		"ceramic":
			m.albedo_color = Color(0.9, 0.88, 0.82)
			m.roughness = 0.25
			m.metallic_specular = 0.6
			m.clearcoat_enabled = true
			m.clearcoat = 0.5
			m.clearcoat_roughness = 0.2
		"ground":
			m.albedo_texture = _tex(0.01, seed_, false, _ramp(Color(0.25, 0.25, 0.23), Color(0.42, 0.41, 0.38)))
			m.roughness = 0.95
			m.normal_enabled = true
			m.normal_texture = _tex(0.04, seed_ + 5, true)
		"water":
			m.albedo_color = Color(0.12, 0.28, 0.32)
			m.roughness = 0.08
			m.metallic = 0.2
			m.metallic_specular = 0.9
		_:
			m.albedo_color = Color.GRAY
	return m
