class_name JobDefinition
extends Resource
## A work order: customer complaint, ordered objectives and the critical
## requirements that are re-checked live at sign-off.

@export var id: StringName = &""
@export var title: String = ""
@export var vehicle_id: StringName = &""
@export_multiline var customer_complaint: String = ""
@export_multiline var technician_notes: String = ""
@export var objectives: Array[JobObjectiveDefinition] = []
## Checked against the live vehicle state when the player signs off the job.
@export var completion_requirements: Array[DependencyCondition] = []
## Replacement parts made available on the parts shelf: {component_id: count}.
@export var supplied_parts: Dictionary = {}
@export var labour_payment: int = 0
