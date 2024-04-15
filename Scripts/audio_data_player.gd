extends AudioStreamPlayer
class_name AudioDataPlayer

# Export variables
@export var current_audio_data: AudioData

# Audio track index
var audio_track_index: int = 0
var track_position: float = 0

# Loop variables
var loop_start_index: int = 0
var loop_end_index: int = 0
var loop_end_buffer: bool = false

# Stop and transition variables
var transition_requested: bool = false
var transition_completed: bool = false
var is_fading_in: bool = false
var is_fading_out: bool = false
var is_stopping: bool = false
var tween_timer: float = 0

const fading_type: Dictionary = {
	INSTANT = 0,
	EASE = 1
}

# Beat variables
var song_pos: float = 0
var song_pos_beat: int = 0
var secs_per_beat: float = 1.0
var last_beat_counted: int = 0
var measure: int = 4

# Signals
signal looped
signal stopped
signal transitioned
signal measured(measure)


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	# Fade-in/out transitions
	if is_fading_in:
		volume_fade_in(_delta)
	
	if is_fading_out:
		volume_fade_out(_delta)
	
	# Checks if the current track is loopable, then checks for the selected loop point
	if (playing and current_audio_data.is_loopable and has_loop_points(current_audio_data.loop_end) 
		and get_playback_position() >= current_audio_data.loop_end[loop_end_index]
		and current_audio_data.loop_end[loop_end_index] != 0 and !is_ending_loop()):
			print(get_playback_position())
			play(current_audio_data.loop_start[loop_start_index])
			loop_end_index -= 1 if loop_end_buffer else 0
			loop_end_buffer = false
			looped.emit()
	
	# Calculate beats of the song
	if (playing):
		song_pos = get_playback_position() + AudioServer.get_time_since_last_mix()
		song_pos -= AudioServer.get_output_latency()
		count_beats()


func start(track_index: int = 0, position: float = 0) -> void:
	stream = current_audio_data.audio_files[track_index]
	secs_per_beat = 60.0 / current_audio_data.bpm
	# Check if track is set for on bar beat transitions
	if current_audio_data.measure_offsets.size() > 0:
		measure = current_audio_data.measure_offsets[track_index]
	
	# All players except the first one start with no volume
	if track_index > 0:
		volume_db = -50
	play(position)


func count_beats() -> void:
	song_pos_beat = int(ceil(song_pos / secs_per_beat))
	if last_beat_counted < song_pos_beat && !transition_completed:
		if measure < current_audio_data.measures:
			measure += 1
		else:
			measure = 1
		last_beat_counted = song_pos_beat
		measured.emit(measure)
		if transition_requested && measure == current_audio_data.measure_offsets_entry[audio_track_index] + 1:
			handle_transition_request()
	elif last_beat_counted > song_pos_beat or transition_completed:
		# This case only happens after the song loops or a transition happened
		last_beat_counted = song_pos_beat
		measure = (int((song_pos_beat % 4)) + current_audio_data.measure_offsets[audio_track_index]) % current_audio_data.measures 
		measured.emit(measure)
		transition_completed = false


#Signals

func _on_finished():
	if current_audio_data.is_loopable and !is_ending_loop():
		play()
	else:
		reset_player_values()
		stopped.emit()


# Stop methods

func stopping(stop_type) -> void:
	if (stop_type == fading_type.INSTANT):
		super.stop()
		reset_player_values()
		stopped.emit()
	elif (stop_type == fading_type.EASE):
		is_stopping = true
		is_fading_out = true


func finish_fade_out() -> void:
	if is_stopping:
		super.stop()
		reset_player_values()
		stopped.emit()


# Helper methods

func volume_fade_in(delta: float, instant: bool = false) -> void:
	if instant:
		volume_db = linear_to_db(1)
	else:
		tween_timer += delta
		volume_db = Tween.interpolate_value(-50, 50, tween_timer, 1, Tween.TRANS_SINE, Tween.EASE_OUT)
		if volume_db >= linear_to_db(1):
			volume_db = linear_to_db(1)
			tween_timer = 0
			is_fading_in = false


func volume_fade_out(delta: float, instant: bool = false) -> void:
	if instant:
		volume_db = -50
	elif volume_db > -50:
		tween_timer += delta
		volume_db = Tween.interpolate_value(0, -50, tween_timer, 1, Tween.TRANS_SINE, Tween.EASE_IN)
		if volume_db <= -50:
			volume_db = -50
			tween_timer = 0
			is_fading_out = false
			transitioned.emit()
			finish_fade_out()
	else:
		is_fading_out = false
		finish_fade_out()


func handle_transition_request() -> void:
	stream = current_audio_data.audio_files[audio_track_index]
	loop_start_index = audio_track_index
	loop_end_index = audio_track_index
	play(track_position)
	measure = current_audio_data.measure_offsets_entry[audio_track_index] + 1
	transition_requested = false
	transition_completed = true

func reset_player_values() -> void:
	volume_db = 0
	loop_start_index = 0
	loop_end_index = 0
	loop_end_buffer = false
	is_fading_in = false
	is_fading_out = false
	is_stopping = false


func has_loop_points(loop_points: Array) -> bool:
	return true if loop_points.size() > 0 else false


func is_ending_loop() -> bool:
	return true if current_audio_data.loop_end[loop_end_index] == -1 else false

func prev_loop_start() -> void:
	if loop_start_index > 0:
		loop_start_index -= 1
	else:
		print("Already on the first loop start point.")


func prev_loop_end() -> bool:
	if loop_end_index > 0 and get_playback_position() > current_audio_data.loop_end[loop_end_index - 1]:
		# If the selected loop point is already behind the current position, wait until
		# the current loop is done.
		loop_end_buffer = true
	elif loop_end_index > 0:
		loop_end_index -= 1
	else:
		print("Already on the first loop end point.")
	
	return loop_end_buffer


func next_loop_start() -> void:
	if loop_start_index < current_audio_data.loop_start.size() - 1:
		loop_start_index += 1
	else:
		print("Already reached the last loop start point.")


func next_loop_end() -> void:
	if loop_end_index < current_audio_data.loop_end.size() - 1:
		loop_end_index += 1
	else:
		print("Already reached the last loop end point.")
