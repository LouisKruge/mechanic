class_name Crosshair
extends Control
## Small centre dot. Brightens when an interactable is targeted and pulses
## briefly when an action is blocked.

var active: bool = false:
	set(v):
		active = v
		queue_redraw()
var _pulse: float = 0.0


## Called when an action is refused.
func flash() -> void:
	_pulse = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 3.0, Color(0, 0, 0, 0.6))
	draw_circle(c, 2.0, Color(1, 1, 1, 0.95 if active else 0.65))
	if active:
		draw_arc(c, 9.0, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 1.0, true)
	if _pulse > 0.0:
		draw_arc(c, 10.0 + (1.0 - _pulse) * 14.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * _pulse), 2.0, true)
