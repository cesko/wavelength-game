extends Control

@onready var score_label: Label = $MarginContainer/PanelContainer/ScoreLabel

func set_score(score:Score):
	score_label.text = str(score.score())
