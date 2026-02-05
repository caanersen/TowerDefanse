extends Node2D
# class_name Soldier

signal died(soldier)

var max_health: int = 100 # Can arttırıldı
var current_health: int = 100
var damage: int = 10
var attack_rate: float = 1.0
var attack_timer: float = 0.0

var blocking_enemy: Node2D = null
var engage_range: float = 40.0 # Tespit menzili
var rally_position: Vector2

# Görsel
@onready var sprite: ColorRect = $Sprite

func initialize(pos: Vector2, hp: int = 100, dmg: int = 10) -> void:
	# position = pos 
	rally_position = pos
	max_health = hp
	current_health = hp
	damage = dmg

# ...


func _process(delta: float) -> void:
	if current_health <= 0: return

	# Eğer bir düşmanı bloklamıyorsak, yakınlarda düşman var mı bak
	if not blocking_enemy or not is_instance_valid(blocking_enemy):
		blocking_enemy = null
		_find_enemy_to_block()
		
		# Rally point'e geri dön (Eğer çok uzaklaştıysa)
		if global_position.distance_to(rally_position) > 5.0:
			global_position = global_position.move_toward(rally_position, 30 * delta)
			
	else:
		# Düşmanla savaşıyoruz
		# Düşmanın da bizi blokladığından emin ol
		if not blocking_enemy.is_blocked:
			blocking_enemy.engage(self)
			
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_rate
			blocking_enemy.take_damage(damage)
			# Görsel vuruş efekti
			var tween = create_tween()
			tween.tween_property(sprite, "position", Vector2(0, -5), 0.1)
			tween.tween_property(sprite, "position", Vector2(0, -10), 0.1) 
	

func _find_enemy_to_block() -> void:
	# Area2D zaten collision ile _on_area_entered tetikliyor.
	# Ancak bazen kaçırabilir, manuel tarama ekleyelim.
	var closest_dist = engage_range
	var candidate = null
	
	# Scene'deki düşmanları bul
	# var enemies = get_tree().get_nodes_in_group("enemies") # Unused
	# Eğer grup yoksa manuel bulma (GameManager üzerinden daha iyi olur ama)
	# Şimdilik Area2D'nin overlap ettiği body/arealara bakalım
	
	var area = $Area2D
	if area:
		var overlaps = area.get_overlapping_areas()
		for ov in overlaps:
			var parent = ov.get_parent()
			if parent.is_in_group("enemies") and not parent.is_blocked:
				# Uçan düşmanları yoksay
				if parent.get("is_flying"): continue
				
				var d = global_position.distance_to(parent.global_position)
				if d < closest_dist:
					closest_dist = d
					candidate = parent
	
	if candidate:
		engage_enemy(candidate)

func _on_area_entered(area: Area2D) -> void:
	if blocking_enemy: return # Zaten birini tutuyoruz
	
	var parent = area.get_parent()
	if parent.is_in_group("enemies") and not parent.is_blocked:
		if parent.get("is_flying"): return # Uçan düşmana dalma
		engage_enemy(parent)

func engage_enemy(enemy: Node2D) -> void:
	blocking_enemy = enemy
	enemy.engage(self)
	# Düşmana doğru hafif yaklaş
	# create_tween().tween_property(self, "global_position", enemy.global_position, 0.2)

func take_damage(amount: int) -> void:
	current_health -= amount
	
	# Kırmızı yanıp sönme efekti
	if sprite:
		# Modulate varsayılanı beyazdır, sprite rengi Mavi olsa bile.
		# Soldier.tscn içinde Sprite rengi Mavi olduğu için modulate'i kırmızı yaparsak koyu kırmızı olur.
		# Modulate'i Kırmızı yapıp sonra Base Color (1,1,1)'e geri döndüreceğiz.
		
		sprite.modulate = Color(3, 0, 0) # Parlak Kırmızı (HDR)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)

	if current_health <= 0:
		die()

func die() -> void:
	if blocking_enemy and is_instance_valid(blocking_enemy):
		blocking_enemy.disengage()
	emit_signal("died", self)
	queue_free()
