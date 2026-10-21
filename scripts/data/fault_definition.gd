class_name FaultDefinition
extends Resource
## A fault a component can carry. Faults are hidden until discovered.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## How the fault can be discovered: "visual", "flashlight", "charging_test", "scan".
@export var discovery_methods: PackedStringArray = PackedStringArray()
## Text shown once discovered by visual inspection (may be vaguer than the test result).
@export_multiline var visual_clue: String = ""
## Multiplier applied to the component's functional output while the fault is present.
@export var output_factor: float = 1.0
