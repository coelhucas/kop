extends Node2D

signal instantiated_bullet(node, rotation, position)

const BULLET_SCENE := preload("res://source/game/Gun/Bullet.tscn")

onready var cannon := $Sprite/Cannon

var local := false
var target_rotation := 0.0

func _process(_delta: float) -> void:
	if not local:
		rotation = lerp(rotation, target_rotation, 0.25)
		return

	look_at(get_global_mouse_position())
	
	if get_global_mouse_position().x < global_position.x:
		scale.y = -1
	elif get_global_mouse_position().x > global_position.x:
		scale.y = 1

func shoot() -> void:
	if not $Cooldown.is_stopped():
		return

	var bullet := BULLET_SCENE.instance()
	bullet.mine = true
	bullet.global_position = cannon.global_position
	bullet.rotation = rotation
	emit_signal("instantiated_bullet", bullet, rotation, cannon.global_position)
	$Cooldown.start()
	randomize()
	
	if not $GunShot.playing:
		$GunShot.pitch_scale = rand_range(0.8, 1.2)
		$GunShot.play()
