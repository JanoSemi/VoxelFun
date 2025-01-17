class_name Player
extends KinematicBody

onready var ceiling_detector: RayCast = $CeilingDetector
onready var stair_detector: RayCast = $StairDetector
onready var camera_base = $CameraBase
onready var raycast = $CameraBase/Camera/RayCast
onready var info_label = $CameraBase/Camera/InfoLabel
onready var headlamp: SpotLight = $CameraBase/Headlamp
onready var voice_player: AudioStreamPlayer3D = $CameraBase/VoiceOut
onready var voice_playback: AudioStreamGeneratorPlayback = voice_player.get_stream_playback()
onready var block_management: Control = $CameraBase/Camera/BlockManagement
# Reset values
onready var initial_position: Vector3 = translation
onready var initial_rotation: Vector2 = Vector2(camera_x_rotation, rotation_degrees.y)

var Chunk = load("res://scripts/game/Chunk.gd")

var camera_x_rotation = 0

const mouse_sensitivity = 0.3
const SPEED = 5
var velocity = Vector3.ZERO
const gravity = 9.8
var jump_vel = 5
var fly: bool = false

var is_finished: bool = false

signal place_block(pos, norm, type)
signal destroy_block(pos, norm, collider)
signal highlight_block(pos, norm)
signal unhighlight_block()


func _ready():
	if not get_tree().has_network_peer():
		finished()


func finished():
	is_finished = true
	if not (not get_tree().has_network_peer() or is_network_master()):
		return
	voice_player.queue_free()


func _input(event):
	if not (not get_tree().has_network_peer() or is_network_master()) or not is_finished:
		return
	# Mouse movement
	if event is InputEventMouseMotion:
		self.rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))
		
		var x_delta = event.relative.y * mouse_sensitivity
		if camera_x_rotation + x_delta > -90 and camera_x_rotation + x_delta < 90:
			camera_base.rotate_x(deg2rad(-x_delta))
			camera_x_rotation += x_delta


func _physics_process(delta):
	if not (not get_tree().has_network_peer() or is_network_master()) or not is_finished:
		return
	var cx = floor(self.translation.x / Global.CHUNK_DIMENSION.x)
	var cz = floor(self.translation.z / Global.CHUNK_DIMENSION.z)
	var px = self.translation.x - cx * Global.CHUNK_DIMENSION.x
	var py = self.translation.y
	var pz = self.translation.z - cz * Global.CHUNK_DIMENSION.z
	info_label.text = "Chunk (%d, %d) pos (%d, %d, %d)" % [cx, cz, px, py, pz]
	# Check the raycast
	if raycast.is_colliding():
		var pos = raycast.get_collision_point()
		var norm = raycast.get_collision_normal()
		emit_signal("highlight_block", pos, norm)
		if Input.is_action_just_pressed("click"):
			print("Click")
			emit_signal("destroy_block", pos, norm, raycast.get_collider())
		elif Input.is_action_just_pressed("right_click"):
			emit_signal("place_block", pos, norm, block_management.selected_blocks[block_management.selected_block])
	else:
		emit_signal("unhighlight_block")
	
	var power_multipler = (Input.get_action_strength("run") + 1)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not fly:
		velocity.y = jump_vel * power_multipler
	else:
		var camera_base_basis = self.get_global_transform().basis
		
		var direction = Vector3()
		
		if Input.is_action_pressed("forward"):
			direction -= camera_base_basis.z #forward is negative in Godot
			if stair_detector.is_colliding() and is_on_floor() and not ceiling_detector.is_colliding() and not fly:
				velocity.y = jump_vel * power_multipler
		if Input.is_action_pressed("backward"):
			direction += camera_base_basis.z
		
		# Strafe
		if Input.is_action_pressed("left"):
			direction -= camera_base_basis.x
		if Input.is_action_pressed("right"):
			direction += camera_base_basis.x
		
		# Process inputs (only in the xz plane)
		var speed_input = SPEED * power_multipler
		velocity.x = direction.x * speed_input
		velocity.z = direction.z * speed_input
	if fly:
		velocity.y = move_toward(velocity.y, Input.get_axis("sink", "jump") * jump_vel, delta * 10)
	else:
		velocity.y -= gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)
	if Input.is_action_just_released("respawn"):
		respawn()
	if Input.is_action_just_released("toggle_fly"):
		fly = not fly
	if Input.is_action_just_released("headlamp"):
		match headlamp.light_energy:
			0.0: headlamp.light_energy = 1.0
			1.0: headlamp.light_energy = 2.0
			2.0: headlamp.light_energy = 0.0
		if get_tree().has_network_peer():
			Net.my_player["headlamp_energy"] = headlamp.light_energy
			rpc("update_headlamp", headlamp.light_energy)
	if get_tree().has_network_peer():
		rpc("update", translation, rotation_degrees, camera_base.rotation_degrees.x)
		var effect: AudioEffectCapture = AudioServer.get_bus_effect(AudioServer.get_bus_index("VoiceIn"), 0)
		rpc("receive_voice_buffer", effect.get_buffer(effect.get_frames_available()))


func initialize(id: int, info: Dictionary):
	name = str(id)
	set_network_master(id)
	if is_network_master():
		$NameLabel.queue_free()
	else:
		if info.has("headlamp_energy"):
			headlamp.light_energy = info["headlamp_energy"]
		$NameLabel.text = info["name"]
		ceiling_detector.queue_free()
		stair_detector.queue_free()
		$CameraBase/Camera.queue_free()
	finished()


func respawn():
	translation = initial_position
	camera_base.rotation_degrees.x = -initial_rotation.x
	camera_x_rotation = initial_rotation.x
	rotation_degrees.y = initial_rotation.y
	velocity = Vector3.ZERO


remote func update(pos: Vector3, rot: Vector3, head_x: int):
	translation = pos
	rotation_degrees = rot
	camera_base.rotation_degrees.x = head_x


remote func update_headlamp(energy: float):
	headlamp.light_energy = energy


remote func receive_voice_buffer(buffer: PoolVector2Array):
	var frame = 0
	for _i in range(0, buffer.size()):
		if voice_playback.push_frame(buffer[frame]):
			frame += 1
