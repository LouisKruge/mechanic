class_name VehicleBodyBuilder
extends RefCounted
## Builds a vehicle body from a [VehicleBodyProfile] by lofting cross-sections
## along the car's length.
##
## The output follows the vehicle model naming convention
## (docs/ASSET_PIPELINE.md), so the procedural body and an imported glTF body
## are interchangeable:
##   Body_shell, Bumper_F, Bumper_R, Panel_hood, Panel_door_L, Panel_door_R,
##   Panel_trunk, Glass_cabin, ShutLines, Light_head_L/R, Light_tail_L/R,
##   Grille, Mirror_L/R, Interior, Exhaust, Wheel_FL/FR/RL/RR, Bay_firewall
##
## This is original procedural placeholder art, not a reproduction of any
## manufacturer's design.

## Ring points per side (bottom centre .. roof centre).
const RING_POINTS: int = 10
## Ring segment indices (point i -> i+1) by role.
const SEG_SIDE_DOOR: Array[int] = [2, 3, 4, 5]
const SEG_TOP: Array[int] = [6, 7, 8]
const SEG_GREENHOUSE: int = 7
const SEG_ROOF: int = 8

var p: VehicleBodyProfile


func _init(profile: VehicleBodyProfile) -> void:
	p = profile


# --- Shape functions -----------------------------------------------------------

func z_front() -> float:
	return -p.length * 0.5


func z_rear() -> float:
	return p.length * 0.5


## Half width in plan view (superellipse).
func half_width_at(z: float) -> float:
	var t := clampf(absf(z) / (p.length * 0.5), 0.0, 1.0)
	return p.half_width * pow(maxf(0.0, 1.0 - pow(t, p.plan_exponent)), 1.0 / p.plan_exponent)


## Top surface (hood / beltline / deck) height.
func top_at(z: float) -> float:
	if z <= p.windscreen_base_z:
		var t := clampf((z - z_front()) / (p.windscreen_base_z - z_front()), 0.0, 1.0)
		var y := lerpf(p.nose_top_y, p.cowl_y, 1.0 - pow(1.0 - t, p.hood_curve))
		return y
	if z <= p.deck_start_z:
		var t2 := clampf((z - p.windscreen_base_z) / (p.deck_start_z - p.windscreen_base_z), 0.0, 1.0)
		return lerpf(p.cowl_y, p.deck_y, smoothstep(0.0, 1.0, t2))
	var t3 := clampf((z - p.deck_start_z) / (z_rear() - p.deck_start_z), 0.0, 1.0)
	return lerpf(p.deck_y, p.tail_top_y, t3 * t3)


## 0 outside the cabin, 1 under the roof. Windscreen ramp is linear (flat glass).
func cabin_at(z: float) -> float:
	if z <= p.windscreen_base_z or z >= p.deck_start_z:
		return 0.0
	if z < p.roof_front_z:
		return (z - p.windscreen_base_z) / (p.roof_front_z - p.windscreen_base_z)
	if z <= p.roof_rear_z:
		return 1.0
	var t := (z - p.roof_rear_z) / (p.deck_start_z - p.roof_rear_z)
	return 1.0 - smoothstep(0.0, 1.0, t)


func bottom_at(z: float) -> float:
	var end := clampf(1.0 - (minf(z - z_front(), z_rear() - z) / 0.35), 0.0, 1.0)
	return p.sill_y + 0.1 * end * end


## Height of the wheel-arch opening at z, or -INF outside the arches.
func arch_at(z: float) -> float:
	var best := -INF
	for axle: Array in [[p.front_axle_z, p.wheel_radius_front], [p.rear_axle_z, p.wheel_radius_rear]]:
		var ra: float = float(axle[1]) + p.arch_clearance
		var dz: float = z - float(axle[0])
		if absf(dz) < ra:
			best = maxf(best, float(axle[1]) + sqrt(ra * ra - dz * dz))
	return best


func flare_at(z: float) -> float:
	var f := 0.0
	for az: float in [p.front_axle_z, p.rear_axle_z]:
		f = maxf(f, 1.0 - clampf(absf(z - az) / 0.6, 0.0, 1.0))
	return p.arch_flare * smoothstep(0.0, 1.0, f)


## Right-half cross-section (x >= 0) as RING_POINTS points.
func half_ring(z: float) -> PackedVector2Array:
	var w := half_width_at(z)
	var wf := w + flare_at(z) * (w / p.half_width)
	var top := top_at(z)
	var c := cabin_at(z)
	var bottom := bottom_at(z)
	var shoulder := top - 0.035
	var roof := lerpf(top + 0.012, p.roof_y, c)
	var gw := w * p.greenhouse_ratio
	var pts := PackedVector2Array([
		Vector2(0.0, bottom),
		Vector2(0.7 * w, bottom),
		Vector2(0.95 * wf, bottom + 0.04),
		Vector2(wf, bottom + 0.16),
		Vector2(wf, shoulder - 0.13),
		Vector2(0.985 * wf, shoulder),
		Vector2(0.93 * w, top),
		Vector2(lerpf(0.86 * w, gw, c), lerpf(top + 0.005, top + 0.03, c)),
		Vector2(lerpf(0.55 * w, gw * 0.86, c), roof),
		Vector2(0.0, roof + lerpf(0.008, 0.02, c)),
	])
	var arch := arch_at(z)
	if arch > -INF:
		var cap := shoulder - 0.05
		for i: int in [1, 2, 3, 4]:
			var y := minf(maxf(pts[i].y, arch), cap - 0.01 * (4 - i))
			pts[i] = Vector2(pts[i].x, y)
		for i: int in range(2, 6):
			if pts[i].y <= pts[i - 1].y:
				pts[i] = Vector2(pts[i].x, pts[i - 1].y + 0.004)
	return pts


## Full closed ring at z: right side bottom->top, then left side top->bottom.
func ring(z: float) -> PackedVector3Array:
	var h := half_ring(z)
	var out := PackedVector3Array()
	for v: Vector2 in h:
		out.append(Vector3(v.x, v.y, z))
	for i: int in range(RING_POINTS - 2, 0, -1):
		out.append(Vector3(-h[i].x, h[i].y, z))
	return out


## Station list with every panel boundary included exactly.
func stations() -> PackedFloat32Array:
	var zs: Array[float] = []
	var z := z_front() + 0.002
	while z < z_rear() - 0.002:
		zs.append(z)
		z += p.station_spacing
	zs.append(z_rear() - 0.002)
	for b: float in [p.hood_front_z, p.hood_rear_z, p.windscreen_base_z, p.roof_front_z, p.roof_rear_z, p.deck_start_z, p.door_front_z, p.door_rear_z, p.trunk_front_z, z_front() + p.bumper_depth, z_rear() - p.bumper_depth]:
		zs.append(b)
	zs.sort()
	var out := PackedFloat32Array()
	for v: float in zs:
		if out.is_empty() or v - out[out.size() - 1] > 0.004:
			out.append(v)
	return out


# --- Panel classification -------------------------------------------------------------

## Which part a ring quad belongs to. [param seg] is the per-side segment index.
func part_for(zm: float, seg: int, left: bool) -> String:
	var c := cabin_at(zm)
	if seg == SEG_ROOF and zm > p.windscreen_base_z + 0.01 and zm < p.roof_front_z - 0.01:
		return "Glass_cabin"
	if seg == SEG_ROOF and zm > p.roof_rear_z + 0.02 and zm < p.deck_start_z - 0.06:
		return "Glass_cabin"
	if seg == SEG_GREENHOUSE and c > 0.12 and zm < p.roof_rear_z + 0.25:
		# Driver's window is wound down so the ignition and diagnostic port are reachable.
		if left and p.driver_window_open and zm < p.door_rear_z:
			return ""
		return "Glass_cabin"
	if SEG_TOP.has(seg) and zm > p.hood_front_z and zm < p.hood_rear_z:
		return "Panel_hood"
	if SEG_TOP.has(seg) and zm > p.trunk_front_z and zm < z_rear() - p.bumper_depth:
		return "Panel_trunk"
	if SEG_SIDE_DOOR.has(seg) and zm > p.door_front_z and zm < p.door_rear_z:
		return "Panel_door_L" if left else "Panel_door_R"
	if zm < z_front() + p.bumper_depth:
		return "Bumper_F"
	if zm > z_rear() - p.bumper_depth:
		return "Bumper_R"
	return "Body_shell"


## Builds {part_name: ArrayMesh} for every body panel.
func build_panels() -> Dictionary:
	var zs := stations()
	var rings: Array[PackedVector3Array] = []
	for z: float in zs:
		rings.append(ring(z))
	var tools := {}
	var n := rings[0].size()
	var per_side := RING_POINTS - 1
	for r: int in rings.size() - 1:
		var zm := (zs[r] + zs[r + 1]) * 0.5
		for j: int in n:
			var j1 := (j + 1) % n
			var seg: int
			var left := false
			if j < per_side:
				seg = j
			else:
				left = true
				seg = n - 1 - j
			var part := part_for(zm, seg, left)
			if part == "":
				continue
			if not tools.has(part):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_smooth_group(0)
				tools[part] = st
			var a := rings[r]
			var b := rings[r + 1]
			ProcMesh._quad(tools[part], a[j], a[j1], b[j1], b[j], Vector2(zs[r], float(j) / n), Vector2(zs[r], float(j1) / n), Vector2(zs[r + 1], float(j1) / n), Vector2(zs[r + 1], float(j) / n))
	var out := {}
	for part: String in tools:
		var st: SurfaceTool = tools[part]
		st.generate_normals()
		st.generate_tangents()
		out[part] = st.commit()
	return out


## Thin dark lines along panel boundaries (hood, doors, trunk).
func build_shut_lines() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines: Array = []
	# Hood edges are not drawn: the lines would float over the bay when the hood opens.
	for z: float in [p.trunk_front_z]:
		var r := ring(z)
		var path := PackedVector3Array()
		for j: int in range(6, RING_POINTS + RING_POINTS - 5):
			path.append(r[j % r.size()] + Vector3(0, 0.0015, 0))
		lines.append(path)
	for z: float in [p.door_front_z, p.door_rear_z]:
		var r2 := ring(z)
		for side: int in 2:
			var path2 := PackedVector3Array()
			for k: int in range(2, 7):
				var idx := k if side == 0 else r2.size() - k
				var v := r2[idx]
				path2.append(v + Vector3(signf(v.x) * 0.0015, 0, 0))
			lines.append(path2)
	# Door bottom/top edges.
	for side: float in [1.0, -1.0]:
		for k: int in [2, 6]:
			var path3 := PackedVector3Array()
			var z := p.door_front_z
			while z <= p.door_rear_z + 0.001:
				var h := half_ring(z)
				path3.append(Vector3(side * (h[k].x + 0.0015), h[k].y, z))
				z += 0.05
			lines.append(path3)
	for path: PackedVector3Array in lines:
		if path.size() < 2:
			continue
		var m := ProcMesh.tube(path, 0.0022, 4, false)
		st.append_from(m, 0, Transform3D.IDENTITY)
	return st.commit()


## Ring polygon closing the bay at the firewall.
func build_firewall() -> ArrayMesh:
	var r := ring(p.hood_rear_z + 0.04)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	ProcMesh.add_cap(st, r, false)
	st.generate_normals()
	return st.commit()


## Z of the body's front (or rear) surface at lateral offset x (bisection on the plan shape).
func end_surface_z(x: float, front: bool) -> float:
	var lo := 0.0
	var hi := p.length * 0.5
	for i: int in 30:
		var mid := (lo + hi) * 0.5
		if half_width_at(mid) > absf(x):
			lo = mid
		else:
			hi = mid
	return -lo if front else lo


## A/B/C pillars as tubes along the greenhouse edges.
func build_pillars() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var a := PackedVector3Array()
		var z := p.windscreen_base_z + 0.01
		while z <= p.roof_front_z + 0.001:
			var h := half_ring(z)
			a.append(Vector3(side * h[8].x, h[8].y, z))
			z += 0.04
		var cpath := PackedVector3Array()
		z = p.roof_rear_z
		while z <= p.deck_start_z:
			var h2 := half_ring(z)
			cpath.append(Vector3(side * h2[8].x, h2[8].y, z))
			z += 0.04
		var hb := half_ring(p.door_rear_z)
		var bpath := PackedVector3Array([Vector3(side * hb[6].x, hb[6].y, p.door_rear_z), Vector3(side * hb[8].x, hb[8].y, p.door_rear_z)])
		for path: PackedVector3Array in [a, cpath]:
			if path.size() > 1:
				st.append_from(ProcMesh.tube(path, 0.02, 8, true), 0, Transform3D.IDENTITY)
		st.append_from(ProcMesh.tube(bpath, 0.022, 6, true), 0, Transform3D.IDENTITY)
		# Roof rails along the top edge of the side glass.
		var rail := PackedVector3Array()
		z = p.roof_front_z
		while z <= p.roof_rear_z + 0.001:
			var h3 := half_ring(z)
			rail.append(Vector3(side * h3[8].x, h3[8].y, z))
			z += 0.08
		if rail.size() > 1:
			st.append_from(ProcMesh.tube(rail, 0.012, 6, true), 0, Transform3D.IDENTITY)
	return st.commit()


## Assembles the full body model under a new Node3D named "BodyModel".
func build(mats: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BodyModel"
	var panels := build_panels()
	for part: String in panels:
		var mat: Material = mats.get("glass") if part.begins_with("Glass") else mats.get("paint")
		ProcMesh.add(root, panels[part], mat, Vector3.ZERO, Vector3.ZERO, part)
	ProcMesh.add(root, build_shut_lines(), mats.get("shut"), Vector3.ZERO, Vector3.ZERO, "ShutLines")
	ProcMesh.add(root, build_pillars(), mats.get("paint"), Vector3.ZERO, Vector3.ZERO, "Pillars")
	ProcMesh.add(root, build_firewall(), mats.get("bay"), Vector3.ZERO, Vector3.ZERO, "Bay_firewall")
	_build_lights(root, mats)
	_build_grille(root, mats)
	_build_mirrors(root, mats)
	_build_exhaust(root, mats)
	_build_wheelhouses(root, mats)
	_build_underbody(root, mats)
	root.add_child(InteriorBuilder.new(self).build(mats))
	for w: Array in wheel_layout():
		var wheel := WheelBuilder.build(w[1], w[2], w[3], p.spoke_count, p.twin_spokes, mats, w[4])
		wheel.name = w[0]
		wheel.position = w[5]
		root.add_child(wheel)
	return root


## [name, radius, tyre width, rim radius, mirror(left side), position].
func wheel_layout() -> Array:
	var out: Array = []
	for axle: Array in [["F", p.front_axle_z, p.wheel_radius_front, p.tyre_width_front, p.rim_radius_front], ["R", p.rear_axle_z, p.wheel_radius_rear, p.tyre_width_rear, p.rim_radius_rear]]:
		for side: Array in [["L", -1.0], ["R", 1.0]]:
			out.append(["Wheel_%s%s" % [axle[0], side[0]], axle[2], axle[3], axle[4], side[1] < 0.0, Vector3(side[1] * p.wheel_x, axle[2], axle[1])])
	return out


func _build_lights(root: Node3D, mats: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		var lx := p.half_width * 0.62
		var lz := end_surface_z(lx + 0.12, true) + 0.03
		var hy := top_at(lz + 0.08) - 0.05
		var head := Node3D.new()
		head.name = "Light_head_%s" % ("L" if side < 0 else "R")
		head.position = Vector3(side * lx, hy, lz)
		head.rotation_degrees = Vector3(-8, side * -12.0, 0)
		root.add_child(head)
		ProcMesh.add(head, ProcMesh.rounded_box(Vector3(0.36, 0.085, 0.08), 0.03), mats.get("lens"), Vector3(0, 0, 0.01), Vector3.ZERO, "Lens")
		ProcMesh.add(head, ProcMesh.rounded_box(Vector3(0.34, 0.07, 0.05), 0.026), mats.get("chrome_dark"), Vector3(0, 0, 0.03), Vector3.ZERO, "Housing")
		for i: int in 2:
			ProcMesh.add(head, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.022, 0), Vector2(0.026, 0.02), Vector2(0, 0.02)]), 20), mats.get("chrome"), Vector3(side * (-0.07 + i * 0.11), 0, 0.0), Vector3(-90, 0, 0), "Projector%d" % i)
		ProcMesh.add(head, ProcMesh.rounded_box(Vector3(0.3, 0.008, 0.01), 0.004), mats.get("drl"), Vector3(0, -0.028, -0.022), Vector3.ZERO, "DRL")
	for side2: float in [-1.0, 1.0]:
		var tx := p.half_width * 0.6
		var tz := end_surface_z(tx + 0.14, false) - 0.025
		var ty := top_at(tz - 0.05) - 0.07
		var tail := Node3D.new()
		tail.name = "Light_tail_%s" % ("L" if side2 < 0 else "R")
		tail.position = Vector3(side2 * tx, ty, tz)
		tail.rotation_degrees = Vector3(0, side2 * 14.0, 0)
		root.add_child(tail)
		ProcMesh.add(tail, ProcMesh.rounded_box(Vector3(0.42, 0.07, 0.06), 0.025), mats.get("tail_lens"), Vector3.ZERO, Vector3.ZERO, "Lens")
		ProcMesh.add(tail, ProcMesh.rounded_box(Vector3(0.38, 0.012, 0.01), 0.005), mats.get("tail_glow"), Vector3(0, 0.012, 0.028), Vector3.ZERO, "Glow")


func _build_grille(root: Node3D, mats: Dictionary) -> void:
	var g := Node3D.new()
	g.name = "Grille"
	var zf := end_surface_z(p.half_width * 0.35, true) + 0.025
	g.position = Vector3(0, bottom_at(zf) + 0.13, zf)
	root.add_child(g)
	var iw := p.half_width * 0.8
	# Lower intake with horizontal slats, outer brake-cooling inlets, splitter.
	ProcMesh.add(g, ProcMesh.rounded_box(Vector3(iw, 0.11, 0.05), 0.035), mats.get("plastic_black"), Vector3.ZERO, Vector3.ZERO, "Intake")
	for i: int in 3:
		ProcMesh.add(g, ProcMesh.rounded_box(Vector3(iw * 0.95, 0.006, 0.02), 0.002), mats.get("chrome_dark"), Vector3(0, -0.03 + i * 0.03, -0.022))
	for side: float in [-1.0, 1.0]:
		var ox := p.half_width * 0.68
		var oz := end_surface_z(ox + 0.06, true) + 0.03
		ProcMesh.add(g, ProcMesh.rounded_box(Vector3(0.14, 0.09, 0.05), 0.035), mats.get("plastic_black"), Vector3(side * ox, -0.005, oz - zf), Vector3(0, side * -14.0, 0))
	var uz := end_surface_z(p.half_width * 0.25, true) + 0.035
	ProcMesh.add(g, ProcMesh.rounded_box(Vector3(p.half_width * 0.55, 0.05, 0.04), 0.022), mats.get("plastic_black"), Vector3(0, top_at(uz + 0.05) - 0.08 - g.position.y, uz - zf), Vector3.ZERO, "UpperGrille")
	ProcMesh.add(g, ProcMesh.rounded_box(Vector3(p.half_width * 1.7, 0.014, 0.1), 0.006), mats.get("plastic_black"), Vector3(0, -0.12, 0.03), Vector3.ZERO, "Splitter")


func _build_mirrors(root: Node3D, mats: Dictionary) -> void:
	var z := p.windscreen_base_z + 0.16
	var h := half_ring(z)
	for side: float in [-1.0, 1.0]:
		var m := Node3D.new()
		m.name = "Mirror_%s" % ("L" if side < 0 else "R")
		m.position = Vector3(side * (h[6].x + 0.11), h[6].y + 0.09, z)
		root.add_child(m)
		ProcMesh.add(m, ProcMesh.rounded_box(Vector3(0.17, 0.1, 0.09), 0.04), mats.get("paint"), Vector3.ZERO, Vector3(0, side * 12.0, 0), "Housing")
		ProcMesh.add(m, ProcMesh.rounded_box(Vector3(0.15, 0.08, 0.005), 0.03), mats.get("chrome"), Vector3(0, 0, 0.046), Vector3(0, side * 12.0, 0), "Glass")
		ProcMesh.add(m, ProcMesh.rounded_box(Vector3(0.09, 0.025, 0.04), 0.01), mats.get("plastic_black"), Vector3(-side * 0.08, -0.04, 0.0), Vector3.ZERO, "Stalk")


func _build_exhaust(root: Node3D, mats: Dictionary) -> void:
	var ex := Node3D.new()
	ex.name = "Exhaust"
	root.add_child(ex)
	var zr := z_rear() - 0.02
	var y := bottom_at(zr) + 0.05
	var count := maxi(1, p.exhaust_tips)
	for i: int in count:
		var side := -1.0 if i < (count + 1) / 2 else 1.0
		var k := i % maxi(1, count / 2)
		var x := side * (0.38 + k * 0.11)
		ProcMesh.add(ex, ProcMesh.lathe(PackedVector2Array([Vector2(0.042, 0.0), Vector2(0.046, 0.0), Vector2(0.046, 0.12), Vector2(0.04, 0.12), Vector2(0.04, 0.01)]), 24), mats.get("chrome"), Vector3(x, y, zr - 0.06), Vector3(90, 0, 0), "Tip%d" % i)
	ProcMesh.add(ex, ProcMesh.rounded_box(Vector3(half_width_at(zr) * 1.3, 0.09, 0.08), 0.03), mats.get("plastic_black"), Vector3(0, y + 0.02, zr - 0.01), Vector3.ZERO, "Diffuser")


func _build_wheelhouses(root: Node3D, mats: Dictionary) -> void:
	# Dark half-cylinder liners above each wheel so the arch reads as an opening.
	for w: Array in wheel_layout():
		var r: float = float(w[1]) + p.arch_clearance - 0.005
		var pos: Vector3 = w[5]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(0)
		var steps := 16
		var x0 := pos.x - signf(pos.x) * 0.17
		var x1 := pos.x + signf(pos.x) * 0.1
		for i: int in steps:
			var a0 := PI * i / steps
			var a1 := PI * (i + 1) / steps
			var p0 := Vector3(0, sin(a0) * r, -cos(a0) * r)
			var p1 := Vector3(0, sin(a1) * r, -cos(a1) * r)
			ProcMesh._quad(st, Vector3(x0, pos.y, pos.z) + p0, Vector3(x1, pos.y, pos.z) + p0, Vector3(x1, pos.y, pos.z) + p1, Vector3(x0, pos.y, pos.z) + p1, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		st.generate_normals()
		var mi := ProcMesh.add(root, st.commit(), mats.get("liner"), Vector3.ZERO, Vector3.ZERO, "Wheelhouse_" + String(w[0]).trim_prefix("Wheel_"))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_underbody(root: Node3D, mats: Dictionary) -> void:
	ProcMesh.add(root, ProcMesh.rounded_box(Vector3(p.half_width * 1.5, 0.04, p.length * 0.86), 0.02), mats.get("plastic_black"), Vector3(0, p.sill_y + 0.02, 0), Vector3.ZERO, "Underbody")
