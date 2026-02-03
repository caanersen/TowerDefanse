extends Control

@export var total_levels: int = 10
@onready var grid_container: GridContainer = $CenterContainer/GridContainer

func _ready() -> void:
	_generate_level_buttons()

func _generate_level_buttons() -> void:
	# Temizle
	for child in grid_container.get_children():
		child.queue_free()
	
	for i in range(1, total_levels + 1):
		var btn = Button.new()
		btn.text = "Level " + str(i)
		btn.custom_minimum_size = Vector2(100, 100)
		
		# Kilit Mantığı
		if GameManager.is_level_unlocked(i):
			btn.disabled = false
			btn.pressed.connect(_on_level_selected.bind(i))
		else:
			btn.disabled = true
			# Kilit Görseli (Placeholder: Butonun üzerine 'KİLİTLİ' yazan bir Label ekle veya rengi değiştir)
			var lock_label = Label.new()
			lock_label.text = "KİLİTLİ"
			lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_label.set_anchors_preset(LayoutPreset.PRESET_FULL_RECT)
			btn.add_child(lock_label)
			btn.modulate = Color(0.5, 0.5, 0.5) # Karart
		
		grid_container.add_child(btn)

func _on_level_selected(level_id: int) -> void:
	GameManager.selected_level = level_id
	print("Level selected: ", level_id)
	# Oyun sahnesine git
	get_tree().change_scene_to_file("res://_Project/Scenes/Game/GameScene.tscn")
