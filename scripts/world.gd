extends Spatial


# We can see this many chunks around us.
const VIEW_DISTANCE = 3

# Tiles available for placement.
var available_tile_types = {
	"stone": Vector2(0.0, 0.0),
	"grass": Vector2(0.0, 1.0),
	"dirt": Vector2(0.0, 2.0),
}

# The seed to generate this world.
var world_seed

# Cached box shapes mapped by their height.
var shape_cache = {}

# Convert chunk position to its instance.
var _position_to_chunk = {}

onready var chunks = $Chunks

onready var creatures = $Creatures

# The A* pathfinder instance to be used elsewhere.
onready var astar = AStar.new()


func _ready():
	randomize()
	world_seed = randi()
	
	var center = Vector2.ONE * Chunk.CHUNK_SIZE * 0.5
	spawn_creature(center, PlayerAI)


func _process(_delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)
	
	$FPS.text = "FPS: %s" % Engine.get_frames_per_second()


# Load VIEW_DISTANCE chunks around given world coordinates.
func load_chunks_around(position):
	position = to_chunk_position(position)
	
	var queue = []
	
	# Generate the chunks around us.
	for dx in range(-VIEW_DISTANCE + 1, VIEW_DISTANCE):
		for dz in range(-VIEW_DISTANCE + 1, VIEW_DISTANCE):
			var chunk_position = position + Vector2(dx, dz)
			
			if position.distance_to(chunk_position) <= VIEW_DISTANCE:
				if not chunk_position in _position_to_chunk:
					# In range and doesn't exist yet. Try generating it.
					queue.push_front(chunk_position)
	
	# Free the chunks that are too far away.
	for chunk in chunks.get_children():
		var chunk_position = to_chunk_position(chunk.translation)
		
		if position.distance_to(chunk_position) > VIEW_DISTANCE:
			chunk.queue_free()
			_position_to_chunk.erase(chunk_position)
	
	# Process the generation queue.
	for position in queue:
		var chunk = preload("res://entities/chunk.tscn").instance()
		chunk.set_position(position)
		chunks.add_child(chunk)
		
		_position_to_chunk[position] = chunk


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
