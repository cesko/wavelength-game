extends Control

@export var score_label: Label

func _ready() -> void:
	pass
	#position = Vector2.ZERO
	#custom_minimum_size = get_viewport().get_visible_rect().size
	#size = get_viewport().get_visible_rect().size

func set_score(score:Score):
	score_label.text = str(score.score())
