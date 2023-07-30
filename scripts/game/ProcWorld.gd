extends Spatial

const SHEEP: PackedScene = preload("res://scenes/game/creatures/sheep.tscn")
var height_noise = OpenSimplexNoise.new()

onready var Chunk = load("res://scripts/game/Chunk.gd")

onready var player: Player = get_parent().player

# Saving variables
var world_path
var world_data = {}
var save_timer: Timer = Timer.new()

# Thread variables No reason to declare these on startup just do it up here
var thread = Thread.new()
var mutex = Mutex.new()
var semaphore = Semaphore.new()
var bKill_thread = false

# Use this when adding/removing from the chunk array/dict
var chunk_mutex = Mutex.new()

var _new_chunk_pos = Vector2()
var _chunk_pos = null
var _loaded_chunks = {}
var _last_chunk = Vector2()

var _kill_thread = false

var current_load_radius = 0


func _init(path):
	world_path = path


func _ready():
	# Init node
	name = "ProcWorld"
	pause_mode = Node.PAUSE_MODE_PROCESS
	# Load
	var file = File.new()
	if world_path and file.file_exists(world_path):
		file.open(world_path, File.READ)
		var data = parse_json(file.get_as_text())
		file.close()
		world_data = data
	# Init autosave
	save_timer.name = "SaveTimer"
	save_timer.process_mode = Timer.TIMER_PROCESS_PHYSICS
	# warning-ignore:return_value_discarded
	save_timer.connect("timeout", self, "save_world")
	# warning-ignore:return_value_discarded
	save_timer.connect("timeout", Global, "save")
	# warning-ignore:return_value_discarded
	Global.connect("autosave_changed", self, "apply_autosave")
	add_child(save_timer)
	apply_autosave()


func apply_autosave():
	save_timer.wait_time = Global.autosave_interval * 60
	if Global.autosave_enabled:
		if save_timer.is_stopped():
			print("Start Timer")
			save_timer.start()
	elif not save_timer.is_stopped():
		print("Stop Timer")
		save_timer.stop()


func start_generating():
	if thread.is_active():
		return
	# Init player
	player.initial_position = str2vec3(world_data["spawn_position"]) if world_data.has("spawn_position") else Vector3(0.5, 50, 0.5)
	if world_data.has("spawn_rotation"):
		var parts = world_data["spawn_rotation"].split_floats(",")
		player.initial_rotation = Vector2(parts[0], parts[1])
	if world_data.has("flying"):
		player.fly = world_data["flying"]
	player.respawn()
	thread.start(self, "_thread_gen")
	height_noise.period = 100


func save_world():
	if not world_path:
		return
	print("Saving world")
	# Apply player pos
	world_data["spawn_position"] = "%.2f,%.2f,%.2f" % [player.translation.x, player.translation.y, player.translation.z]
	world_data["spawn_rotation"] = "%.0f,%.0f" % [player.camera_x_rotation, player.rotation_degrees.y]
	world_data["flying"] = player.fly
	# Save
	var file = File.new()
	file.open(world_path, File.WRITE)
	file.store_string(to_json(world_data))
	file.close()


func _thread_gen(_userdata):
	var i = 0
	# Center map generation on the player
	while(!bKill_thread):
		# Check if player in new chunk
		var player_pos_updated = false
		player_pos_updated = _new_chunk_pos != _chunk_pos
		
		# Make sure we aren't making a shallow copy
		_chunk_pos = Vector2(_new_chunk_pos.x, _new_chunk_pos.y)
		var current_chunk_pos = Vector2(_new_chunk_pos.x, _new_chunk_pos.y)
		i = i + 1
		if player_pos_updated:
			# If new chunk unload unneeded chunks (changed to be entirely done off main thread if I understand correctly, fixling some stuttering I was feeling
			enforce_render_distance(current_chunk_pos)
			# Make sure player chunk is loaded
			_last_chunk = _load_chunk(current_chunk_pos.x, current_chunk_pos.y)
			current_load_radius = 1
		else:
			# Load next chunk based on the position of the last one
			var delta_pos = _last_chunk - current_chunk_pos
			# Only have player chunk
			if delta_pos == Vector2():
				# Move down one
				_last_chunk = _load_chunk(_last_chunk.x, _last_chunk.y + 1)
			elif delta_pos.x < delta_pos.y:
				# Either go right or up
				# Prioritize going right
				if delta_pos.y == current_load_radius and -delta_pos.x != current_load_radius:
					# Go right
					_last_chunk = _load_chunk(_last_chunk.x - 1, _last_chunk.y)
				# Either moving in constant x or we just reached bottom right
				elif -delta_pos.x == current_load_radius or -delta_pos.x == delta_pos.y:
					# Go up
					_last_chunk = _load_chunk(_last_chunk.x, _last_chunk.y - 1)
				else:
					# We increment here idk why
					if current_load_radius < Global.load_radius:
						current_load_radius += 1
			else:
				# Either go left or down
				# Prioritize going left
				if -delta_pos.y == current_load_radius and delta_pos.x != current_load_radius:
					# Go left
					_last_chunk = _load_chunk(_last_chunk.x + 1, _last_chunk.y)
				elif delta_pos.x == current_load_radius or delta_pos.x == -delta_pos.y:
					# Go down
					# Stop the last one where we'd go over the limit
					if delta_pos.y < Global.load_radius:
						_last_chunk = _load_chunk(_last_chunk.x, _last_chunk.y + 1)


func update_player_pos(new_pos):
	_new_chunk_pos = new_pos


func change_block(cx, cz, bx, by, bz, t, update = true, rpc = true):
	world_data[get_chunk_key(cx, cz)]["%d,%d,%d" % [bx, by, bz]] = t
	if get_tree().has_network_peer() and rpc:
		rpc("change_block_remote", cx, cz, bx, by, bz, t, update)
	var c_pos = Vector2(cx, cz)
	if _loaded_chunks.has(c_pos):
		var c = _loaded_chunks[c_pos]
		if c._block_data[bx][by][bz].type != t:
			if c._block_data[bx][by][bz].type == "Diamond":
				Global.collect_diamond()
			if c._block_data[bx][by][bz].type == "Gold":
				Global.collect_gold()
			c._block_data[bx][by][bz].create(t)
			if update:
				_update_chunk(cx, cz)


remote func change_block_remote(cx, cz, bx, by, bz, t, update = true):
	world_data[get_chunk_key(cx, cz)]["%d,%d,%d" % [bx, by, bz]] = t
	var c_pos = Vector2(cx, cz)
	if _loaded_chunks.has(c_pos):
		var c = _loaded_chunks[c_pos]
		if c._block_data[bx][by][bz].type != t:
			c._block_data[bx][by][bz].create(t)
			if update:
				_update_chunk(cx, cz)


func get_chunk_key(cx: int, cz: int, create: bool = true) -> String:
	var ckey = "%d,%d" % [cx, cz]
	if create and not world_data.has(ckey):
		world_data[ckey] = {}
	return ckey



func _load_chunk(cx, cz):
	var c_pos = Vector2(cx, cz)
	if not _loaded_chunks.has(c_pos):
		var c = Chunk.new(world_data.get("type", "Forest"))
		c.name = "ChunkX%dZ%d" % [cx, cz]
		c.generate(self, cx, cz)
		c.update()
		add_child(c)
		chunk_mutex.lock()
		_loaded_chunks[c_pos] = c
		chunk_mutex.unlock()
		# Generate sheeps
		var ckey = get_chunk_key(cx, cz, false)
		if (not world_data.has(ckey) or not world_data[ckey].has("HasSheep")) and c.rng.randf() > 0.8:
			create_creature(
				"Sheep",
				"SheepX%dZ%d" % [cx, cz],
				Vector3(((cx * Global.CHUNK_DIMENSION.x) + (Global.CHUNK_DIMENSION.x / 2)), Global.CHUNK_DIMENSION.y, ((cz * Global.CHUNK_DIMENSION.z) + (Global.CHUNK_DIMENSION.z / 2))),
				Vector3(0, randf() * 360.0, 0),
				0.0,
				0.0
			)
			world_data[get_chunk_key(cx, cz)]["HasSheep"] = true
		if world_data.has(ckey) and world_data[ckey].has("Creatures"):
			var creatures = world_data[ckey]["Creatures"]
			for cn in creatures:
				var cd = creatures[cn]
				create_creature(
					cd["type"],
					cn,
					str2vec3(cd.get("position", "0,0,0")),
					str2vec3(cd.get("rotation", "0,0,0")),
					cd.get("position_y_velocity", 0.0),
					cd.get("rotation_y_velocity", 0.0)
				)
	return c_pos


func create_creature(ctype: String, cname: String, cposition: Vector3, crotation: Vector3, cposition_y_velocity: float, crotation_y_velocity: float):
	var creature: Creature
	match ctype:
		"Sheep":
			creature = SHEEP.instance()
		_:
			return
	creature.name = cname
	creature.translation = cposition
	creature.rotation_degrees = crotation
	creature.velocity.y = cposition_y_velocity
	creature.rotation_velocity = crotation_y_velocity
	creature.pw = self
	add_child(creature)


func str2vec3(string: String) -> Vector3:
	var parts = string.split_floats(",")
	return Vector3(parts[0], parts[1], parts[2])


func _update_chunk(cx, cz):
	var c_pos = Vector2(cx, cz)
	if _loaded_chunks.has(c_pos):
		var c = _loaded_chunks[c_pos]
		c.update()
	return c_pos


# Detects and removes chunks all in one go without consulting the main thread.
func enforce_render_distance(current_chunk_pos):
		# Checks and deletes the offending chunks all in one go 
	for v in _loaded_chunks.keys():
		# Anywhere you directly interface with chunks outside of unloading
		if abs(v.x - current_chunk_pos.x) > Global.load_radius or abs(v.y - current_chunk_pos.y) > Global.load_radius:
			chunk_mutex.lock()
			_loaded_chunks[v].free()
			_loaded_chunks.erase(v)
			chunk_mutex.unlock()


func kill_thread():
	bKill_thread = true
