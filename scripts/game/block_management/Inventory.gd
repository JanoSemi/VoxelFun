extends PopupPanel


const InventoryBlock = preload("res://scripts/game/block_management/InventoryBlock.gd")
onready var blocks_child: Control = $Blocks
var snap_points: PoolVector2Array = PoolVector2Array()
var blocks: Dictionary = {}


func _ready():
	for y in range(0, 5):
		for x in range(0, 9):
			if y == 4:
				snap_points.append(Vector2((x * 42) + 6, (y * 42) + 16))
			else:
				snap_points.append(Vector2((x * 42) + 6, (y * 42) + 6))
	var Chunk = get_parent().Chunk
	for i in Chunk.block_types.size() + Chunk.extra_blocks.size():
		var block_name = Chunk.block_types.keys()[i] if i < Chunk.block_types.size() else Chunk.extra_blocks.keys()[i - Chunk.block_types.size()]
		var block = Chunk.block_types[block_name] if i < Chunk.block_types.size() else Chunk.extra_blocks[block_name]
		if block.has("Tags") and block["Tags"].has(Chunk.Tags.Dont_List):
			continue
		var iblock = InventoryBlock.new()
		iblock.name = block_name
		iblock.block_idx = i
		iblock.texture = get_parent().get_texture_for_block(i)
		iblock.hint_tooltip = block_name
		iblock.rect_position = get_last_free_snap_point()
		blocks[iblock.rect_position] = iblock
		blocks_child.add_child(iblock)
		


func _physics_process(_delta):
	if Input.is_action_just_released("inventory") and not visible:
		popup_centered()


func get_last_free_snap_point():
	for sp in snap_points:
		if not blocks.has(sp):
			return sp


func _on_about_to_show():
	# Pause Game
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	for i in range(0, 9):
		var bindex = get_parent().selected_blocks[i]
		var sp = snap_points[i + 36]
		if bindex > -1:
			var new_pos = sp
			var Chunk = get_parent().Chunk
			var block = blocks_child.get_node(Chunk.block_types.keys()[bindex] if bindex < Chunk.block_types.size() else Chunk.extra_blocks.keys()[bindex - Chunk.block_types.size()])
			# warning-ignore:return_value_discarded
			blocks.erase(block.rect_position)
			block.rect_position = new_pos
			blocks[block.rect_position] = block
		elif blocks.has(sp):
			var block = blocks[sp]
			# warning-ignore:return_value_discarded
			blocks.erase(sp)
			var new_pos = get_last_free_snap_point()
			block.rect_position = new_pos
			blocks[new_pos] = block


func _on_popup_hide():
	# Apply changes
	for i in range(0, 9):
		var sp = snap_points[i + 36]
		get_parent().selected_blocks[i] = blocks[sp].block_idx if blocks.has(sp) else -1
	get_parent().update_block_preview()
	# Resume Game
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
