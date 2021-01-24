extends Spatial


# How many seconds it takes for 24 "visual" hours to pass.
export(float) var cycle_length = 180.0

# Current time. Defaults to midday.
var time = cycle_length / 4.0


func _process(delta):
	time += delta
	
	while time > cycle_length:
		time -= cycle_length
	
	var theta = 2.0 * PI * time / cycle_length
	var energy = 0.5 * (1 + sin(theta))
	var sun_longitude = theta
	
	var light = $Light
	light.light_energy = energy
	light.rotation.x = sun_longitude
	
	var sky = $Environment.environment.background_sky
	sky.sun_longitude = rad2deg(sun_longitude)
