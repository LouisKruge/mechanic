class_name FastenerInstance
extends RefCounted
## Mutable runtime state of one fastener slot on a vehicle.
##
## Threaded fasteners track thread engagement (0 = finger-started, 1 = seated)
## and applied torque. Connectors and clips are either engaged or removed.

enum State { REMOVED, LOOSE, TIGHT, OVERTIGHT }

## Runtime ID "<component_id>.<slot_id>".
var id: StringName
var component_id: StringName
var slot: FastenerSlotDefinition
var removed: bool = false
## 0..1 thread engagement (threaded fasteners only).
var thread_progress: float = 1.0
var torque_nm: float = 0.0
## Seconds of loosening effort accumulated while breaking the fastener free.
var breakaway_effort: float = 0.0


func _init(p_component_id: StringName, p_slot: FastenerSlotDefinition) -> void:
	component_id = p_component_id
	slot = p_slot
	id = StringName("%s.%s" % [p_component_id, p_slot.slot_id])
	apply_initial(p_slot.initial_state)


func definition() -> FastenerDefinition:
	return slot.fastener


func apply_initial(state_name: StringName) -> void:
	breakaway_effort = 0.0
	match state_name:
		&"removed":
			removed = true
			thread_progress = 0.0
			torque_nm = 0.0
		&"loose":
			removed = false
			thread_progress = 1.0
			torque_nm = 0.0
		_:
			removed = false
			thread_progress = 1.0
			torque_nm = definition().torque_target_nm


## Derived state from progress and torque.
func get_state() -> State:
	if removed:
		return State.REMOVED
	var def := definition()
	if not def.is_threaded():
		return State.TIGHT
	if thread_progress < 1.0 or def.torque_target_nm <= 0.0:
		return State.LOOSE if thread_progress < 1.0 else State.TIGHT
	var lo := def.torque_target_nm * (1.0 - def.torque_tolerance)
	var hi := def.torque_target_nm * (1.0 + def.torque_tolerance)
	if torque_nm > hi:
		return State.OVERTIGHT
	if torque_nm >= lo:
		return State.TIGHT
	return State.LOOSE


func is_installed() -> bool:
	return not removed


func is_to_spec() -> bool:
	return get_state() == State.TIGHT


func state_text() -> String:
	var def := definition()
	if def.is_hand_operated():
		return "Disconnected" if removed else ("Connected" if def.kind == FastenerDefinition.Kind.ELECTRICAL_CONNECTOR else "Engaged")
	match get_state():
		State.REMOVED: return "Removed"
		State.LOOSE:
			if thread_progress < 1.0:
				return "Loose (%d%% threaded)" % int(thread_progress * 100.0)
			return "Seated, under-torqued (%.0f N·m)" % torque_nm
		State.TIGHT: return "Tightened (%.0f N·m)" % torque_nm
		State.OVERTIGHT: return "OVER-TORQUED (%.0f N·m)" % torque_nm
	return "?"


func display_name() -> String:
	return slot.display_name


func to_dict() -> Dictionary:
	return {
		"removed": removed,
		"thread_progress": snappedf(thread_progress, 0.0001),
		"torque_nm": snappedf(torque_nm, 0.01),
	}


## Applies saved data with validation; bad values fall back to safe defaults.
func from_dict(d: Dictionary) -> void:
	removed = bool(d.get("removed", removed))
	thread_progress = clampf(float(d.get("thread_progress", thread_progress)), 0.0, 1.0)
	torque_nm = clampf(float(d.get("torque_nm", torque_nm)), 0.0, 1000.0)
	breakaway_effort = 0.0
	if removed:
		thread_progress = 0.0
		torque_nm = 0.0
