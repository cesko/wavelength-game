@tool
extends Node2D

@export var step_size: float = 50.0
@export var start_length: float = 1000.0
@export var initial_total_length: float = 3000.0
@export var extend_buffer_min: float = 500.0
@export var cleanup_buffer_min: float = 500.0

@export var fill_extent: float = 2000.0
@export var collision_thickness: float = 200.0

@export var texture_tile_size: Vector2 = Vector2(128, 128)

@export var level_seed: int = -1

@onready var ceiling_body: StaticBody2D = $CeilingBody
@onready var ceiling_line: Line2D = $CeilingLine
@onready var ceiling_fill: Polygon2D = $CeilingFill

@onready var ground_body: StaticBody2D = $GroundBody
@onready var ground_line: Line2D = $GroundLine
@onready var ground_fill: Polygon2D = $GroundFill

var profile: EnvironmentProfile
var absolute_front_step: int = 0

var _visible_min_x: float = 0.0
var _visible_max_x: float = 0.0
var _bounds_valid: bool = false

var ceiling_segments: Array[CollisionPolygon2D] = []
var ground_segments: Array[CollisionPolygon2D] = []

var _ceiling_pool: Array[CollisionPolygon2D] = []
var _ground_pool: Array[CollisionPolygon2D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_editor_preview()
		return

	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_init_profile()
	_update_visible_bounds()
	_ensure_coverage()
	_append_new_segments(0)
	_rebuild_visuals()

func _init_profile() -> void:
	profile = EnvironmentProfile.new(start_length, initial_total_length, step_size, level_seed)

func _on_viewport_size_changed() -> void:
	if Engine.is_editor_hint():
		return
	if profile == null:
		return
	_update_visible_bounds()
	if _bounds_valid:
		_ensure_coverage()
		_check_cleanup()
		_rebuild_visuals()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if profile == null:
		return

	_update_visible_bounds()
	if not _bounds_valid:
		return

	_check_extend()
	_check_cleanup()
	

func _update_visible_bounds() -> void:
	var cam := _get_camera()
	if cam == null:
		_bounds_valid = false
		return

	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size

	var canvas_scale: float = viewport.get_canvas_transform().get_scale().x
	if not is_finite(canvas_scale) or absf(canvas_scale) < 0.0001:
		_bounds_valid = false
		return

	if cam.zoom.x == 0.0 or not is_finite(cam.zoom.x):
		_bounds_valid = false
		return

	var screen_to_world_scale: float = 1.0 / canvas_scale
	var half_width := (viewport_size.x * 0.5) * screen_to_world_scale / cam.zoom.x

	if not is_finite(half_width) or half_width <= 0.0:
		_bounds_valid = false
		return

	var cam_x := cam.global_position.x
	_visible_min_x = cam_x - half_width
	_visible_max_x = cam_x + half_width
	_bounds_valid = true

func _get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()

func _get_visible_x() -> Vector2:
	return Vector2(_visible_min_x, _visible_max_x)

func _get_extend_buffer() -> float:
	var visible_width: float = _visible_max_x - _visible_min_x
	return maxf(extend_buffer_min, visible_width * 0.5)

func _get_cleanup_buffer() -> float:
	var visible_width: float = _visible_max_x - _visible_min_x
	return maxf(cleanup_buffer_min, visible_width * 0.5)

# world x of profile.ceiling_profile[0] / profile.ground_profile[0]
func _front_world_x() -> float:
	return absolute_front_step * step_size

# world x of the LAST valid step in the current profile
func _back_world_x() -> float:
	return (absolute_front_step + profile.get_step_count() - 1) * step_size

func _ensure_coverage() -> void:
	if not _bounds_valid:
		return

	var target_x: float = _visible_max_x + _get_extend_buffer()
	var current_max_x := _back_world_x()

	if target_x > current_max_x:
		var additional_length := target_x - current_max_x
		var prev_step_count := profile.get_step_count()
		profile.extend(additional_length, step_size)
		_append_new_segments(prev_step_count)

func _check_extend() -> void:
	var prev_step_count := profile.get_step_count()
	_ensure_coverage()
	if profile.get_step_count() != prev_step_count:
		_rebuild_visuals()

func _check_cleanup() -> void:
	var cleanup_edge_x := _visible_min_x - _get_cleanup_buffer()
	# how many absolute steps must remain unreached to the left of cleanup edge
	var target_front_step := int(floor(cleanup_edge_x / step_size))
	var steps_to_trim := target_front_step - absolute_front_step

	steps_to_trim = clamp(steps_to_trim, 0, profile.get_step_count() - 2)

	if steps_to_trim <= 0:
		return

	profile.trim_front(steps_to_trim)
	absolute_front_step += steps_to_trim

	_trim_front_segments(steps_to_trim)
	_rebuild_visuals()

# ---------------------------------------------------------------------------
# Collision segment management (convex quads, added/removed incrementally)
# ---------------------------------------------------------------------------

func _get_pooled_segment(pool: Array[CollisionPolygon2D], parent: StaticBody2D) -> CollisionPolygon2D:
	if pool.size() > 0:
		return pool.pop_back()
	else:
		var col := CollisionPolygon2D.new()
		col.disabled = true
		parent.add_child(col)
		return col

func _append_new_segments(from_step_index: int) -> void:
	var step_count := profile.get_step_count()
	if step_count < 2:
		return

	var start_i: int = max(from_step_index, 1)

	for i in range(start_i, step_count):
		# IMPORTANT: use absolute_front_step + local index, NOT local index alone
		var x0 := (absolute_front_step + i - 1) * step_size
		var x1 := (absolute_front_step + i) * step_size

		var c0 := Vector2(x0, profile.ceiling_profile[i - 1])
		var c1 := Vector2(x1, profile.ceiling_profile[i])
		var c_seg := _get_pooled_segment(_ceiling_pool, ceiling_body)
		c_seg.polygon = _make_quad(c0, c1, collision_thickness, -1.0)
		c_seg.disabled = false
		ceiling_segments.append(c_seg)

		var g0 := Vector2(x0, profile.ground_profile[i - 1])
		var g1 := Vector2(x1, profile.ground_profile[i])
		var g_seg := _get_pooled_segment(_ground_pool, ground_body)
		g_seg.polygon = _make_quad(g0, g1, collision_thickness, 1.0)
		g_seg.disabled = false
		ground_segments.append(g_seg)

func _make_quad(p0: Vector2, p1: Vector2, thickness: float, offset_dir: float) -> PackedVector2Array:
	var o := Vector2(0, offset_dir * thickness)
	var quad := PackedVector2Array()
	quad.resize(4)
	quad[0] = p0
	quad[1] = p1
	quad[2] = p1 + o
	quad[3] = p0 + o
	return quad

func _trim_front_segments(count: int) -> void:
	count = min(count, ceiling_segments.size())
	for i in range(count):
		var c_seg := ceiling_segments[i]
		c_seg.disabled = true
		_ceiling_pool.append(c_seg)

		var g_seg := ground_segments[i]
		g_seg.disabled = true
		_ground_pool.append(g_seg)

	ceiling_segments = ceiling_segments.slice(count)
	ground_segments = ground_segments.slice(count)

# ---------------------------------------------------------------------------
# Visual rebuild (Line2D + Polygon2D fill)
# ---------------------------------------------------------------------------

func _rebuild_visuals() -> void:
	if profile == null:
		return

	var step_count := profile.get_step_count()
	var front_x := _front_world_x()
	var has_extra_point := _visible_min_x < front_x
	var total_points := step_count + (1 if has_extra_point else 0)

	var ceiling_points := PackedVector2Array()
	var ground_points := PackedVector2Array()
	ceiling_points.resize(total_points)
	ground_points.resize(total_points)

	var idx := 0
	if has_extra_point:
		# clip visually only; collision still starts exactly at front_x
		ceiling_points[0] = Vector2(_visible_min_x, profile.ceiling_profile[0])
		ground_points[0] = Vector2(_visible_min_x, profile.ground_profile[0])
		idx = 1

	for i in range(step_count):
		# IMPORTANT: same absolute formula as segments
		var x := (absolute_front_step + i) * step_size
		ceiling_points[idx] = Vector2(x, profile.ceiling_profile[i])
		ground_points[idx] = Vector2(x, profile.ground_profile[i])
		idx += 1

	ceiling_line.points = ceiling_points
	ground_line.points = ground_points

	_build_fill_polygon(ceiling_fill, ceiling_points, true)
	_build_fill_polygon(ground_fill, ground_points, false)

func _build_fill_polygon(poly_node: Polygon2D, profile_points: PackedVector2Array, is_ceiling: bool) -> void:
	var n := profile_points.size()
	if n < 2:
		return

	var offset_dir := -1.0 if is_ceiling else 1.0
	var offset_vec := Vector2(0, offset_dir * fill_extent)

	var poly := PackedVector2Array()
	poly.resize(n * 2)

	for i in range(n):
		poly[i] = profile_points[i]
	for i in range(n):
		poly[n + i] = profile_points[n - 1 - i] + offset_vec

	poly_node.polygon = poly

	var uvs := PackedVector2Array()
	uvs.resize(poly.size())
	for i in range(poly.size()):
		uvs[i] = poly[i]
	poly_node.uv = uvs

func _rebuild_editor_preview() -> void:
	pass
