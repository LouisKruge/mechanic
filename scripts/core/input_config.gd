class_name InputConfig
extends RefCounted
## Registers the game's input actions at runtime.
##
## Actions are defined here rather than as serialized InputEvent blobs in
## project.godot so that the bindings are readable, reviewable and can be
## rebuilt for tests or future rebinding UI. Calling [method ensure_actions]
## more than once is safe: existing actions are left untouched.

const KEY_ACTIONS: Dictionary = {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"inspect": [KEY_F],
	"inventory": [KEY_TAB],
	"pause": [KEY_ESCAPE],
	"work_order": [KEY_J],
	"socket_next": [KEY_BRACKETRIGHT],
	"socket_prev": [KEY_BRACKETLEFT],
	"holster": [KEY_H],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"tool_slot_1": [KEY_1],
	"tool_slot_2": [KEY_2],
	"tool_slot_3": [KEY_3],
	"tool_slot_4": [KEY_4],
	"tool_slot_5": [KEY_5],
	"tool_slot_6": [KEY_6],
	"tool_slot_7": [KEY_7],
}

const MOUSE_ACTIONS: Dictionary = {
	"tool_primary": MOUSE_BUTTON_LEFT,
	"tool_secondary": MOUSE_BUTTON_RIGHT,
	"tool_adjust_up": MOUSE_BUTTON_WHEEL_UP,
	"tool_adjust_down": MOUSE_BUTTON_WHEEL_DOWN,
}


## Adds every action that is not already present in the InputMap.
static func ensure_actions() -> void:
	for action: String in KEY_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: int in KEY_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_ACTIONS[action] as MouseButton
		InputMap.action_add_event(action, mb)
