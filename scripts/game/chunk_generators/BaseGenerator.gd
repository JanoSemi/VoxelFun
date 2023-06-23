class_name ChunkGenerator
extends Node


const Chunk = preload("res://scripts/game/Chunk.gd")


static func generate_surface(_height, _x, y, _z):
	if y == 0:
		return "Stone"
	else:
		return "Air"


static func generate_details(c, rng, _ground_height):
	# Place diamond
	var db = c.BlockData.new()
	db.create("Diamond")
	var dx = rng.randi_range(0, int(c.DIMENSION.x))
	var dy = rng.randi_range(1, 10)
	var dz = rng.randi_range(0, int(c.DIMENSION.z))
	c._set_block_data(dx, dy, dz, db, true, false)
	# Place gold
	var gb = c.BlockData.new()
	gb.create("Gold")
	var gx = rng.randi_range(0, int(c.DIMENSION.x))
	var gy = rng.randi_range(1, 10)
	var gz = rng.randi_range(0, int(c.DIMENSION.z))
	c._set_block_data(gx, gy, gz, gb, true, false)
