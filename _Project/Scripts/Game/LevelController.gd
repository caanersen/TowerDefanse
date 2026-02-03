extends Node2D

@export var archer_tower_scene: PackedScene
@export var mage_tower_scene: PackedScene
@export var towers_container: Node2D

var selected_tower_type: int = 0 # 0: None, 1: Archer, 2: Mage
var valid_ground_cells: Array[Vector2] = []
var current_gold: int = 2000 # Başlangıç parası (Test için artırıldı)
var selected_tower: BaseTower = null
# Upgrade Panel artık UI root altında
@onready var upgrade_panel: Control = get_node("UI/UpgradePanel")
@onready var upgrade_btn: Button = get_node("UI/UpgradePanel/UpgradeBtn")

# ... (Diğer kodlar) ...


@onready var gold_label: Label = get_node("UI/HBoxInfo/GoldLabel")
@onready var health_label: Label = get_node("UI/HBoxInfo/HealthLabel")
@onready var wave_manager: Node = get_node("WaveManager")
@onready var game_over_panel: Control = get_node("UI/GameOverPanel")
@onready var restart_btn: Button = get_node("UI/GameOverPanel/VBox/RestartBtn")

var base_health: int = 20

# MapHolder referansı
@onready var map_holder: Node = get_node("MapHolder")

# Dinamik yüklenen harita referansı
var current_map_instance: Node = null

func _ready() -> void:
	# 1. Haritayı Yükle
	_load_current_map()
	
	update_gold_ui()
	update_health_ui()
	
	if game_over_panel: game_over_panel.visible = false
	if restart_btn: restart_btn.pressed.connect(_on_restart_pressed)
	
	# WaveManager sinyalini dinle
	if wave_manager:
		wave_manager.on_enemy_reward.connect(add_gold)
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)

	# UI Bağlantıları (Sahne ağacından bulup bağla)
	var ui_btns = get_node("UI/BottomPanel/HBox/BuildButtons")
	if ui_btns:
		ui_btns.get_node("ArcherBtn").pressed.connect(select_archer)
		ui_btns.get_node("MageBtn").pressed.connect(select_mage)
	
	if upgrade_btn:
		upgrade_btn.pressed.connect(upgrade_selected_tower)
		
	# Upgrade Panel'in kendisi tıklamaları engellemesin (arkadaki kuleye tıklanabilsin)
	if upgrade_panel:
		upgrade_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _load_current_map() -> void:
	# GameManager'da selected_level var mı kontrol et, yoksa varsayılan 1
	var level_id = 1
	if GameManager.get("selected_level"):
		level_id = GameManager.selected_level
	
	# Dosya yolu formatı: res://_Project/Scenes/Maps/Map{id}.tscn
	var map_path = "res://_Project/Scenes/Maps/Map" + str(level_id) + ".tscn"
	
	if ResourceLoader.exists(map_path):
		var map_scene = load(map_path)
		current_map_instance = map_scene.instantiate()
		map_holder.add_child(current_map_instance)
		print("Loaded map: ", map_path)
		
		calculate_valid_cells()
		
		# WaveManager'a Path2D'yi ver
		if wave_manager and current_map_instance.has_node("Path2D"):
			var path_node = current_map_instance.get_node("Path2D")
			if wave_manager.has_method("initialize"):
				wave_manager.initialize(path_node)
				# Otomatik başlatma WaveManager içinde değilse buradan tetiklenebilir
			if wave_manager.has_method("start_next_wave"):
				wave_manager.start_next_wave()
	else:
		print("Map file not found: ", map_path)

func take_base_damage(amount: int) -> void:
	base_health -= amount
	if base_health < 0: base_health = 0
	update_health_ui()
	
	if base_health == 0:
		game_over()

func update_health_ui() -> void:
	if health_label:
		health_label.text = "Health: " + str(base_health)

func game_over() -> void:
	print("GAME OVER")
	if game_over_panel:
		game_over_panel.visible = true
	get_tree().paused = true

func _on_wave_started(wave_num: int) -> void:
	var wave_label = get_node_or_null("UI/HBoxInfo/WaveLabel")
	if wave_label:
		wave_label.text = "Wave: " + str(wave_num)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_tower_type != 0:
			_try_build_tower(get_global_mouse_position())
		else:
			_try_select_tower(get_global_mouse_position())

func _try_select_tower(pos: Vector2) -> void:
	var new_selection = null
	var min_dist = 10000.0
	
	# Tıklanan EN YAKIN kuleyi bul
	for tower in towers_container.get_children():
		if tower.has_method("check_clicked") and tower.check_clicked(pos):
			# check_clicked true dönse bile mesafeye bakalım
			var dist = tower.global_position.distance_to(pos)
			if dist < min_dist:
				min_dist = dist
				new_selection = tower
	
	# Eğer eski seçim varsa ve yeni seçimden farklıysa (veya yeni seçim yoksa) -> Deselect
	if selected_tower and selected_tower != new_selection:
		selected_tower.set_selected(false)
	
	selected_tower = new_selection
	
	# Yeni seçim varsa -> Select
	if selected_tower:
		selected_tower.set_selected(true)
	
	_update_ui()

	_update_ui()

func _update_ui() -> void:
	update_gold_ui()
	
	# Dinamik butonları temizle (Varsa)
	var dynamic_container = upgrade_panel.get_node_or_null("DynamicButtons")
	if dynamic_container:
		# Konteyneri komple temizle ve sil
		for child in dynamic_container.get_children():
			child.queue_free()
		# Konteynerin kendisini de kaldırabiliriz ama 
		# parent'a ekli kalması input block yaratabilir mi? 
		# Emin olmak için görünmez yapalım veya silelim.
		dynamic_container.queue_free()
		dynamic_container = null # Referansı sıfırla
	
	if selected_tower:
		upgrade_panel.visible = true
		
		# Upgrade Panel'i kulenin üzerine taşı
		var screen_pos = selected_tower.get_global_transform_with_canvas().origin
		upgrade_panel.position = screen_pos + Vector2(-75, -80)
		
		# MAGE BRANCHING CHECK
		if selected_tower is MageTower and selected_tower.level == 2:
			upgrade_btn.visible = false # Standart butonu gizle
			
			# Container oluştur
			dynamic_container = HBoxContainer.new()
			dynamic_container.name = "DynamicButtons"
			dynamic_container.alignment = BoxContainer.ALIGNMENT_CENTER
			upgrade_btn.get_parent().add_child(dynamic_container)
			# Butonun hemen altında veya yerinde çıksın diye pozisyonlama yapılabilir
			# Şimdilik VBox/HBox düzenine güveniyoruz
			
			# ICE BUTTON
			var ice_btn = Button.new()
			ice_btn.text = "Buz (300g)"
			ice_btn.pressed.connect(_on_choose_ice)
			dynamic_container.add_child(ice_btn)
			
			# FIRE BUTTON
			var fire_btn = Button.new()
			fire_btn.text = "Ateş (300g)"
			fire_btn.pressed.connect(_on_choose_fire)
			dynamic_container.add_child(fire_btn)
			
			# Para Yeterli mi?
			if current_gold < 300:
				ice_btn.disabled = true
				ice_btn.text = "Buz (300g) - Yetersiz"
				fire_btn.disabled = true
				fire_btn.text = "Ateş (300g) - Yetersiz"
			
		else:
			# STANDART UPGRADE
			upgrade_btn.visible = true
			
			var cost = get_upgrade_cost(selected_tower)
			upgrade_btn.text = "Yükselt (" + str(cost) + "g)"
			
			if selected_tower.level >= selected_tower.max_level:
				upgrade_btn.text = "Maksimum Seviye"
				upgrade_btn.disabled = true
			elif current_gold < cost:
				upgrade_btn.disabled = true
				upgrade_btn.text = "Yükselt (" + str(cost) + "g) - Yetersiz Altın"
			else:
				upgrade_btn.disabled = false
	else:
		upgrade_panel.visible = false

func _on_choose_ice() -> void:
	if selected_tower and selected_tower is MageTower:
		if current_gold >= 300:
			current_gold -= 300
			selected_tower.choose_element(1) # ICE
			_update_ui()
			print("Upgraded to ICE MAGE")

func _on_choose_fire() -> void:
	if selected_tower and selected_tower is MageTower:
		if current_gold >= 300:
			current_gold -= 300
			selected_tower.choose_element(2) # FIRE
			_update_ui()
			print("Upgraded to FIRE MAGE")

func get_upgrade_cost(tower) -> int:
	if tower.has_method("get_upgrade_cost"):
		return tower.get_upgrade_cost()
	return 50 * tower.level

func upgrade_selected_tower() -> void:
	if selected_tower:
		var cost = get_upgrade_cost(selected_tower)
		if current_gold >= cost:
			current_gold -= cost
			selected_tower.upgrade()
			_update_ui()
			print("Upgraded for ", cost, " gold.")
		else:
			print("Not enough gold!")

func add_gold(amount: int) -> void:
	current_gold += amount
	update_gold_ui()

func update_gold_ui() -> void:
	if gold_label:
		gold_label.text = "Gold: " + str(current_gold)

func _try_build_tower(pos: Vector2) -> void:
	# Maliyet Kontrolü
	var cost = 0
	if selected_tower_type == 1: cost = 50 # Archer
	elif selected_tower_type == 2: cost = 100 # Mage
	
	if current_gold < cost:
		print("Not enough gold! Need: ", cost)
		selected_tower_type = 0 # iptal
		return
	
	# Grid'e hizala (32x32)
	# Hizalamayı farenin bulunduğu karenin merkezine yapmak için offset ekleyelim ve floorlayalım
	var grid_size = 32
	var local_pos = towers_container.to_local(pos) # Container'a göre yerel kooordinat
	var grid_pos = (local_pos / grid_size).floor()
	var snapped_pos = (grid_pos * grid_size) + Vector2(grid_size/2.0, grid_size/2.0) # Merkeze al

	# Basit geçerlilik kontrolü: Zaten kule var mı? (Container local koordinatta çalışıyor)
	# Dikkat: pos global, tower.position local (towers_container child'ı)
	# KURAL: Kuleler arasında 1 grid (32px) boşluk olmalı.
	# İki kule merkezi arası mesafe en az 64px olmalı (32+32).
	for tower in towers_container.get_children():
		if tower.position.distance_to(snapped_pos) < 64.0:
			print("Kuleler çok yakın! Arada boşluk bırakmalısın.")
			return

	# ZEMİN KONTROLÜ (Helper fonksiyona devrettik)
	if not is_valid_ground(snapped_pos):
		print("Geçersiz zemin!")
		return
	
	var tower_instance
	if selected_tower_type == 1:
		tower_instance = archer_tower_scene.instantiate()
	elif selected_tower_type == 2:
		tower_instance = mage_tower_scene.instantiate()
	
	if tower_instance:
		current_gold -= cost 
		update_gold_ui()
		
		tower_instance.position = snapped_pos
		towers_container.add_child(tower_instance)
		print("Tower built at ", snapped_pos)
		
		selected_tower_type = 0 
		
		if selected_tower: selected_tower.set_selected(false) 
		selected_tower = tower_instance
		selected_tower.set_selected(true)
		_update_ui()
		
		# İnşa sonrası durum değiştiği için tekrar çizdir (eğer anlık güncelleme lazımsa)
		queue_redraw()

func select_archer() -> void:
	selected_tower_type = 1
	selected_tower = null
	_update_ui()
	print("Archer selected")

func select_mage() -> void:
	selected_tower_type = 2
	selected_tower = null
	_update_ui()
	print("Mage selected")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# İnşa edilebilir alanları çiz (Açık Sarı Kareler)
	var grid_size = 32
	var rect_size = Vector2(grid_size - 2, grid_size - 2) # Biraz küçült (padding)
	
	for cell_pos in valid_ground_cells:
		
		# Kule engeli kontrolü (Visual sadece)
		var is_blocked = false
		for tower in towers_container.get_children():
			if tower.position.distance_to(cell_pos) < 64.0:
				is_blocked = true
				break
		
		if not is_blocked:
			var top_left = cell_pos - rect_size / 2.0
			draw_rect(Rect2(top_left, rect_size), Color(1, 1, 0, 0.2)) # Açık sarı şeffaf

func calculate_valid_cells() -> void:
	valid_ground_cells.clear()
	if not current_map_instance: return
	var path_line = current_map_instance.get_node_or_null("PathLine")
	if not path_line: return
	
	# Harita sınırlarını bul
	var points = path_line.points
	if points.size() == 0: return
	
	var min_x = 10000.0
	var max_x = -10000.0
	var min_y = 10000.0
	var max_y = -10000.0
	
	for p in points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	
	# Biraz marj ekle
	var margin = 200
	min_x -= margin
	max_x += margin
	min_y -= margin
	max_y += margin
	
	var grid_size = 32
	var x = min_x
	while x <= max_x:
		var y = min_y
		while y <= max_y:
			# Grid merkezini bul
			var grid_pos = (Vector2(x, y) / grid_size).floor()
			var center_pos = (grid_pos * grid_size) + Vector2(grid_size/2.0, grid_size/2.0)
			
			if is_valid_ground(center_pos):
				valid_ground_cells.append(center_pos)
			
			y += grid_size
		x += grid_size
	
	queue_redraw()

func is_valid_ground(pos: Vector2) -> bool:
	# YOL KONTROLÜ
	# Red Zone (Başlangıç ve Bitiş) Kontrolü
	if pos.x < 160 or pos.x > 840:
		return false

	var path_line = null
	if current_map_instance:
		path_line = current_map_instance.get_node_or_null("PathLine")
		
	if path_line:
		var points = path_line.points
		var path_half_width = path_line.width / 2.0
		var tower_radius = 15.0 # 16 yerine 15 yaparak 64px mesafede temasa izin veriyoruz
		var margin = 0.1
		var min_safe_dist = path_half_width + tower_radius + margin
		var max_build_dist = min_safe_dist + 15.0 # Arka sıraları iptal et (Sadece ilk sıra)
		
		# Kural:
		# 1. En az bir segmentin "max_build_dist" menzilinde olmalı (Yola yakın olmalı)
		# 2. Hiçbir segmentin "min_safe_dist" menzilinde OLMAMALI (Yolun üstünde olmamalı)
		
		var within_build_zone = false
		var on_the_path = false
		
		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i+1]
			
			var closest_point = Geometry2D.get_closest_point_to_segment(pos, p1, p2)
			var dist = pos.distance_to(closest_point)
			
			# AABB Kontrolü
			var safe_zone_aabb = min_safe_dist
			var min_range_x = min(p1.x, p2.x) - safe_zone_aabb
			var max_range_x = max(p1.x, p2.x) + safe_zone_aabb
			var min_range_y = min(p1.y, p2.y) - safe_zone_aabb
			var max_range_y = max(p1.y, p2.y) + safe_zone_aabb
			var rect = Rect2(min_range_x, min_range_y, max_range_x - min_range_x, max_range_y - min_range_y)
			
			if rect.has_point(pos):
				on_the_path = true
				break 
			
			if dist <= max_build_dist:
				within_build_zone = true
		
		if on_the_path: return false
		if not within_build_zone: return false
		
		return true
	return false
