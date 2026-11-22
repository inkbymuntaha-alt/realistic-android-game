class_name Piece
extends RigidBody3D
## One stackable object (stone slab, pebble disc, wood block, ceramic block).

var kind := "stone"
var half_height := 0.1
var held := true
var size := Vector3(0.3, 0.2, 0.3)

static func create(kind_: String, shape_name: String, size: Vector3, seed_: int) -> Piece:
	var p := Piece.new()
	p.kind = kind_
	p.half_height = size.y * 0.5
	p.size = size
	var mesh := MeshInstance3D.new()
	var col := CollisionShape3D.new()
	if shape_name == "disc":
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 0.5
		cm.bottom_radius = size.x * 0.5
		cm.height = size.y
		cm.radial_segments = 24
		mesh.mesh = cm
		var cs := CylinderShape3D.new()
		cs.radius = size.x * 0.5
		cs.height = size.y
		col.shape = cs
	else:
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		var bs := BoxShape3D.new()
		bs.size = size
		col.shape = bs
	mesh.material_override = Materials.make(kind_, seed_)
	p.add_child(mesh)
	p.add_child(col)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9 if kind_ != "ceramic" else 0.6
	pm.bounce = 0.02
	p.physics_material_override = pm
	# Heavier materials weigh more (approx. density * volume); gives natural momentum.
	var density: float = {"stone": 2600.0, "wood": 700.0, "ceramic": 2300.0}.get(kind_, 1000.0)
	p.mass = density * size.x * size.y * size.z * (0.785 if shape_name == "disc" else 1.0)
	p.linear_damp = 0.15
	p.angular_damp = 0.8
	p.can_sleep = true
	p.freeze = true  # held until released
	return p

func release() -> void:
	held = false
	freeze = false

func is_settled() -> bool:
	return held or sleeping or (linear_velocity.length() < 0.03 and angular_velocity.length() < 0.08)

## Highest point of the piece, using its rotated bounding box (tilted pieces count correctly).
func top_y() -> float:
	var best := -INF
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var corner: Vector3 = global_transform * Vector3(size.x * sx, size.y * sy, size.z * sz)
				best = maxf(best, corner.y)
	return best
