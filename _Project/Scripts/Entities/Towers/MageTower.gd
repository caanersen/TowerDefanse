extends "res://_Project/Scripts/Entities/BaseTower.gd"

class_name MageTower

# 0: None, 1: Ice, 2: Fire
var element_type: int = 0 

func _ready():
	super._ready()
	max_level = 3 # Zaten base 3 ama emin olalım

func get_upgrade_cost() -> int:
	if level == 1: return 150
	if level == 2: return 300 # Branching seçim
	return 0

func upgrade() -> void:
	# Büyücü kulesi upgrade'i level 2->3 geçişinde özel seçim gerektirir.
	# Bu fonksiyon standart upgrade (Lvl 1->2) için kullanılabilir.
	# Lvl 2->3 için choose_element çağrılmalı.
	
	if level >= max_level: return
	
	if level == 1:
		level += 1
		damage += 15
		attack_range += 30.0
		fire_rate -= 0.1
		$Sprite.color = Color(0.2, 0.2, 1.0)
		update_range_shape()
	
	# Level 2->3 geçişi buraya düşerse varsayılan bir şey yapmamalı,
	# UI üzerinden choose_element çağrılmasını beklemeli.

func choose_element(type: int) -> void:
	if level != 2: return # Sadece level 2 iken seçim yapılabilir
	
	element_type = type
	level = 3
	
	damage += 30
	attack_range += 50.0
	
	if element_type == 1: # ICE
		# Ice görseli
		$Sprite.color = Color(0.0, 1.0, 1.0) # Cyan
	elif element_type == 2: # FIRE
		# Fire görseli
		$Sprite.color = Color(1.0, 0.5, 0.0) # Orange
	
	update_range_shape()

# MageTower'a özel hedef seçme mantığı
func _find_new_target() -> void:
	# Listeyi güncelle ve temizle
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	
	if enemies_in_range.is_empty():
		target = null
		return
		
	# 1. Öncelik: Etkilenmemiş en öndeki düşman
	var best_clean_target: BaseEnemy = null
	var max_clean_progress: float = -1.0
	
	# 2. Öncelik: Hepsi etkilenmişse en öndeki herhangi biri
	var best_any_target: BaseEnemy = null
	var max_any_progress: float = -1.0
	
	for enemy in enemies_in_range:
		# Mesafe kontrolü
		if global_position.distance_to(enemy.global_position) > attack_range + 50.0:
			continue
			
		var has_effect = false
		if element_type == 1: # ICE
			has_effect = enemy.is_slowed
		elif element_type == 2: # FIRE
			has_effect = enemy.is_burning
		
		# En öndekini takip et (Herkes için)
		if enemy.progress > max_any_progress:
			max_any_progress = enemy.progress
			best_any_target = enemy
			
		# Etkilenmemişse ayrıca takip et
		if not has_effect:
			if enemy.progress > max_clean_progress:
				max_clean_progress = enemy.progress
				best_clean_target = enemy
	
	# Eğer etkilenmemiş bir aday varsa onu seç, yoksa en öndekini seç
	if best_clean_target:
		target = best_clean_target
	else:
		target = best_any_target

# Her karede hedefi kontrol et: Eğer hedef zaten ekilendiyse ve başka aday varsa değiştirmek isteyebiliriz.
func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		var should_switch = false
		if element_type == 1 and target.is_slowed: should_switch = true
		elif element_type == 2 and target.is_burning: should_switch = true
		
		# Eğer hedef zaten etkilenmişse, hedefi bırak. 
		# BaseTower._process içindeki _find_new_target çağrısı (super._process ile veya sonraki karede) 
		# "temiz" bir hedef bulmaya çalışacak.
		if should_switch:
			target = null
			
	super._process(delta)

func _attack() -> void:
	if not target or not is_instance_valid(target): return
	
	if projectile_scene:
		var proj = projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj) # Parent fix
		proj.global_position = global_position
		
		proj.initialize(target, damage)
		
		# Element efektlerini aktar
		if element_type == 1: # ICE
			proj.effect_type = 1
			proj.effect_value = 0.5 # %50 Hız
			proj.effect_duration = 3.0 # Geri alındı (7s -> 3s)
			print("Mage fired ICE missile")
		elif element_type == 2: # FIRE
			proj.effect_type = 2
			proj.effect_value = 0.05 # %5 Can
			proj.effect_duration = 5.0
			print("Mage fired FIRE missile")
