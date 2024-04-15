extends Resource
class_name AudioData

@export_group("Main properties")
## The audio file to be used (.mp3, .ogg, .wav)
@export var audio_files: Array[AudioStream]

## The name of the audio file, used for reference within code.
@export var name: String

## The number of beats per minute of the track.[br]
## This can be typed in the audio file properties, but we will add it here for now.
@export var bpm: int = 120

## The number of measures
@export var measures: int = 4

## The measure offset of the tracks in general.[br]
## Each slot must be in the same order as the audio files.
@export var measure_offsets: Array[int]

## The measure offset the track starts from in-game.[br]
## Each slot must be in the same order as the audio files.
@export var measure_offsets_entry: Array[int]


@export_group("Loop configuration")
## Checks if the audio file is loopable or not.
@export var is_loopable: bool

## The time (in seconds) where the loopable section begins.[br]
## Set to 0 if the loopable section starts from the very beginning.[br][br]
## More elaborate loopable sections can be done by setting multiple starting points.
@export var loop_start: Array[float]

## The time (in seconds) where the loopable section ends.[br]
## Set to 0 if the loopable section ends at the very end.[br]
## Set to -1 to finish the loopable at the end of the track[br][br]
## More elaborate loopable sections can be done by setting multiple end points.
@export var loop_end: Array[float]
