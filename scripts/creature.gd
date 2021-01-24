class_name Creature
extends KinematicBody


# How hard this creature is pulled down.
export(float) var gravity = 9.8

# How many tiles the creature can traverse per second.
export(float) var movement_speed = 5.0

# Jumping accelerates the creature this much.
export(float) var jump_power = 5.0

# Velocity with movement applied.
var velocity = Vector3.ZERO

var target

var path = []

onready var world = get_node("/root/World")

onready var tile_grid = world.tile_grid

onready var astar = world.astar

onready var creatures = get_node("/root/World/Creatures")


func _ready():
	shade_ring()


func _physics_process(delta):
	run_ai()
	go_to_next_node(delta)
	
	velocity.y -= gravity * delta
	
	# Prevent moving into our spot.
	astar.set_point_weight_scale(standing_on(), 1.0)
	velocity = move_and_slide(velocity, Vector3.UP)
	astar.set_point_weight_scale(standing_on(), 100.0)


func run_ai():
	if target:
		var start_id = astar.get_closest_point(translation)
		var end_id = astar.get_closest_point(target)
		path = astar.get_point_path(start_id, end_id)


func go_to_next_node(delta):
	var start = translation
	
	var goal
	
	if not path:
		return
	elif len(path) == 1:
		goal = path[0]
	else:
		goal = path[1]
	
	var start_xz = Vector2(start.x, start.z)
	var goal_xz = Vector2(goal.x, goal.z)
	
	var direction = goal_xz - start_xz
	
	var speed = movement_speed
	
	if speed * delta > direction.length():
		speed = direction.length()
		path.remove(0)
	
	var movement = direction.normalized() * speed
	
	velocity.x = movement.x
	velocity.z = movement.y
	
	if is_on_floor() and goal.y > start.y:
		velocity.y = jump_power


# Return the ID of the tile we are standing on.
func standing_on():
	return astar.get_closest_point(translation + Vector3.DOWN * 0.5)


func shade_ring(color = Color(0.7, 0.7, 0.7)):
	$Ring.modulate = color
