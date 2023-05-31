extends Spatial

var initial_world_path: String = "user://worlds/default"
var initial_world_type = null
var pw
onready var player = $Player
onready var block_outline = $BlockOutline

const TNT_BLOCK = preload("res://scenes/game/tnt_block.tscn")
var Chunk = load("res://scripts/game/Chunk.gd")
var ProcWorld = load("res://scripts/game/ProcWorld.gd")

var chunk_pos = Vector2()


func _ready():
	print("CREATING WORLD")
	pw = ProcWorld.new(initial_world_path)
	if initial_world_type != null:
		pw.world_data["type"] = initial_world_type
	add_child(pw)
	# warning-ignore:return_value_discarded
	self.connect("tree_exiting", self, "_on_tree_exiting")
	
	# warning-ignore:return_value_discarded
	player.connect("place_block", self, "_on_player_place_block")
	# warning-ignore:return_value_discarded
	player.connect("place_tnt_block", self, "_on_player_place_tnt_block")
	# warning-ignore:return_value_discarded
	player.connect("destroy_block", self, "_on_player_destroy_block")
	# warning-ignore:return_value_discarded
	player.connect("highlight_block", self, "_on_player_highlight_block")
	# warning-ignore:return_value_discarded
	player.connect("unhighlight_block", self, "_on_player_unhighlight_block")


func _process(_delta):
	# Check the players chunk position and see if it has changed
	if player != null and pw != null and pw.mutex != null:
		var chunk_x = floor(player.translation.x / Chunk.DIMENSION.x)
		var chunk_z = floor(player.translation.z / Chunk.DIMENSION.z)
		var new_chunk_pos = Vector2(chunk_x, chunk_z)
	
		# If its a new chunk update for the ProcWorld thread
		if new_chunk_pos != chunk_pos:
			chunk_pos = new_chunk_pos
			#pw.update_player_pos(chunk_pos)
			pw.call_deferred("update_player_pos", chunk_pos)
	# Save world on CTRL+S pressed
	if Input.is_action_just_released("save"):
		pw.save_world()
		Global.save()


func _on_tree_exiting():
	pw.save_world()
	print("Kill map loading thread")
	if pw != null:
		pw.call_deferred("kill_thread")
		#pw.kill_thread()
		#pw.thread.wait_to_finish()
	print("Finished")


func _on_player_destroy_block(pos, norm):
	# Take a half step into the block
	pos -= norm * 0.5
	
	# Get chunk from pos
	var cx = int(floor(pos.x / Chunk.DIMENSION.x))
	var cz = int(floor(pos.z / Chunk.DIMENSION.z))
	
	# Get block from pos
	var bx = fposmod(floor(pos.x), Chunk.DIMENSION.x) + 0.5
	var by = fposmod(floor(pos.y), Chunk.DIMENSION.y) + 0.5
	var bz = fposmod(floor(pos.z), Chunk.DIMENSION.z) + 0.5
	#pw.change_block(cx, cz, bx, by, bz, "Air")
	pw.call_deferred("change_block", cx, cz, bx, by, bz, "Air")


func _on_player_place_block(pos, norm, t):
	# Take a half step out of the block
	pos += norm * 0.5
	
	# Get chunk from pos
	var cx = int(floor(pos.x / Chunk.DIMENSION.x))
	var cz = int(floor(pos.z / Chunk.DIMENSION.z))
	
	# Get block from pos
	var bx = fposmod(floor(pos.x), Chunk.DIMENSION.x) + 0.5
	var by = fposmod(floor(pos.y), Chunk.DIMENSION.y) + 0.5
	var bz = fposmod(floor(pos.z), Chunk.DIMENSION.z) + 0.5
	#pw.change_block(cx, cz, bx, by, bz, t)
	pw.call_deferred("change_block", cx, cz, bx, by, bz, t)

func _on_player_place_tnt_block(pos, norm):
	pos += norm * 0.5
	var tnt = TNT_BLOCK.instance()
	tnt.pw = pw
	tnt.chunk_size = Chunk.DIMENSION
	tnt.translation = Vector3(floor(pos.x) + 0.5, floor(pos.y) + 0.5, floor(pos.z) + 0.5)
	add_child(tnt)

func _on_player_highlight_block(pos, norm):
	block_outline.visible = true
	
	# Take a half step into the block
	pos -= norm * 0.5
	
	var bx = floor(pos.x) + 0.5
	var by = floor(pos.y) + 0.5
	var bz = floor(pos.z) + 0.5
	
	block_outline.translation = Vector3(bx, by, bz)


func _on_player_unhighlight_block():
	block_outline.visible = false
