extends Node

enum {
	LOBBY,
	STARTING,
	IN_GAME,
	ENDING
}

onready var world := $World
onready var players_container := $World/PlayersContainer
onready var bullets_container := $World/BulletsContainer
onready var map : Map = $World/Map
onready var gui := $GUI

# Packed Scenes
var player_scene := load("res://source/game/Player/Player.tscn")
#

var game_state := LOBBY
var is_server := false

var client := GameClient.new()
var server := GameServer.new()

var hosting_game := false
var local_player := Node.new()
var spectating_target := Node.new()
var spectating := false

# Called when the node enters the scene tree for the first time.
func _ready():
	is_server = bool(int(GodotEnv.get_var("SERVER")))
	print(is_server)

	if is_server:
		add_child(server)
		server.start()
	else:
		add_child(client)
		client.connect_to_server()

		var err := OK
		err = client.connect("updated_player_position", self, "updated_player_position")
		err = client.connect("updated_player_animation", self, "updated_player_animation")
		err = client.connect("player_disconnected", self, "player_disconnected")
		err = client.connect("connection_refused", self, "connection_refused")
		err = client.connect("received_players_data", self, "create_players")
		err = client.connect("player_entered", self, "add_new_player")
		err = client.connect("created_bullet", self, "created_bullet")
		err = client.connect("updated_gun_rotation", self, "updated_gun_rot")
		err = client.connect("updated_bullet_position", self, "updated_bullet_pos")
		err = client.connect("destroyed_bullet", self, "destroy_bullet")
		err = client.connect("host_changed", self, "host_changed")
		err = client.connect("countdown_updated", self, "countdown_updated")
		err = client.connect("game_started", self, "game_started")
		err = client.connect("damaged", self, "damage_player")
		err = client.connect("match_countdown_updated", self, "countdown_updated")
		err = client.connect("match_ended", self, "match_ended")
		err = client.connect("connection_lost", self, "connection_closed")

		if err != OK:
			Logger.error("Error %s connecting client signal." % err)

func _process(_delta : float) -> void:
	if game_state == IN_GAME and is_instance_valid(spectating_target):
		if spectating and not spectating_target.alive:
			look_for_spectate()

func player_already_exists(id : String) -> bool:
	var exists := players_container.get_node_or_null(id)
	return exists != null

func create_players(players_data : Dictionary, own_id : int) -> void:
	for playerID in players_data.keys():
		if player_already_exists(playerID) or not players_data[playerID]:
			continue

		var player_info : Dictionary = players_data[playerID]
		var player = player_scene.instance()
		player.global_position = Utils.dict2vec(player_info.position)
		player.target_position = Utils.dict2vec(player_info.position)
		player.animation = player_info.animation
		player.id = player_info.id
		player.local = player_info.id == own_id
		player.name = str(player_info.id)
		player.game_client = client

		players_container.add_child(player)

		if player.local:
			gui.check_remaining_players(players_container.get_child_count())
			player.connect("bullet_created", bullets_container, "add_child")
			player.connect("died", self, "look_for_spectate")
			player.connect("damaged", gui.hud, "updated_hp")
			local_player = player

func add_new_player(player_data : Dictionary) -> void:
	if player_already_exists(str(player_data.id)):
		return
	
	var player = player_scene.instance()
	player.global_position = Utils.dict2vec(player_data.position)
	player.target_position = Utils.dict2vec(player_data.position)
	player.id = player_data.id
	player.name = str(player_data.id)

	players_container.add_child(player)
	gui.check_remaining_players(players_container.get_child_count())
	Logger.print(str(players_container.get_child_count()))

func connection_refused(data : Dictionary) -> void:
	var remaining_time : String = data.remaining
	gui.show_reconnect(remaining_time)

func reset_game() -> void:
	for _p in players_container.get_children():
		_p.queue_free()
	
	for _b in bullets_container.get_children():
		_b.queue_free()
	
	gui.hud.hide()
	gui.spectating.hide()
	spectating_target = null
	gui.hud.updated_hp(Utils.MAX_HP)
	gui.hide_countdown()
	map.enable_bounds()
	$InGameMusic.stop()
	$LobbyMusic.play()

func updated_player_position(new_position : Vector2, playerID : int) -> void:
	var updated_player := players_container.get_node_or_null(str(playerID))

	if updated_player:
		updated_player.target_position = new_position

func updated_player_animation(packet : Packet) -> void:
	Logger.warn("Updating animation: %s" % packet.data)
	var animation : String = packet.data.animation
	var flipped : bool = packet.data.flipped
	var updated_player := players_container.get_node_or_null(str(packet.clientID))

	if updated_player:
		updated_player.animation = animation
		updated_player.flipped = flipped

func look_for_spectate() -> void:
	if local_player.alive and local_player.has_method("reset_spectation"):
		gui.spectating.hide()
		local_player.reset_spectation()
		return
	
	if has_players_alive():
		spectating_target = get_first_alive_player()
		spectating_target.spectate(local_player.camera)
		gui.spectating.show()
		spectating = true

func has_players_alive() -> bool:
	for _p in players_container.get_children():
		if _p.alive and not _p.king:
			return true
	return false

func get_first_alive_player() -> KinematicBody2D:
	for _p in players_container.get_children():
		if _p.alive and not _p.king:
			return _p
	return null

func player_disconnected(id : int) -> void:
	var player_to_remove := players_container.get_node_or_null(str(id))
	
	if player_to_remove:
		players_container.remove_child(player_to_remove)
		player_to_remove.queue_free()
		
	gui.check_remaining_players(players_container.get_child_count())
	

func created_bullet(packet : Packet) -> void:
	Logger.print("Will create bullet")
	var dir : float = packet.data.direction
	var pos : Vector2 = Utils.dict2vec(packet.data.position)

	var bullet : Node2D = Utils.BULLET_SCENE.instance()
	bullet.global_position = pos
	bullet.owner_id = packet.clientID
	bullet.rotation = dir

	Logger.print("Created bullet")
	bullets_container.add_child(bullet)

func updated_gun_rot(packet : Packet) -> void:
	var rot : float = packet.data.rotation
	var player := players_container.get_node_or_null(str(packet.clientID))

	if player:
		player.gun.target_rotation = rot

# DEPRECATED, SHOULD BE REMOVED
func updated_bullet_pos(_data : Dictionary) -> void:
	pass

func destroy_bullet(b_name : String) -> void:
	var bullet_node := bullets_container.get_node_or_null(b_name)

	if bullet_node:
		bullet_node.queue_free()

func host_changed() -> void:
	hosting_game = true
	gui.check_remaining_players(players_container.get_child_count())
	gui.show_start_button()

func countdown_updated(data : Dictionary) -> void:
	var remaining : String = data.remaining
	gui.update_countdown(remaining, game_state == IN_GAME)

	if game_state == LOBBY:
		game_state = STARTING
		local_player.camera.limit_left = map.upper_left_point.global_position.x
		local_player.camera.limit_top = map.upper_left_point.global_position.y
		local_player.camera.limit_right = map.bottom_right_point.global_position.x
		local_player.camera.limit_bottom = map.bottom_right_point.global_position.y
		
		map.disable_bounds()

	if int(remaining) == 0 and game_state == STARTING:
		game_state = IN_GAME
		$InGameMusic.play()
		$LobbyMusic.stop()
		gui.hud.show()

func game_started(data : Dictionary) -> void:
	var sorted_king : String = data.king
	var king_player := players_container.get_node_or_null(sorted_king)

	if king_player:
		king_player.setup_king()

func damage_player() -> void:
	local_player.take_damage()

func match_ended(result : Dictionary) -> void:
	game_state = ENDING
	var winner : int = result.winner
	gui.show_result(winner == GameServer.GUESTS)

func connection_closed() -> void:
	reset_game()
	gui.disconnected_screen.show()

func _on_StartGame_pressed():
	gui.hide_start_button()
	
	var packet := Packet.new()
	packet.id = GameServer.CStartGame
	
	client.send_packet(packet)

func _on_Play_Again_Button_pressed():
	reset_game()
	var packet := Packet.new()
	packet.id = GameServer.CPlayAgain
	packet.clientID = local_player.id
	client.send_packet(packet)
	game_state = LOBBY
	gui.hide_result()

func _on_Reconnect_Button_pressed():
	client.connect_to_server()
	gui.disconnected_screen.hide()
