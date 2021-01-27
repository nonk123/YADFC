class_name WalkingAI
extends AI


# Path to `target'. A list of positions we have to traverse.
var path = []

onready var astar = get_node("/root/World").astar


func _think(delta):
	if target:
		build_path()
		
		if path:
			go_to_next_node(delta)
	else:
		host.velocity.x = 0.0
		host.velocity.z = 0.0


func build_path():
	var start_id = astar.get_closest_point(host.translation, true)
	var end_id = astar.get_closest_point(target, true)
	
	path = astar.get_point_path(start_id, end_id)


func go_to_next_node(delta):
	var start = host.translation
	var start_xz = Vector2(start.x, start.z)
	
	var goal = path[0 if len(path) == 1 else 1]
	var goal_xz = Vector2(goal.x, goal.z)
	
	var direction = goal_xz - start_xz
	
	var speed = host.movement_speed
	
	if speed * delta > direction.length():
		speed = direction.length()
		
		# Reached the final node in the path.
		if len(path) == 1:
			target = null
	
	var movement = direction.normalized() * speed
	
	host.velocity.x = movement.x
	host.velocity.z = movement.y
	
	if host.is_on_floor() and (goal.y - start.y > 0.01):
		host.velocity.y = host.jump_power
