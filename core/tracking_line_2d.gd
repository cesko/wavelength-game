extends Line2D
class_name TrackingLine2D

## How many seconds of history to keep
@export var track_duration: float = 2.0

## Minimum distance between recorded points (optimization, avoids overly dense points)
@export var min_distance_threshold: float = 1.0

## Whether to track global or local position
@export var track_global_position: bool = true

# Stores (timestamp, position) pairs
var _history: Array[Dictionary] = []

# Internal clock, driven by delta instead of wall time
var _elapsed_time: float = 0.0

# The node whose position we're tracking (defaults to self)
@export var target_node: Node2D

func _ready() -> void:
	if target_node == null:
		target_node = self
	# Clear points since we build them from history
	clear_points()

func _process(delta: float) -> void:
	_elapsed_time += delta
	_record_position()
	_prune_old_points()
	_rebuild_line_points()

func _record_position() -> void:
	var current_pos: Vector2
	if track_global_position:
		current_pos = target_node.global_position
	else:
		current_pos = target_node.position

	# Skip recording if too close to last recorded point (reduces point spam)
	if _history.size() > 0:
		var last_pos: Vector2 = _history[-1]["position"]
		if current_pos.distance_to(last_pos) < min_distance_threshold:
			return

	_history.append({
		"time": _elapsed_time,
		"position": current_pos
	})

func _prune_old_points() -> void:
	var cutoff: float = _elapsed_time - track_duration

	# Remove from front while too old
	while _history.size() > 0 and _history[0]["time"] < cutoff:
		_history.pop_front()

func _rebuild_line_points() -> void:
	clear_points()
	for entry in _history:
		var pos: Vector2 = entry["position"]
		if track_global_position:
			# Line2D points are in local space, so convert
			add_point(to_local(pos))
		else:
			add_point(pos)

## Optional: get position at a specific time offset (seconds ago)
func get_position_seconds_ago(seconds_ago: float) -> Vector2:
	if _history.is_empty():
		return target_node.global_position if track_global_position else target_node.position

	var target_time: float = _elapsed_time - seconds_ago

	# Find closest recorded point
	for i in range(_history.size() - 1, -1, -1):
		if _history[i]["time"] <= target_time:
			return _history[i]["position"]

	return _history[0]["position"]

## Clear all tracked history
func clear_history() -> void:
	_history.clear()
	clear_points()
