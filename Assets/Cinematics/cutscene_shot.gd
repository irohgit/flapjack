## One shot of a held frame cutscene: the animation that plays, and the lines
## spoken over it. The shot stays on screen until every line has been advanced
## past, then the next shot begins.
class_name CutsceneShot
extends Resource

## Built by build_segments.gd from a folder of frames.
@export var segment: CutsceneSegment
## Frames per second for this shot. Slower reads as a held, deliberate moment.
@export_range(1.0, 30.0, 1.0) var fps := 12.0
## Loop the frames while waiting, or freeze on the last frame.
@export var loop := true
## Reuses the same DialogueLine as the Vinny outro, so both cutscenes are
## authored identically.
@export var lines: Array[DialogueLine] = []
