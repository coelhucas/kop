extends Resource
class_name PlayerPeer

export(int) var id := -1
export(Vector2) var position := Vector2.ZERO
export(String) var animation := "default"
export(bool) var king := false
export(bool) var alive := true

func toDict() -> Dictionary:
	return {
		id = id,
		position = {
			x = position.x,
			y = position.y
		},
		animation = animation,
		king = king,
		alive = alive
	}
