class_name PlayerController
extends CharacterBody3D
## First-person mechanic: walk, sprint, crouch, jump and mouse-look.
##
## The node tree is created in code so the scene file stays minimal:
##   PlayerController (CharacterBody3D)
##     CollisionShape3D (capsule)
##     Head (Node3D)            <- yaw is on the body, pitch on the head
##       Camera3D
##         Flashlight (SpotLight3D)
##         InteractionRay (RayCast3D, owned by InteractionManager)

signal moved_to(position: Vector3)

const WALK_SPEED: float = 3.2
const SPRINT_SPEED: float = 5.6
const CROUCH_SPEED: float = 1.6
const GROUND_ACCEL: float = 11.0
const AIR_ACCEL: float = 2.5
const JUMP_VELOCITY: float = 4.2
const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.15
const CAPSULE_RADIUS: float = 0.32
const STAND_EYE: float = 1.64
const CROUCH_EYE: float = 1.02
const EYE_LERP_SPEED: float = 10.0
const PITCH_LIMIT_DEG: float = 88.0

## Radians of rotation per pixel of mouse motion, multiplied by [member mouse_sensitivity].
const BASE_MOUSE_SCALE: float = 0.0022

@export var mouse_sensitivity: float = 1.0
## When false, movement and look input are ignored (UI panels open, paused).
var input_enabled: bool = true
var is_crouching: bool = false

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var viewmodel: ToolViewmodel
var _shape: CapsuleShape3D
var _collision: CollisionShape3D
var _gravity: float = 9.8
var _pitch: float = 0.0


func _init() -> void:
	collision_layer = MeshKit.LAYER_PLAYER
	collision_mask = MeshKit.LAYER_WORLD | MeshKit.LAYER_FURNITURE
	floor_max_angle = deg_to_rad(46.0)
	_collision = CollisionShape3D.new()
	_collision.name = "CollisionShape3D"
	_shape = CapsuleShape3D.new()
	_shape.radius = CAPSULE_RADIUS
	_shape.height = STAND_HEIGHT
	_collision.shape = _shape
	_collision.position = Vector3(0, STAND_HEIGHT * 0.5, 0)
	add_child(_collision)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, STAND_EYE, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 72.0
	camera.near = 0.03
	camera.far = 120.0
	camera.current = true
	head.add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.spot_angle = 24.0
	flashlight.spot_range = 7.0
	flashlight.light_energy = 3.0
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.12, -0.08, 0.0)
	flashlight.visible = false
	camera.add_child(flashlight)
	viewmodel = ToolViewmodel.new()
	camera.add_child(viewmodel)


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		apply_look(motion.relative)


## Rotates the view by a mouse delta in pixels. Public so tests can drive it.
func apply_look(relative: Vector2) -> void:
	var scale := BASE_MOUSE_SCALE * mouse_sensitivity
	rotate_y(-relative.x * scale)
	_pitch = clampf(_pitch - relative.y * scale, deg_to_rad(-PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
	head.rotation.x = _pitch


## Sets the view direction directly (used by save/load and tests).
func set_view(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, deg_to_rad(-PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
	head.rotation.x = _pitch


func get_yaw() -> float:
	return rotation.y


func get_pitch() -> float:
	return _pitch


func _physics_process(delta: float) -> void:
	var wish := Vector2.ZERO
	var want_crouch := false
	var want_sprint := false
	var want_jump := false
	if input_enabled:
		wish = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		want_crouch = Input.is_action_pressed("crouch")
		want_sprint = Input.is_action_pressed("sprint")
		want_jump = Input.is_action_just_pressed("jump")
	_update_crouch(want_crouch, delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif want_jump and not is_crouching:
		velocity.y = JUMP_VELOCITY

	var speed := WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif want_sprint and wish.y < 0.0:
		speed = SPRINT_SPEED
	var dir := (transform.basis * Vector3(wish.x, 0.0, wish.y))
	dir.y = 0.0
	dir = dir.normalized() * minf(wish.length(), 1.0)
	var target := dir * speed
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(target, clampf(accel * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var before := global_position
	move_and_slide()
	if global_position.distance_squared_to(before) > 0.000001:
		moved_to.emit(global_position)


func _update_crouch(want: bool, delta: float) -> void:
	if want and not is_crouching:
		is_crouching = true
	elif not want and is_crouching and _can_stand():
		is_crouching = false
	var h := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	if not is_equal_approx(_shape.height, h):
		_shape.height = h
		_collision.position.y = h * 0.5
	var eye := CROUCH_EYE if is_crouching else STAND_EYE
	head.position.y = lerpf(head.position.y, eye, clampf(EYE_LERP_SPEED * delta, 0.0, 1.0))


func _can_stand() -> bool:
	if not is_inside_tree():
		return true
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.radius = CAPSULE_RADIUS * 0.95
	probe.height = STAND_HEIGHT
	q.shape = probe
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.02, 0))
	q.collision_mask = MeshKit.LAYER_WORLD | MeshKit.LAYER_FURNITURE
	q.exclude = [get_rid()]
	return space.intersect_shape(q, 1).is_empty()


## Shows or hides the handheld flashlight beam.
func set_flashlight(on: bool) -> void:
	flashlight.visible = on
