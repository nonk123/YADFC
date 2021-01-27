class_name PlayerAI
extends AI


const MOUSE_SENSITIVITY = 0.025


var camera


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	camera = host.get_node("Camera")
	camera.current = true


func _input(event):
	if event is InputEventMouseMotion:
		var rotation = event.relative * MOUSE_SENSITIVITY
		
		camera.rotation.x = clamp(camera.rotation.x - rotation.y, -PI / 2.0, PI / 2.0)
		host.rotation.y -= rotation.x


func _think(_delta):
	var movement = Vector2.ZERO
	
	movement.x += Input.get_action_strength("move_left")
	movement.x -= Input.get_action_strength("move_right")
	
	movement.y += Input.get_action_strength("move_forwards")
	movement.y -= Input.get_action_strength("move_backwards")
	
	# Make it relative to the camera.
	movement = movement.normalized().rotated(-host.rotation.y)
	movement *= host.movement_speed
	
	host.velocity.x = movement.x
	host.velocity.z = movement.y
	
	if host.is_on_floor():
		host.velocity.y = host.jump_power * Input.get_action_strength("jump")
