extends Node2D

@export var archer_tower_scene: PackedScene
@export var mage_tower_scene: PackedScene
@export var catapult_tower_scene: PackedScene
@export var storm_tower_scene: PackedScene
@export var barracks_tower_scene: PackedScene
@export var towers_container: Node2D

var selected_tower_type: int = 0 # 0: None, 1: Archer, 2: Mage
var valid_ground_cells: Array[Vector2] = []
var current_gold: int = 450 # Başlangıç parası dengelendi (2000 -> 450)
var selected_tower: Node2D = null # Type hint removed due to class_name conflict
# Upgrade Panel artık UI root altında
@onready var upgrade_panel: Control = get_node("UI/UpgradePanel")
@onready var upgrade_btn: Button = get_node("UI/UpgradePanel/UpgradeBtn")

# ... (Diğer kodlar) ...


@onready var gold_label: Label = get_node("UI/HBoxInfo/GoldLabel")
@onready var health_label: Label = get_node("UI/HBoxInfo/HealthLabel")
@onready var wave_manager: Node = get_node("WaveManager")
@onready var game_over_panel: Control = get_node("UI/GameOverPanel")
@onready var restart_btn: Button = get_node("UI/GameOverPanel/VBox/RestartBtn")
@onready var play_btn: Button # Kod ile oluşturacağız

var base_health: int = 20
var is_game_started: bool = false
var is_game_paused: bool = false # Pause state

# MapHolder referansı
@onready var map_holder: Node = get_node("MapHolder")

# Dinamik yüklenen harita referansı
var current_map_instance: Node = null
var tower_spots_node: Node2D = null

# HEX GRID AYARLARI (FLAT TOPPED)
# Flat Top: Köşeler 0, 60, 120... (Sağ/Sol köşeli, Üst/Alt düz)
# Horizontal yollarla daha iyi hizalanır.
var hex_radius: float = 24.0
var hex_height: float = sqrt(3) * hex_radius # Dikey yükseklik (Flat to Flat)
var hex_width: float = 2 * hex_radius # Yatay genişlik (Point to Point)

# Boşluklar (Flat Topped için Staggered Columns)
# X ekseninde her hex 3/4 genişlik kaplar (iç içe geçme)
var hex_horiz_spacing: float = hex_width * 0.75 
# Y ekseninde tam yükseklik
var hex_vert_spacing: float = hex_height

func _ready() -> void:
	# 1. Haritayı Yükle
	_load_current_map()
	
	# Load Scenes...
	if catapult_tower_scene == null:
		catapult_tower_scene = load("res://_Project/Scenes/Entities/Towers/CatapultTower.tscn")
	if storm_tower_scene == null:
		storm_tower_scene = load("res://_Project/Scenes/Entities/Towers/StormTower.tscn")
	if barracks_tower_scene == null:
		barracks_tower_scene = load("res://_Project/Scenes/Entities/Towers/BarracksTower.tscn")
	
	update_gold_ui()
	update_health_ui()
	
	if game_over_panel: game_over_panel.visible = false
	if restart_btn: restart_btn.pressed.connect(_on_restart_pressed)
	
	# UI Bağlantıları (Sahne ağacından bulup bağla)
	var ui_btns = get_node_or_null("UI/BuildPanel/BuildButtons")
	if ui_btns:
		# Önce temizle (Scene'den gelenleri veya eski kalanları)
		for child in ui_btns.get_children():
			child.queue_free()
			
		# Yeni Butonları Oluştur (Ucuzdan Pahalıya)
		_create_build_btn(ui_btns, "🛡️\n50", select_barracks)
		_create_build_btn(ui_btns, "🏹\n80", select_archer)
		_create_build_btn(ui_btns, "🧙\n100", select_mage)
		_create_build_btn(ui_btns, "⚡\n180", select_storm)
		_create_build_btn(ui_btns, "☄️\n200", select_catapult)

	# WaveManager sinyalini dinle
	if wave_manager:
		wave_manager.on_enemy_reward.connect(add_gold)
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)

	# Haritaya göre valid cells güncelle
	calculate_valid_cells()
	
	# Play ve Upgrade butonlarını hazırla (Sadece 1 kez)
	_ready_play_and_upgrade()

func _create_build_btn(parent, text, callback) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 80)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP # Godot 4 feature but text multiline works fine
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _ready_play_and_upgrade() -> void:
	if upgrade_btn:
		upgrade_btn.pressed.connect(upgrade_selected_tower)
		
	# Play Button Oluştur
	_create_play_button()


func _create_play_button() -> void:
	# UI/HBoxInfo içine ekleyelim
	var hbox = get_node_or_null("UI/HBoxInfo")
	if hbox:
		play_btn = Button.new()
		play_btn.text = " > " # Simple text arrow
		play_btn.custom_minimum_size = Vector2(50, 40)
		play_btn.process_mode = Node.PROCESS_MODE_ALWAYS # PAUSE modunda çalışması için ÖNEMLİ!
		
		# Renk Ayarları (Siyah Beyaz)
		play_btn.add_theme_color_override("font_color", Color.WHITE)
		play_btn.add_theme_color_override("font_hover_color", Color.LIGHT_GRAY)
		play_btn.add_theme_color_override("font_pressed_color", Color.GRAY)
		
		# Butonun kendisini siyahımsı yapalım
		play_btn.modulate = Color(1, 1, 1) 
		
		play_btn.pressed.connect(_on_play_pause_pressed)
		hbox.add_child(play_btn)

func _on_play_pause_pressed() -> void:
	if not is_game_started:
		# İlk Başlangıç
		is_game_started = true
		play_btn.text = "||" # Text pause
		if wave_manager and wave_manager.has_method("start_next_wave"):
			wave_manager.start_next_wave()
	else:
		# Pause / Resume
		is_game_paused = !is_game_paused
		get_tree().paused = is_game_paused
		
		if is_game_paused:
			play_btn.text = " > "
		else:
			play_btn.text = "||"


	
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
		if wave_manager:
			var found_paths = []
			# Tüm child node'ları tara
			for child in current_map_instance.get_children():
				if child is Path2D:
					found_paths.append(child)
			
			# Fallback for old map structure (if named specifically "Path2D")
			if found_paths.is_empty() and current_map_instance.has_node("Path2D"):
				found_paths.append(current_map_instance.get_node("Path2D"))
			
			if wave_manager.has_method("initialize"):
				wave_manager.initialize(found_paths)
				# Otomatik başlatma ARTIK Play butonu ile yapılıyor
				# wave_manager.start_next_wave() satırı kaldırıldı.
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
	# Eğer oyun başladıysa VE duraklatıldıysa işlem yapma (Ancak oyun başlamadıysa işlem yap, serbest mod)
	if is_game_started and is_game_paused: return 
	
	
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
	
	# Dinamik butonları temizle (Varsa) - Cleanup handled below within creation logic
	var dynamic_container = null

	
	if selected_tower:
		upgrade_panel.visible = true
		
		# Upgrade Panel'i kulenin üzerine taşı
		var screen_pos = selected_tower.get_global_transform_with_canvas().origin
		upgrade_panel.position = screen_pos + Vector2(-75, -80)
		
		# Container oluştur (Upgrade + Sell butonları için)
		# Container (Upgrade + Sell butonları için) - Logic moved up

		# UpgradeBtn'nin parent'ına (VBox muhtemelen) ekle.
		upgrade_btn.visible = false # Orijinal butonu gizle (yerine dynamic container içinde yenisini oluşturacağız)
		
		# Eğer zaten varsa kullan, yoksa oluştur
		if upgrade_btn.get_parent().has_node("DynamicButtons"):
			dynamic_container = upgrade_btn.get_parent().get_node("DynamicButtons")
			# İçini temizle
			for child in dynamic_container.get_children():
				child.queue_free()
		else:
			dynamic_container = HBoxContainer.new()
			dynamic_container.name = "DynamicButtons"
			dynamic_container.alignment = BoxContainer.ALIGNMENT_CENTER
			upgrade_btn.get_parent().add_child(dynamic_container)
			upgrade_btn.get_parent().move_child(dynamic_container, upgrade_btn.get_index() + 1)
		
		# SELL BUTTON (Her zaman göster)
		var sell_btn = Button.new()
		var refund = selected_tower.get_sell_refund()
		sell_btn.text = "$ (" + str(refund) + ")" # 'g' harfini kaldırdım, daha temiz
		sell_btn.modulate = Color(1, 0.4, 0.4) # Biraz daha canlı kırmızı
		sell_btn.add_theme_font_size_override("font_size", 18) # Daha büyük font
		# Kalınlık için tema fontu yoksa, büyük font yeterli olacaktır.
		
		sell_btn.pressed.connect(sell_selected_tower)
		dynamic_container.add_child(sell_btn)
		
		# MAGE BRANCHING CHECK
		# Use script check instead of global class check due to conflicts
		# var mage_script = load("res://_Project/Scripts/Entities/Towers/MageTower.gd")
		# Or check for unique properties like 'element_type'
		if "element_type" in selected_tower and selected_tower.level == 2:
			upgrade_btn.visible = false # Standart butonu gizle
			
			# ICE BUTTON
			var ice_btn = Button.new()
			ice_btn.text = "❄️ (300)"
			ice_btn.pressed.connect(_on_choose_ice)
			dynamic_container.add_child(ice_btn)
			
			# FIRE BUTTON
			var fire_btn = Button.new()
			fire_btn.text = "🔥 (300)"
			fire_btn.pressed.connect(_on_choose_fire)
			dynamic_container.add_child(fire_btn)
			
			if current_gold < 300:
				ice_btn.disabled = true
				fire_btn.disabled = true
			
		else:
			# STANDART UPGRADE (Yeni buton oluştur)
			var new_upgrade_btn = Button.new()
			var cost = get_upgrade_cost(selected_tower)
			new_upgrade_btn.text = "⬆ (" + str(cost) + ")" # Kalın ok
			new_upgrade_btn.add_theme_font_size_override("font_size", 18) # Daha büyük font
			new_upgrade_btn.pressed.connect(upgrade_selected_tower)
			dynamic_container.add_child(new_upgrade_btn)
			
			if selected_tower.level >= selected_tower.max_level:
				new_upgrade_btn.text = "MAX"
				new_upgrade_btn.disabled = true
			elif current_gold < cost:
				new_upgrade_btn.disabled = true
			else:
				new_upgrade_btn.disabled = false
	else:
		upgrade_panel.visible = false

# ... (Ice/Fire handlers)

func sell_selected_tower() -> void:
	if selected_tower:
		var refund = selected_tower.get_sell_refund()
		add_gold(refund)
		print("Sold tower for ", refund, " gold.")
		
		# Kuleyi sil
		selected_tower.queue_free()
		selected_tower = null
		_update_ui()
		call_deferred("update_construction_site_visibility")

func _on_choose_ice() -> void:
	# Check for "element_type" property for MageTower
	if selected_tower and "element_type" in selected_tower:
		if current_gold >= 300:
			current_gold -= 300
			selected_tower.total_cost += 300 # Maliyet güncelle
			selected_tower.choose_element(1) # ICE
			_update_ui()
			print("Upgraded to ICE MAGE")

func _on_choose_fire() -> void:
	if selected_tower and "element_type" in selected_tower:
		if current_gold >= 300:
			current_gold -= 300
			selected_tower.total_cost += 300 # Maliyet güncelle
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
			selected_tower.total_cost += cost # Maliyet güncelle
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
	if selected_tower_type == 1: cost = 80 # Archer
	elif selected_tower_type == 2: cost = 100 # Mage
	elif selected_tower_type == 3: cost = 200 # Catapult
	elif selected_tower_type == 4: cost = 180 # Storm
	elif selected_tower_type == 5: cost = 50 # Barracks
	
	if current_gold < cost:
		print("Not enough gold! Need: ", cost)
		selected_tower_type = 0 # iptal
		return
	
	# Grid'e hizala (Hex Snapping)
	# Fare pozisyonuna en yakın GEÇERLİ hex hücresini bul
	var closest_cell = Vector2.ZERO
	var min_dist = 10000.0
	
	for cell in valid_ground_cells:
		var d = pos.distance_to(cell)
		if d < min_dist:
			min_dist = d
			closest_cell = cell
	# Eğer fare bir hücreye yeterince yakınsa
	# Toleransı artırıyoruz (1.0 -> 1.4) çünkü görsel ile tıklama alanı bazen tam oturmayabilir.
	if min_dist > hex_radius * 1.4:
		print("Buraya inşa edilemez! Uzaklık: ", min_dist, " / Limit: ", hex_radius * 1.4)
		print("Valid Cells Count: ", valid_ground_cells.size())
		return


	var snapped_pos = closest_cell

	# Basit geçerlilik kontrolü: Zaten kule var mı?
	# "Yanındaki kareye inşaat yapılamasın" kuralı için mesafeyi artırıyoruz.
	# Komşu hex merkezleri arası mesafe yaklaşık 41-48px (Radius 24 iken).
	# 1.5 * 24 = 36 idi (İzin veriyordu).
	# 2.2 * 24 = 52.8 (Komşuyu engeller).
	for tower in towers_container.get_children():
		if tower.position.distance_to(snapped_pos) < hex_radius * 2.2:
			print("Kuleler çok yakın! Bitişik alana inşaat yapılamaz.")
			return

	# ZEMİN KONTROLÜ (Zaten valid listesinden seçtik ama yine de double check)
	# if not is_valid_hex_ground(snapped_pos): return
	
	var tower_instance
	if selected_tower_type == 1:
		tower_instance = archer_tower_scene.instantiate()
	elif selected_tower_type == 2:
		tower_instance = mage_tower_scene.instantiate()
	elif selected_tower_type == 3:
		tower_instance = catapult_tower_scene.instantiate()
	elif selected_tower_type == 4:
		tower_instance = storm_tower_scene.instantiate()
	elif selected_tower_type == 5:
		tower_instance = barracks_tower_scene.instantiate()
	
	if tower_instance:
		current_gold -= cost 
		update_gold_ui()
		
		tower_instance.position = snapped_pos
		tower_instance.total_cost = cost # Başlangıç maliyetini kaydet
		towers_container.add_child(tower_instance)
		print("Tower built at ", snapped_pos)
		
		selected_tower_type = 0 
		
		selected_tower = tower_instance
		selected_tower.set_selected(true)
		_update_ui()
		
		update_construction_site_visibility()

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

func select_catapult() -> void:
	selected_tower_type = 3 # 3: Catapult
	selected_tower = null
	_update_ui()
	print("Catapult selected")

func select_storm() -> void:
	selected_tower_type = 4 # 4: Storm
	selected_tower = null
	_update_ui()
	print("Storm selected")

func select_barracks() -> void:
	selected_tower_type = 5 # 5: Barracks
	selected_tower = null
	_update_ui()
	print("Barracks selected")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Manuel yerleşimde (ConstructionSite) görsel zaten var.
	# Buradaki çizimi sadece "Visual Debug" veya "Highlight" için tutabiliriz.
	# Fakat kullanıcı "senin kod ile yazdıklarını kaldır" dediği için burada 
	# base görseli kapatıyoruz.
	pass
	# NOT: Eğer oyun içinde hover efekti vs istersen burayı açabilirsin.

func _get_hex_corners(center: Vector2) -> PackedVector2Array:
	var corners = PackedVector2Array()
	# FLAT TOPPED: 0, 60, 120, 180, 240, 300
	for i in range(6):
		var angle_deg = 60 * i 
		var angle_rad = deg_to_rad(angle_deg)
		var px = center.x + hex_radius * cos(angle_rad)
		var py = center.y + hex_radius * sin(angle_rad)
		corners.append(Vector2(px, py))
	return corners

func calculate_valid_cells() -> void:
	valid_ground_cells.clear()
	if not current_map_instance: return
	
	# MANUEL YERLEŞİM MODU
	# Procedural kod yerine, haritadaki "TowerSpots" node'larını kullan.
	
	var spots_container = current_map_instance.get_node_or_null("TowerSpots")
	if spots_container:
		tower_spots_node = spots_container
		for child in spots_container.get_children():
			# Child'ın global pozisyonunu kaydet
			# Bu sayede _try_build_tower bu noktalara snap edebilecek.
			valid_ground_cells.append(child.global_position)
	else:
		# Fallback: Eski haritalar için veya node bulunamazsa
		# (İsteğe bağlı eski koda dönebiliriz ama şimdilik manuel moddayız)
		print("TowerSpots node not found in map.")
	
	update_construction_site_visibility()
	
	queue_redraw()

func update_construction_site_visibility() -> void:
	if not tower_spots_node: return
	
	for site in tower_spots_node.get_children():
		var is_blocked = false
		for tower in towers_container.get_children():
			if tower.is_queued_for_deletion(): continue
			
			if tower.global_position.distance_to(site.global_position) < hex_radius * 2.2:
				is_blocked = true
				break
		
		site.visible = !is_blocked

func is_valid_ground(_pos: Vector2) -> bool:
	return false
