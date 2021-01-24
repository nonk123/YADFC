extends KinematicBody


export(float) var gravity = 9.8

var velocity = Vector3.ZERO


func _physics_process(delta):
	velocity.y -= gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)
