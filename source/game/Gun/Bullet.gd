extends KinematicBody2D
class_name Bullet

signal updated_position(pos, name)
signal damaged(name)
signal bullet_destroyed(name)

var mine := false
var motion := Vector2.ZERO
var speed := 1000
var owner_id := -1

var _parent := Node.new()

func _ready() -> void:
	randomize()
	_parent = get_parent()

	if _parent:
		name = "bullet-%s-%s" % [owner_id, _parent.get_child_count()]
	
	if not mine:
		$AudioStreamPlayer2D.play()
		$SendUpdate.queue_free()

func _physics_process(_delta : float) -> void:
	motion = move_and_slide(Vector2.RIGHT.rotated(rotation) * speed)

func destroy() -> void:
	$Sprite.hide()
	$Hitbox.queue_free()
	
	if $AudioStreamPlayer2D.playing:
		yield($AudioStreamPlayer2D, "finished")
	
	queue_free()
	
func _send_update():
	emit_signal("updated_position", global_position, name)

func _on_Hitbox_body_entered(body):
	if mine:
		if body is KinematicBody2D and body.alive:
			emit_signal("damaged", body.name)
		
		if body is KinematicBody2D and not body.alive:
			return
	
		emit_signal("bullet_destroyed", name)
		destroy()
	
	if not body is KinematicBody2D:
		destroy()


func _on_DestroyTimer_timeout():
	destroy()
