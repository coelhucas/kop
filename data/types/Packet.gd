extends Resource
class_name Packet

export(int) var id := -1

# < 1 - Received from server.
export(int) var clientID := -1
export(Dictionary) var data := {}

func toDict() -> Dictionary:
	return {
		pkt = id,
		clientID = clientID,
		data = data
	}
