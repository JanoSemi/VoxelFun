extends Control


const Chunk = preload("res://scripts/game/Chunk.gd")
# Preview/Selection
onready var previews_child: HBoxContainer = $Blocks/Texture/Previews
onready var selected_child: TextureRect = $Blocks/Texture/SelectedBlock
export var texture: AtlasTexture
var block_previews: Array = []
var selected_blocks: PoolIntArray = PoolIntArray()
var selected_block: int = 0


func _ready():
	block_previews.resize(9)
	selected_blocks.resize(9)
	selected_blocks.fill(-1)
	selected_blocks[0] = 2
	selected_blocks[1] = 1
	selected_blocks[2] = 0
	for i in range(0, 9):
		var block_preview = TextureRect.new()
		block_preview.expand = true
		block_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		block_preview.size_flags_horizontal = TextureRect.SIZE_EXPAND_FILL
		block_previews[i] = block_preview
		previews_child.add_child(block_preview)
	update_block_preview()


func _input(event):
	if not event is InputEventKey or event.is_pressed():
		return
	match event.scancode:
		KEY_1:
			select_block(0)
		KEY_2:
			select_block(1)
		KEY_3:
			select_block(2)
		KEY_4:
			select_block(3)
		KEY_5:
			select_block(4)
		KEY_6:
			select_block(5)
		KEY_7:
			select_block(6)
		KEY_8:
			select_block(7)
		KEY_9:
			select_block(8)


func update_block_preview():
	if selected_blocks[selected_block] < 0:
		for i in range(0, 9):
			if selected_blocks[i] > -1:
				select_block(i)
	for i in range(0, 9):
		var block_idx = selected_blocks[i]
		var block_preview = block_previews[i]
		if block_idx < 0:
			block_preview.texture = null
		else:
			block_preview.texture = get_texture_for_block(block_idx)


func get_texture_for_block(idx: int) -> Texture:
	if idx < Chunk.block_types.size():
		var block = Chunk.block_types.values()[idx]
		var t = texture.duplicate()
		if block.has(Chunk.Side.left):
			t.region.position = block[Chunk.Side.left] * 16
		elif block.has(Chunk.Side.only):
			t.region.position = block[Chunk.Side.only] * 16
		else:
			t.region.position = Vector2(-16, -16)
		return t
	else:
		return Chunk.extra_blocks.values()[idx - Chunk.block_types.size()]["Preview"]


func select_block(value: int):
	if value < selected_blocks.size() and selected_blocks[value] > -1:
		selected_block = value
		selected_child.rect_position.x = (value * 42) + 2
