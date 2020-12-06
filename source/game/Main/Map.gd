extends Node2D
class_name Map

onready var upper_left_point := $CameraPoints/UpperLeft
onready var bottom_right_point := $CameraPoints/BottomRight
onready var lobby_bounds := $LobbyBoundaries

func disable_bounds() -> void:
	for _b in lobby_bounds.get_children():
		_b.disabled = true

func enable_bounds() -> void:
	for _b in lobby_bounds.get_children():
		_b.disabled = false
