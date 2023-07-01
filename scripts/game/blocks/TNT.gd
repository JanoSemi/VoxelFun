extends StaticBody


const remove_radius = 5
var pw
var chunk_size
onready var animation_player: AnimationPlayer = $AnimationPlayer


func _physics_process(_delta):
	if (not get_tree().has_network_peer() or is_network_master()) and Input.is_action_just_released("ignite_tnt"):
		ignite()
		if get_tree().has_network_peer():
			rpc("ignite")


remote func ignite():
	animation_player.play("explode")
	var changed_chunks: Array = []
	for x in range(translation.x - remove_radius, translation.x + (remove_radius + 1)):
		for y in range(translation.y - remove_radius, translation.y + (remove_radius + 1)):
			for z in range(translation.z - (remove_radius + 1), translation.z + remove_radius):
				var pos: Vector3 = Vector3(x, y, z)
				# Calculate chunk
				var chunk: Vector3 = pos / chunk_size
				chunk = chunk.floor()
				if not changed_chunks.has(chunk):
					changed_chunks.append(chunk)
				# Calculate position on chunk
				pos = pos - (chunk * chunk_size)
				pw.change_block(chunk.x, chunk.z, pos.x, pos.y, pos.z, "Air", false, false)
	for c in changed_chunks:
		pw._update_chunk(c.x, c.z)


remote func queue_free():
	.queue_free()
