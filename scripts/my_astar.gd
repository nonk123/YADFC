class_name MyAStar
extends AStar


# Scale vertical movement costs by this much.
const VERTICAL_COST_FACTOR = 0.9


# Make vertical movement move favourable.
func _estimate_cost(from_id, to_id):
	var from = get_point_position(from_id)
	var to = get_point_position(to_id)
	
	var dx = abs(from.x - to.x)
	var dy = abs(from.y - to.y) * VERTICAL_COST_FACTOR
	var dz = abs(from.z - to.z)
	
	return dx + dy + dz
