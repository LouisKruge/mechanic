class_name ComponentDefinition
extends Resource
## Immutable definition of a mechanical/electrical component type.
##
## Runtime, per-vehicle mutable state lives in [ComponentInstance]; nothing in
## this resource is changed during play.

enum Category { BODY, ENGINE, ELECTRICAL, ACCESSORY_DRIVE, CHASSIS, BRAKES, SUSPENSION, DRIVETRAIN }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.ENGINE
## Vehicle IDs or assembly IDs this part fits (e.g. "project_c01", "c01.front_accessory_drive").
@export var compatible_with: PackedStringArray = PackedStringArray()
## True when the component can be removed from the vehicle at all.
@export var removable: bool = false
## Tool IDs needed to remove/install the body of the part (fasteners list their own tools).
@export var required_tools: PackedStringArray = PackedStringArray()
@export var fasteners: Array[FastenerSlotDefinition] = []
@export var removal_dependencies: Array[DependencyCondition] = []
@export var installation_dependencies: Array[DependencyCondition] = []
@export var toggles: Array[ComponentToggleDefinition] = []
## Condition loss per simulated operating hour (percentage points).
@export var wear_per_hour: float = 0.0
## Below this condition the part no longer functions.
@export var min_functional_condition: float = 10.0
## Fault IDs this component can develop.
@export var fault_capabilities: PackedStringArray = PackedStringArray()
## Purchase price in workshop credits (fictional currency).
@export var purchase_price: int = 0
@export var mass_kg: float = 0.0
## Named performance / operating parameters, e.g. {"rated_output_a": 90.0}.
@export var performance: Dictionary = {}
@export_multiline var description: String = ""


func category_name() -> String:
	return Category.keys()[category].capitalize()


func get_toggle(flag: StringName) -> ComponentToggleDefinition:
	for t: ComponentToggleDefinition in toggles:
		if t.flag == flag:
			return t
	return null


func get_fastener_slot(slot_id: StringName) -> FastenerSlotDefinition:
	for f: FastenerSlotDefinition in fasteners:
		if f.slot_id == slot_id:
			return f
	return null


func perf(key: String, fallback: float = 0.0) -> float:
	return float(performance.get(key, fallback))
