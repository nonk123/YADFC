class_name AI
extends Node


# The world position we should be walking towards. Can be ignored.
var target

# The creature we are controlling.
onready var host = get_parent()


func _ready():
	name = "AI"


# Override this to add AI routines.
func _think(_delta):
	pass


func _physics_process(delta):
	_think(delta)
