@tool
extends Node2D

@export var step_size: float = 50.0
@export var start_length: float = 1000.0
@export var initial_total_length: float = 3000.0
@export var extend_buffer: float = 500.0  # generate ahead of camera edge
@export var cleanup_buffer: float = 500.0 # despawn behind camera edge

@export var fill_extent: float = 2000.0  # how far above/below to extend the fill

@export var texture_tile_size: Vector2 = Vector2(128, 128)

@export var level_seed: int = -1
	#set(value):
		#level_seed = value
		#_init_profile()
		

# Editor-only: forces a rebuild when toggled/changed in the inspector.
@export var editor_preview: bool = true:
	set(value):
		editor_preview = value
		if Engine.is_editor_hint():
			_rebuild_editor_preview()

@export_tool_button("Regenerate Preview")
var regenerate_action: Callable = _rebuild_editor_preview

var profile: EnvironmentProfile

# Tracks how many steps have been trimmed from the front,
# so we know the world-space x of index 0.
var trimmed_step_offset: int = 0

@onready var ceiling_body: StaticBody2D = $CeilingBody
@onready var ceiling_collision: CollisionPolygon2D = $CeilingBody/CollisionPolygon2D
@onready var ceiling_line: Line2D = $CeilingLine
@onready var ceiling_fill: Polygon2D = $CeilingFill

@onready var ground_body: StaticBody2D = $GroundBody
@onready var ground_collision: CollisionPolygon2D = $GroundBody/CollisionPolygon2D
@onready var ground_line: Line2D = $GroundLine
@onready var ground_fill: Polygon2D = $GroundFill


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_editor_preview()
		return

	_init_profile()
	_rebuild_meshes()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_check_extend()
	_check_cleanup()

# ------------------------------------------------------------------
# EDITOR PREVIEW
# ------------------------------------------------------------------

func _rebuild_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
	if not editor_preview:
		return

	# Build a lightweight profile just for preview purposes.
	profile = EnvironmentProfile.new(start_length, initial_total_length, step_size)
	_rebuild_meshes()


# ------------------------------------------------------------------
# RUNTIME LOGIC (unchanged)
# ------------------------------------------------------------------

func _init_profile() -> void:
	profile = EnvironmentProfile.new(start_length, initial_total_length, step_size, level_seed)

func _get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()

func _get_visible_x() -> Vector2:
	var camera := _get_camera()
	if camera == null:
		return Vector2.ZERO
	
	var viewport_size := get_viewport_rect().size
	var visible_half_width := (viewport_size.x * camera.zoom.x) / 2.0
	return Vector2(
		camera.global_position.x - visible_half_width,
		camera.global_position.x + visible_half_width)

func _check_extend() -> void:
	
	var target_x:float = _get_visible_x()[1] + extend_buffer
	var current_max_x := self.global_position.x + (profile.get_step_count() - 1) * step_size
	
	if target_x > current_max_x:
		var additional_length := target_x - current_max_x
		profile.extend(additional_length, step_size)
		_rebuild_meshes()


func _check_cleanup() -> void:
	var cleanup_edge_x :=  _get_visible_x()[0] - cleanup_buffer

	var local_cleanup_x := cleanup_edge_x - self.global_position.x
	var steps_to_trim := int(floor(local_cleanup_x / step_size))

	steps_to_trim = clamp(steps_to_trim, 0, profile.get_step_count() - 2)

	if steps_to_trim <= 0:
		return

	profile.trim_front(steps_to_trim)
	trimmed_step_offset += steps_to_trim

	self.global_position.x += steps_to_trim * step_size

	_rebuild_meshes()


func _rebuild_meshes() -> void:
	if profile == null:
		return

	var ceiling_points := PackedVector2Array()
	var ground_points := PackedVector2Array()

	var minimum_x = _get_visible_x()[0]
	if minimum_x < 0:
		print("minimum_x: ", minimum_x)
		ceiling_points.append(Vector2(minimum_x, profile.ceiling_profile[0]))
		ground_points.append(Vector2(minimum_x, profile.ground_profile[0]))
		
	
	for i in range(profile.get_step_count()):
		var x := i * step_size
		ceiling_points.append(Vector2(x, profile.ceiling_profile[i]))
		ground_points.append(Vector2(x, profile.ground_profile[i]))

	ceiling_line.points = ceiling_points
	ground_line.points = ground_points

	_build_collision_polygon(ceiling_collision, ceiling_points, true)
	_build_collision_polygon(ground_collision, ground_points, false)

	_build_fill_polygon(ceiling_fill, ceiling_points, true)
	_build_fill_polygon(ground_fill, ground_points, false)


func _build_collision_polygon(col: CollisionPolygon2D, profile_points: PackedVector2Array, is_ceiling: bool) -> void:
	var thickness := 200.0
	var offset_dir := -1.0 if is_ceiling else 1.0

	var top_points := profile_points
	var bottom_points := PackedVector2Array()
	for p in profile_points:
		bottom_points.append(p + Vector2(0, offset_dir * thickness))

	var poly := PackedVector2Array()
	poly.append_array(top_points)
	for i in range(bottom_points.size() - 1, -1, -1):
		poly.append(bottom_points[i])

	col.polygon = poly


func _build_fill_polygon(poly_node: Polygon2D, profile_points: PackedVector2Array, is_ceiling: bool) -> void:
	if profile_points.size() < 2:
		return

	var offset_dir := -1.0 if is_ceiling else 1.0

	var top_points := profile_points
	var far_points := PackedVector2Array()
	for p in profile_points:
		far_points.append(p + Vector2(0, offset_dir * fill_extent))

	var poly := PackedVector2Array()
	poly.append_array(top_points)
	for i in range(far_points.size() - 1, -1, -1):
		poly.append(far_points[i])

	poly_node.polygon = poly

	var uvs := PackedVector2Array()
	for p in poly:
		uvs.append(p)
	poly_node.uv = uvs
