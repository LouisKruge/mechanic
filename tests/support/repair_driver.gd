class_name RepairDriver
extends RefCounted
## Drives a GameSession through player-equivalent inputs (the same session
## entry points that the E / F / LMB / RMB handlers call), so tests exercise
## the real rules rather than shortcuts.

const STEP: float = 1.0 / 60.0

var s: GameSession
var log: PackedStringArray = PackedStringArray()


func _init(session: GameSession) -> void:
	s = session
	s.message_posted.connect(func(t: String, ok: bool) -> void: log.append(("OK  " if ok else "NO  ") + t))


static func comp(id: StringName) -> Dictionary:
	return {"type": &"component", "id": id}


static func fast(id: StringName) -> Dictionary:
	return {"type": &"fastener", "id": id}


static func other(type: StringName, id: StringName = &"") -> Dictionary:
	return {"type": type, "id": id if id != &"" else type}


func last() -> String:
	return log[log.size() - 1] if not log.is_empty() else ""


func press(target: Dictionary) -> String:
	s.interact(target)
	return last()


func hold_primary(target: Dictionary, seconds: float) -> void:
	var t := 0.0
	var first := true
	while t < seconds:
		s.tool_primary(target, STEP, first)
		first = false
		t += STEP
	s.tool_released()


func hold_secondary(target: Dictionary, seconds: float) -> void:
	var t := 0.0
	var first := true
	while t < seconds:
		s.tool_secondary(target, STEP, first)
		first = false
		t += STEP
	s.tool_released()


func equip(tool: StringName, socket_mm: int = 0) -> void:
	s.equip_tool(tool)
	if socket_mm > 0:
		var guard := 0
		while s.tools.socket_mm != socket_mm and guard < 12:
			s.cycle_socket(1)
			guard += 1


func set_torque(nm: float) -> void:
	var steps := int(round((nm - s.tools.torque_setting_nm) / ToolManager.TORQUE_STEP_NM))
	s.adjust_tool(steps)


func tick(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		s.tick(STEP)
		t += STEP


# --- Procedure fragments ------------------------------------------------------

func arrive_and_diagnose() -> void:
	s.record_event(&"entered_workshop")
	press(other(&"work_order", &"board"))
	s.record_event(&"approached_vehicle")
	press(comp(&"hood"))
	equip(&"flashlight")
	hold_primary({}, STEP)  # beam on
	s.inspect(comp(&"alternator"))
	s.inspect(comp(&"battery"))
	equip(&"scanner")
	press(other(&"obd"))
	press(other(&"ignition"))  # start
	s.diagnostics.charging_test()
	tick(0.5)
	press(other(&"ignition"))  # stop


func disassemble() -> void:
	equip(&"ratchet", 10)
	hold_secondary(fast(&"battery.NEG"), 2.0)
	hold_primary(comp(&"belt_tensioner"), STEP)
	press(comp(&"accessory_belt"))
	press(fast(&"alternator.CONN"))
	equip(&"ratchet", 13)
	hold_secondary(fast(&"alternator.B01"), 4.0)
	hold_secondary(fast(&"alternator.B02"), 4.0)
	press(comp(&"alternator"))


func fit_new_alternator() -> void:
	press(other(&"shelf", &"alternator"))
	press(comp(&"alternator"))


func refit_and_torque_bolts(torque_nm: float = 45.0) -> void:
	press(fast(&"alternator.B01"))
	press(fast(&"alternator.B02"))
	equip(&"ratchet", 13)
	hold_primary(fast(&"alternator.B01"), 3.5)
	hold_primary(fast(&"alternator.B02"), 3.5)
	equip(&"torque_wrench", 13)
	set_torque(torque_nm)
	hold_primary(fast(&"alternator.B01"), 2.5)
	hold_primary(fast(&"alternator.B02"), 2.5)


func reassemble_rest() -> void:
	press(fast(&"alternator.CONN"))
	press(comp(&"accessory_belt"))
	equip(&"ratchet", 10)
	hold_primary(comp(&"belt_tensioner"), STEP)
	press(fast(&"battery.NEG"))
	hold_primary(fast(&"battery.NEG"), 2.0)


func verify_and_sign_off() -> ActionResult:
	equip(&"scanner")
	press(other(&"ignition"))
	tick(0.5)
	s.diagnostics.charging_test()
	s.job.evaluate()
	return s.try_sign_off()


func full_repair() -> ActionResult:
	arrive_and_diagnose()
	disassemble()
	fit_new_alternator()
	refit_and_torque_bolts()
	reassemble_rest()
	return verify_and_sign_off()
