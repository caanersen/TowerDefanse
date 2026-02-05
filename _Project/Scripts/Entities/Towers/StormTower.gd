extends "res://_Project/Scripts/Entities/BaseTower.gd"
# class_name StormTower # Commented out to fix conflict

var chain_count: int = 2 # Sekme sayısı
var chain_range: float = 150.0 # Sekme menzili
var lightning_lines: Array[Line2D] = []

func _ready():
	super._ready()
	damage = 30 # Buffed from 15
	fire_rate = 1.0 # Slightly faster
	attack_range = 180.0
	
	# Görsel (Geçici)
	var sprite = get_node_or_null("Sprite")
	if sprite:
		sprite.color = Color(0.5, 0.0, 0.5) # Mor
		
	# Line2D havuzunu oluştur (Maksimum sekme sayısı kadar)
	for i in range(chain_count + 1):
		var line = Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.8, 0.3, 1.0, 1.0) # Açık Mor/Neon
		line.texture_mode = Line2D.LINE_TEXTURE_NONE
		line.visible = false
		add_child(line)
		lightning_lines.append(line)

func get_upgrade_cost() -> int:
	return 300 * level # Pahalı (150 -> 300 yapıldı)

func upgrade() -> void:
	if level >= max_level: return
	
	level += 1
	damage += 20 # Arttırıldı (10 -> 20)
	chain_count += 1 # Her seviyede +1 sekme
	
	# Yeni Line ekle
	var line = Line2D.new()
	line.width = 3.0 + (level * 0.5)
	line.default_color = Color(0.8, 0.3, 1.0, 1.0)
	line.visible = false
	add_child(line)
	lightning_lines.append(line)
	
	print(name, " upgraded (Storm)")
	scale *= 1.1
	update_range_shape()

func _attack() -> void:
	if not target or not is_instance_valid(target): return
	
	# 1. Hedefe Vur (MAGIC DAMAGE)
	target.take_damage(damage, "MAGIC")
	
	# Görsel: Kule -> Hedef
	_draw_lightning(0, global_position, target.global_position)
	
	# 2. Zincirleme (Chain)
	var current_target = target
	var hit_enemies = [target]
	
	for i in range(chain_count):
		# current_target etrafındaki en yakın VURULMAMIŞ düşmanı bul
		var best_next: Node2D = null
		var min_dist = 10000.0
		
		# Verimsiz ama basit yöntem: Parent'taki (düşman container) herkese bak
		# Daha iyisi: LevelController veya WaveManager'dan canlı düşman listesi almak.
		# Şimdilik target'ın parent'ından (Path2D) kardeşlerine bakıyoruz.
		var parent = current_target.get_parent()
		if not parent: break
		
		for candidate in parent.get_children():
			if candidate.is_in_group("enemies") and is_instance_valid(candidate):
				if candidate in hit_enemies: continue # Zaten vuruldu
				
				var dist = current_target.global_position.distance_to(candidate.global_position)
				if dist <= chain_range and dist < min_dist:
					min_dist = dist
					best_next = candidate
		
		if best_next:
			# Vur
			best_next.take_damage(int(damage * 0.8), "MAGIC") # Seken hasar biraz azalır (%80)
			
			# Görsel: Eski Hedef -> Yeni Hedef
			# Line2D local koordinatta çizdiği için to_local kullanmamız lazım, 
			# AMA Line2D'ler child olduğu için global_position kullanmak yerine points arrayine 
			# tower'a göre relatif pozisyonları vermeliyiz.
			_draw_lightning(i + 1, current_target.global_position, best_next.global_position)
			
			hit_enemies.append(best_next)
			current_target = best_next
		else:
			break # Zincir koptu

func _draw_lightning(index: int, from_global: Vector2, target_pos: Vector2) -> void:
	if index >= lightning_lines.size(): return
	
	var line = lightning_lines[index]
	line.clear_points()
	# Line2D node'u tower'ın child'ı, yani (0,0) tower'ın merkezi.
	line.add_point(to_local(from_global))
	line.add_point(to_local(target_pos))
	line.visible = true
	
	# Kısa süre sonra gizle
	var tween = create_tween()
	tween.tween_interval(0.1) # 0.1 sn göster
	tween.tween_callback(func(): line.visible = false)
