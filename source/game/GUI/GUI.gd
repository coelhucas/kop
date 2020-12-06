extends Control

const BUTTON_DISABLED_TEXT := "START GAME ( NEEDS %s MORE PLAYERS)"
const BUTTON_TEXT := "START GAME"
const RESULT_TEMPLATE_TEXT := "%s's victory!"
const RECONNECT_TEXT := "There's already a game occurring.\nTry again in %s..."

onready var start_game := $CanvasLayer/StartGame
onready var countdown := $CanvasLayer/Countdown
onready var result := $CanvasLayer/ResultScreen
onready var result_label := $CanvasLayer/ResultScreen/VBoxContainer/Label
onready var reconnect_screen := $CanvasLayer/ReconnectScreen
onready var reconnect_label := $CanvasLayer/ReconnectScreen/VBoxContainer/Label
onready var reconnect_button := $CanvasLayer/ReconnectScreen/VBoxContainer/Button
onready var disconnected_screen := $CanvasLayer/DisconnectedScreen
onready var hud := $CanvasLayer/HUD
onready var spectating := $CanvasLayer/Spectating

var needed_players := Utils.MINIMUM_PLAYERS
var time_to_reconnect := 0.0

func show_start_button() -> void:
	start_game.disabled = false
	start_game.show()

func hide_start_button() -> void:
	start_game.disabled = true
	start_game.hide()

func show_result(guests_victory : bool = false) -> void:
	result_label.text = RESULT_TEMPLATE_TEXT % ("Guests" if guests_victory else "King")
	if guests_victory:
		$CanvasLayer/ResultScreen/Guests.show()
		$CanvasLayer/ResultScreen/King.hide()
	else:
		$CanvasLayer/ResultScreen/Guests.hide()
		$CanvasLayer/ResultScreen/King.show()
	result.show()

func hide_result() -> void:
	result.hide()

func show_reconnect(remaining_time : String) -> void:
	time_to_reconnect = float(remaining_time)
	reconnect_label.show()
	reconnect_label.text = RECONNECT_TEXT % time_to_reconnect
	reconnect_screen.show()
	$CanvasLayer/ReconnectScreen/Timer.start()

func hide_reconnect() -> void:
	reconnect_screen.hide()
	reconnect_button.disabled = true

func check_remaining_players(total_players : int) -> void:
	needed_players = int(clamp(Utils.MINIMUM_PLAYERS - total_players, 0, Utils.MINIMUM_PLAYERS))
	
	if needed_players > 0:
		start_game.text = BUTTON_DISABLED_TEXT % needed_players
		start_game.disabled = true
	elif needed_players == 0:
		start_game.text = BUTTON_TEXT
		start_game.disabled = false

func update_countdown(value : String, in_game : bool = false) -> void:
	countdown.text = value

	if not countdown.visible:
		countdown.show()
		
	if not in_game:
		randomize()
		$ClockSound.pitch_scale = rand_range(0.8, 1.2)
		$ClockSound.play()
	
	if int(countdown.text) == 1 and not in_game:
		$ReadyGo.play()	
	
	if int(countdown.text) == 0 and not in_game:
		Logger.print("Started game! Show some cool effect!")
		countdown.hide()

func hide_countdown() -> void:
	countdown.hide()

func _on_Timer_timeout():
	time_to_reconnect -= 1

	if time_to_reconnect > 0:
		$CanvasLayer/ReconnectScreen/Timer.start()
		reconnect_label.text = RECONNECT_TEXT % time_to_reconnect
	else:
		reconnect_label.hide()
		reconnect_button.disabled = false


