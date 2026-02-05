extends Area2D
# class_name Projectile

var target: Node2D = null
var damage: int = 10
var speed: float = 400.0

# Özel Efektler
var is_headshot: bool = false
var effect_type: int = 0 # 0: None, 1: Slow, 2: Burn
var effect_duration: float = 0.0
var effect_value: float = 0.0
var damage_type: String = "PHYSICAL"

func initialize(_target: Node2D, _damage: int) -> void:
	target = _target
	damage = _damage
	# Hedefe dön
	if target and is_instance_valid(target):
		look_at(target.global_position)

func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		queue_free()
		return
	
	# Hedefe yönel
	var direction = (target.global_position - global_position).normalized()
	look_at(target.global_position)
	position += direction * speed * delta
	
	# Çarpışma kontrolü (mesafe bazlı veya Area2D sinyali ile)
	if global_position.distance_to(target.global_position) < 10.0:
		_hit_target()

func _hit_target() -> void:
	if target and is_instance_valid(target):
		if is_headshot:
			target.take_damage(99999, "PHYSICAL") # Tek Atış
			if target.has_method("show_floating_text"):
				target.show_floating_text("HEADSHOT!", Color.YELLOW) # Sarı (Daha belirgin)
		else:
			target.take_damage(damage, damage_type)
			
		# Efekt Uygula
		if effect_type == 1: # SLOW
			print("Applying SLOW effect")
			if target.has_method("apply_slow"):
				target.apply_slow(effect_value, effect_duration)
		elif effect_type == 2: # BURN
			print("Applying BURN effect")
			if target.has_method("apply_burn"):
				target.apply_burn(effect_value, effect_duration)
				
	queue_free()
