extends Node2D
class_name BaseTower

@export var attack_range: float = 200.0
@export var damage: int = 10
@export var fire_rate: float = 1.0
@export var projectile_scene: PackedScene

var level: int = 1
var max_level: int = 3

var can_shoot: bool = true
var target: BaseEnemy = null
var enemies_in_range: Array[BaseEnemy] = []
var is_selected: bool = false

@onready var timer: Timer = Timer.new()

func _ready() -> void:
	# Timer kurulumu
	timer.wait_time = fire_rate
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	# Area2D kurulumu
	var area = $Area2D
	if area:
		area.area_entered.connect(_on_area_entered)
		area.area_exited.connect(_on_area_exited)
		
		# CollisionShape (silindirik menzil)
		# Editörden eklenmiş olabilir, kontrol et
		var col = area.get_node_or_null("CollisionShape2D")
		var shape
		
		if col:
			shape = col.shape
			if not shape: # Node var ama shape yoksa
				shape = CircleShape2D.new()
				col.shape = shape
		else:
			# Yoksa oluştur
			shape = CircleShape2D.new()
			col = CollisionShape2D.new()
			col.shape = shape
			area.add_child(col)
		
		# Yarıçapı/Boyutu güncelle
		if shape is CircleShape2D:
			shape.radius = attack_range
		elif shape is RectangleShape2D:
			# Eğer kullanıcı dikdörtgen kullanmak isterse, boyutu menzile genişlet
			shape.size = Vector2(attack_range * 2, attack_range * 2)

func update_range_shape() -> void:
	var area = $Area2D
	if area:
		var col = area.get_node_or_null("CollisionShape2D")
		if col and col.shape:
			if col.shape is CircleShape2D:
				col.shape.radius = attack_range
			elif col.shape is RectangleShape2D:
				col.shape.size = Vector2(attack_range * 2, attack_range * 2)
	queue_redraw()

func _process(_delta: float) -> void:
	if target == null:
		_find_new_target()
	
	if target != null:
		if can_shoot:
			_attack()
			_start_cooldown()

func _start_cooldown() -> void:
	can_shoot = false
	timer.start()

func _find_new_target() -> void:
	# Menzildeki en öndeki düşmanı seç (progress'i en büyük olan)
	var max_progress: float = -1.0
	var best_target: BaseEnemy = null
	
	# Listeyi temizle (ölenler gitmiş olabilir)
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	
	for enemy in enemies_in_range:
		# Extra mesafe kontrolü (Area2D bazen kaçırabilir)
		if global_position.distance_to(enemy.global_position) > attack_range + 50.0:
			continue
			
		if enemy.progress > max_progress:
			max_progress = enemy.progress
			best_target = enemy
	
	target = best_target

func _attack() -> void:
	if target and is_instance_valid(target):
		# Default projectile logic
		if projectile_scene:
			var projectile = projectile_scene.instantiate()
			projectile.global_position = global_position
			get_tree().current_scene.add_child(projectile)
			projectile.initialize(target, damage)
		else:
			target.take_damage(damage)
	else:
		target = null

func _on_timer_timeout() -> void:
	can_shoot = true

# Düşman tespiti (Düşmanlarda Area2D olmalı)
func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is BaseEnemy:
		enemies_in_range.append(parent)

func _on_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is BaseEnemy:
		enemies_in_range.erase(parent)
		if target == parent:
			target = null

func upgrade() -> void:
	if level >= max_level:
		return
	
	level += 1
	damage = int(damage * 1.5)
	# Görsel değişim (Renk koyulaşsın veya boyutu artsın)
	scale *= 1.1
	update_range_shape()
	print(name, " upgraded to level ", level, ". Damage: ", damage)

func check_clicked(pos: Vector2) -> bool:
	# Mesafe kontrolü (Daha güvenilir)
	# Yarıçapı artırdım: 40px (Kullanıcı isteği üzerine rahat seçim)
	if global_position.distance_to(pos) < 40:
		return true
	return false

func set_selected(val: bool) -> void:
	is_selected = val
	queue_redraw()

func _draw() -> void:
	if is_selected:
		draw_circle(Vector2.ZERO, attack_range, Color(0, 1, 0, 0.1))
