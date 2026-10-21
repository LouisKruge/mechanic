class_name VehicleDefinition
extends Resource
## Immutable definition of a vehicle model: which components it carries, their
## starting condition and the conditions used by the electrical model.

@export var id: StringName = &""
@export var display_name: String = ""
@export var body_style: String = ""
@export var drivetrain: String = ""
@export_multiline var description: String = ""
## Components fitted to this vehicle, in display order.
@export var components: Array[ComponentDefinition] = []
## Per-component initial overrides: {component_id: {"condition": float, "faults": [ids], "flags": {...}}}.
@export var initial_state: Dictionary = {}
## Diagnostic trouble codes already stored when the vehicle arrives.
@export var initial_dtcs: PackedStringArray = PackedStringArray()
## Initial battery state of charge (0..1).
@export var initial_battery_soc: float = 0.8
## Engine start is refused unless all of these hold.
@export var start_requirements: Array[DependencyCondition] = []
## Battery is electrically connected only when all of these hold.
@export var battery_connection: Array[DependencyCondition] = []
## Alternator output reaches the battery only when all of these hold (driven + wired).
@export var charging_path: Array[DependencyCondition] = []
## Component IDs that play electrical roles.
@export var battery_component: StringName = &"battery"
@export var alternator_component: StringName = &"alternator"
@export var starter_component: StringName = &"starter"
## Electrical loads in amperes.
@export var ignition_load_a: float = 9.0
@export var running_load_a: float = 32.0


func get_component(component_id: StringName) -> ComponentDefinition:
	for c: ComponentDefinition in components:
		if c.id == component_id:
			return c
	return null
