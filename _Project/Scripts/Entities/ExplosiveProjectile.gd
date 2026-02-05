extends "res://_Project/Scripts/Entities/Projectile.gd"
# class_name ExplosiveProjectile

var aoe_radius: float = 100.0

func _hit_target() -> void:
	# Patlama efekti (Basit)
	# Burada normalde bir patlama sahnesi instantiate ederdik.
	# Şimdilik konsola yazalım ve alan hasarı verelim.
	
	if target and is_instance_valid(target):
		var parent = target.get_parent()
		if parent:
			for enemy in parent.get_children():
				if enemy.is_in_group("enemies") and is_instance_valid(enemy):
					if global_position.distance_to(enemy.global_position) <= aoe_radius:
						enemy.take_damage(damage)
						# Herkese efekt uygulamak istersek buraya ekleyebiliriz
						
	# Görsel geri bildirim (Merkezde büyük bir metin?)
	# Patlama efekti olmadığı için geçici olarak floating text patlatalım
	var label = Label.new()
	label.text = "BOOM!"
	label.modulate = Color(1, 0.5, 0)
	label.z_index = 101
	label.position = global_position + Vector2(-20, -40)
	get_tree().current_scene.add_child(label)
	
	var tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2(2, 2), 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

	queue_free()
