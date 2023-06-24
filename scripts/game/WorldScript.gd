extends Spatial

const PLAYER = preload("res://scenes/game/player.tscn")
var initial_world_path = "user://worlds/default"
var initial_world_type = null
onready var money_label: Label = $MoneyView/CenterContainer/Label
var pw
onready var players: Spatial = $Players
onready var player: Player
onready var block_outline = $BlockOutline

var Chunk = load("res://scripts/game/Chunk.gd")
var ProcWorld = load("res://scripts/game/ProcWorld.gd")

var chunk_pos = Vector2()


func _ready():
	# Load my player
	player = load_player()
	if get_tree().has_network_peer():
		player.initialize(get_tree().get_network_unique_id(), Net.my_player)
	var mrt = RemoteTransform.new()
	mrt.translation = Vector3(0, 100, 0)
	mrt.update_rotation = false
	mrt.update_scale = false
	mrt.remote_path = "../../../Map/MapContainer/MapViewport/Camera"
	player.add_child(mrt)
	# First money view update
	update_money_view()
	# warning-ignore:return_value_discarded
	Global.connect("money_changed", self, "update_money_view")
	# Connect network signals
	# warning-ignore:return_value_discarded
	get_tree().connect("server_disconnected", get_tree(), "change_scene", ["res://scenes/server_disonnected.tscn"])
	# warning-ignore:return_value_discarded
	Net.connect("player_registered", self, "_on_player_registered")
	# warning-ignore:return_value_discarded
	Net.connect("player_unregistered", self, "_on_player_unregistered")
	# Create world
	print("CREATING WORLD")
	pw = ProcWorld.new(initial_world_path)
	if not get_tree().has_network_peer() or get_tree().is_network_server():
		if initial_world_type != null:
			pw.world_data["type"] = initial_world_type
		pw.start_generating()
		$ModalMessage.hide()
	add_child(pw)
	# Save and kill map loading on exit
	# warning-ignore:return_value_discarded
	self.connect("tree_exiting", self, "_on_tree_exiting")
	
	# Connect player
	# warning-ignore:return_value_discarded
	player.connect("place_block", self, "_on_player_place_block")
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


func load_player() -> Player:
	var p = PLAYER.instance()
	p.translation = Vector3(0, 50, 0)
	players.add_child(p)
	return p


func update_money_view():
	money_label.text = "Money: %s\nGold: %s\nDiamonds: %s" % [Global.money, Global.gold, Global.diamonds]


remote func receive_world(world: Dictionary):
	pw.world_data = world
	pw.start_generating()
	$ModalMessage.hide()


func _on_player_registered(id: int):
	rpc_id(id, "receive_world", pw.world_data)
	load_player().initialize(id, Net.other_players[id])


func _on_player_unregistered(id: int):
	var p = players.get_node_or_null(str(id))
	if p:
		p.queue_free()


func _on_tree_exiting():
	pw.save_world()
	print("Kill map loading thread")
	if pw != null:
		pw.call_deferred("kill_thread")
		#pw.kill_thread()
		#pw.thread.wait_to_finish()
	print("Finished")


func _on_player_destroy_block(pos, norm, collider):
	if collider.is_in_group("extra_blocks"):
		collider.queue_free()
		if get_tree().has_network_peer():
			collider.rpc("queue_free")
	else:
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
	
	if t < Chunk.block_types.size():
		#pw.change_block(cx, cz, bx, by, bz, Chunk.block_types.keys()[t])
		pw.call_deferred("change_block", cx, cz, bx, by, bz, Chunk.block_types.keys()[t])
	else:
		var bpos = Vector3(((cx * Chunk.DIMENSION.x) + bx), by, ((cz * Chunk.DIMENSION.z) + bz))
		var idx = t - Chunk.block_types.size()
		var bname = str(get_child_count())
		var id = get_tree().get_network_unique_id() if get_tree().has_network_peer() else -1
		if not id == -1:
			bname += str(id)
		add_block_instance(bpos, idx, id, bname)
		if get_tree().has_network_peer():
			rpc("add_block_instance", bpos, idx, id, bname)


remote func add_block_instance(bpos: Vector3, index: int, id: int, bname: String):
	var block_instance: Spatial = Chunk.extra_blocks.values()[index]["Instance"].instance()
	if get_tree().has_network_peer():
		block_instance.set_network_master(id)
	block_instance.chunk_size = Chunk.DIMENSION
	block_instance.pw = pw
	block_instance.translation = bpos
	block_instance.name = "ExtraBlock%s" % bname
	add_child(block_instance)


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
