class_name ConditionContext
extends RefCounted
## Read-only view of game state used by [ConditionEvaluator].
##
## [GameSession] extends this; tests can provide lightweight subclasses. Every
## method has a conservative default (false / null) so an unimplemented query
## blocks an action rather than permitting it.


func ctx_component_def(_component_id: StringName) -> ComponentDefinition:
	return null


func ctx_component(_component_id: StringName) -> ComponentInstance:
	return null


func ctx_fastener(_fastener_id: StringName) -> FastenerInstance:
	return null


func ctx_component_fasteners(_component_id: StringName) -> Array[FastenerInstance]:
	return []


func ctx_engine_running() -> bool:
	return false


func ctx_charging_test_passed() -> bool:
	return false


func ctx_event(_event_id: StringName) -> bool:
	return false


func ctx_tool_equipped(_tool_id: StringName) -> bool:
	return false


func ctx_part_in_inventory(_component_id: StringName, _only_new: bool) -> bool:
	return false


func ctx_objective_complete(_objective_id: StringName) -> bool:
	return false


func ctx_fluid_state(_circuit_id: StringName, _key: StringName) -> bool:
	return false


func ctx_test_passed(_test_id: StringName) -> bool:
	return false


func ctx_world_flag(_flag: StringName) -> bool:
	return false


func ctx_fault_def(_fault_id: StringName) -> FaultDefinition:
	return null


func ctx_fault_name(fault_id: StringName) -> String:
	var fd := ctx_fault_def(fault_id)
	return fd.display_name if fd else String(fault_id)
