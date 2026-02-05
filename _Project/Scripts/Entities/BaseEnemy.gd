extends PathFollow2D
# class_name BaseEnemy # Commented out to fix conflict

signal died(enemy)
signal reached_base(enemy)

@export var speed: float = 100.0
@export var max_health: int = 30
@export var gold_reward: int = 10
@export var physical_armor: int = 0
@export var is_flying: bool = false
@onready var current_health: int = max_health

# Görsel referansı (tilenmesi için placeholder renk değişimi)
@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	add_to_group("enemies")
	loop = false # Tek sefer git
	rotates = false # İsteğe bağlı
	_setup_particles()
	_setup_health_bar()

var health_bg: ColorRect
var health_fill: ColorRect

func _setup_health_bar() -> void:
	# Arkaplan (Siyah)
	health_bg = ColorRect.new()
	health_bg.color = Color(0, 0, 0, 0.5)
	health_bg.size = Vector2(40, 4) # 4px yükseklik (2px fill + kenar için)
	health_bg.position = Vector2(-20, 25)
	health_bg.z_index = 10 
	add_child(health_bg)
	
	# Dolum (Yeşil) - Tam 2px olacak şekilde
	health_fill = ColorRect.new()
	health_fill.color = Color(0, 1, 0)
	health_fill.size = Vector2(40, 2) # İstenilen 2px
	health_fill.position = Vector2(0, 1) # Bg içinde ortala
	health_bg.add_child(health_fill)
	
	_update_health_bar()

func _update_health_bar() -> void:
	if health_fill and max_health > 0:
		var ratio = float(current_health) / float(max_health)
		# Genişliği orana göre ayarla
		health_fill.size.x = 40.0 * ratio

var is_blocked: bool = false
var blocker_unit: Node2D = null # Asker referansı
var attack_damage: int = 5
var attack_timer: float = 0.0
var attack_interval: float = 1.0

func _physics_process(delta: float) -> void:
	# Eğer bloklanmışsa ilerleme ve SALDIR!
	if is_blocked:
		if not is_instance_valid(blocker_unit):
			disengage() # Asker öldüyse serbest kal
		else:
			# Dövüş
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = attack_interval
				if blocker_unit.has_method("take_damage"):
					blocker_unit.take_damage(attack_damage)
		return

	progress += speed * delta
	_handle_status_effects(delta)
	
	# Yolun sonuna geldi mi?
	if progress_ratio >= 1.0:
		_on_reach_base()

func _on_reach_base() -> void:
	# LevelController'a hasar ver
	# Oyun sahnesi root (LevelController orada attached)
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("take_base_damage"):
		main_scene.take_base_damage(1)
	
	emit_signal("reached_base", self) # Sinyali yay
	queue_free()

func take_damage(amount: int, damage_type: String = "PHYSICAL") -> void:
	var actual_damage = amount
	
	if damage_type == "PHYSICAL":
		# Apply armor reduction
		actual_damage = max(1, amount - physical_armor)
	
	# MAGIC hasar zırhı yok sayar (direkt amount)
	
	current_health -= actual_damage
	_update_health_bar()
	
	var color = Color.WHITE
	if damage_type == "MAGIC":
		color = Color.CYAN # Büyü hasarı mavi
	
	show_floating_text("-" + str(actual_damage), color)
	print(name, " took ", actual_damage, " ", damage_type, " damage. HP: ", current_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	emit_signal("died", self)
	queue_free()

# --- STATUS EFFECTS ---
var is_slowed: bool = false
var slow_timer: float = 0.0
var base_speed: float = 0.0

var is_burning: bool = false
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
var burn_damage_per_tick: int = 0

func _init_speed():
	if base_speed == 0.0:
		# Hız Varyasyonu (Kaos): %80 ile %120 arası rastgele hız
		var variance = randf_range(0.8, 1.2)
		base_speed = speed * variance
		speed = base_speed

func show_floating_text(text: String, color: Color = Color.RED) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 100 # En üstte görünsün
	
	# Font boyutu artırma (LabelSettings ile)
	var settings = LabelSettings.new()
	settings.font_size = 24
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	
	# Global pozisyonu al (Çünkü parent değişecek)
	var screen_pos = get_global_transform_with_canvas().origin
	label.position = screen_pos + Vector2(-40, -60)
	
	# Label'ı Enemy'nin parent'ına veya Root'a ekle
	# Enemy ölünce Label silinmesin diye.
	get_tree().root.add_child(label)
	
	# Basit tween animasyonu (Yukarı çık ve kaybol)
	# Label Root'a ekli olduğu için, Tween'i Label üzerinden oluşturmalıyız.
	# Enemy (self) ölürse, self'e bağlı Tween de ölür.
	var tween = label.create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


var frost_particles: CPUParticles2D
var fire_particles: CPUParticles2D

func _setup_particles() -> void:
	# FROST
	frost_particles = CPUParticles2D.new()
	frost_particles.amount = 12 # Azaltıldı (32->12)
	frost_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	frost_particles.emission_sphere_radius = 20.0
	frost_particles.gravity = Vector2(0, 10)
	frost_particles.scale_amount_min = 2.0 # Küçültüldü
	frost_particles.scale_amount_max = 4.0
	frost_particles.color = Color(0.2, 1, 1, 0.6) # Opaklık azaltıldı
	frost_particles.emitting = false
	frost_particles.one_shot = false
	frost_particles.z_index = 5
	add_child(frost_particles)
	
	# FIRE
	fire_particles = CPUParticles2D.new()
	fire_particles.amount = 12 # Azaltıldı
	fire_particles.direction = Vector2(0, -1)
	fire_particles.gravity = Vector2(0, -40)
	fire_particles.initial_velocity_min = 20.0
	fire_particles.initial_velocity_max = 40.0
	fire_particles.scale_amount_min = 3.0 # Küçültüldü
	fire_particles.scale_amount_max = 6.0
	fire_particles.color = Color(1.0, 0.4, 0.0, 0.8) # Opaklık azaltıldı
	fire_particles.emitting = false
	fire_particles.one_shot = false
	fire_particles.z_index = 5
	add_child(fire_particles)

func apply_slow(factor: float, duration: float) -> void:
	_init_speed()
	is_slowed = true
	slow_timer = duration
	speed = base_speed * factor
	# Görsel efekt
	if sprite: sprite.modulate = Color(0.5, 0.5, 1.0) 
	if frost_particles: frost_particles.emitting = true

func apply_burn(percent_damage: float, duration: float) -> void:
	is_burning = true
	burn_timer = duration
	burn_damage_per_tick = int(float(max_health) * percent_damage)
	if burn_damage_per_tick < 1: burn_damage_per_tick = 1
	
	# Görsel efekt
	if sprite: sprite.modulate = Color(1.0, 0.5, 0.0) 
	if fire_particles: fire_particles.emitting = true

func _handle_status_effects(delta: float) -> void:
	_init_speed()
	
	# SLOW
	if is_slowed:
		slow_timer -= delta
		if slow_timer <= 0:
			is_slowed = false
			speed = base_speed
			if sprite: sprite.modulate = Color(1, 1, 1) # Rengi sıfırla
			if frost_particles: frost_particles.emitting = false
	
	# BURN
	if is_burning:
		burn_timer -= delta
		burn_tick_timer += delta
		if burn_tick_timer >= 1.0: # Her saniye
			burn_tick_timer = 0.0
			take_damage(burn_damage_per_tick, "MAGIC")
			
		if burn_timer <= 0:
			is_burning = false
			if sprite and not is_slowed: # Slow yoksa rengi düzelt
				sprite.modulate = Color(1, 1, 1)
			if fire_particles: fire_particles.emitting = false

func engage(unit: Node2D) -> void:
	if is_flying:
		return
	is_blocked = true
	blocker_unit = unit
	# Animasyon varsa burada saldırı animasyonuna geçilir

func disengage() -> void:
	is_blocked = false
	blocker_unit = null
	# Yürümeye devam
