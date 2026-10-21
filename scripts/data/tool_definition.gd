class_name ToolDefinition
extends Resource
## Immutable definition of a workshop tool.

enum Category { HAND, DRIVE, SOCKET, MEASURING, DIAGNOSTIC, LIGHTING }

## Unique tool ID, e.g. "ratchet".
@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.HAND
## Actions this tool can perform: loosen, tighten, torque, scan, illuminate, lever.
@export var actions: PackedStringArray = PackedStringArray()
## True when the tool drives a socket from the socket set (ratchet, torque wrench).
@export var uses_socket: bool = false
## True when the tool can bring a fastener to its final tightening target.
@export var can_final_torque: bool = false
## Short glyph/abbreviation used by the HUD and inventory (no image assets yet).
@export var ui_glyph: String = ""
## Hotbar slot (1-9). 0 = not on the hotbar.
@export var hotbar_slot: int = 0
@export_multiline var description: String = ""
## Socket sizes provided, for tools in the SOCKET category (millimetres).
@export var socket_sizes_mm: PackedInt32Array = PackedInt32Array()


func has_action(action: StringName) -> bool:
	return actions.has(String(action))
