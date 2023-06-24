extends KinematicBody


const SPEED = 1.0
const GRAVITY = 9.8
onready var left_wall_detector = $LeftWallDetector
onready var center_wall_detector = $CenterWallDetector
onready var right_wall_detector = $RightWallDetector
export var animation_speed: float = 1.0
export var animation_name: String
var velocity = Vector3.ZERO
var rotation_velocity = 0.0
onready var initial_pos = translation


func _ready():
	pause_mode = Node.PAUSE_MODE_STOP
	var animation_player = $Model/AnimationPlayer
	animation_player.playback_speed = animation_speed
	animation_player.get_animation(animation_name).loop = true
	animation_player.play(animation_name)


func _physics_process(delta):
	if not (not get_tree().has_network_peer() or get_tree().is_network_server()):
		return
	if translation.y < 0:
		print("Creature %s has a negative y position and will be resetted!" % get_path())
		translation = initial_pos
	var direction = transform.basis.z
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
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
