class_name JobManager
extends RefCounted
## Tracks work-order progress.
##
## Objectives latch: once an objective's conditions hold (after its
## prerequisites), it stays complete. Sign-off does NOT trust latches — it
## re-checks the job's completion requirements against the live vehicle.

signal objective_completed(objective_id: StringName)
signal job_completed(job_id: StringName)
signal progress_changed

const SIGN_OFF_EVENT: StringName = &"job_signed_off"

var definition: JobDefinition
var ctx: ConditionContext
var completed: Dictionary = {}  # StringName -> true
var signed_off: bool = false
var last_sign_off_report: PackedStringArray = PackedStringArray()


func _init(def: JobDefinition, p_ctx: ConditionContext) -> void:
	definition = def
	ctx = p_ctx


func is_complete(objective_id: StringName) -> bool:
	return completed.has(objective_id)


## Re-evaluates objectives in order (multiple passes until stable).
func evaluate() -> void:
	var any := true
	var guard := 0
	while any and guard < 64:
		any = false
		guard += 1
		for o: JobObjectiveDefinition in definition.objectives:
			if completed.has(o.id):
				continue
			if not _prereqs_done(o):
				continue
			if ConditionEvaluator.all_met(o.conditions, ctx):
				completed[o.id] = true
				any = true
				objective_completed.emit(o.id)
	if any or guard > 1:
		progress_changed.emit()


func _prereqs_done(o: JobObjectiveDefinition) -> bool:
	for a: String in o.after:
		if not completed.has(StringName(a)):
			return false
	return true


## First incomplete objective, or null when all are done.
func current_objective() -> JobObjectiveDefinition:
	for o: JobObjectiveDefinition in definition.objectives:
		if not completed.has(o.id):
			return o
	return null


func completed_count() -> int:
	return completed.size()


## Attempts to sign off the job. Returns failure reasons when blocked.
func try_sign_off() -> ActionResult:
	if signed_off:
		return ActionResult.fail("Job already signed off.")
	var report := PackedStringArray()
	for o: JobObjectiveDefinition in definition.objectives:
		if _is_sign_off_objective(o):
			continue
		if not completed.has(o.id):
			report.append("Objective incomplete: %s" % o.text)
	report.append_array(ConditionEvaluator.unmet_messages(definition.completion_requirements, ctx))
	last_sign_off_report = report
	if not report.is_empty():
		progress_changed.emit()
		return ActionResult.fail("Cannot sign off %s:\n• %s" % [definition.title, "\n• ".join(report)])
	signed_off = true
	return ActionResult.success("%s signed off. Vehicle ready for the customer." % definition.title)


func _is_sign_off_objective(o: JobObjectiveDefinition) -> bool:
	for c: DependencyCondition in o.conditions:
		if c.kind == &"event" and c.subject_id == SIGN_OFF_EVENT:
			return true
	return false


## Called by the session after the sign-off event has been recorded.
func finish() -> void:
	evaluate()
	job_completed.emit(definition.id)


func to_dict() -> Dictionary:
	var ids: Array = []
	for k: StringName in completed:
		ids.append(String(k))
	return {
		"job_id": String(definition.id),
		"completed_objectives": ids,
		"signed_off": signed_off,
	}


func from_dict(d: Dictionary, warnings: PackedStringArray) -> void:
	completed.clear()
	var valid := {}
	for o: JobObjectiveDefinition in definition.objectives:
		valid[String(o.id)] = true
	for k: Variant in d.get("completed_objectives", []):
		if valid.has(str(k)):
			completed[StringName(str(k))] = true
		else:
			warnings.append("Unknown objective '%s' in save ignored." % k)
	signed_off = bool(d.get("signed_off", false))
	progress_changed.emit()
