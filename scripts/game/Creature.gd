class_name Creature
extends KinematicBody


const SPEED = -1.0
const GRAVITY = 9.8
onready var left_wall_detector = $LeftWallDetector
onready var center_wall_detector = $CenterWallDetector
onready var right_wall_detector = $RightWallDetector
export var animation_speed: float = 1.0
export var animation_name: String
export var creature_name: String
var velocity = Vector3.ZERO
var rotation_velocity = 0.0
var pw
var initial_y: float = Global.CHUNK_DIMENSION.y
var current_chunk: Vector2 = Vector2.ZERO


func _ready():
	pause_mode = Node.PAUSE_MODE_STOP
	var animation_player = $Model/AnimationPlayer
	animation_player.playback_speed = animation_speed
	animation_player.get_animation(animation_name).loop = true
	animation_player.play(animation_name)


func _physics_process(delta):
	if not (not get_tree().has_network_peer() or get_tree().is_network_server()):
		return
	# Reset on negative y position
	if translation.y < 0:
		print("Creature %s has a negative y position and will be resetted!" % get_path())
		translation.y = initial_y
	# Remove, if there no chunk generated
	if not pw._loaded_chunks.has(current_chunk):
		print("Creature %s goes from world and will be removed!" % get_path())
		queue_free()
	# Update save data
	var ckey = pw.get_chunk_key(current_chunk.x, current_chunk.y)
	var new_chunk = Vector2(floor(translation.x / Global.CHUNK_DIMENSION.x), floor(translation.z / Global.CHUNK_DIMENSION.z))
	if new_chunk != current_chunk:
		if pw.world_data.has(ckey) and pw.world_data[ckey].has("Creatures"):
			pw.world_data[ckey]["Creatures"].erase(name)
		current_chunk = Vector2(new_chunk.x, new_chunk.y)
		ckey = pw.get_chunk_key(current_chunk.x, current_chunk.y)
	if not pw.world_data[ckey].has("Creatures"):
		pw.world_data[ckey]["Creatures"] = {}
	pw.world_data[ckey]["Creatures"][name] = {
		"position": "%.2f,%.2f,%.2f" % [translation.x, translation.y, translation.z],
		"rotation": "%.0f,%.0f,%.0f" % [rotation_degrees.x, rotation_degrees.y, rotation_degrees.z],
		"position_y_velocity": stepify(velocity.y, 0.01),
		"rotation_y_velocity": stepify(rotation_velocity, 0.01),
		"type": creature_name
	}
	# Move
	var direction = transform.basis.z * SPEED
	velocity.z = direction.z
	velocity.x = direction.x
	if center_wall_detector.is_colliding() and is_on_floor():
		velocity.y = 5
	elif velocity.y <= 0 and rotation_velocity == 0:
		if left_wall_detector.is_colliding():
			rotation_velocity = 10
		elif right_wall_detector.is_colliding():
			rotation_velocity = -10
	velocity.y -= GRAVITY * delta
	velocity = move_and_slide(velocity, Vector3.UP)
	rotation.y += rotation_velocity * delta
	rotation_velocity = move_toward(rotation_velocity, 0, delta * 10)
	if get_tree().has_network_peer():
		rpc("update", translation, rotation_degrees)


remote func update(pos: Vector3, rot: Vector3):
	translation = pos
	rotation_degrees = rot
