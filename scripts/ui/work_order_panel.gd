class_name WorkOrderPanel
extends ModalPanel
## J: the work order with complaint, objectives and sign-off.

var session: GameSession
var _meta: Label
var _objectives: VBoxContainer
var _report: Label
var _sign_btn: Button


func setup(p_session: GameSession) -> void:
	session = p_session
	var j := session.job.definition
	title_label.text = j.title
	_meta = UITheme.label("", UITheme.SIZE_BODY, UITheme.TEXT_DIM)
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.custom_minimum_size = Vector2(900, 0)
	body.add_child(_meta)
	body.add_child(UITheme.caption("Objectives"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_objectives = VBoxContainer.new()
	_objectives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_objectives)
	_report = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.custom_minimum_size = Vector2(900, 0)
	body.add_child(_report)
	_sign_btn = UITheme.button("Sign off and complete work order", _on_sign)
	body.add_child(_sign_btn)
	session.job.progress_changed.connect(func() -> void:
		if visible:
			_rebuild())


func _on_open() -> void:
	session.record_event(&"read_work_order")
	_report.text = ""
	_rebuild()


func _rebuild() -> void:
	var j := session.job.definition
	var v := session.vehicle.definition
	_meta.text = "Vehicle: %s — %s, %s\nCustomer complaint: %s\nNotes: %s" % [v.display_name, v.body_style, v.drivetrain, j.customer_complaint, j.technician_notes]
	ModalPanel.clear(_objectives)
	var current := session.job.current_objective()
	var n := 0
	for o: JobObjectiveDefinition in j.objectives:
		n += 1
		var done := session.job.is_complete(o.id)
		var is_current := current != null and current.id == o.id
		var col := UITheme.TEXT_FAINT if done else (UITheme.TEXT if is_current else UITheme.TEXT_DIM)
		var l := UITheme.label("%s  %02d   %s" % ["✓" if done else ("›" if is_current else "·"), n, o.text], UITheme.SIZE_BODY, col)
		_objectives.add_child(l)
	_sign_btn.disabled = session.job.signed_off
	if session.job.signed_off:
		_report.text = "Signed off. %d cr labour credited." % j.labour_payment


func _on_sign() -> void:
	var r := session.try_sign_off()
	_report.text = r.message
	_rebuild()
