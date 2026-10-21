class_name DrivetrainConfiguration
extends Resource
## Drivetrain architecture. Structural only; no performance claims.

enum Layout { FRONT_ENGINE_RWD, FRONT_ENGINE_FWD, FRONT_ENGINE_AWD, REAR_ENGINE_RWD, REAR_ENGINE_AWD, MID_ENGINE_RWD }
enum Transmission { MANUAL, AUTOMATIC_TORQUE_CONVERTER, DUAL_CLUTCH }

@export var id: StringName = &""
@export var layout: Layout = Layout.FRONT_ENGINE_RWD
@export var transmission: Transmission = Transmission.MANUAL
@export var gears: int = 6
## "open", "limited_slip", "active_limited_slip".
@export var rear_differential: StringName = &"open"
@export_multiline var notes: String = ""


func engine_position() -> StringName:
	match layout:
		Layout.REAR_ENGINE_RWD, Layout.REAR_ENGINE_AWD: return &"rear"
		Layout.MID_ENGINE_RWD: return &"mid"
	return &"front"


func layout_name() -> String:
	return ["Front-engine, rear-wheel drive", "Front-engine, front-wheel drive", "Front-engine, all-wheel drive", "Rear-engine, rear-wheel drive", "Rear-engine, all-wheel drive", "Mid-engine, rear-wheel drive"][layout]


func transmission_name() -> String:
	return "%d-speed %s" % [gears, ["manual", "automatic (torque converter)", "dual-clutch"][transmission]]
