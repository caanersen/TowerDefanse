extends Node

var unlocked_levels: int = 10 # Şimdilik hepsi açık (Test)
var selected_level: int = 1

func _ready() -> void:
	print("GameManager initialized. Unlocked levels: ", unlocked_levels)

func unlock_next_level() -> void:
	if selected_level == unlocked_levels:
		unlocked_levels += 1
		print("Level ", unlocked_levels, " unlocked!")

func is_level_unlocked(level_id: int) -> bool:
	return level_id <= unlocked_levels
