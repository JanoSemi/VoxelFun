extends ChunkGenerator


static func generate_surface(height, _x, y, _z):
	var type
	if y < height - 10 or y == 0:
		type = "Stone"
	elif y <= height - 1:
		type = "Sand"
	else:
		type = "Air"
	return type


static func generate_details(c, rng, ground_height):
	# Now generate cactus
	var cactus_width = 2
	for _n_cactus in range(0, rng.randi_range(0, 3)):
		var x = rng.randi_range(cactus_width, Global.CHUNK_DIMENSION.x - cactus_width - 1)
		var z = rng.randi_range(cactus_width, Global.CHUNK_DIMENSION.z - cactus_width - 1)
		# Place a cactus at this position up to some height
		var cactus_height = rng.randi_range(5, 7)
		for i in range(0, cactus_height):
			var b = c.BlockData.new()
			b.create("Cactus")
			var y = ground_height[x][z] + i
			c._set_block_data(x, y, z, b, true, false)
		# Place 1 branch per side
		# Left
		var dir = Vector2(1, 0)
		if rng.randi() % 2:
			dir = Vector2(0, 1)
		for side in [dir, -dir]:
			var branch_height = rng.randi_range(3, cactus_height - 2)
			if rng.randi() % 2:
				# Just a nub
				var y = ground_height[x][z] + branch_height
				var b = c.BlockData.new()
				b.create("Cactus")
				c._set_block_data(x + side.x, y, z + side.y, b, true, false)
			else:
				# Full branch
				for offset in [
					Vector3(side.x, 0, side.y), 
					Vector3(2 * side.x, 0, 2 * side.y), 
					Vector3(2 * side.x, 1, 2 * side.y)]:
						var y = ground_height[x][z] + branch_height + offset.y
						var b = c.BlockData.new()
						b.create("Cactus")
						c._set_block_data(x + offset.x, y, z + offset.z, b, false, false)
	# Now some tufts of grass
	for _n_shrub in range(0, rng.randi_range(0, 5)):
		var x = rng.randi_range(0, Global.CHUNK_DIMENSION.x - 1)
		var z = rng.randi_range(0, Global.CHUNK_DIMENSION.z - 1)
		var y = ground_height[x][z]
		var b = c.BlockData.new()
		b.create("Shrub")
		c._set_block_data(x, y, z, b, false, false)
	.generate_details(c, rng, ground_height)
	return
