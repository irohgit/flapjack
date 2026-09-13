class_name DialogueLine
extends Resource

enum Side { LEFT, RIGHT, FULL }

@export var speaker := ""
@export_multiline var text := ""
@export var portrait: Texture2D
@export var side: DialogueLine.Side = DialogueLine.Side.LEFT
@export var voice_sfx: AudioStream
