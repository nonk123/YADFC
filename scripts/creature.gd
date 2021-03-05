class_name Creature
extends KinematicBody


# How hard this creature is pulled down.
export(float) var gravity = 9.8

# How many tiles the creature can traverse per second.
export(float) var movement_speed = 8.0

# Jumping accelerates the creature this much.
export(float) var jump_power = 6.0

# How far can the gun fire.
export(float) var gun_range = 64.0

# Firerate of the gun.
export(float) var gun_rpm = 800

# How much damage does the gun deal.
export(float) var gun_damage = 20.0

# Velocity with movement applied.
var velocity = Vector3.ZERO

# When this value reaches zero, you die!
var health = 100.0

# Used to determine if the gun is ready to fire.
var _time_since_last_shot = 0.0

# Delay between each shot of the gun.
onready var gun_cooldown = 60.0 / gun_rpm

# Rotate this node to aim up and down.
onready var sight = $Sight

onready var raycast = sight.get_node("RayCast")

onready var gun = sight.get_node("Gun")

onready var gunshot = gun.get_node("Gunshot")

onready var astar = get_node("/root/World").astar


func _ready():
	# Adapt to firerate.
	var fps = ceil(gun_rpm / 60.0) * 2
	gun.frames.set_animation_speed("shooting", fps)
	
	raycast.cast_to *= gun_range
	
	# Don't play a shooting animation when we spawn.
	_time_since_last_shot = gun_cooldown


func _physics_process(delta):
	velocity.y -= gravity * delta
	
	# Prevent moving into our spot.
	toggle_node_below(false)
	velocity = move_and_slide(velocity, Vector3.UP)
	toggle_node_below(true)


func _process(delta):
	_time_since_last_shot += delta
	
	if _time_since_last_shot > gun_cooldown:
		gun.play("idle")
	else:
		gun.play("shooting")


# Disable or enable the pathfinding node we are standing on.
func toggle_node_below(disabled):
	var its_id = astar.get_closest_point(translation, true)
	
	if its_id != -1:
		astar.set_point_disabled(its_id, disabled)


# Fire the gun wherever it's aiming.
func fire():
	# Make sure we don't fire 60 rounds per second.
	if _time_since_last_shot <= gun_cooldown:
		return
	
	_time_since_last_shot = 0.0
	gunshot.play()
	
	if not raycast.is_colliding():
		return
	
	var enemy = raycast.get_collider()
	var point = raycast.get_collision_point()
	
	if enemy.has_method("deal_damage"):
		enemy.deal_damage(gun_damage, point)


# Deal this much damage to the creature, deleting it if it died.
# Also spawn blood particles at HIT_POSITION.
func deal_damage(how_much, hit_position=null):
	health -= how_much
	
	# Default to center of the sprite.
	if hit_position == null:
		hit_position = global_transform.origin + Vector3.UP * 0.5
	
	var blood = $Blood
	blood.global_transform.origin = hit_position
	blood.emitting = true
	
	$Hit.play()
	
	if health <= 0.0:
		queue_free()
