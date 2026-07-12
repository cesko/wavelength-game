extends Node

var title_context_scene = preload("res://title_context/title_root.tscn")
var title_context_node:Node

var game_context_scene = preload("res://game_context/game_root.tscn")
var game_context_node:Node

var _game_settings

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_title_context()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func unload_all():
	if game_context_node:
		game_context_node.queue_free()
	if title_context_node:
		title_context_node.queue_free()

func load_title_context() -> void:
	unload_all()
	title_context_node = title_context_scene.instantiate()
	title_context_node.play.connect(_on_start_game)
	add_child(title_context_node)

func load_game_context(game_settings:GameSettings) -> void:
	unload_all()
	_game_settings = game_settings
	game_context_node = game_context_scene.instantiate()
	game_context_node.game_settings = game_settings
	game_context_node.play_again.connect(_on_play_again)
	add_child(game_context_node)

func _on_start_game(game_settings:GameSettings) -> void:
	load_game_context(game_settings)
	
func _on_play_again():
	load_game_context(_game_settings)
