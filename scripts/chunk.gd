class_name Chunk
extends StaticBody


# Each chunk is a square with this side length.
const CHUNK_SIZE = 16

# Higher values result in smoother terrain.
const NOISE_PERIOD = CHUNK_SIZE * 4

# The height of the stone layer below terrain.
const UNDERGROUND_HEIGHT = 16

# A generated slope cannot get higher than this.
const TERRAIN_SLOPE = 16

# A chunk will not generate taller than this.
const CHUNK_HEIGHT = UNDERGROUND_HEIGHT + TERRAIN_SLOPE

# How many tiles can there be in a chunk.
const TILES_MAX = CHUNK_SIZE * CHUNK_SIZE * CHUNK_HEIGHT

# Put this many tiles of dirt below a tile of grass.
const DIRT_UNDER_GRASS = 5

# Boxes to be added.
var _box_queue = {}

var _noisy

var _shape_index = 0

# The world we are in.
onready var world = get_node("/root/World")

onready var mesh = $Mesh


func _ready():
	_noisy = OpenSimplexNoise.new()
	_noisy.seed = world.world_seed
	_noisy.period = NOISE_PERIOD
	
	seed(world.world_seed)
	
	setup_multimesh()
	generate()


func _process(_delta):
	# Process the box queue.
	for position in _box_queue:
		if _box_queue[position] is Vector3:
			continue
		
		var height = _box_queue[position] * 0.5
		position += Vector3(0.5, height, 0.5)
		
		var shape = world.shape_cache.get(height)
		
		if not shape:
			shape = PhysicsServer.shape_create(PhysicsServer.SHAPE_BOX)
			PhysicsServer.shape_set_data(shape, Vector3(0.5, height, 0.5))
			world.shape_cache[height] = shape
		
		var transform = Transform(Basis.IDENTITY, position)
		PhysicsServer.body_add_shape(get_rid(), shape, transform)
	
	_box_queue.clear()


func setup_multimesh():
	var multimesh = MultiMesh.new()
	
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT
	multimesh.instance_count = TILES_MAX
	multimesh.mesh = preload("res://resources/tile_mesh.tres")
	
	mesh.multimesh = multimesh


func generate():
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var noise = _noisy.get_noise_2d(translation.x + x, translation.z + z)
			
			# Ensure the noise value is in range [0; 1).
			noise = min(0.5 * (noise + 1), 0.99999)
			
			var slope = floor(noise * TERRAIN_SLOPE)
			
			var y = 0
			
			while y < UNDERGROUND_HEIGHT + slope - DIRT_UNDER_GRASS:
				fill(x, y, z, "stone")
				y += 1
			
			for _i in range(0, DIRT_UNDER_GRASS):
				fill(x, y, z, "dirt")
				y += 1
			
			fill(x, UNDERGROUND_HEIGHT + slope, z, "grass")


func fill(x, y, z, tile_type):
	var point = Vector3(x, y, z)
	var tile_id = get_tile_id(point)
	
	var offset = world.available_tile_types[tile_type]
	var offset8 = Color(offset.x, offset.y, 0.0, 0.0)
	
	var transform = Transform(Basis.IDENTITY, point + Vector3.ONE * 0.5)
	mesh.multimesh.set_instance_transform(tile_id, transform)
	mesh.multimesh.set_instance_custom_data(tile_id, offset8)
	
	add_cube_collider(point)
	
	# TODO: update the world's astar.


func add_cube_collider(position):
	var below = position + Vector3.DOWN
	var box_below = _box_queue.get(below)
	
	if box_below is Vector3:
		# Extend the "parent" box it's pointing to.
		_box_queue[box_below] += 1.0
		_box_queue[position] = box_below
	elif box_below is float:
		# Merge this box into the one directly below.
		_box_queue[below] += 1.0
		_box_queue[position] = below
	else:
		# Otherwise, add a whole new box.
		_box_queue[position] = 1.0


func get_tile_id(v):
	return v.x * CHUNK_HEIGHT * CHUNK_SIZE \
		 + v.y * CHUNK_SIZE \
		 + v.z


func set_position(chunk_position):
	translation = Vector3(chunk_position.x, 0.0, chunk_position.y) * CHUNK_SIZE
