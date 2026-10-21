class_name JobObjectiveDefinition
extends Resource
## One step of a work order. Completes (and latches) once all conditions hold
## and every objective listed in [member after] is complete.

@export var id: StringName = &""
@export var text: String = ""
## Optional hint shown in the HUD while this is the current objective.
@export var hint: String = ""
@export var conditions: Array[DependencyCondition] = []
@export var after: PackedStringArray = PackedStringArray()
