extends Node
class_name GameClient

signal received_players_data(players_list, own_id)
signal host_changed()
signal updated_player_position(id, position)
signal updated_player_animation(packet)
signal updated_gun_rotation(data)
signal updated_bullet_position(data)
signal connection_refused(data)
signal player_entered(player)
signal player_disconnected(id)
signal created_bullet(data)
signal destroyed_bullet(node_name)
signal countdown_updated(data)
signal game_started(data)
signal match_countdown_updated(data)
signal match_ended(data)
signal damaged()

signal connection_lost()

const SELF_PACKETS_BLOCK_LIST := [
	GameServer.CUpdatePosition,
	GameServer.CUpdateAnimation,
	GameServer.CUpdateGunRot,
	GameServer.CCreatedBullet,
	GameServer.CUpdateBulletPosition
]

var SERVER_URL := ""
var client := WebSocketClient.new()
var own_id := -1
var is_connected := false

func _ready():
	pass # Replace with function body.

func _process(_delta: float) -> void:
	if is_connected:
		client.poll()

func connect_to_server() -> void:
	SERVER_URL = GodotEnv.get_var("SERVER_URL") + ":" + str(GameServer.PORT)
	print(SERVER_URL)
	var err := client.connect_to_url(SERVER_URL)
	Logger.print("Attempt to connect to server at %s..." % SERVER_URL)

	while err != OK:
		err = client.connect_to_url(SERVER_URL)
		Logger.print("Failed to connect to the server, trying again...")
	
	Logger.print("OK. Connecting signals...")
	
	if not client.is_connected("data_received", self, "_on_data_received"):
		err = client.connect("data_received", self, "_on_data_received")
		err = client.connect("connection_established", self, "_connected")
		err = client.connect("connection_error", self, "_connection_failed")
		err = client.connect("connection_closed", self, "_connection_closed")

	if err != OK:
		Logger.error("Signal wasn't successfully connected. ERROR %s." % err)

	is_connected = true

func send_packet(packet : Packet) -> void:
	# Basic validation
	if packet.id < 0:
		Logger.error("Invalid Packed ID")
		return
	
	var pkt_utf8 := JSON.print(Utils.pkt2dict(packet)).to_utf8()
	client.get_peer(1).put_packet(pkt_utf8)


# This should be in the server. It's better to the client not even know
# about these packet. But as it's a proof of concept, it's ok for now.
func can_process_packet(packet : Packet) -> bool:
	var clientID : int = packet.clientID
	var packet_type : int = packet.id

	# Same problem as described at handle_packet.
	if clientID == own_id and packet_type in SELF_PACKETS_BLOCK_LIST:
		return false
	return true

func handle_packet(packet : Packet) -> void:
	if not can_process_packet(packet):
#		Logger.print("Can't process packet with data: %s" % str(packet.data))
		return

	# For some reason, in release builds, even when recognized as an integer
	# and working in if comparisons, using directly packet.id stopped working
#	 on match statement.
	var packet_type : int = packet.id
	
	match packet_type:
		GameServer.SCreateLocalPlayer:
			own_id = packet.data.own_id
			emit_signal("received_players_data", packet.data.players_list, packet.data.own_id)
		GameServer.SCreateRemotePlayer:
			var new_player : Dictionary = packet.data.new_player
			if new_player.id == own_id:
				return
			emit_signal("player_entered", new_player)
		GameServer.SRemovePlayer:
			emit_signal("player_disconnected", packet.clientID)
		GameServer.SSetHost:
			emit_signal("host_changed")
		GameServer.SUpdateStartCountdown:
			emit_signal("countdown_updated", packet.data)
		GameServer.SUpdateMatchCountdown:
			emit_signal("match_countdown_updated", packet.data)
		GameServer.SMatchResult:
			emit_signal("match_ended", packet.data)
		GameServer.SConnectionRefused:
			emit_signal("connection_refused", packet.data)
			client.get_peer(1).close()
		GameServer.CUpdatePosition:
			emit_signal("updated_player_position", Utils.dict2vec(packet.data.position), packet.clientID)
		GameServer.CUpdateAnimation:
			Logger.print("Update animation.")
			emit_signal("updated_player_animation", packet)
		GameServer.CCreatedBullet:
			emit_signal("created_bullet", packet)
		GameServer.CUpdateGunRot:
			emit_signal("updated_gun_rotation", packet)
		GameServer.CUpdateBulletPosition:
			emit_signal("updated_bullet_position", packet.data)
		GameServer.CDestroyBullet:
			emit_signal("destroyed_bullet", packet.data.name)	
		GameServer.SStartGame:
			emit_signal("game_started", packet.data)
		GameServer.CDamagedPlayer:
			emit_signal("damaged")

func _connected(_proto : String) -> void:
	pass

func _connection_failed() -> void:
	Logger.error("Failed to connect")
	emit_signal("connection_lost")

func _on_data_received() -> void:
	var data := client.get_peer(1).get_packet()
	var pkt_dict : Dictionary = parse_json(data.get_string_from_utf8())
	var packet := Utils.dict2pkt(pkt_dict)

	handle_packet(packet)

func _connection_closed(_was_clean_close : bool) -> void:
	emit_signal("connection_lost")
