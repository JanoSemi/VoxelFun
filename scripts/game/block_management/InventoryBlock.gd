extends TextureRect


onready var inventory = get_parent().get_parent()
var block_idx: int = 0
var mouse_pressed: bool = false
var original_position: Vector2 = Vector2.ZERO


func _ready():
	set_notify_transform(true)
	expand = true
	rect_size = Vector2(36, 36)


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed() and not mouse_pressed and get_global_rect().has_point(event.global_position) and event.button_index == BUTTON_LEFT:
			mouse_pressed = true
			original_position = rect_position
		else:
			mouse_pressed = false
			for sp in inventory.snap_points:
				if rect_position.distance_squared_to(sp) <= 648:
					if inventory.blocks.has(sp):
						inventory.blocks[sp].rect_position = original_position
						inventory.blocks[original_position] = inventory.blocks[sp]
					else:
						inventory.blocks.erase(original_position)
					rect_position = sp
					inventory.blocks[sp] = self
					return
			rect_position = original_position
	if event is InputEventMouseMotion and mouse_pressed:
		rect_position += event.relative
