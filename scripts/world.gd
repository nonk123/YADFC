extends Spatial


# In what way the mouse is locked.
enum MouseLock {
	NONE,
	PANNING,
	ROTATING,
}


# Camera flight speed in tiles/s.
const CAMERA_FLIGHT_SPEED = 20.0

const PANNING_FACTOR = 0.04

const ROTATION_FACTOR = 0.02

# Place each pathfinding node on top of the tile, in its center.
const PATHFINDING_OFFSET = Vector3(0.5, 1.0, 0.5)

# World size in the XZ plane.
export(int) var world_size = 80

# How tall the entire terrain section is.
export(int) var terrain_height = 16

# Larger values make the world smoother.
export(float) var period = 0.8

# Not sure what this does to worldgen, but it does something.
export(float) var lacunarity = 2.5

# Spawn this many creatures when the world is generated.
export(int) var creatures_count = 30

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

var selected_creature

var mouse_lock = MouseLock.NONE

# Convert a tile type name to its ID in the mesh library.
var _tile_type_to_id = {}

# Quick access to pathfinding node IDs through their coordinates.
var _point_to_id = {}

onready var tile_grid = $Tiles

onready var creatures = $Creatures

onready var camera = $Camera

onready var selected_tile = $SelectedTile

# The A* pathfinder instance to be used elsewhere.
onready var astar = AStar.new()


func _ready():
	update_mesh_library()
	generate_terrain()
	place_creatures()


func _input(event):
	if event is InputEventMouseMotion:
		match mouse_lock:
			MouseLock.PANNING:
				var movement = event.relative * PANNING_FACTOR
				camera.translate(Vector3(movement.x, -movement.y, 0.0))
			MouseLock.ROTATING:
				var rotation = event.relative * ROTATION_FACTOR
				camera.rotation += Vector3(-rotation.y, -rotation.x, 0.0)
				camera.rotation.x = clamp(camera.rotation.x, -PI / 2.0, PI / 2.0)
		
		reposition_selected_tile(event.position)
	elif event is InputEventMouseButton:
		if event.is_pressed():
			match event.button_index:
				BUTTON_LEFT:
					if mouse_lock == MouseLock.NONE:
						do_click_action(event.position)
				BUTTON_MIDDLE:
					mouse_lock = MouseLock.PANNING
				BUTTON_RIGHT:
					mouse_lock = MouseLock.ROTATING
		else:
			mouse_lock = MouseLock.NONE
	
	if mouse_lock == MouseLock.NONE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)
	
	process_camera(delta)
	
	$FPS.text = "FPS: %s" % Engine.get_frames_per_second()


func reposition_selected_tile(mouse_position):
	var result = cast_ray(mouse_position, creatures.get_children())
		
	if result:
		var tile_position = tile_grid.world_to_map(result.position)
		# Prevent clipping into the ground.
		selected_tile.translation = tile_position + Vector3.UP * 0.001


func do_click_action(click_position):
	var result = cast_ray(click_position)
	
	if not result:
		return
	
	var node_position = astar.get_closest_point(result.position, true)
	var node_enabled = not astar.is_point_disabled(node_position)
	
	if result.collider is Creature:
		if selected_creature:
			selected_creature.shade_ring()
		
		selected_creature = result.collider
		
		selected_creature.shade_ring(Color(0.0, 0.8, 0.0))
	elif selected_creature and node_enabled:
		var ai = selected_creature.get_node("AI")
		ai.target = result.position


func process_camera(delta):
	var velocity = Vector3.ZERO
	
	velocity.x -= Input.get_action_strength("fly_left")
	velocity.x += Input.get_action_strength("fly_right")
	
	velocity.y += Input.get_action_strength("fly_up")
	velocity.y -= Input.get_action_strength("fly_down")
	
	velocity.z -= Input.get_action_strength("fly_forward")
	velocity.z += Input.get_action_strength("fly_backward")
	
	velocity = velocity * CAMERA_FLIGHT_SPEED * delta
	
	camera.translate(velocity)


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
		
		var ai = WalkingAI.new()
		node.add_child(ai)
		
		creatures.add_child(node)


func cast_ray(cursor_position, exclude = []):
	var start = camera.project_ray_origin(cursor_position)
	var end = start + camera.project_ray_normal(cursor_position) * camera.far
	
	var space = get_world().direct_space_state
	return space.intersect_ray(start, end, exclude)


func get_neighbours(point):
	var neighbours = []
	
	for dx in [-1.0, 0.0, 1.0]:
		for dy in [-1.0, 0.0, 1.0]:
			for dz in [-1.0, 0.0, 1.0]:
				var offset = Vector3(dx, dy, dz)
				
				if offset.length_squared() != 0.0:
					neighbours.push_front(point + offset)
	
	return neighbours


# Fill the specified position with a type, and update the pathfinding nodes.
func fill(x, y, z, tile_type):
	var tile_id = _tile_type_to_id[tile_type]
	tile_grid.set_cell_item(x, y, z, tile_id)
	
	# The rest updates the pathfinding nodes.
	
	var point = tile_grid.world_to_map(Vector3(x, y, z)) + PATHFINDING_OFFSET
	var point_id = astar.get_available_point_id()
	
	_point_to_id[point] = point_id
	astar.add_point(point_id, point)
	
	for neighbour in get_neighbours(point):
		var their_id = _point_to_id.get(neighbour)
		
		if their_id != null:
			if neighbour == point + Vector3.DOWN:
				# The tile directly below cannot be walked on.
				_point_to_id.erase(neighbour)
				astar.remove_point(their_id)
			else:
				astar.connect_points(point_id, their_id)


func erase(x, y, z):
	tile_grid.set_cell_item(x, y, z, tile_grid.INVALID_CELL_ITEM)
	
	var point = tile_grid.world_to_map(Vector3(x, y, z))
	var point_id = _point_to_id[point]
	
	_point_to_id.erase(point)
	astar.remove_point(point_id)


func erase_v(position):
	erase(position.x, position.y, position.z)


func is_air(x, y, z):
	return tile_grid.get_cell_item(x, y, z) == tile_grid.INVALID_CELL_ITEM


func is_air_v(position):
	return is_air(position.x, position.y, position.z)
