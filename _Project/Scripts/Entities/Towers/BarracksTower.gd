extends "res://_Project/Scripts/Entities/BaseTower.gd"
# class_name BarracksTower # Commented out to fix conflict

@export var soldier_scene: PackedScene
var soldiers: Array[Node2D] = []
var max_soldiers: int = 3
var respawn_timer: Timer

var rally_point: Vector2

func _ready():
	# Super _ready çağır
	# ... super._ready() olsa iyi olurdu ama BaseTower _ready'si range shape vs ayarlıyor.
	# BaseTower'da _ready var ve super çağrısı otomatik yapılmaz GDScript'te, manuel çağırmak lazım.
	# Ama BaseTower extends Node2D ise _process otomatik çalışır. Functions override edilir.
	# BaseTower.gd'ye bakalım -> extends Node2D.
	# super._ready() çağırmak en iyisi.
	super._ready() # BaseTower setup'ı çalışsın
	
	attack_range = 100.0 # Askerlerin devriye menzili
	update_range_shape_barracks() # Kendi shape mantığımız
	
	# Respawn Timer
	respawn_timer = Timer.new()
	respawn_timer.wait_time = 10.0
	respawn_timer.autostart = true
	respawn_timer.timeout.connect(_check_respawn)
	add_child(respawn_timer)
	
	# Rally Point Belirle (Yol üzerinde en yakın nokta)
	call_deferred("_calculate_rally_point")

func _calculate_rally_point() -> void:
	rally_point = global_position # Default: Kule altı
	
	# Haritayı ve Yolları Bul
	# GameScene -> MapHolder -> MapX -> Roads
	var game_scene = get_tree().current_scene
	var map_holder = game_scene.get_node_or_null("MapHolder")
	
	var best_point = global_position
	var min_dist = 10000.0
	var found_road = false
	
	if map_holder and map_holder.get_child_count() > 0:
		var current_map = map_holder.get_child(0)
		var roads_container = current_map.get_node_or_null("Roads")
		
		if roads_container:
			# Tüm Line2D yolları tara (Çift yol desteği)
			for road in roads_container.get_children():
				if road is Line2D:
					var points = road.points
					# Line segmentleri üzerinde en yakın noktayı bul
					for i in range(points.size() - 1):
						var p1 = road.to_global(points[i]) # Local to Global
						var p2 = road.to_global(points[i+1])
						
						var close_p = Geometry2D.get_closest_point_to_segment(global_position, p1, p2)
						var d = global_position.distance_to(close_p)
						
						if d < min_dist:
							min_dist = d
							best_point = close_p
							found_road = true

	if found_road:
		rally_point = best_point
	else:
		# Fallback: Eski yöntem (Tekil isim arama)
		var path_line = game_scene.find_child("PathLine", true, false)
		if path_line and path_line is Line2D:
			# ... (Eski logic tekrarı gerekmez, zaten yeni sistem çalışmalı)
			pass
		
		# Hiçbir şey bulunamazsa offset ver
		if rally_point == global_position:
			rally_point += Vector2(0, 50)
		
	# İlk askerleri çıkar
	_spawn_soldiers()

func update_range_shape_barracks() -> void:
	# BaseTower circle kullanıyor, biz rect istiyoruz demiştik ama BaseTower logic'i kalsın.
	var area = $Area2D
	if area:
		var col = area.get_node_or_null("CollisionShape2D")
		if not col:
			col = CollisionShape2D.new()
			col.shape = CircleShape2D.new()
			area.add_child(col)
		
		if col.shape is CircleShape2D:
			col.shape.radius = attack_range
		elif col.shape is RectangleShape2D:
			col.shape.size = Vector2(attack_range * 2, attack_range * 2)

func _spawn_soldiers() -> void:
	for i in range(max_soldiers):
		_create_soldier()

# Stats
var soldier_health: int = 100
var soldier_damage: int = 10

func _create_soldier() -> void:
	if not soldier_scene: return
	
	var soldier = soldier_scene.instantiate()
	
	# Rally point etrafında küçük rastgelelik
	var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	soldier.global_position = rally_point + offset
	
	# Statları aktar
	soldier.initialize(soldier.global_position, soldier_health, soldier_damage)
	
	get_tree().current_scene.add_child(soldier)
	
	soldier.died.connect(_on_soldier_died)
	soldiers.append(soldier)

func _on_soldier_died(soldier):
	soldiers.erase(soldier)

func _check_respawn() -> void:
	if soldiers.size() < max_soldiers:
		_create_soldier()

func upgrade() -> void:
	if level >= max_level: return
	
	level += 1
	# Askerleri güçlendir
	soldier_health += 50
	soldier_damage += 5
	
	print(name, " upgraded (Barracks) -> Soldier HP:", soldier_health, " DMG:", soldier_damage)
	
	# Mevcut askerleri anlık güncelleme ? Opsiyonel.
	# Şimdilik respawn olanlar güçlü gelsin.
	scale *= 1.1

# Override attack (Barracks ateş etmez)
func _attack() -> void:
	pass
