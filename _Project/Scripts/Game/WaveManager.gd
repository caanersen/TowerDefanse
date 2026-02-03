extends Node

signal wave_started(wave_num)
signal wave_ended(wave_num)
signal on_enemy_reward(amount)

@export var goblin_scene: PackedScene
@export var troll_scene: PackedScene
@export var warg_scene: PackedScene # Editor'den atanamazsa initialize'da yüklenir

# Export artık gerekli değil veya boş olabilir, initialize ile atanacak
var spawn_path: Path2D 

var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_alive: int = 0

@onready var spawn_timer: Timer = Timer.new()

func _ready() -> void:
	spawn_timer.wait_time = 1.0 # 1 saniye arayla spawn
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)
	
	# start_next_wave'i LevelController çağıracak (initialize sonrası)

func initialize(path_node: Path2D) -> void:
	spawn_path = path_node
	if warg_scene == null:
		warg_scene = load("res://_Project/Scenes/Entities/Enemies/Warg.tscn")
	print("WaveManager initialized with path.")

func start_next_wave() -> void:
	current_wave += 1
	var base_count = 10
	# Formül: Linear Scaling. Her wave +5 düşman.
	# Wave 1: 10, Wave 2: 15, ..., Wave 10: 55
	enemies_to_spawn = base_count + (current_wave - 1) * 5
	
	emit_signal("wave_started", current_wave)
	print("Wave ", current_wave, " started! Enemies: ", enemies_to_spawn)
	spawn_timer.start()

func _spawn_enemy() -> void:
	if enemies_to_spawn <= 0:
		spawn_timer.stop()
		return
	
	var enemy_instance
	
	# WAVE LOGIC
	if current_wave == 10:
		# BOSS WAVE
		if enemies_to_spawn <= 5: # Son 5 düşman Troll
			enemy_instance = troll_scene.instantiate()
		else:
			# Geri kalanı Warg sürüsü
			enemy_instance = warg_scene.instantiate()
	
	elif current_wave >= 8:
		# HARD WAVES (Warg + Troll + Goblin)
		var roll = randf()
		if roll < 0.4: enemy_instance = warg_scene.instantiate()
		elif roll < 0.5: enemy_instance = troll_scene.instantiate() # Nadir Troll
		else: enemy_instance = goblin_scene.instantiate()
		
	elif current_wave >= 5:
		# MID WAVES (Goblin + Warg)
		if randf() < 0.3: # %30 Warg
			enemy_instance = warg_scene.instantiate()
		else:
			enemy_instance = goblin_scene.instantiate()
	
	else:
		# EASY WAVES
		enemy_instance = goblin_scene.instantiate()
	
	if enemy_instance:
		spawn_path.add_child(enemy_instance)
		enemy_instance.died.connect(_on_enemy_died)
		enemy_instance.reached_base.connect(_on_enemy_reached_base) # Bağla
		enemies_alive += 1
	
	enemies_to_spawn -= 1

func _on_enemy_reached_base(_enemy) -> void:
	enemies_alive -= 1
	_check_wave_completion()

func _on_enemy_died(enemy) -> void:
	enemies_alive -= 1
	
	if enemy.get("gold_reward"):
		emit_signal("on_enemy_reward", enemy.gold_reward)
	
	_check_wave_completion()

var _is_waiting_next_wave: bool = false

func _check_wave_completion() -> void:
	if enemies_alive <= 0 and enemies_to_spawn <= 0:
		if not _is_waiting_next_wave:
			_on_wave_completed()

func _on_wave_completed() -> void:
	print("Wave ", current_wave, " completed!")
	emit_signal("wave_ended", current_wave)
	
	if current_wave >= 10:
		# Oyun Bitti (Kazanıldı)
		print("Level Completed!")
		GameManager.unlock_next_level()
		
		# Biraz bekle sonra ana menüye dön
		_is_waiting_next_wave = true
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://_Project/Scenes/UI/LevelSelection.tscn")
		return

	# Sonraki Wave
	_is_waiting_next_wave = true
	# Kullanıcı "ard arda" dediği için süreyi biraz artıralım (5s -> 10s) veya yeterli. 
	# Double trigger flag'i _is_waiting_next_wave ile çözdük.
	await get_tree().create_timer(5.0).timeout
	_is_waiting_next_wave = false
	start_next_wave()
