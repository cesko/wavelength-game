@tool
extends Control

signal pressed
signal toggled(button_pressed: bool)

@export var button_text: String = "BUTTON":
	set(value):
		button_text = value
		if is_instance_valid(button):
			button.text = value

@export var color_a: Color = Color(0, 1, 1):
	set(value):
		color_a = value
		_update_colors()

@export var color_b: Color = Color(1, 0, 1):
	set(value):
		color_b = value
		_update_colors()

@export var hover_glow_mult: float = 1.6
@export var pressed_glow_mult: float = 0.7

@onready var bg: ColorRect = $NeonBackground
@onready var button: Button = $Button

var shader_mat: ShaderMaterial
var base_glow_strength: float = 2.0

func _ready():
	if is_instance_valid(bg):
		shader_mat = bg.material as ShaderMaterial

	if is_instance_valid(button):
		button.text = button_text

	_update_colors()

	if shader_mat:
		base_glow_strength = shader_mat.get_shader_parameter("glow_strength")

	if Engine.is_editor_hint():
		return

	button.mouse_entered.connect(_on_hover)
	button.mouse_exited.connect(_on_unhover)
	button.button_down.connect(_on_pressed)
	button.button_up.connect(_on_unhover)
	button.pressed.connect(_on_button_pressed)
	button.toggled.connect(_on_button_toggled)

func _on_button_pressed():
	pressed.emit()

func _on_button_toggled(is_pressed: bool):
	toggled.emit(is_pressed)

func _update_colors():
	# Guard: bail out entirely if nodes aren't ready yet
	if not is_instance_valid(bg):
		return
	if not shader_mat:
		shader_mat = bg.material as ShaderMaterial
	if not shader_mat:
		return
	shader_mat.set_shader_parameter("color_a", color_a)
	shader_mat.set_shader_parameter("color_b", color_b)

func _on_hover():
	_tween_glow(base_glow_strength * hover_glow_mult)

func _on_pressed():
	_tween_glow(base_glow_strength * pressed_glow_mult)

func _on_unhover():
	_tween_glow(base_glow_strength)

func _tween_glow(target: float):
	if not shader_mat:
		return
	var tw = create_tween()
	tw.tween_method(
		func(v): shader_mat.set_shader_parameter("glow_strength", v),
		shader_mat.get_shader_parameter("glow_strength"),
		target,
		0.15
	)
