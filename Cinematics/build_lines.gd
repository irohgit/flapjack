# build_lines.gd
#
# OWNS res://Cinematics/SavingVinny/Lines/*.tres
# These files are GENERATED. Do not hand edit them in the Inspector, your
# changes will be destroyed the next time this runs. Edit the table below.
#
# HOW THE TABLE WORKS
# Every key except "f" is a CutsceneLine property name, so anything the
# resource supports can be set here without changing this script. A few short
# aliases exist for the common ones, see ALIAS. An unknown key is an error,
# not a silent no-op.
#
#   "f"      output filename, without extension
#   "who"    speaker        "say"    text
#   "hold"   hold_time      "anim"   stage_animation
#   "left"   left_portrait  "stage"  stage_image
#
# Textures and sounds are given as file names, not paths.
# Motion is given as a dictionary of CutsceneMotion properties, and enabled
# is set for you.
#
# Run with Ctrl+Shift+X, or File > Run.

@tool
extends EditorScript

const OUT_DIR := "res://Cinematics/SavingVinny/Lines/"
const PH := "res://Cinematics/Placeholders/"
const SFX := "res://Assets/Audio/Cinematic/"

const ALIAS := {
	"who": "speaker",
	"say": "text",
	"hold": "hold_time",
	"left": "left_portrait",
	"stage": "stage_image",
	"anim": "stage_animation",
}

const TEXTURE_PROPS := ["left_portrait", "stage_image"]
const STREAM_PROPS := ["sound"]
const MOTION_PROPS := ["left_motion", "stage_motion"]
const NAME_PROPS := ["stage_animation", "animation"]

const KEEP := CutsceneLine.Layout.KEEP
const SPLIT := CutsceneLine.Layout.SPLIT
const FULL := CutsceneLine.Layout.FULL


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# One row per beat, in playback order.
	# Blank stage_animation means keep whatever shot is already running, so a
	# run of dialogue on one shot only names it once.
	var beats: Array[Dictionary] = [
		{"f": "01_open", "layout": SPLIT, "left": "JACK_MONOCLE.png", "anim": "scene01", "hold": 2.0},
		{"f": "02_focus", "anim": "scene02", "hold": 0.4},
		{"f": "03_jack_shocked", "left": "JACK_SHOCKED.png", "hold": 1.2},
		{"f": "04_wide", "layout": FULL, "anim": "scene03", "hold": 0.8},
		{"f": "05_vinny_payment", "who": "Vinny", "say": "That is not what we agreed. I want proper payment."},
		{"f": "06_captain_no", "who": "Captain", "say": "No."},
		{"f": "07_vinny_tanqueray", "who": "Vinny", "say": "I may not look intimidating. But I warn you against ever crossing a deal with a Tanqueray."},
		{"f": "08_captain_blackbeard", "who": "Captain", "say": "You? A Tanqueray? If you're a Tanqueray, we're the Blackbeard Pirates. The most despicable, most terrible pirates in these waters."},
		{"f": "09_captain_plank", "who": "Captain", "say": "How about we pay you by not making you walk the plank?"},
		{"f": "10_vinny_asked", "who": "Vinny", "say": "You asked for it."},
		{"f": "11_drink", "anim": "scene04", "hold": 1.0},
		{"f": "12_glow", "anim": "scene05", "hold": 1.4},
		{"f": "13_fart", "anim": "scene06", "hold": 1.0},
		{"f": "14_vinny_degas", "who": "Vinny", "say": "...I brought the Degas Potion."},
		{"f": "15_laugh", "anim": "scene07", "hold": 1.8},
		{"f": "16_crowsnest", "who": "Crow's Nest", "say": "CAPTAIN! ONE NAVY VESSEL AHEAD. IT DOESN'T LOOK LIKE A GALLEON.", "anim": "scene08"},
		{"f": "17_captain_tieup", "who": "Captain", "say": "Tie him up. Let's do what we do best. Pirating.", "anim": "scene09"},
		{"f": "18_return_split", "layout": SPLIT, "left": "JACK_WARY.png", "anim": "scene10", "hold": 1.0},
		{"f": "19_jack_sailing", "who": "Jack", "say": "Uh. I think they're sailing towards us now."},
	]

	var written := 0
	var failed := 0

	for beat: Dictionary in beats:
		if not beat.has("f"):
			push_error("Beat with no filename key, skipped")
			failed += 1
			continue

		var line := CutsceneLine.new()
		if not _apply(line, beat):
			failed += 1
			continue

		var path: String = OUT_DIR + str(beat["f"]) + ".tres"
		var err: int = ResourceSaver.save(line, path)
		if err != OK:
			push_error("Failed to save %s (error %d)" % [path, err])
			failed += 1
		else:
			written += 1

	EditorInterface.get_resource_filesystem().scan()
	print("build_lines: %d written, %d failed, %d beats total" % [written, failed, beats.size()])


# Copies a beat row onto a CutsceneLine. Returns false if the row is bad,
# so a typo costs one beat and a loud error, not a silently wrong cutscene.
func _apply(line: CutsceneLine, beat: Dictionary) -> bool:
	for key: String in beat:
		if key == "f":
			continue

		var prop: String = ALIAS.get(key, key)
		if not _has_property(line, prop):
			push_error("Beat '%s': CutsceneLine has no property '%s'" % [beat["f"], prop])
			return false

		line.set(prop, _convert(prop, beat[key], str(beat["f"])))

	return true


func _convert(prop: String, value: Variant, beat_name: String) -> Variant:
	if prop in TEXTURE_PROPS and value is String:
		return _load_asset(PH + value, beat_name)
	if prop in STREAM_PROPS and value is String:
		return _load_asset(SFX + value, beat_name)
	if prop in MOTION_PROPS and value is Dictionary:
		return _motion(value, beat_name)
	if prop in NAME_PROPS:
		return StringName(value)
	return value


func _motion(spec: Dictionary, beat_name: String) -> CutsceneMotion:
	var m := CutsceneMotion.new()
	m.enabled = true
	for key: String in spec:
		if not _has_property(m, key):
			push_error("Beat '%s': CutsceneMotion has no property '%s'" % [beat_name, key])
			continue
		m.set(key, spec[key])
	return m


func _load_asset(path: String, beat_name: String) -> Resource:
	if not ResourceLoader.exists(path):
		push_warning("Beat '%s': missing asset %s" % [beat_name, path])
		return null
	return load(path)


# get_property_list is the reliable check. `set` on a bad name does nothing
# and reports nothing, which is exactly the failure we are refusing to have.
func _has_property(obj: Object, prop: String) -> bool:
	for p: Dictionary in obj.get_property_list():
		if p.name == prop:
			return true
	return false
