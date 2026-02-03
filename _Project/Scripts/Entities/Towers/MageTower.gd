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

func _attack() -> void:
	if not target or not is_instance_valid(target): return
	
	if projectile_scene:
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		
		proj.initialize(target, damage)
		
		# Element efektlerini aktar
		if element_type == 1: # ICE
			proj.effect_type = 1
			proj.effect_value = 0.5 # %50 Hız
			proj.effect_duration = 3.0
			print("Mage fired ICE missile")
		elif element_type == 2: # FIRE
			proj.effect_type = 2
			proj.effect_value = 0.05 # %5 Can
			proj.effect_duration = 5.0
			print("Mage fired FIRE missile")
