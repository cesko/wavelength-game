extends Node

var title_context_scene = preload("res://title_context/title_root.tscn")
var title_context_node: Node

var game_context_scene = preload("res://game_context/game_root.tscn")
var game_context_node: Node

var _game_settings:GameSettings

func _ready() -> void:
	print("Viewport size: ", get_viewport().size)
	load_title_context()

func unload_all() -> void:
	if game_context_node:
		game_context_node.queue_free()
		await game_context_node.tree_exited
		game_context_node = null
	if title_context_node:
		title_context_node.queue_free()
		await title_context_node.tree_exited
		title_context_node = null

func load_title_context() -> void:
	await unload_all()
	title_context_node = title_context_scene.instantiate()
	title_context_node.play.connect(_on_start_game)
	title_context_node.exit.connect(exit)
	add_child(title_context_node)

func load_game_context(game_settings: GameSettings) -> void:
	await unload_all()
	game_settings.level_seed = 42
	_game_settings = game_settings
	game_context_node = game_context_scene.instantiate()
	game_context_node.game_settings = game_settings
	game_context_node.play_again.connect(_on_play_again)
	game_context_node.quit_game.connect(_on_game_quit)
	game_context_node.new_score.connect(_on_new_score)
	add_child(game_context_node)

func _on_start_game(game_settings: GameSettings) -> void:
	load_game_context(game_settings)

func _on_play_again() -> void:
	load_game_context(_game_settings)

func _on_game_quit() -> void:
	load_title_context()

func _on_new_score(_score: Score) -> void:
	HighscoreManager.add_score(_game_settings.difficulty, "Unknown Player", _score.score())

func exit() -> void:
	get_tree().quit()
