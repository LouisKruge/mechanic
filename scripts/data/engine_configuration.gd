class_name EngineConfiguration
extends Resource
## Engine architecture used by the simulation and by the engine-assembly
## builder. Layout fields are structural; any numeric performance figures are
## either "reference" (publicly reported, informational only) or fictional
## demonstration values, and are labelled as such.

enum Layout { INLINE, FLAT, V }
enum Aspiration { NATURAL, TURBO, TWIN_TURBO }
enum Mounting { LONGITUDINAL, TRANSVERSE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var layout: Layout = Layout.INLINE
@export var cylinders: int = 4
## Angle between banks (V and flat engines; flat = 180).
@export var bank_angle_deg: float = 0.0
@export var displacement_l: float = 2.0
@export var aspiration: Aspiration = Aspiration.NATURAL
@export var mounting: Mounting = Mounting.LONGITUDINAL
## "none", "air_to_air", "water_to_air".
@export var charge_cooling: StringName = &"none"
## "port", "direct", "direct_and_port".
@export var fuel_injection: StringName = &"port"
@export var valves_per_cylinder: int = 4
## Geometry for placeholder construction (metres).
@export var bore_spacing_m: float = 0.09
@export var block_height_m: float = 0.36
@export var block_width_m: float = 0.42
## Throttle body at the front of the plenum (false = rear, keeps the front of the bay clear).
@export var throttle_at_front: bool = true
## Lateral offset of an inline engine's plenum from the block side (metres).
@export var plenum_offset_m: float = 0.13
## Which side the exhaust exits for inline engines: +1 = +X (right), -1 = -X.
@export var exhaust_side: float = 1.0
## Publicly reported figures, informational only — never used as specifications.
@export var reference_figures: Dictionary = {}
@export_multiline var notes: String = ""


func banks() -> int:
	return 1 if layout == Layout.INLINE else 2


func cylinders_per_bank() -> int:
	return cylinders / banks()


func turbo_count() -> int:
	match aspiration:
		Aspiration.TURBO: return 1
		Aspiration.TWIN_TURBO: return 2
	return 0


func layout_name() -> String:
	match layout:
		Layout.INLINE: return "Inline-%d" % cylinders
		Layout.FLAT: return "Flat-%d" % cylinders
		Layout.V: return "V%d" % cylinders
	return "?"


func aspiration_name() -> String:
	return ["Naturally aspirated", "Turbocharged", "Twin-turbocharged"][aspiration]
