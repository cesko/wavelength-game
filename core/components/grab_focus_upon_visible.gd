extends Control

class_name GrabFocusUponVisibleComponent

var target: Control

func _ready() -> void:
	target = get_parent_control()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if is_visible_in_tree() and _should_grab_focus():
		target.grab_focus()

func _should_grab_focus() -> bool:
	# Touch-only devices (typically phones) usually don't benefit from focus grabbing.
	if DisplayServer.is_touchscreen_available() and Input.get_connected_joypads().is_empty():
		return false
	return true
