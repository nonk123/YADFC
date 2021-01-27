class_name Creature
extends KinematicBody


# How hard this creature is pulled down.
export(float) var gravity = 9.8

# How many tiles the creature can traverse per second.
export(float) var movement_speed = 8.0

# Jumping accelerates the creature this much.
export(float) var jump_power = 4.5

# Velocity with movement applied.
var velocity = Vector3.ZERO

onready var astar = get_node("/root/World").astar


func _ready():
	shade_ring()


func _physics_process(delta):
	velocity.y -= gravity * delta
	
	# Prevent moving into our spot.
	disable_node_below(false)
	velocity = move_and_slide(velocity, Vector3.UP)
	disable_node_below(true)


# Disable the pathfinding node we are standing on.
func disable_node_below(disabled):
	var its_id = astar.get_closest_point(translation, true)
	
	if its_id != -1:
		astar.set_point_disabled(its_id, disabled)


func shade_ring(color = Color(0.7, 0.7, 0.7)):
	$Ring.modulate = color
