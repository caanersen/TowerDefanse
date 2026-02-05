extends "res://_Project/Scripts/Entities/BaseTower.gd"
# class_name CatapultTower # Commented out to fix conflict

func _ready():
	super._ready()
	# Varsayılan değerler (Inspector'dan da ayarlanabilir)
	damage = 60
	fire_rate = 3.0 # Yavaş
	attack_range = 250.0 # Uzun menzil
	
	# Görsel (Geçici)
	var sprite = get_node_or_null("Sprite")
	if sprite:
		sprite.color = Color(0.4, 0.2, 0.1) # Kahverengi/Koyu
	
	can_target_flying = false # Mancınık uçanlara vuramaz

func get_upgrade_cost() -> int:
	return 150 * level # Pahalı upgrade

func upgrade() -> void:
	if level >= max_level: return
	
	level += 1
	damage += 20
	# AOE radius upgrade'i projectile'da olduğu için burada direkt projectile parametresi değiştiremiyoruz
	# Ancak projectile initialize edilirken kule leveline göre AOE atanabilir.
	# Şimdilik sadece hasar artıyor.
	print(name, " upgraded (Catapult)")
	
	scale *= 1.1
	update_range_shape()

func _attack() -> void:
	if target and is_instance_valid(target):
		if projectile_scene:
			var proj = projectile_scene.instantiate()
			proj.global_position = global_position
			get_tree().current_scene.add_child(proj)
			
			proj.initialize(target, damage)
			
			# Level'a göre AOE artışı
			if "aoe_radius" in proj:
				# AOE Yarıçapı daha da düşürüldü
				# Yeni: 40 + (lvl * 10) -> Max 70
				proj.aoe_radius = 40.0 + (level * 10.0)
				
			# Görsel hız ayarı (Mancınık taşı yavaş gider)
			proj.speed = 250.0
		else:
			target.take_damage(damage)
	else:
		target = null
