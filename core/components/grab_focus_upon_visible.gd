extends Control

class_name GrabFocusUponVisibleComponent

var target:Control

func _ready() -> void:
	target = get_parent_control()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if is_visible_in_tree():
		target.grab_focus()
