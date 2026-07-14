@tool
extends Node2D

@export var step_size: float = 50.0
@export var start_length: float = 1000.0
@export var initial_total_length: float = 3000.0
@export var extend_buffer: float = 500.0  # generate ahead of camera edge
@export var cleanup_buffer: float = 500.0 # despawn behind camera edge

@export var fill_extent: float = 2000.0  # how far above/below to extend the fill
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
var trimmed_step_offset: int = 0
var _visible_min_x: float = 0.0
var _visible_max_x: float = 0.0

# Per-segment convex collision shapes (one per step interval).
var ceiling_segments: Array[CollisionPolygon2D] = []
var ground_segments: Array[CollisionPolygon2D] = []

# Pools of freed CollisionPolygon2D nodes, reused instead of instantiating anew.
var _ceiling_pool: Array[CollisionPolygon2D] = []
var _ground_pool: Array[CollisionPolygon2D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_editor_preview()
		return

	_init_profile()
	_update_visible_bounds()
	_append_new_segments(0)
	_rebuild_visuals()


func _init_profile() -> void:
	profile = EnvironmentProfile.new(start_length, initial_total_length, step_size, level_seed)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if profile == null:
		return

	_update_visible_bounds()
	_check_extend()
	_check_cleanup()


func _update_visible_bounds() -> void:
	var cam := _get_camera()
	if cam == null:
		return

	var viewport_size := get_viewport_rect().size
	var half_width := (viewport_size.x * 0.5) / cam.zoom.x

	var cam_x := cam.global_position.x
	_visible_min_x = cam_x - half_width
	_visible_max_x = cam_x + half_width


func _get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()

func _get_visible_x() -> Vector2:
	return Vector2(_visible_min_x, _visible_max_x)


func _check_extend() -> void:
	var target_x: float = _get_visible_x()[1] + extend_buffer
	var current_max_x := global_position.x + (profile.get_step_count() - 1) * step_size

	if target_x > current_max_x:
		var additional_length := target_x - current_max_x
		var prev_step_count := profile.get_step_count()
		profile.extend(additional_length, step_size)
		_append_new_segments(prev_step_count)
		_rebuild_visuals()


func _check_cleanup() -> void:
	var cleanup_edge_x := _visible_min_x - cleanup_buffer
	var local_cleanup_x := cleanup_edge_x - global_position.x
	var steps_to_trim := int(floor(local_cleanup_x / step_size))

	steps_to_trim = clamp(steps_to_trim, 0, profile.get_step_count() - 2)

	if steps_to_trim <= 0:
		return

	profile.trim_front(steps_to_trim)
	trimmed_step_offset += steps_to_trim

	_trim_front_segments(steps_to_trim)

	var delta_x := steps_to_trim * step_size
	_shift_segments(delta_x)          # <-- FIX: re-baseline remaining segments
	global_position.x += delta_x

	_rebuild_visuals()


# ---------------------------------------------------------------------------
# Collision segment management (convex quads, added/removed incrementally)
# ---------------------------------------------------------------------------

func _get_pooled_segment(pool: Array[CollisionPolygon2D], parent: StaticBody2D) -> CollisionPolygon2D:
	if pool.size() > 0:
		var col:CollisionPolygon2D = pool.pop_back()
		col.disabled = false
		return col
	else:
		var col := CollisionPolygon2D.new()
		parent.add_child(col)
		return col


func _append_new_segments(from_step_index: int) -> void:
	var step_count := profile.get_step_count()
	if step_count < 2:
		return

	var start_i :int = max(from_step_index, 1)

	for i in range(start_i, step_count):
		var x0 := (i - 1) * step_size
		var x1 := i * step_size

		var c0 := Vector2(x0, profile.ceiling_profile[i - 1])
		var c1 := Vector2(x1, profile.ceiling_profile[i])
		var c_seg := _get_pooled_segment(_ceiling_pool, ceiling_body)
		c_seg.polygon = _make_quad(c0, c1, collision_thickness, -1.0)
		ceiling_segments.append(c_seg)

		var g0 := Vector2(x0, profile.ground_profile[i - 1])
		var g1 := Vector2(x1, profile.ground_profile[i])
		var g_seg := _get_pooled_segment(_ground_pool, ground_body)
		g_seg.polygon = _make_quad(g0, g1, collision_thickness, 1.0)
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


func _shift_segments(delta_x: float) -> void:
	# Segment polygons are stored in local coordinates relative to this node.
	# Since global_position.x is shifted on trim, and segments were built
	# using local x = i * step_size (pre-shift), we must offset their
	# polygon points by -delta_x to remain visually/physically consistent
	# after the parent node moves. This keeps their world-space position fixed.
	for seg in ceiling_segments:
		var poly := seg.polygon
		for i in range(poly.size()):
			poly[i].x -= delta_x
		seg.polygon = poly
	for seg in ground_segments:
		var poly := seg.polygon
		for i in range(poly.size()):
			poly[i].x -= delta_x
		seg.polygon = poly


# ---------------------------------------------------------------------------
# Visual rebuild (Line2D + Polygon2D fill) — kept as full-array rebuilds,
# since these are cheap CPU-side writes with no physics baking involved.
# ---------------------------------------------------------------------------

func _rebuild_visuals() -> void:
	if profile == null:
		return

	var step_count := profile.get_step_count()
	var local_min_x := _visible_min_x - global_position.x
	var has_extra_point := local_min_x < 0.0
	var total_points := step_count + (1 if has_extra_point else 0)

	var ceiling_points := PackedVector2Array()
	var ground_points := PackedVector2Array()
	ceiling_points.resize(total_points)
	ground_points.resize(total_points)

	var idx := 0
	if has_extra_point:
		ceiling_points[0] = Vector2(local_min_x, profile.ceiling_profile[0])
		ground_points[0] = Vector2(local_min_x, profile.ground_profile[0])
		idx = 1

	for i in range(step_count):
		var x := i * step_size
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


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

## Given a global-space position, returns the vertical distance from that
## point to the ceiling profile and to the ground profile (Y-component only).
## If the given X falls outside the currently generated strip, returns a
## negative value: how far past the left edge (if < 0) or right edge
## (if > max_x) the point is, for both components.
func get_vertical_distances(global_pos: Vector2) -> Vector2:
	if profile == null:
		return Vector2(-1.0, -1.0)

	var step_count := profile.get_step_count()
	if step_count < 2:
		return Vector2(-1.0, -1.0)

	var local_x := global_pos.x - global_position.x
	var max_x := (step_count - 1) * step_size

	if local_x < 0.0:
		return Vector2(local_x, local_x)
	if local_x > max_x:
		var overflow := max_x - local_x
		return Vector2(overflow, overflow)

	var f := local_x / step_size
	var i0 := int(floor(f))
	i0 = clamp(i0, 0, step_count - 2)
	var i1 := i0 + 1
	var t := f - float(i0)

	var ceiling_y := float(lerp(profile.ceiling_profile[i0], profile.ceiling_profile[i1], t))
	var ground_y := float(lerp(profile.ground_profile[i0], profile.ground_profile[i1], t))

	var local_y := global_pos.y - global_position.y

	var dist_to_ceiling := absf(local_y - ceiling_y)
	var dist_to_floor := absf(local_y - ground_y)

	return Vector2(dist_to_ceiling, dist_to_floor)


# ---------------------------------------------------------------------------
# Editor preview stub (implement per your existing setup)
# ---------------------------------------------------------------------------

func _rebuild_editor_preview() -> void:
	pass
