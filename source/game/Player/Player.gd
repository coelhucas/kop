extends KinematicBody2D
class_name Player

signal bullet_created(node)
signal damaged(hp)
signal died

const BASE_SPEED := 315
const KING_SPEED := 200

onready var gun := $Gun
onready var camera := $Camera
onready var crown := $Sprites/Crown
onready var anim_player := $AnimationPlayer
onready var sprites := $Sprites

var motion := Vector2.ZERO
var speed := BASE_SPEED
var hp := 5

var local := false
var king := false
var alive := true
var prev_alive := true
var flipped := false
var prev_flipped := false

var target_position := Vector2.ZERO
var animation := ""

var prev_position := Vector2.ZERO
var prev_animation := ""

var game_manager := Node.new()
var game_client := GameClient.new()

var id := -1

func _ready() -> void:
	if local:
		camera.current = true
		$SendUpdate.start()
		gun.local = true
	else:
		gun.set_process(false)
	
	if not king:
		gun.hide()
	else:
		setup_king()

func _physics_process(_delta : float) -> void:
	if animation != anim_player.assigned_animation:
		anim_player.play(animation)
		
		if animation == "dead":
			$Wilhelm.play()

	if not alive and prev_alive:
		prev_alive = false
		emit_signal("died")

	if not alive and animation != "dead":
		animation = "dead"
	
	if king and not crown.visible:
		crown.show()
	
	if alive and animation == "dead":
		alive = false

	if not alive:
		return

	if not local:
		global_position = lerp(global_position, target_position, 0.62)
		$Sprites.scale.x = -1 if flipped else 1
		gun.scale.y = -1 if flipped else 1
		return
		
	if Input.is_action_pressed("LMB") and king:
		gun.shoot()
	
	var h_axis : int = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	var v_axis : int = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))

	if king and get_global_mouse_position().x > global_position.x:
		flipped = false
	elif king and get_global_mouse_position().x < global_position.x:
		flipped = true
	
	if not king and motion.x > 0:
		flipped = false
	elif not king and motion.x < 0:
		flipped = true
	
	if flipped:
		$Sprites.scale.x = -1
	else:
		$Sprites.scale.x = 1
	
	motion.x = h_axis
	motion.y = v_axis
	
	if motion.length() > 1:
		speed = (KING_SPEED if king else BASE_SPEED) * .8
	else:
		speed = BASE_SPEED

	motion = move_and_slide(motion * speed)
	global_position = global_position.floor()

func setup_king() -> void:
	king = true
	crown.show()
	gun.show()
	gun.set_process(true)
	speed = KING_SPEED
	animation = "king_default"
	
	var err := gun.connect("instantiated_bullet", self, "_on_instantiated_bullet")

	if err != OK:
		Logger.warn("Error %s connecting signal to Gun." % err)

func send_data() -> void:
	if global_position != prev_position:
		var packet := Packet.new()
		prev_position = global_position
		packet.id = GameServer.CUpdatePosition
		packet.clientID = id
		packet.data = {
			position = Utils.vec2dict(global_position.floor())
		}

		game_client.send_packet(packet)

	if prev_animation != animation or prev_flipped != flipped:
		var packet := Packet.new()
		packet.id = GameServer.CUpdateAnimation
		packet.clientID = id
		packet.data = {
			animation = animation,
			flipped = $Sprites.scale.x != 1
		}
		
		game_client.send_packet(packet)
		prev_animation = animation
		prev_flipped = flipped

	if king:
		if not is_instance_valid(gun):
			return
			
		var packet := Packet.new()
		packet.id = GameServer.CUpdateGunRot
		packet.clientID = id
		packet.data = {
			rotation = gun.rotation
		}

		game_client.send_packet(packet)

func take_damage() -> void:
	if not alive:
		return

	hp -= 1
	emit_signal("damaged", hp)
	camera.shake()
	
	if hp > 0:
		animation = "damaged"

	if hp <= 0 and alive:
		var packet := Packet.new()
		packet.id = GameServer.CPlayerDied
		packet.clientID = id
		animation = "dead"
		game_client.send_packet(packet)
		alive = false
		emit_signal("died")

func _on_SendUpdate_timeout():
	send_data()

func spectate(cam : Camera2D) -> void:
	camera.current = true
	(camera as Camera2D).limit_left = cam.limit_left
	(camera as Camera2D).limit_top = cam.limit_top
	(camera as Camera2D).limit_right = cam.limit_right
	(camera as Camera2D).limit_bottom = cam.limit_bottom

func reset_spectation() -> void:
	camera.current = true

func _updated_bullet_position(new_pos : Vector2, bullet_name : String) -> void:
	var packet := Packet.new()
	packet.id = GameServer.CUpdateBulletPosition
	packet.clientID = id
	packet.data = {
		name = bullet_name,
		position = Utils.vec2dict(new_pos)
	}
	
	game_client.send_packet(packet)

func _destroyed_bullet(b_name : String) -> void:
	var packet := Packet.new()
	packet.id = GameServer.CDestroyBullet
	packet.clientID = id
	packet.data = {
		name = b_name
	}
	
	game_client.send_packet(packet)

func _damaged_player(player_name : String) -> void:
	var packet := Packet.new()
	packet.id = GameServer.CDamagedPlayer
	packet.clientID = id
	packet.data = {
		target = player_name
	}

	game_client.send_packet(packet)

func _on_instantiated_bullet(node : Node, rot : float, pos : Vector2) -> void:
	var err := node.connect("updated_position", self, "_updated_bullet_position")
	err = node.connect("damaged", self, "_damaged_player")
	err = node.connect("bullet_destroyed", self, "_destroyed_bullet")
	node.owner_id = id

	if err != OK:
		Logger.error("Error %s attempting to connect bullet signal." % err)
		return

	var bullet_pkt := Packet.new()
	bullet_pkt.id = GameServer.CCreatedBullet
	bullet_pkt.clientID = id
	bullet_pkt.data = {
		direction = rot,
		position = Utils.vec2dict(pos)
	}
	
	game_client.send_packet(bullet_pkt)
	emit_signal("bullet_created", node)



func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "damaged" and hp > 0 and local:
		animation = "default"
	elif anim_name == "damaged" and hp <= 0 and local:
		animation = "dead"
