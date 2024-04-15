extends Node
class_name AudioManager

@export var audio_data: AudioData
@export_enum("Normal", "On bar beat") var bgm_transition_type: int

var bgm_players: int:
	get:
		return bgm_players
	set(new_value):
		# Delete children first if there's any, then add the necessary players
		audio_data_players.clear()
		for child in get_children():
			remove_child(child)
			child.queue_free()
		
		var player_scene = preload(Scenes.AUDIO_DATA_PLAYER)
		for i in new_value:
			var player = player_scene.instantiate()
			player.bus = Vars.BGM_BUS
			player.looped.connect(_on_loop_end)
			player.stopped.connect(_on_stop_fadeout_end)
			player.transitioned.connect(_on_transition_end)
			player.measured.connect(_on_measure_received)
			add_child(player)
			audio_data_players.append(player)
		
		bgm_players = new_value

# Onready variables
@onready var text: RichTextLabel = $"../Canvas/Panel/Margin/VBoxContainer/NowPlaying"
@onready var measure_text: RichTextLabel = $"../Canvas/Panel/Margin/VBoxContainer/Beats"
@onready var prev_loop_end_button: Button = $"../Canvas/Panel/Margin/VBoxContainer/VBoxContainer2/Prev loop end"
@onready var transition_button: Button = $"../Canvas/Panel/Margin/VBoxContainer/VBoxContainer/Transition"

# Other variables
var audio_data_players: Array[AudioDataPlayer] = []
var active_player_index: int = 0
var loop_end_buffer: bool = false:
	set(new_value):
		prev_loop_end_button.disabled = new_value
		loop_end_buffer = new_value
var track_name: String = ""


func _ready() -> void:
	print("AudioManager ready")


func _on_play_pressed() -> void:
	print("Play pressed.")
	prepare_tracks()
	if bgm_transition_type == 0:
		for i in audio_data_players.size():
			var player = audio_data_players[i]
			if !player.playing:
				player.start(i)
				track_name = player.current_audio_data.name
				text.text = "Now playing: " + track_name
	else:
		var player = audio_data_players[0]
		player.start()
		track_name = player.current_audio_data.name
		text.text = "Now playing: " + track_name


func _on_pause_pressed() -> void:
	print("Pause pressed.")
	for player in audio_data_players:
		player.stream_paused = !player.stream_paused
		if player.current_audio_data != null:
			text.text = "Now playing: " + track_name +  " (Paused)" if player.stream_paused else "Now playing: " + track_name


func _on_stop_pressed(stop_type: int) -> void:
	for player in audio_data_players:
		if player.playing:
			# 0: Instant stop
			# 1: Fade-out
			player.stopping(stop_type)
	
	active_player_index = 0
	prev_loop_end_button.disabled = false


func _on_prev_loop_end_pressed() -> void:
	for player in audio_data_players:
		if player.playing:
			loop_end_buffer = player.prev_loop_end()


func _on_next_loop_end_pressed() -> void:
	for player in audio_data_players:
		if player.playing:
			player.next_loop_end()


func _on_transition_pressed(to_player_index: int, instant: bool = false) -> void:
	if instant && to_player_index != active_player_index:
		# Instant + different player selected
		instant_transition(to_player_index)
	elif instant && to_player_index == active_player_index:
		# Instant + default to 0
		instant_transition(0)
	elif to_player_index != active_player_index:
		# Not instant + different player selected
		normal_transition(to_player_index)
	else:
		# Not instant + default to 0
		normal_transition(0)


func _on_beat_transition_pressed(next_track_index: int, play_position: float = 0) -> void:
	beat_transition(next_track_index, play_position)


func instant_transition(to_player_index: int) -> void:
	audio_data_players[to_player_index].volume_fade_in(true)
	audio_data_players[active_player_index].volume_fade_out(true)
	active_player_index = to_player_index


func normal_transition(to_player_index: int) -> void:
	transition_button.disabled = true
	audio_data_players[to_player_index].is_fading_in = true
	audio_data_players[active_player_index].is_fading_out = true
	active_player_index = to_player_index


func beat_transition(next_track_index: int, play_position: float = 0) -> void:
	audio_data_players[active_player_index].transition_requested = true
	audio_data_players[active_player_index].audio_track_index = next_track_index
	audio_data_players[active_player_index].track_position = audio_data.loop_start[next_track_index] if play_position == 0 else play_position

# Signal receivers

func _on_loop_end() -> void:
	loop_end_buffer = false


func _on_stop_fadeout_end() -> void:
	text.text = "Stopped"
	measure_text.text = "-"


func _on_transition_end() -> void:
	transition_button.disabled = false


func _on_measure_received(measure: int) -> void:
	measure_text.text = str(measure)


func prepare_tracks() -> void:
	bgm_players = audio_data.audio_files.size()
	for i in audio_data_players.size():
		audio_data_players[i].current_audio_data = audio_data
