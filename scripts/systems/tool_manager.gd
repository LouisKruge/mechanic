class_name ToolManager
extends RefCounted
## Equipped tool, fitted socket size, torque-wrench setting and flashlight state.

signal changed

const TORQUE_MIN_NM: float = 5.0
const TORQUE_MAX_NM: float = 120.0
const TORQUE_STEP_NM: float = 1.0
const DEFAULT_TORQUE_SETTING_NM: float = 20.0
## Tool that provides sockets to drive tools.
const SOCKET_SET_ID: StringName = &"socket_set"

var db: ContentDatabase
var inventory: InventoryManager
## Equipped tool ID; &"" means bare hands.
var equipped: StringName = &""
## Socket fitted to the drive tool (mm), 0 = none.
var socket_mm: int = 0
var torque_setting_nm: float = DEFAULT_TORQUE_SETTING_NM
var flashlight_on: bool = false


func _init(p_db: ContentDatabase, p_inventory: InventoryManager) -> void:
	db = p_db
	inventory = p_inventory


func equipped_def() -> ToolDefinition:
	return db.get_tool(equipped) if equipped != &"" else null


func equipped_name() -> String:
	var t := equipped_def()
	return t.display_name if t else "Hands"


## Equips a tool the player owns.
func equip(tool_id: StringName) -> ActionResult:
	if tool_id == &"":
		return holster()
	var t := db.get_tool(tool_id)
	if t == null:
		return ActionResult.fail("Unknown tool '%s'." % tool_id)
	if not inventory.has_tool(tool_id):
		return ActionResult.fail("You do not have a %s." % t.display_name.to_lower())
	equipped = tool_id
	if t.uses_socket and socket_mm == 0:
		_auto_fit_socket()
	if tool_id != &"flashlight":
		flashlight_on = false
	changed.emit()
	var extra := ""
	if t.uses_socket:
		extra = " — %s" % socket_text()
	return ActionResult.success("Equipped %s%s." % [t.display_name.to_lower(), extra], false)


func holster() -> ActionResult:
	equipped = &""
	flashlight_on = false
	changed.emit()
	return ActionResult.success("Hands free.", false)


func available_sockets() -> PackedInt32Array:
	var t := db.get_tool(SOCKET_SET_ID)
	if t == null or not inventory.has_tool(SOCKET_SET_ID):
		return PackedInt32Array()
	return t.socket_sizes_mm


func _auto_fit_socket() -> void:
	var sizes := available_sockets()
	socket_mm = sizes[0] if sizes.size() > 0 else 0


## Steps the fitted socket through the socket set (dir = +1 / -1).
func cycle_socket(dir: int) -> ActionResult:
	var sizes := available_sockets()
	if sizes.is_empty():
		return ActionResult.fail("No socket set in inventory.")
	var i := sizes.find(socket_mm)
	i = posmod(i + dir, sizes.size()) if i >= 0 else 0
	socket_mm = sizes[i]
	changed.emit()
	return ActionResult.success("Socket: %d mm" % socket_mm, false)


## Adjusts the torque-wrench setting by whole steps.
func adjust_torque(steps: int) -> ActionResult:
	torque_setting_nm = clampf(torque_setting_nm + steps * TORQUE_STEP_NM, TORQUE_MIN_NM, TORQUE_MAX_NM)
	changed.emit()
	return ActionResult.success("Torque wrench set to %.0f N·m" % torque_setting_nm, false)


func toggle_flashlight() -> ActionResult:
	if equipped != &"flashlight":
		return ActionResult.fail("Flashlight not equipped.")
	flashlight_on = not flashlight_on
	changed.emit()
	return ActionResult.success("Flashlight %s." % ("on" if flashlight_on else "off"), false)


## True when a lit flashlight is in hand.
func is_illuminating() -> bool:
	return equipped == &"flashlight" and flashlight_on


func socket_text() -> String:
	return "%d mm socket" % socket_mm if socket_mm > 0 else "no socket"


## One-line description for the HUD.
func hud_text() -> String:
	var t := equipped_def()
	if t == null:
		return "HANDS"
	var s := t.display_name.to_upper()
	if t.uses_socket:
		s += "  ·  %s" % socket_text()
	if t.can_final_torque:
		s += "  ·  set %.0f N·m" % torque_setting_nm
	if t.id == &"flashlight":
		s += "  ·  %s" % ("ON" if flashlight_on else "OFF")
	return s


func to_dict() -> Dictionary:
	return {
		"equipped": String(equipped),
		"socket_mm": socket_mm,
		"torque_setting_nm": torque_setting_nm,
		"flashlight_on": flashlight_on,
	}


func from_dict(d: Dictionary) -> void:
	var e := StringName(str(d.get("equipped", "")))
	equipped = e if (e == &"" or (db.tools.has(e) and inventory.has_tool(e))) else &""
	var s := int(d.get("socket_mm", 0))
	socket_mm = s if available_sockets().has(s) else 0
	torque_setting_nm = clampf(float(d.get("torque_setting_nm", DEFAULT_TORQUE_SETTING_NM)), TORQUE_MIN_NM, TORQUE_MAX_NM)
	flashlight_on = bool(d.get("flashlight_on", false)) and equipped == &"flashlight"
	changed.emit()
