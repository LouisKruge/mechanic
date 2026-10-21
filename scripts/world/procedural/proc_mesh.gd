class_name ProcMesh
extends RefCounted
## Procedural mesh primitives used for placeholder art: lathe (revolved
## profiles), loft (ring sequences), tubes along paths and extruded profiles.
##
## Everything is original geometry generated at runtime, so it carries no
## third-party licence. Meshes are built with SurfaceTool and smooth normals.


## Revolves [param profile] (x = radius, y = height along the axis) around the
## local Y axis. Use [param smooth] = false for hard-edged parts (bolt heads).
static func lathe(profile: PackedVector2Array, segments: int = 32, smooth: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if smooth:
		st.set_smooth_group(0)
	else:
		st.set_smooth_group(-1)
	for s: int in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		for i: int in profile.size() - 1:
			var p := profile[i]
			var q := profile[i + 1]
			var v00 := Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x)
			var v01 := Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)
			var v10 := Vector3(cos(a0) * q.x, q.y, sin(a0) * q.x)
			var v11 := Vector3(cos(a1) * q.x, q.y, sin(a1) * q.x)
			var u0 := float(s) / segments
			var u1 := float(s + 1) / segments
			var t0 := float(i) / (profile.size() - 1)
			var t1 := float(i + 1) / (profile.size() - 1)
			_quad(st, v00, v10, v11, v01, Vector2(u0, t0), Vector2(u0, t1), Vector2(u1, t1), Vector2(u1, t0))
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Builds a skin through closed (or open) rings of equal vertex count.
## Optional caps close the first/last ring with a fan.
static func loft(rings: Array[PackedVector3Array], closed: bool = true, cap_start: bool = false, cap_end: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	add_loft(st, rings, closed)
	if cap_start:
		add_cap(st, rings[0], true)
	if cap_end:
		add_cap(st, rings[rings.size() - 1], false)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func add_loft(st: SurfaceTool, rings: Array[PackedVector3Array], closed: bool) -> void:
	var n := rings[0].size()
	var segs := n if closed else n - 1
	for r: int in rings.size() - 1:
		var a := rings[r]
		var b := rings[r + 1]
		for j: int in segs:
			var j1 := (j + 1) % n
			var v0 := float(r) / (rings.size() - 1)
			var v1 := float(r + 1) / (rings.size() - 1)
			_quad(st, a[j], b[j], b[j1], a[j1], Vector2(float(j) / segs, v0), Vector2(float(j) / segs, v1), Vector2(float(j + 1) / segs, v1), Vector2(float(j + 1) / segs, v0))


static func add_cap(st: SurfaceTool, ring: PackedVector3Array, flip: bool) -> void:
	var c := Vector3.ZERO
	for v: Vector3 in ring:
		c += v
	c /= ring.size()
	for j: int in ring.size():
		var a := ring[j]
		var b := ring[(j + 1) % ring.size()]
		if flip:
			_tri(st, c, b, a)
		else:
			_tri(st, c, a, b)


## Tube of [param radius] along [param path] using parallel-transport frames.
static func tube(path: PackedVector3Array, radius: float, sides: int = 10, cap: bool = true) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	var up := Vector3.UP
	var prev_n := Vector3.ZERO
	for i: int in path.size():
		var t: Vector3
		if i == 0:
			t = (path[1] - path[0]).normalized()
		elif i == path.size() - 1:
			t = (path[i] - path[i - 1]).normalized()
		else:
			t = (path[i + 1] - path[i - 1]).normalized()
		var nrm: Vector3
		if prev_n == Vector3.ZERO:
			nrm = t.cross(up)
			if nrm.length() < 0.01:
				nrm = t.cross(Vector3.RIGHT)
		else:
			nrm = prev_n - t * prev_n.dot(t)
		nrm = nrm.normalized()
		prev_n = nrm
		var bin := t.cross(nrm).normalized()
		var ring := PackedVector3Array()
		for s: int in sides:
			var a := TAU * s / sides
			ring.append(path[i] + (nrm * cos(a) + bin * sin(a)) * radius)
		rings.append(ring)
	return loft(rings, true, cap, cap)


## Cubic Bezier sampled into [param steps] + 1 points.
static func bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, steps: int = 16) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i: int in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out


## Smooth hose between two points that leaves/enters along the given directions.
static func hose(a: Vector3, dir_a: Vector3, b: Vector3, dir_b: Vector3, radius: float, slack: float = 0.35) -> ArrayMesh:
	var d := a.distance_to(b) * slack
	return tube(bezier(a, a + dir_a.normalized() * d, b - dir_b.normalized() * d, b, 18), radius, 10)


## Rounded rectangle (XY) outline, counter-clockwise.
static func rounded_rect(w: float, h: float, r: float, corner_steps: int = 4) -> PackedVector2Array:
	r = minf(r, minf(w, h) * 0.5 - 0.0001)
	var pts := PackedVector2Array()
	var centres := [Vector2(w * 0.5 - r, h * 0.5 - r), Vector2(-w * 0.5 + r, h * 0.5 - r), Vector2(-w * 0.5 + r, -h * 0.5 + r), Vector2(w * 0.5 - r, -h * 0.5 + r)]
	for c: int in 4:
		for s: int in corner_steps + 1:
			var a := PI * 0.5 * c + PI * 0.5 * s / corner_steps
			pts.append(centres[c] + Vector2(cos(a), sin(a)) * r)
	return pts


## Extrudes an XY outline along Z (centred), with flat caps and hard edges at the caps.
static func extrude(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for p: Vector2 in outline:
		front.append(Vector3(p.x, p.y, -depth * 0.5))
		back.append(Vector3(p.x, p.y, depth * 0.5))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rings: Array[PackedVector3Array] = [front, back]
	add_loft(st, rings, true)
	st.set_smooth_group(-1)
	add_cap(st, front, false)
	add_cap(st, back, true)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## A box with rounded vertical edges (rounded around Z), centred.
static func rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	return extrude(rounded_rect(size.x, size.y, radius), size.z)


## Hexagonal fastener head (axis along local Y) with a washer face.
static func hex_head(across_flats: float, height: float) -> ArrayMesh:
	var r := across_flats / sqrt(3.0)
	return lathe(PackedVector2Array([Vector2(0, 0), Vector2(r * 1.15, 0), Vector2(r * 1.15, height * 0.18), Vector2(r, height * 0.2), Vector2(r, height), Vector2(0, height)]), 6, false)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ud)
	st.add_vertex(d)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Wraps a mesh in a MeshInstance3D child of [param parent].
static func add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi
