extends Spatial


# Pan by this many tiles per second.
const CAMERA_PAN_SPEED = 20.0

# World size in the XZ plane.
export(int) var world_size = 256

# How tall the entire terrain section is.
export(int) var terrain_height = 16

# Larger values make the world smoother.
export(float) var generation_period = 0.5

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


func _ready():
	update_mesh_library()
	generate_terrain()


func _process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)
	
	var velocity = Vector2.ZERO
	
	velocity.x += Input.get_action_strength("pan_left")
	velocity.x -= Input.get_action_strength("pan_right")
	
	velocity.y += Input.get_action_strength("pan_up")
	velocity.y -= Input.get_action_strength("pan_down")
	
	velocity = velocity.normalized() * CAMERA_PAN_SPEED * delta
	
	var camera = $Camera
	camera.translation.x += velocity.x
	camera.translation.z += velocity.y
	
	$FPS.text = "FPS: %s" % Engine.get_frames_per_second()


# Create a `MeshLibrary' based on the available tile types.
func update_mesh_library():
	var mesh_library = MeshLibrary.new()
	
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
	
	tile_grid.mesh_library = mesh_library


func generate_terrain():
	var noisy = OpenSimplexNoise.new()
	noisy.period = world_size * generation_period
	
	for x in range(world_size):
		for z in range(world_size):
			var noise = noisy.get_noise_2d(x, z)
			var height = 0.5 * (noise + 1) * terrain_height
			
			for y in range(height):
				fill(x, y, z, "dirt")
			fill(x, height, z, "grass")


func fill(x, y, z, tile_type):
	var id = _tile_type_to_id[tile_type]
	tile_grid.set_cell_item(x, y, z, id)
