extends Node
class_name GameServer

# Packet Types.
# S prefix: came from server;
# C prefix: came from client;
#
# Packet format: [PacketType: int, ClientID: String, data: Dictionary]
# - ClientUUID refers to the client which generated the response. An empty string
# means it was generated from the server.
#
# - data contains the needed data to handle each packet.
enum {
	SCreateLocalPlayer = 0,
	SCreateRemotePlayer,
	SRemovePlayer,
	SUpdateStartCountdown,
	SUpdateMatchCountdown,
	SSetHost,
	SStartGame,
	SMatchResult,
	SConnectionRefused,
	CRegisterPlayer,
	CUpdatePosition,
	CUpdateAnimation,
	CUpdateGunRot,
	CCreatedBullet,
	CUpdateBulletPosition,
	CDestroyBullet,
	CDamagedPlayer,
	CPlayerDied,
	CStartGame,
	CPlayAgain
}

enum {
	LOBBY,
	GAME,
	ENDING
}

enum {
	KING,
	GUESTS
}

const PORT := 9080
const TIME_TO_START := 5
const MATCH_DURATION := 120

var server_state := LOBBY
var connected_peers := {}
var host_peer := PlayerPeer.new()
var server := WebSocketServer.new()

# Cooldown timer -> Used to start the match
var c_timer := Timer.new()
var c_timer_name := "start_game_timer"
var c_wait_time := 1.0
var c_remaining := 5

# Match timer -> Counts til the game end
var m_timer := Timer.new()
var m_timer_name := "match_timer"
var m_wait_time := 1.0
var m_remaining := 120

func _process(_delta : float) -> void:
	if server.is_listening():
		server.poll()

func start():
	var err := server.listen(PORT)

	while err != OK:
		err = server.listen(PORT)
		Logger.error("Server start failed, trying again...")
	Logger.print("Server successfully listening at %s..." % PORT, true)

	err = server.connect("client_connected", self, "_on_client_connected")
	err = server.connect("client_disconnected", self, "_on_client_disconnected")
	err = server.connect("data_received", self, "_on_data_received")

	if err != OK:
		Logger.error("ERROR Connecting server signals")

func spread_packet(packet : Packet, ignore : int = -1) -> void:
	for _str_pID in connected_peers.keys():
		var peerID : int = int(_str_pID)
		if not server.has_peer(peerID) or peerID == ignore:
			continue
	
		send_packet(packet, peerID)

func send_packet(packet : Packet, targetID : int) -> void:
	var pkt := str(JSON.print(Utils.pkt2dict(packet))).to_utf8()

	var err := server.get_peer(targetID).put_packet(pkt)

	if err != OK:
		Logger.error("Error Could not send data to peer %s." % targetID)

func handle_packet(packet : Packet) -> void:
	var packet_type : int = packet.id
	
	match packet_type:
		CUpdatePosition:
			update_peer_position(packet)
			spread_packet(packet)
		CUpdateAnimation:
			update_peer_animation(packet)
			spread_packet(packet)
		CCreatedBullet:
			spread_packet(packet)
		CUpdateGunRot:
			spread_packet(packet)
		CUpdateBulletPosition:
			spread_packet(packet)
		CDestroyBullet:
			spread_packet(packet)
		CStartGame:
			_handle_start_game()
		CDamagedPlayer:
			# I shouldn't do that, but I already know this packet definition and I don't have any
			# plans to change it.
			send_packet(packet, int(packet.data.target))
		CPlayerDied:
			update_dead_players(packet)
		CPlayAgain:
			reconnect_player(packet)

func update_peer_position(packet : Packet) -> void:
	var pos : Dictionary = packet.data.position

	if connected_peers.has(str(packet.clientID)):
		connected_peers[str(packet.clientID)].position = pos

func update_peer_animation(packet : Packet) -> void:
	var anim : String = packet.data.animation

	if connected_peers.has(packet.clientID):
		connected_peers[str(packet.clientID)].animation = anim

func update_dead_players(packet : Packet) -> void:
	Logger.warn("Has Peer? %s" % connected_peers.has(str(packet.clientID)))
	Logger.warn("Dead peer: %s" % packet.clientID)
	Logger.warn("%s" % str(connected_peers))
	connected_peers[str(packet.clientID)].alive = false
	
	if _get_alive_guests_players() <= 0:
		_finish_match()
	
	Logger.warn(str(_get_alive_guests_players()))

func reconnect_player(packet : Packet) -> void:
	_connect_new_player(packet.clientID)

func _connect_new_player(id : int) -> void:
	var p_peer := PlayerPeer.new()
	p_peer.id = id
	p_peer.position = Utils.SCREEN_CENTER

	if connected_peers.empty():
		_set_host(p_peer)

	connected_peers[str(id)] = p_peer.toDict()

	var connection_packet := Packet.new()
	connection_packet.id = SCreateLocalPlayer
	connection_packet.data = {
		own_id = id,
		players_list = connected_peers
	}

	var new_peer_packet := Packet.new()
	new_peer_packet.id = SCreateRemotePlayer
	new_peer_packet.data = {
		new_player = p_peer.toDict()
	}

	spread_packet(new_peer_packet, id)
	send_packet(connection_packet, id)

func _on_client_connected(id : int, _protocol : String) -> void:
	if server_state != LOBBY:
		var packet := Packet.new()
		packet.id = SConnectionRefused
		packet.data = {
			remaining = str(m_remaining)
		}

		send_packet(packet, id)
		return

	_connect_new_player(id)
	
func _on_data_received(id : int) -> void:
	var pkt_dict : Dictionary = JSON.parse(server.get_peer(id).get_packet().get_string_from_utf8()).result

	handle_packet(Utils.dict2pkt(pkt_dict))

func _on_client_disconnected(id : int, _was_clean_close : bool) -> void:
	var was_king : bool = connected_peers[str(id)].king
	var removed := connected_peers.erase(str(id))

	if not connected_peers.empty() and id == host_peer.id:
		var oldest_peer : Dictionary = connected_peers[str(connected_peers.keys()[0])]
		_set_host(Utils.dict2player(oldest_peer))

	if removed:
		var remove_packet := Packet.new()
		remove_packet.id = SRemovePlayer
		remove_packet.clientID = id
		spread_packet(remove_packet)
		
		if was_king:
			_finish_match()
			return

		if _get_all_alive_players() <= 1 and server_state == GAME:
			_finish_match()
			return

	else:
		Logger.warn("Attempt to remove PeerID %s failed because it didn't existed" % id)
		
func _handle_start_game() -> void:
	var packet := Packet.new()
	packet.id = SUpdateStartCountdown
	packet.data = {
		remaining = str(TIME_TO_START)
	}
	spread_packet(packet)

	var c_timer_node := get_node_or_null(c_timer_name)

	if not c_timer_node:
		c_timer.name = c_timer_name
		add_child(c_timer)

		var err := c_timer.connect("timeout", self, "_update_start_timer")
		if err != OK:
			Logger.error(str(err))
	c_timer.wait_time = c_wait_time
	c_remaining = TIME_TO_START

	c_timer.start()

func _start_match() -> void:
	randomize()
	if server_state != LOBBY:
		Logger.warn("Attempt to start game during a match.")
		return
	
	var _players_list := connected_peers.keys()
	_players_list.shuffle()
	var sorted_king : String = str(_players_list[0])
	connected_peers[sorted_king].king = true

	var packet := Packet.new()
	packet.id = SStartGame
	packet.data = {
		king = sorted_king,
		remaining = str(MATCH_DURATION)
	}

	server_state = GAME
	spread_packet(packet)

	var m_timer_node := get_node_or_null(m_timer_name)

	if not m_timer_node:
		m_timer.name = m_timer_name
		add_child(m_timer)

		var err := m_timer.connect("timeout", self, "_update_match_timer")
		if err != OK:
			Logger.error(str(err))
	m_timer.wait_time = m_wait_time
	m_remaining = MATCH_DURATION

	m_timer.start()

func _update_start_timer() -> void:
	c_remaining -= 1

	var packet := Packet.new()
	packet.id = SUpdateStartCountdown
	packet.data = {
		remaining = str(c_remaining)
	}
	spread_packet(packet)

	if c_remaining <= 0:
		_start_match()
		c_timer.stop()

func _update_match_timer() -> void:
	m_remaining -= 1

	var packet := Packet.new()
	packet.id = SUpdateMatchCountdown
	packet.data = {
		remaining = str(m_remaining)
	} 

	spread_packet(packet)

	if m_remaining <= 0:
		_finish_match()
		m_timer.stop()

func _finish_match() -> void:
	Logger.warn("Finishing game")
	server_state = ENDING
	var packet := Packet.new()
	packet.id = SMatchResult

	Logger.warn("Alive guests: %s" % _get_alive_guests_players())

	if _get_alive_guests_players() > 0:
		packet.data = {
			winner = GUESTS
		}
	else:
		packet.data = {
			winner = KING
		}
	
	spread_packet(packet)
	_reset_game()

func _reset_game() -> void:
	connected_peers.clear()
	server_state = LOBBY
	c_timer.stop()
	m_timer.stop()

	c_timer.wait_time = c_wait_time
	m_timer.wait_time = m_wait_time

func _set_host(p_peer : PlayerPeer) -> void:
	host_peer = p_peer

	var packet := Packet.new()
	packet.id = SSetHost
	
	send_packet(packet, p_peer.id)

func _get_all_alive_players() -> int:
	var counter := 0
	for _id in connected_peers.keys():
		var _p = connected_peers[_id]
		if _p.alive:
			counter += 1
	
	return counter

func _get_alive_guests_players() -> int:
	var counter := 0
	Logger.print("%s connected players o.O" % connected_peers.size(), true)
	for _id in connected_peers.keys():
		var _p = connected_peers[_id]
		if not _p.king and _p.alive:
			counter += 1
	
	return counter
