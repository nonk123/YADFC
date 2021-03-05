class_name Chunk
extends StaticBody


# Each chunk is a square with this side length.
const CHUNK_SIZE = 16

# Higher values result in smoother terrain.
const NOISE_PERIOD = CHUNK_SIZE * 4

# The height of the stone layer below terrain.
const UNDERGROUND_HEIGHT = 16

# A generated slope cannot get taller than this.
const TERRAIN_SLOPE = 16

# A chunk will not generate taller than this.
const CHUNK_HEIGHT = UNDERGROUND_HEIGHT + TERRAIN_SLOPE

# How many tiles can there be in a chunk.
const TILES_MAX = CHUNK_SIZE * CHUNK_SIZE * CHUNK_HEIGHT

# Put this many tiles of dirt below a tile of grass.
const DIRT_UNDER_GRASS = 5

var tiles = {}

var boxes = {}

var _noisy = OpenSimplexNoise.new()

# The chunk's unique identifier.
var _id

onready var world = get_node("/root/World")


func _ready():
	_noisy.seed = world.world_seed
	_noisy.period = NOISE_PERIOD
	
	try_to_load()


# Generate a new chunk and save it, unless it can be loaded.
func try_to_load():
	var path = "chunks/chunk_%d.bin" % _id
	
	var file = File.new()
	
	var should_generate = true
	
	if file.file_exists(path):
		file.open(path, File.READ)
		should_generate = not do_load(file)
	
	if should_generate:
		generate()
		save(path)
	
	update_mesh()
	update_shapes()


func generate():
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var noise = _noisy.get_noise_2d(translation.x + x, translation.z + z)
			
			# Ensure the noise value is in range [0; 1).
			noise = min(0.5 * (noise + 1), 0.99999)
			
			var slope = floor(noise * TERRAIN_SLOPE)
			
			var y = 0
			
			while y < UNDERGROUND_HEIGHT + slope - DIRT_UNDER_GRASS:
				fill(x, y, z, 0)
				y += 1
			
			for _i in range(0, DIRT_UNDER_GRASS):
				fill(x, y, z, 2)
				y += 1
			
			fill(x, UNDERGROUND_HEIGHT + slope, z, 1)


func fill(x, y, z, tile_type):
	var position = Vector3(x, y, z)
	
	tiles[position] = tile_type
	
	var below = position + Vector3.DOWN
	var box_below = boxes.get(below)
	
	if box_below == null:
		# No box below. Start a new one.
		boxes[position] = 1.0
	elif box_below < 0.0:
		# Extend the "parent" box it's pointing to.
		var way_below = below + Vector3.DOWN * -box_below
		boxes[way_below] += 1.0
		boxes[position] = box_below - 1.0
	elif box_below > 0.0:
		# Merge this box into the one directly below.
		boxes[below] += 1.0
		boxes[position] = -1.0
	
	# TODO: update the world's astar.


func update_mesh():
	var multimesh = MultiMesh.new()
	
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT
	multimesh.instance_count = len(tiles)
	multimesh.mesh = preload("res://resources/tile_mesh.tres")
	
	var tile_id = 0
	
	for position in tiles:
		var tile_type = tiles[position]
		
		var offset = world.available_tile_types[tile_type]
		var offset8 = Color(offset.x, offset.y, 0.0, 0.0)
		
		var transform = Transform(Basis.IDENTITY, position + Vector3.ONE * 0.5)
		
		multimesh.set_instance_transform(tile_id, transform)
		multimesh.set_instance_custom_data(tile_id, offset8)
		
		tile_id += 1
	
	$Mesh.multimesh = multimesh


func update_shapes():
	for position in boxes:
		if boxes[position] < 0.0:
			continue
		
		var height = boxes[position] * 0.5
		position += Vector3(0.5, height, 0.5)
		
		var shape = world.shape_cache.get(height)
		
		if not shape:
			shape = PhysicsServer.shape_create(PhysicsServer.SHAPE_BOX)
			PhysicsServer.shape_set_data(shape, Vector3(0.5, height, 0.5))
			world.shape_cache[height] = shape
		
		var transform = Transform(Basis.IDENTITY, position)
		PhysicsServer.body_add_shape(get_rid(), shape, transform)


# Return true if the chunk was loaded from FILE.
func do_load(file):
	# Generate a new chunk if the seeds don't match.
	if file.get_32() != world.world_seed:
		file.close()
		return false
	
	# Do the actual loading.
	while true:
		var x = file.get_16() - pow(2, 15)
		
		if file.eof_reached():
			break
		
		var y = file.get_16() - pow(2, 15)
		var z = file.get_16() - pow(2, 15)
		
		var tile_type = file.get_8() - pow(2, 7)
		
		fill(x, y, z, tile_type)
	
	file.close()
	
	return true


func save(path):
	var file = File.new()
	file.open(path, File.WRITE)
	
	file.store_32(world.world_seed)
	
	for position in tiles:
		file.store_16(pow(2, 15) + position.x)
		file.store_16(pow(2, 15) + position.y)
		file.store_16(pow(2, 15) + position.z)
		file.store_8(pow(2, 7) + tiles[position])
	
	file.close()


func set_position(chunk_position):
	translation = Vector3(chunk_position.x, 0.0, chunk_position.y) * CHUNK_SIZE
