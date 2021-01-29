class_name PlayerAI
extends AI


const MOUSE_SENSITIVITY = 0.02


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var camera = host.get_node("Sight/Camera")
	camera.current = true


func _input(event):
	if event is InputEventMouseMotion:
		var rotation = event.relative * MOUSE_SENSITIVITY
		
		var sight = host.sight
		sight.rotation.x = clamp(sight.rotation.x + rotation.y, -PI / 2.0, PI / 2.0)
		
		host.rotation.y -= rotation.x


func _think(_delta):
	if Input.is_action_pressed("fire"):
		host.fire()
	
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
	
	get_node("/root/World").load_chunks_around(host.translation)
