class_name ComponentToggleDefinition
extends Resource
## A boolean operating state on a component (hood open, tensioner released,
## belt on pulley). Changing it can require tools and dependencies.

## Flag key stored in the component's runtime state.
@export var flag: StringName = &""
@export var default_value: bool = false
## Verb shown when the flag would become true / false.
@export var label_set_true: String = ""
@export var label_set_false: String = ""
## Past-tense state descriptions for the inspection panel.
@export var state_true_text: String = ""
@export var state_false_text: String = ""
## Input that triggers the toggle: "interact" (E) or "tool_primary" (LMB with a tool).
@export var input: StringName = &"interact"
## Tool IDs, any of which may perform the toggle. Empty = by hand.
@export var required_tools: PackedStringArray = PackedStringArray()
## When false, changing this state does not invalidate verification tests
## (closing a hood or filler cap after a test does not change the repair).
@export var invalidates_tests: bool = true
@export var set_true_dependencies: Array[DependencyCondition] = []
@export var set_false_dependencies: Array[DependencyCondition] = []
