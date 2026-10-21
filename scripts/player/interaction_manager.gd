class_name InteractionManager
extends Node
## Centre-screen raycast that finds the [Interactable] under the crosshair and
## forwards player input (E / F / LMB / RMB) to the [GameSession].
##
## The ray also hits world geometry, so walls and the car body block targeting
## through them.

signal target_changed(target: Interactable)

## Maximum reach from the eye, metres.
const REACH: float = 2.3

var session: GameSession
var ray: RayCast3D
var current: Interactable = null
## When false, the player is in a UI panel and actions are not forwarded.
var input_enabled: bool = true


## Attaches the raycast to the given camera.
func setup(camera: Camera3D, game_session: GameSession) -> void:
	session = game_session
	ray = RayCast3D.new()
	ray.name = "InteractionRay"
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collision_mask = MeshKit.LAYER_WORLD | MeshKit.LAYER_INTERACT
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.enabled = true
	camera.add_child(ray)


func _physics_process(delta: float) -> void:
	if ray == null:
		return
	refresh_target()
	if not input_enabled or session == null:
		return
	var t := get_target_dict()
	var vm := (get_parent() as PlayerController).viewmodel if get_parent() is PlayerController else null
	if vm:
		vm.using = Input.is_action_pressed("tool_primary") or Input.is_action_pressed("tool_secondary")
	if Input.is_action_pressed("tool_primary"):
		session.tool_primary(t, delta, Input.is_action_just_pressed("tool_primary"))
	elif Input.is_action_pressed("tool_secondary"):
		session.tool_secondary(t, delta, Input.is_action_just_pressed("tool_secondary"))
	else:
		session.tool_released()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or session == null:
		return
	if event.is_action_pressed("interact"):
		session.interact(get_target_dict())
	elif event.is_action_pressed("inspect"):
		session.inspect(get_target_dict())


## Re-runs the raycast immediately and updates [member current].
func refresh_target() -> void:
	ray.force_raycast_update()
	var hit: Interactable = null
	if ray.is_colliding():
		hit = _find_interactable(ray.get_collider())
	if hit != current:
		if is_instance_valid(current):
			current.set_highlighted(false)
		current = hit
		if current:
			current.set_highlighted(true)
		target_changed.emit(current)


## Returns {} when nothing is targeted.
func get_target_dict() -> Dictionary:
	if current and is_instance_valid(current):
		return current.get_target()
	return {}


func _find_interactable(obj: Object) -> Interactable:
	var n := obj as Node
	while n:
		if n is Interactable:
			return n as Interactable
		n = n.get_parent()
		# Stop at plain static bodies (e.g. the bin's own obstacle collider is a child).
		if n is StaticBody3D and not (n is Interactable):
			return null
	return null
