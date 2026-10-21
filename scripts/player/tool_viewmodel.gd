class_name ToolViewmodel
extends Node3D
## First-person representation of the equipped tool (procedural placeholders).
##
## Sits at the lower right of the camera. A short push animation plays while
## the tool is being used so turning a fastener has visible feedback.

const REST_POS: Vector3 = Vector3(0.21, -0.2, -0.42)
const USE_OFFSET: Vector3 = Vector3(-0.015, 0.012, -0.05)
const LERP_SPEED: float = 14.0

var _current: StringName = &"__none__"
var _model: Node3D
var _use: float = 0.0
var using: bool = false
var _time: float = 0.0
## Fastener being worked: the tool is placed onto it (socket on the head).
var align_target: Node3D = null
var _align: float = 0.0
## Where the socket sits on the model (tool-local), for alignment.
var _socket_tip: Vector3 = Vector3.ZERO
var _rest_xf: Transform3D


func _init() -> void:
	name = "ToolViewmodel"
	position = REST_POS
	_rest_xf = Transform3D(Basis.IDENTITY, REST_POS)


func _m(n: StringName) -> StandardMaterial3D:
	return WorkshopMaterials.get_mat(n)


## Rebuilds the model when the equipped tool changes.
func set_tool(tool_id: StringName) -> void:
	if tool_id == _current:
		return
	_current = tool_id
	if _model:
		_model.queue_free()
		_model = null
	if tool_id == &"":
		return
	_model = Node3D.new()
	add_child(_model)
	_socket_tip = Vector3.ZERO
	match tool_id:
		&"ratchet":
			_socket_tip = Vector3(0, -0.044, -0.07)
			MeshKit.cylinder(_model, 0.012, 0.2, Vector3(0, 0, 0.04), _m(&"steel"), Vector3(90, 0, 0))
			MeshKit.cylinder(_model, 0.016, 0.1, Vector3(0, 0, 0.1), _m(&"rubber"), Vector3(90, 0, 0))
			MeshKit.cylinder(_model, 0.024, 0.018, Vector3(0, 0, -0.07), _m(&"steel"))
			MeshKit.cylinder(_model, 0.011, 0.035, Vector3(0, -0.026, -0.07), _m(&"steel_dark"))  # socket
		&"torque_wrench":
			_socket_tip = Vector3(0, -0.044, -0.1)
			MeshKit.cylinder(_model, 0.013, 0.34, Vector3(0, 0, 0.08), _m(&"steel"), Vector3(90, 0, 0))
			MeshKit.cylinder(_model, 0.018, 0.12, Vector3(0, 0, 0.2), _m(&"rubber"), Vector3(90, 0, 0))
			MeshKit.box(_model, Vector3(0.02, 0.008, 0.05), Vector3(0, 0.014, 0.12), _m(&"plastic_grey"))  # scale window
			MeshKit.cylinder(_model, 0.024, 0.018, Vector3(0, 0, -0.1), _m(&"steel"))
			MeshKit.cylinder(_model, 0.011, 0.035, Vector3(0, -0.026, -0.1), _m(&"steel_dark"))
		&"flashlight":
			MeshKit.cylinder(_model, 0.016, 0.16, Vector3(0, 0, 0.02), _m(&"plastic_black"), Vector3(90, 0, 0))
			MeshKit.cylinder(_model, 0.022, 0.035, Vector3(0, 0, -0.07), _m(&"aluminium"), Vector3(90, 0, 0))
			MeshKit.cylinder(_model, 0.019, 0.004, Vector3(0, 0, -0.088), _m(&"light_fixture"), Vector3(90, 0, 0), "Lens")
		&"scanner":
			MeshKit.box(_model, Vector3(0.1, 0.03, 0.16), Vector3(0, 0, 0), _m(&"plastic_grey"), Vector3(-35, 0, 0))
			MeshKit.box(_model, Vector3(0.08, 0.005, 0.07), Vector3(0, 0.03, -0.02), _m(&"plastic_black"), Vector3(-35, 0, 0))
			MeshKit.box(_model, Vector3(0.06, 0.002, 0.045), Vector3(0, 0.035, -0.022), _m(&"led_green"), Vector3(-35, 0, 0))
		&"socket_set":
			MeshKit.box(_model, Vector3(0.16, 0.04, 0.1), Vector3(0, 0, 0), _m(&"plastic_black"), Vector3(-20, 0, 0))
			for i: int in 5:
				MeshKit.cylinder(_model, 0.008 + i * 0.001, 0.02, Vector3(-0.06 + i * 0.03, 0.025, 0), _m(&"steel"), Vector3(-20, 0, 0))
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_time += delta
	_use = lerpf(_use, 1.0 if using else 0.0, clampf(LERP_SPEED * delta, 0.0, 1.0))
	var aligned := using and is_instance_valid(align_target) and _socket_tip != Vector3.ZERO
	_align = lerpf(_align, 1.0 if aligned else 0.0, clampf(8.0 * delta, 0.0, 1.0))
	var wobble := Vector3(0, 0, sin(_time * 18.0) * 0.006) * _use
	var rest := Transform3D(Basis(Vector3(0, 0, 1), -0.35 * _use * (0.5 + 0.5 * sin(_time * 9.0))), REST_POS + USE_OFFSET * _use + wobble)
	if _align < 0.01 or not is_instance_valid(align_target):
		transform = rest
		return
	# Seat the socket on the fastener: tool +Y along the fastener's outward axis,
	# handle swinging back and forth around that axis (a ratchet stroke).
	var cam := get_parent() as Node3D
	var head := align_target.global_transform
	var out := -head.basis.z.normalized()
	var to_cam := cam.global_position - head.origin
	var handle := (to_cam - out * to_cam.dot(out)).normalized()
	if handle.length() < 0.1:
		handle = cam.global_transform.basis.z
	handle = handle.rotated(out, sin(_time * 7.0) * 0.5)
	var basis_w := Basis(out.cross(handle).normalized(), out, handle)
	var world := Transform3D(basis_w, head.origin + out * 0.004 - basis_w * _socket_tip)
	var local := cam.global_transform.affine_inverse() * world
	transform = rest.interpolate_with(local, _align)
