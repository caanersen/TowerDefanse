extends "res://_Project/Scripts/Entities/BaseTower.gd"

# class_name ArcherTower # Commented out to fix conflict

var has_headshot: bool = false

func _ready():
	super._ready()
	damage = 20 # Arttırılmış hasar
	fire_rate = 1.0

# Upgrade maliyeti hesaplama (Override)
func get_upgrade_cost() -> int:
	if level == 1: return 100
	if level == 2: return 350
	return 0

# Upgrade işlemi (Override)
func upgrade() -> void:
	if level >= max_level: return
	
	level += 1
	if level == 2:
		damage += 10
		fire_rate = 0.8 # Hızlanıyor
		attack_range += 20.0
		# Görsel güncelleme (Örn: renk açılması)
		$Sprite.color = Color(0.2, 1.0, 0.2)
	elif level == 3:
		damage += 20
		fire_rate = 0.6 # Daha da hızlanıyor
		attack_range += 30.0
		has_headshot = true
		$Sprite.color = Color(0.5, 1.0, 0.5)
	
	update_range_shape()

# Atış yapma (Override)
func _attack() -> void:
	if not target or not is_instance_valid(target): return
	
	if projectile_scene:
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		
		# Projecktili hazırla
		proj.initialize(target, damage)
		
		# Headshot şansı
		if has_headshot:
			if randf() < 0.25: # %25 Şans
				proj.is_headshot = true
				print("Archer triggered HEADSHOT chance!")
