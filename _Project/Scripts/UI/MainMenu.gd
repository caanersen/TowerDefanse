extends Control

func _ready() -> void:
	$PlayButton.pressed.connect(_on_play_button_pressed)

func _on_play_button_pressed() -> void:
	# Seviye Seçimine git (Henüz yok, placeholder print)
	print("Play button pressed. Loading Level Selection...")
	get_tree().change_scene_to_file("res://_Project/Scenes/UI/LevelSelection.tscn")
