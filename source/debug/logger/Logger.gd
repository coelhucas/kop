extends CanvasLayer

func _ready() -> void:
	$Box.hide()
	if not OS.is_debug_build():
		$Box.hide()

func print(msg: String, console_print : bool = false) -> void:
	if not OS.is_debug_build():
		return

	$Box.append_bbcode(msg + "\n")
	var dt := OS.get_datetime()
	push_warning("[%02d:%02d] - %s" % [dt.hour, dt.minute, msg])

func error(msg: String) -> void:
	self.print("[color=red]%s[/color]" % msg)
	push_error(msg)

func warn(msg: String) -> void:
	self.print("[color=yellow]%s[/color]" % msg)
	push_warning(msg)

