extends Spatial


# Camera flight speed in tiles/s.
const CAMERA_FLIGHT_SPEED = 20.0

# How far you can click.
const CLICK_RANGE = 64.0

# World size in the XZ plane.
export(int) var world_size = 128

# How tall the entire terrain section is.
export(int) var terrain_height = 16

# Larger values make the world smoother.
export(float) var period = 0.8

# Not sure what this does to worldgen, but it does something.
export(float) var lacunarity = 2.5

# Spawn this many creatures when the world is generated.
export(int) var creatures_count = 50

# Creatures will be placed at least this many tiles apart.
export(float) var private_space = 5.0

# Tiles available for placement.
var available_tile_types = {
	"dirt": {
		"color": Color(0.54, 0.27, 0.07)
	},
	"grass": {
		"color": Color(0.0, 0.6, 0.0)
	},
}

# Convert a tile type name to its ID in the mesh library.
var _tile_type_to_id = {}

onready var tile_grid = $Tiles

onready var creatures = $Creatures

onready var camera = $Camera


func _ready():
	update_mesh_library()
	generate_terrain()
	place_creatures()


func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		var start = camera.project_ray_origin(event.position)
		var end = start + camera.project_ray_normal(event.position) * CLICK_RANGE
		
		var space = get_world().direct_space_state
		var exclude = creatures.get_children()
		var result = space.intersect_ray(start, end, exclude)
		
		if result:
			# A little hack. "Dig" into the tile to get the right position.
			var extension = start.direction_to(end) * 0.05
			var position = result.position + extension
			erase_v(tile_grid.world_to_map(position))


func _process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)
	
	process_camera(delta)
	
	$FPS.text = "FPS: %s" % Engine.get_frames_per_second()


func process_camera(delta):
	var velocity = Vector3.ZERO
	
	velocity.x += Input.get_action_strength("fly_left")
	velocity.x -= Input.get_action_strength("fly_right")
	
	velocity.y += Input.get_action_strength("fly_up")
	velocity.y -= Input.get_action_strength("fly_down")
	
	velocity.z += Input.get_action_strength("fly_forward")
	velocity.z -= Input.get_action_strength("fly_backward")
	
	velocity = velocity * CAMERA_FLIGHT_SPEED * delta
	
	# `translate' takes into account the rotation.
	camera.translation += velocity


# Create a `MeshLibrary' based on the available tile types.
func update_mesh_library():
	var mesh_library = MeshLibrary.new()
	
	var shape = BoxShape.new()
	shape.extents = Vector3.ONE * 0.5
	
	for tile_name in available_tile_types:
		var tile_def = available_tile_types[tile_name]
		
		var id = mesh_library.get_last_unused_item_id()
		_tile_type_to_id[tile_name] = id
		mesh_library.create_item(id)
		
		var mesh = CubeMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = SpatialMaterial.new()
		mesh.material.albedo_color = tile_def.color
		
		mesh_library.set_item_name(id, tile_name)
		mesh_library.set_item_mesh(id, mesh)
		mesh_library.set_item_shapes(id, [shape, Transform.IDENTITY])
	
	tile_grid.mesh_library = mesh_library


func generate_terrain():
	randomize()
	
	var noisy = OpenSimplexNoise.new()
	noisy.seed = randi()
	noisy.period = world_size * period
	noisy.lacunarity = lacunarity
	
	for x in range(world_size):
		for z in range(world_size):
			var noise = noisy.get_noise_2d(x, z)
			var height = 0.5 * (noise + 1) * terrain_height
			
			for y in range(height):
				fill(x, y, z, "dirt")
			fill(x, height, z, "grass")


func place_creatures():
	var placed_so_far = []
	
	while len(placed_so_far) < creatures_count:
		var x = floor(rand_range(0, world_size))
		var y = floor(rand_range(0, world_size))
		
		var position = Vector2(x, y) + Vector2.ONE * 0.5
		var can_place = true
		
		for neighbour in placed_so_far:
			if position.distance_to(neighbour) < private_space:
				can_place = false
				break
		
		if not can_place:
			continue
		
		placed_so_far.append(position)
		
		var node = preload("res://entities/creature.tscn").instance()
		node.translate(Vector3(position.x, terrain_height, position.y))
		creatures.add_child(node)


func fill(x, y, z, tile_type):
	var id = _tile_type_to_id[tile_type]
	tile_grid.set_cell_item(x, y, z, id)


func erase(x, y, z):
	tile_grid.set_cell_item(x, y, z, -1)


func erase_v(position):
	erase(position.x, position.y, position.z)
