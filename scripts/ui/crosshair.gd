class_name Crosshair
extends Control
## Small centre dot. Brightens when an interactable is targeted.

var active: bool = false:
	set(v):
		active = v
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 3.0, Color(0, 0, 0, 0.6))
	draw_circle(c, 2.0, Color(1, 1, 1, 0.95 if active else 0.65))
	if active:
		draw_arc(c, 9.0, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 1.0, true)
