class_name FastenerSlotDefinition
extends Resource
## A fastener position on a component mount, e.g. alternator bolt B01.
##
## The runtime ID of a slot is "<component_id>.<slot_id>" (e.g. "alternator.B01").

@export var slot_id: StringName = &""
@export var display_name: String = ""
@export var fastener: FastenerDefinition
## When true, the component cannot be removed until this fastener is removed.
@export var retains_component: bool = true
## Conditions that must hold before this fastener can be loosened/disconnected.
@export var removal_dependencies: Array[DependencyCondition] = []
## Conditions that must hold before this fastener can be fitted/connected.
@export var installation_dependencies: Array[DependencyCondition] = []
## Initial state on a freshly spawned vehicle: "tight", "loose" or "removed".
@export var initial_state: StringName = &"tight"
