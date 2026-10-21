class_name FastenerDefinition
extends Resource
## Immutable definition of a fastener type (bolt, nut, screw, connector, clip).
##
## Torque figures in this prototype are FICTIONAL DEMONSTRATION VALUES and are
## always labelled as such in the UI. They are not manufacturer specifications.

enum Kind { BOLT, NUT, SCREW, ELECTRICAL_CONNECTOR, CLIP }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.BOLT
## Tool ID that drives this fastener ("ratchet" for socket fasteners, "" = by hand).
@export var tool_type: StringName = &""
## Socket size in millimetres (0 when no socket is used).
@export var tool_size_mm: int = 0
## Demonstration tightening target in N·m (threaded fasteners only).
@export var torque_target_nm: float = 0.0
## Accepted deviation from the target, as a fraction (0.1 = ±10 %).
@export var torque_tolerance: float = 0.1
## When true, only a tool with can_final_torque (torque wrench) can reach the target.
@export var requires_torque_wrench: bool = false
## Fraction of the target a plain ratchet may reach when a torque wrench is required.
@export var ratchet_snug_fraction: float = 0.5
## Torque above target x this factor strips the threads (0 = cannot be damaged).
@export var damage_torque_factor: float = 1.5
## Number of turns between finger-start and seated (for run-down speed).
@export var thread_turns: float = 8.0
@export_multiline var notes: String = ""


func is_threaded() -> bool:
	return kind == Kind.BOLT or kind == Kind.NUT or kind == Kind.SCREW


func is_hand_operated() -> bool:
	return kind == Kind.ELECTRICAL_CONNECTOR or kind == Kind.CLIP


func kind_name() -> String:
	match kind:
		Kind.BOLT: return "Bolt"
		Kind.NUT: return "Nut"
		Kind.SCREW: return "Screw"
		Kind.ELECTRICAL_CONNECTOR: return "Electrical connector"
		Kind.CLIP: return "Clip"
	return "Fastener"
