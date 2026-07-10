extends Node2D
class_name StarField

@export var cell_size: float = 256.0
@export var stars_per_cell: int = 8
@export var min_star_size: float = 0.5
@export var max_star_size: float = 2.0
@export var sky_color: Color = Color(0.02, 0.02, 0.08)
@export var star_color_a: Color = Color(0.8, 0.8, 1.0)
@export var star_color_b: Color = Color(1.0, 1.0, 0.9)
@export var margin_cells: int = 1
@export var parallax_factor: float = 1.0
@export var star_seed: int = 12345
@export var wrap_cells: int = 2000 # keeps hashed cell coords bounded -> no drift

@export var enable_twinkle: bool = true
@export var twinkle_speed: float = 1.5

var _time: float = 0.0

func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	z_as_relative = false
	z_index = -100
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	var inv_transform: Transform2D = get_canvas_transform().affine_inverse()

	var top_left: Vector2 = inv_transform * viewport_rect.position
	var bottom_right: Vector2 = inv_transform * (viewport_rect.position + viewport_rect.size)
	var world_rect := Rect2(top_left, bottom_right - top_left).abs()

	# Apply parallax by scaling the "camera" position used for sampling stars
	var sample_pos: Vector2 = world_rect.position * parallax_factor
	var sample_size: Vector2 = world_rect.size

	# background fill covers actual visible world_rect (not the parallax-shifted one)
	draw_rect(Rect2(top_left - Vector2(cell_size, cell_size),
		world_rect.size + Vector2(cell_size, cell_size) * 2.0), sky_color)

	var start_x: int = int(floor(sample_pos.x / cell_size)) - margin_cells
	var end_x: int = int(ceil((sample_pos.x + sample_size.x) / cell_size)) + margin_cells
	var start_y: int = int(floor(sample_pos.y / cell_size)) - margin_cells
	var end_y: int = int(ceil((sample_pos.y + sample_size.y) / cell_size)) + margin_cells

	# offset to convert from "sample space" back into actual local draw space
	var draw_offset: Vector2 = world_rect.position - sample_pos

	for cy in range(start_y, end_y + 1):
		for cx in range(start_x, end_x + 1):
			_draw_cell_stars(cx, cy, draw_offset)


func _draw_cell_stars(cx: int, cy: int, draw_offset: Vector2) -> void:
	var wx: int = ((cx % wrap_cells) + wrap_cells) % wrap_cells
	var wy: int = ((cy % wrap_cells) + wrap_cells) % wrap_cells

	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_cell(wx, wy)

	var cell_base: Vector2 = Vector2(cx, cy) * cell_size + draw_offset

	for i in range(stars_per_cell):
		var pos: Vector2 = cell_base + Vector2(rng.randf(), rng.randf()) * cell_size

		var size: float = rng.randf_range(min_star_size, max_star_size)
		var brightness: float = rng.randf_range(0.4, 1.0)
		var col: Color = star_color_a.lerp(star_color_b, rng.randf())

		if enable_twinkle:
			var phase: float = float(_hash_cell(wx * 97 + i, wy) % 6283) / 1000.0
			brightness *= lerp(0.5, 1.0, 0.5 + 0.5 * sin(_time * twinkle_speed + phase))

		col.a = brightness
		draw_circle(pos, size, col)


func _hash_cell(cx: int, cy: int) -> int:
	var h: int = star_seed
	h = h ^ (cx * 374761393)
	h = h ^ (cy * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return abs(h) % 2147483647
