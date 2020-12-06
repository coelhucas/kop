extends Control

func updated_hp(current_hp : int) -> void:
	$Label.text = "%s/%s" % [current_hp, Utils.MAX_HP]
