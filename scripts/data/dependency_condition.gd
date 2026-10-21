class_name DependencyCondition
extends Resource
## One structured precondition, evaluated by [ConditionEvaluator].
##
## Supported [member kind] values (see docs/ARCHITECTURE.md for the full table):
##   component_installed   subject = component id, expected = bool
##   component_flag        subject = component id, key = flag name, expected = bool
##   fastener_state        subject = fastener runtime id, key = removed|installed|tight|damaged
##   component_fasteners   subject = component id, key = removed|installed|tight (all retaining)
##   component_fault_free  subject = component id, expected = bool
##   fault_discovered      subject = component id, key = fault id
##   engine_running        expected = bool
##   charging_test_passed  (valid for the current assembly revision)
##   event                 subject = event id
##   tool_equipped         subject = tool id
##   part_in_inventory     subject = component id, key = "new" or ""
##   objective_complete    subject = objective id
##   fluid_state           subject = circuit id, key = full|empty|low|bled
##   test_passed           subject = diagnostic test id (valid for the current revision)
##   world_flag            subject = workshop flag (e.g. lift_raised), expected = bool

const KINDS: PackedStringArray = [
	"component_installed", "component_flag", "fastener_state", "component_fasteners",
	"component_fault_free", "fault_discovered", "engine_running", "charging_test_passed",
	"event", "tool_equipped", "part_in_inventory", "objective_complete",
	"fluid_state", "test_passed", "world_flag",
]

@export var kind: StringName = &""
@export var subject_id: StringName = &""
@export var key: StringName = &""
@export var expected: bool = true
## Optional player-facing text for when the condition is NOT met.
## When empty, a message is generated from the condition.
@export var message: String = ""


static func make(p_kind: StringName, p_subject: StringName, p_key: StringName = &"", p_expected: bool = true, p_message: String = "") -> DependencyCondition:
	var c := DependencyCondition.new()
	c.kind = p_kind
	c.subject_id = p_subject
	c.key = p_key
	c.expected = p_expected
	c.message = p_message
	return c
