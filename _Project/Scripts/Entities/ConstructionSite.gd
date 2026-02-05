@tool
extends Node2D

# Editor'da görünecek altıgen yarıçapı
# LevelController ile uyumlu olmalı (24.0)
const HEX_RADIUS = 24.0
const COLOR_NORMAL = Color(1, 0.8, 0, 0.3) # Sarı, şeffaf
const COLOR_BORDER = Color(1, 0.8, 0, 0.8)

func _draw() -> void:
	# Engine.is_editor_hint() kontrolüne gerek yok, oyun içinde de görünebilir (veya gizlenebilir)
	# Oyun içinde LevelController çiziyor olabilir ama editor için bu şart.
	
	var corners = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60 * i # Flat Topped (0, 60, 120...)
		var angle_rad = deg_to_rad(angle_deg)
		var px = HEX_RADIUS * cos(angle_rad)
		var py = HEX_RADIUS * sin(angle_rad)
		corners.append(Vector2(px, py))
	
	draw_colored_polygon(corners, COLOR_NORMAL)
	corners.append(corners[0])
	draw_polyline(corners, COLOR_BORDER, 1.0)
