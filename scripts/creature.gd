class_name Creature
extends KinematicBody


# Scan this many path nodes ahead to find better movement strategy.
# Shouldn't be more than how far the creature jumps (in the XZ plane).
const SCAN_AHEAD = 5

# If the Y difference is this big, we try to jump over the obstacle.
const JUMP_EPSILON = 0.5

# How hard this creature is pulled down.
export(float) var gravity = 9.8

# How many tiles the creature can traverse per second.
export(float) var movement_speed = 5.0

# Jumping accelerates the creature this much.
export(float) var jump_power = 5.4

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
	if target:
		run_ai()
		
		if path:
			go_to_next_node(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	
	velocity.y -= gravity * delta
	
	# Prevent moving into our spot.
	disable_node_below(false)
	velocity = move_and_slide(velocity, Vector3.UP)
	disable_node_below(true)


func run_ai():
	var start_id = astar.get_closest_point(translation, true)
	var end_id = astar.get_closest_point(target, true)
	
	path = astar.get_point_path(start_id, end_id)


func go_to_next_node(delta):
	var translation_xz = Vector2(translation.x, translation.z)
	var last = translation
	
	var goal
	var goal_xz
	
	var direction
	
	var index = 0 if len(path) == 1 else 1
	
	var should_jump = false
	
	# Try to find a better path to the node (e.g., by jumping onto it).
	while index < len(path) and index < SCAN_AHEAD:
		goal = path[index]
		goal_xz = Vector2(goal.x, goal.z)
		
		direction = goal_xz - translation_xz
		
		if goal.y - last.y >= JUMP_EPSILON:
			should_jump = true
		
		last = goal
		
		index += 1
	
	var speed = movement_speed
	
	if speed * delta > direction.length():
		speed = direction.length()
		
		# Reached the final node in the path.
		if len(path) == 1:
			target = null
	
	var movement = direction.normalized() * speed
	
	velocity.x = movement.x
	velocity.z = movement.y
	
	if is_on_floor() and should_jump:
		velocity.y = jump_power


# Disable the pathfinding node we are standing on.
func disable_node_below(disabled):
	var its_id = astar.get_closest_point(translation, true)
	
	if its_id != -1:
		astar.set_point_disabled(its_id, disabled)


func shade_ring(color = Color(0.7, 0.7, 0.7)):
	$Ring.modulate = color
