class_name WheelBuilder
extends RefCounted
## Procedural wheel: tyre (lathe with sidewall bulge and tread grooves), rim
## (barrel, dished spokes, hub, lug nuts) and a non-rotating brake assembly.
## The axle is local X; the outer face points +X (right) or -X (left).


static func build(radius: float, width: float, rim_radius: float, spokes: int, twin: bool, mats: Dictionary, left: bool) -> Node3D:
	var root := Node3D.new()
	var spin := Node3D.new()
	spin.name = "Spin"  # rotates with the wheel (tyre + rim)
	root.add_child(spin)
	var axis_rot := Vector3(0, 0, 90 if left else -90)
	var w := width * 0.5
	var R := radius
	var rr := rim_radius
	# Tyre profile (r, y): inner bead -> inner sidewall -> tread -> outer sidewall -> outer bead.
	var tp := PackedVector2Array([
		Vector2(rr + 0.004, -w + 0.02), Vector2(rr + 0.018, -w - 0.002), Vector2(lerpf(rr, R, 0.55), -w - 0.008),
		Vector2(R - 0.025, -w + 0.002), Vector2(R - 0.006, -w + 0.02), Vector2(R, -w + 0.04),
	])
	for g: float in [-0.45, -0.15, 0.15, 0.45]:
		var gy := g * w
		tp.append(Vector2(R, gy - 0.008))
		tp.append(Vector2(R - 0.007, gy - 0.005))
		tp.append(Vector2(R - 0.007, gy + 0.005))
		tp.append(Vector2(R, gy + 0.008))
	tp.append_array(PackedVector2Array([
		Vector2(R, w - 0.04), Vector2(R - 0.006, w - 0.02), Vector2(R - 0.025, w - 0.002),
		Vector2(lerpf(rr, R, 0.55), w + 0.008), Vector2(rr + 0.018, w + 0.002), Vector2(rr + 0.004, w - 0.02),
	]))
	ProcMesh.add(spin, ProcMesh.lathe(tp, 48), mats.get("tyre"), Vector3.ZERO, axis_rot, "Tire")
	# Rim barrel with outer lip.
	var rp := PackedVector2Array([
		Vector2(rr - 0.03, -w + 0.03), Vector2(rr, -w + 0.012), Vector2(rr + 0.008, -w + 0.004), Vector2(rr - 0.004, -w + 0.0),
		Vector2(rr - 0.022, -w + 0.02), Vector2(rr - 0.03, w * 0.2), Vector2(rr - 0.022, w - 0.02),
		Vector2(rr - 0.004, w + 0.0), Vector2(rr + 0.008, w + 0.004), Vector2(rr, w - 0.004), Vector2(rr - 0.02, w - 0.01),
	])
	var rim := Node3D.new()
	rim.name = "Rim"
	rim.rotation_degrees = axis_rot
	spin.add_child(rim)
	ProcMesh.add(rim, ProcMesh.lathe(rp, 40), mats.get("rim"), Vector3.ZERO, Vector3.ZERO, "Barrel")
	var face_y := w - 0.035
	var n := maxi(3, spokes)
	var spoke_len := rr - 0.075
	for i: int in n:
		for t: int in (2 if twin else 1):
			var ang := TAU * i / n + (0.0 if not twin else (t - 0.5) * 0.16)
			var sp := ProcMesh.rounded_box(Vector3(0.03 if twin else 0.042, 0.022, spoke_len), 0.01)
			var mi := ProcMesh.add(rim, sp, mats.get("rim"), Vector3(sin(ang) * (0.06 + spoke_len * 0.5), face_y - 0.012, cos(ang) * (0.06 + spoke_len * 0.5)), Vector3(-7.0, rad_to_deg(ang), 0))
			mi.name = "Spoke%d_%d" % [i, t]
	ProcMesh.add(rim, ProcMesh.lathe(PackedVector2Array([Vector2(0.0, face_y + 0.004), Vector2(0.03, face_y + 0.004), Vector2(0.075, face_y - 0.01), Vector2(0.08, face_y - 0.04), Vector2(0.0, face_y - 0.04)]), 32), mats.get("rim"), Vector3.ZERO, Vector3.ZERO, "Hub")
	ProcMesh.add(rim, ProcMesh.lathe(PackedVector2Array([Vector2(0.0, face_y + 0.012), Vector2(0.026, face_y + 0.01), Vector2(0.027, face_y)]), 24), mats.get("chrome_dark"), Vector3.ZERO, Vector3.ZERO, "CentreCap")
	for k: int in 5:
		var a := TAU * k / 5.0 + 0.3
		ProcMesh.add(rim, ProcMesh.hex_head(0.017, 0.014), mats.get("chrome"), Vector3(sin(a) * 0.05, face_y - 0.004, cos(a) * 0.05), Vector3.ZERO, "Lug%d" % k)
	# Brake: disc spins, caliper is fixed to the upright.
	var disc_r := minf(rr - 0.035, 0.19)
	var brake := Node3D.new()
	brake.name = "Brake"
	brake.rotation_degrees = axis_rot
	root.add_child(brake)
	var dp := PackedVector2Array([Vector2(0.075, -0.03), Vector2(disc_r, -0.03), Vector2(disc_r, 0.0), Vector2(0.11, 0.0), Vector2(0.1, 0.03), Vector2(0.06, 0.035), Vector2(0.0, 0.035)])
	# The disc stays on the hub when the road wheel is removed.
	ProcMesh.add(brake, ProcMesh.lathe(dp, 40), mats.get("disc"), Vector3(0, -0.02, 0), Vector3.ZERO, "Disc")
	var cal := ProcMesh.add(brake, ProcMesh.rounded_box(Vector3(0.11, 0.07, 0.16), 0.03), mats.get("caliper"), Vector3(0, -0.02, 0), Vector3.ZERO, "Caliper")
	# Caliper sits at the trailing upper edge of the disc.
	cal.position = Vector3(disc_r * 0.62, -0.025, -disc_r * 0.62)
	cal.rotation_degrees = Vector3(0, 45, 0)
	return root
