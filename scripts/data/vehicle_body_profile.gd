class_name VehicleBodyProfile
extends Resource
## Dimensions and shape controls for the procedural vehicle body.
##
## Car-local space: metres, +Y up, nose towards -Z, driver on -X. The body is
## lofted through cross-sections; these values are the design knobs. They are
## approximate proportions for placeholder art only.

@export var length: float = 4.4
@export var half_width: float = 0.92
## Plan-view squareness of the nose/tail (higher = squarer corners).
@export var plan_exponent: float = 5.0
@export var sill_y: float = 0.18
@export var nose_top_y: float = 0.66
## Hood surface height at the windscreen base (cowl).
@export var cowl_y: float = 0.86
## Hood rise curve: higher values lift the hood quickly behind the nose.
@export var hood_curve: float = 3.5
@export var deck_y: float = 0.86
@export var tail_top_y: float = 0.8
@export var roof_y: float = 1.3
## Greenhouse width as a fraction of body width.
@export var greenhouse_ratio: float = 0.8
@export var windscreen_base_z: float = -0.72
@export var roof_front_z: float = -0.08
@export var roof_rear_z: float = 0.9
@export var deck_start_z: float = 1.62
@export var hood_front_z: float = -2.08
## Hood hinge line; must match the "hood" mount marker in the vehicle scene.
@export var hood_rear_z: float = -0.78
@export var door_front_z: float = -0.62
@export var door_rear_z: float = 0.55
@export var trunk_front_z: float = 1.66
@export var bumper_depth: float = 0.16
## Extra width over the wheel arches (fender flare), metres.
@export var arch_flare: float = 0.02
@export var front_axle_z: float = -1.35
@export var rear_axle_z: float = 1.32
@export var wheel_x: float = 0.8
@export var wheel_radius_front: float = 0.33
@export var wheel_radius_rear: float = 0.33
@export var tyre_width_front: float = 0.235
@export var tyre_width_rear: float = 0.235
@export var rim_radius_front: float = 0.225
@export var rim_radius_rear: float = 0.225
@export var arch_clearance: float = 0.045
@export var spoke_count: int = 5
@export var twin_spokes: bool = false
@export var exhaust_tips: int = 2
@export var paint_color: Color = Color(0.62, 0.64, 0.66)
@export var rim_color: Color = Color(0.72, 0.73, 0.74)
@export var caliper_color: Color = Color(0.2, 0.2, 0.22)
## Leaves the driver's side window open (access to the ignition / diagnostic port).
@export var driver_window_open: bool = true
## Loft station spacing in metres (smaller = smoother body).
@export var station_spacing: float = 0.05


func axle_y_front() -> float:
	return wheel_radius_front


func axle_y_rear() -> float:
	return wheel_radius_rear
