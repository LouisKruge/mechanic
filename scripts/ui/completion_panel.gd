class_name CompletionPanel
extends ModalPanel
## Shown when a job is signed off.

var _text: Label


func setup(session: GameSession) -> void:
	title_label.text = "Work order complete"
	_text = UITheme.label("", UITheme.SIZE_BODY)
	_text.custom_minimum_size = Vector2(640, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_text)
	body.add_child(UITheme.button("Continue", close))
	session.job_finished.connect(func(_id: StringName) -> void:
		var j := session.job.definition
		var e := session.electrical
		_text.text = "%s\n\nVehicle: %s\nRepair: alternator replaced, charging verified at %.2f V.\nLabour credited: %d cr\n\nThis is the end of milestone 1. The workshop remains open — you can keep inspecting the car or save your game." % [j.title, session.vehicle.definition.display_name, float(session.diagnostics.last_test.get("voltage", e.system_voltage)), j.labour_payment]
		open())
