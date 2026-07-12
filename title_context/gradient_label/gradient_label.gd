@tool
extends Label
class_name GradientLabel

@export var gradient_texture: GradientTexture1D:
	set(value):
		gradient_texture = value
		_update_shader_params()

const SHADER_FILENAME := "gradient_label.gdshader"

var _shader_material: ShaderMaterial


func _init() -> void:
	call_deferred("_setup_material")


func _ready() -> void:
	_setup_material()
	_ensure_default_gradient()
	_update_shader_params()
	_update_label_width()

	if not resized.is_connected(_update_label_width):
		resized.connect(_update_label_width)


func _setup_material() -> void:
	var script_path: String = (get_script() as Script).resource_path
	if script_path == "":
		push_warning("GradientLabel: script resource_path is empty, cannot locate shader.")
		return

	var shader_path := script_path.get_base_dir().path_join(SHADER_FILENAME)

	if not ResourceLoader.exists(shader_path):
		push_error("GradientLabel: Shader not found at " + shader_path)
		return

	var shader := load(shader_path) as Shader
	if shader == null:
		push_error("GradientLabel: Failed to load shader at " + shader_path)
		return

	if material is ShaderMaterial and (material as ShaderMaterial).shader == shader:
		_shader_material = material
	else:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader
		material = _shader_material

	_update_shader_params()
	_update_label_width()


func _ensure_default_gradient() -> void:
	if gradient_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.RED)
		gradient.set_color(1, Color.BLUE)
		var tex := GradientTexture1D.new()
		tex.gradient = gradient
		gradient_texture = tex


func _update_shader_params() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("gradient_texture", gradient_texture)


func _update_label_width() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("label_width", size.x)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_label_width()
