class_name TrackPiece
extends RefCounted

# Bitmask Constants for Orientations
const TYPE_NONE = 0
const TYPE_HORIZONTAL = 1 << 0  # 1
const TYPE_VERTICAL   = 1 << 1  # 2
const TYPE_NE         = 1 << 2  # 4 (Curve North-to-East)
const TYPE_SE         = 1 << 3  # 8
const TYPE_SW         = 1 << 4  # 16
const TYPE_NW         = 1 << 5  # 32

# The actual active track types on this tile
# Example: A cross track is (TYPE_HORIZONTAL | TYPE_VERTICAL)
var orientation_mask: int = TYPE_NONE

# The 8-neighbor connectivity array
# Order: [N, NE, E, SE, S, SW, W, NW]
# True = A train CAN exit this tile in that direction.
var connections: Array[bool] = [false, false, false, false, false, false, false, false]

# Function to add a track type and update connections automatically
func add_orientation(type: int):
	orientation_mask |= type # Bitwise OR to overlay
	_update_connections()

func _update_connections():
	# Reset
	connections.fill(false)
	
	# STRAIGHTS
	if orientation_mask & TYPE_HORIZONTAL:
		connections[2] = true # East
		connections[6] = true # West
	if orientation_mask & TYPE_VERTICAL:
		connections[0] = true # North
		connections[4] = true # South
		
	# CURVES
	# North-East Curve (connects Up and Right)
	if orientation_mask & TYPE_NE:
		connections[0] = true
		connections[2] = true
		
	# South-East Curve (connects Down and Right)
	if orientation_mask & TYPE_SE:
		connections[4] = true
		connections[2] = true
		
	# South-West Curve (connects Down and Left)
	if orientation_mask & TYPE_SW:
		connections[4] = true
		connections[6] = true
		
	# North-West Curve (connects Up and Left)
	if orientation_mask & TYPE_NW:
		connections[0] = true
		connections[6] = true
