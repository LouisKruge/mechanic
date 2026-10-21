class_name ConditionEvaluator
extends RefCounted
## Evaluates [DependencyCondition]s against a [ConditionContext] and explains
## failures in player-facing language.
##
## This is the shared rule engine for component removal/installation, toggles,
## fasteners, engine start, job objectives and job sign-off.


## True when the condition currently holds.
static func evaluate(c: DependencyCondition, ctx: ConditionContext) -> bool:
	match c.kind:
		&"component_installed":
			var inst := ctx.ctx_component(c.subject_id)
			return inst != null and inst.installed == c.expected
		&"component_flag":
			var inst := ctx.ctx_component(c.subject_id)
			return inst != null and inst.get_flag(c.key) == c.expected
		&"fastener_state":
			var f := ctx.ctx_fastener(c.subject_id)
			return f != null and _fastener_matches(f, c.key) == c.expected
		&"component_fasteners":
			var list := ctx.ctx_component_fasteners(c.subject_id)
			for f: FastenerInstance in list:
				if _fastener_matches(f, c.key) != c.expected:
					return false
			return true
		&"component_fault_free":
			var inst := ctx.ctx_component(c.subject_id)
			return inst != null and inst.installed and inst.is_fault_free() == c.expected
		&"fault_discovered":
			var inst := ctx.ctx_component(c.subject_id)
			return inst != null and inst.discovered_faults.has(String(c.key)) == c.expected
		&"engine_running":
			return ctx.ctx_engine_running() == c.expected
		&"charging_test_passed":
			return ctx.ctx_charging_test_passed() == c.expected
		&"event":
			return ctx.ctx_event(c.subject_id) == c.expected
		&"tool_equipped":
			return ctx.ctx_tool_equipped(c.subject_id) == c.expected
		&"part_in_inventory":
			return ctx.ctx_part_in_inventory(c.subject_id, c.key == &"new") == c.expected
		&"objective_complete":
			return ctx.ctx_objective_complete(c.subject_id) == c.expected
	push_error("Unknown condition kind '%s'" % c.kind)
	return false


## True when every condition holds.
static func all_met(conds: Array[DependencyCondition], ctx: ConditionContext) -> bool:
	for c: DependencyCondition in conds:
		if not evaluate(c, ctx):
			return false
	return true


## Explanations for every unmet condition, in order.
static func unmet_messages(conds: Array[DependencyCondition], ctx: ConditionContext) -> PackedStringArray:
	var out := PackedStringArray()
	for c: DependencyCondition in conds:
		if not evaluate(c, ctx):
			out.append(describe_unmet(c, ctx))
	return out


## The first unmet explanation, or "" if all conditions hold.
static func first_unmet(conds: Array[DependencyCondition], ctx: ConditionContext) -> String:
	for c: DependencyCondition in conds:
		if not evaluate(c, ctx):
			return describe_unmet(c, ctx)
	return ""


static func _fastener_matches(f: FastenerInstance, key: StringName) -> bool:
	match key:
		&"removed":
			return f.removed
		&"installed":
			return not f.removed
		&"tight":
			return f.is_to_spec()
	push_error("Unknown fastener state key '%s'" % key)
	return false


## Player-facing description of why [param c] is not satisfied.
static func describe_unmet(c: DependencyCondition, ctx: ConditionContext) -> String:
	if c.message != "":
		return c.message
	match c.kind:
		&"component_installed":
			return "%s is %s" % [_cname(c.subject_id, ctx), "not installed" if c.expected else "still installed"]
		&"component_flag":
			var def := ctx.ctx_component_def(c.subject_id)
			var t: ComponentToggleDefinition = def.get_toggle(c.key) if def else null
			if t:
				var current_text := t.state_false_text if c.expected else t.state_true_text
				return "%s is %s" % [_cname(c.subject_id, ctx), current_text]
			return "%s: '%s' must be %s" % [_cname(c.subject_id, ctx), c.key, c.expected]
		&"fastener_state":
			var f := ctx.ctx_fastener(c.subject_id)
			var fname := f.display_name() if f else String(c.subject_id)
			return fastener_message(fname, f, c.key, c.expected)
		&"component_fasteners":
			for f: FastenerInstance in ctx.ctx_component_fasteners(c.subject_id):
				if _fastener_matches(f, c.key) != c.expected:
					return fastener_message(f.display_name(), f, c.key, c.expected)
			return "%s fasteners are not in the required state" % _cname(c.subject_id, ctx)
		&"component_fault_free":
			return "%s still has a fault" % _cname(c.subject_id, ctx) if c.expected else "%s is fault-free" % _cname(c.subject_id, ctx)
		&"fault_discovered":
			return "the %s fault has not been identified" % ctx.ctx_fault_name(c.key).to_lower()
		&"engine_running":
			return "the engine is not running" if c.expected else "the engine is running"
		&"charging_test_passed":
			return "no passing charging-system test since the last change"
		&"event":
			return "%s has not happened yet" % String(c.subject_id).replace("_", " ")
		&"tool_equipped":
			return "the %s is not equipped" % String(c.subject_id).replace("_", " ")
		&"part_in_inventory":
			return "no %s%s in inventory" % ["new " if c.key == &"new" else "", _cname(c.subject_id, ctx).to_lower()]
		&"objective_complete":
			return "objective '%s' is not complete" % c.subject_id
	return "unknown requirement '%s'" % c.kind


static func fastener_message(fname: String, f: FastenerInstance, key: StringName, expected: bool) -> String:
	var is_conn := f != null and f.definition().is_hand_operated()
	match key:
		&"removed":
			if expected:
				return "%s is still %s" % [fname, "connected" if is_conn else "installed"]
			return "%s has been %s" % [fname, "disconnected" if is_conn else "removed"]
		&"installed":
			if expected:
				return "%s is %s" % [fname, "disconnected" if is_conn else "not fitted"]
			return "%s is still fitted" % fname
		&"tight":
			if f and f.get_state() == FastenerInstance.State.OVERTIGHT:
				return "%s is over-torqued — loosen and re-torque" % fname
			return "%s is not tightened to spec" % fname
	return "%s is not in the required state" % fname


static func _cname(component_id: StringName, ctx: ConditionContext) -> String:
	var def := ctx.ctx_component_def(component_id)
	return def.display_name if def else String(component_id)
