extends Spatial


class ChunkSorter:
	var around
	
	func sort(a, b):
		var distance_a = a.distance_squared_to(around)
		var distance_b = b.distance_squared_to(around)
		
		return distance_a < distance_b


# We can see this many chunks around us.
const VIEW_DISTANCE = 3

# World size in chunks. Only used for ID calculations.
const WORLD_SIZE = 1024

# Tiles available for placement. Describes their offset in tiles.png
var available_tile_types = [
	Vector2(0.0, 0.0), # stone
	Vector2(0.0, 1.0), # grass
	Vector2(0.0, 2.0), # dirt
]

# The seed to generate this world.
var world_seed

# Cached box shapes mapped by their height.
var shape_cache = {}

onready var chunks = $Chunks

onready var creatures = $Creatures

onready var fps = $FPS

# The A* pathfinder instance to be used elsewhere.
onready var astar = AStar.new()


func _ready():
	randomize()
	world_seed = randi()
	seed(world_seed)
	
	var center = Vector2.ONE * Chunk.CHUNK_SIZE * 0.5
	spawn_creature(center, PlayerAI)


func _process(_delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)
	
	fps.text = "FPS: %s" % Engine.get_frames_per_second()


# Load VIEW_DISTANCE chunks around given world coordinates.
func load_chunks_around(position):
	position = to_chunk_position(position)
	
	# Used to check already loaded chunks.
	var chunk_positions = []
	
	# Free the chunks that are too far away.
	for chunk in chunks.get_children():
		var chunk_position = to_chunk_position(chunk.translation)
		
		if position.distance_to(chunk_position) > VIEW_DISTANCE:
			chunk.queue_free()
		else:
			chunk_positions.push_front(chunk_position)
	
	var queue = []
	
	# Instantiate the chunks around us.
	for dx in range(-VIEW_DISTANCE + 1, VIEW_DISTANCE):
		for dz in range(-VIEW_DISTANCE + 1, VIEW_DISTANCE):
			var chunk_position = position + Vector2(dx, dz)
			
			if not chunk_position in chunk_positions:
				if position.distance_to(chunk_position) <= VIEW_DISTANCE:
					queue.push_front(chunk_position)
	
	var sorter = ChunkSorter.new()
	sorter.around = position
	queue.sort_custom(sorter, "sort")
	
	for position in queue:
		var centered = (position + Vector2.ONE * WORLD_SIZE / 2.0).floor()
		
		var chunk = preload("res://entities/chunk.tscn").instance()
		chunk._id = centered.y * WORLD_SIZE + centered.x
		chunk.name = "Chunk#%d" % chunk._id
		chunk.set_position(position)
		chunks.add_child(chunk)


func to_chunk_position(its_translation):
	var its_xz = Vector2(its_translation.x, its_translation.z)
	return (its_xz / Chunk.CHUNK_SIZE).floor()


# Spawn a creature with specified AI type and position in the XZ plane.
func spawn_creature(position_xz, ai_type = WalkingAI):
	var node = preload("res://entities/creature.tscn").instance()
	node.translate(Vector3(position_xz.x, Chunk.CHUNK_HEIGHT, position_xz.y))
	
	var ai = ai_type.new()
	node.add_child(ai)
	
	creatures.add_child(node)
