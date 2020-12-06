extends Node
class_name Utils

const MINIMUM_PLAYERS := 3
const MAX_HP := 5
const SCREEN_CENTER := Vector2(320, 180)
const BULLET_SCENE := preload("res://source/game/Gun/Bullet.tscn")

static func vec2dict(vec : Vector2) -> Dictionary:
	return {
		x = vec.x,
		y = vec.y
	}

static func dict2vec(dict : Dictionary) -> Vector2:
	return Vector2(dict.x, dict.y)

static func pkt2dict(packet : Packet) -> Dictionary:
	return {
		pkt = packet.id,
		clientID = packet.clientID,
		data = packet.data
	}

static func dict2pkt(dict : Dictionary) -> Packet:
	var packet := Packet.new()
	packet.id = dict.pkt
	packet.clientID = dict.clientID
	packet.data = dict.data
	return packet

static func dict2player(dict : Dictionary) -> PlayerPeer:
	var player := PlayerPeer.new()
	player.id = dict.id
	player.position = dict2vec(dict.position)
	player.animation = dict.animation
	player.king = dict.king

	return player
