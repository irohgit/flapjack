@tool
extends EditorScript

const OUT_DIR := "res://Cinematics/SavingVinny/Lines/"
const PH := "res://Cinematics/Placeholders/"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var beats: Array[Dictionary] = [
		{"f": "01_open", "layout": 1, "left": "JACK_MONOCLE.png", "stage": "STAGE_BLURRED_GROUP.png", "hold": 2.0},
		{"f": "02_focus", "stage": "STAGE_GROUP_CRISP.png", "hold": 0.4},
		{"f": "03_jack_shocked", "left": "JACK_SHOCKED.png", "hold": 1.2},
		{"f": "04_wide", "layout": 2, "stage": "WIDE_VINNY_PIRATES.png", "hold": 0.8},
		{"f": "05_vinny_payment", "who": "Vinny", "say": "That is not what we agreed. I want proper payment."},
		{"f": "06_captain_no", "who": "Captain", "say": "No."},
		{"f": "07_vinny_tanqueray", "who": "Vinny", "say": "I may not look intimidating. But I warn you against ever crossing a deal with a Tanqueray."},
		{"f": "08_captain_blackbeard", "who": "Captain", "say": "You? A Tanqueray? If you're a Tanqueray, we're the Blackbeard Pirates. The most despicable, most terrible pirates in these waters."},
		{"f": "09_captain_plank", "who": "Captain", "say": "How about we pay you by not making you walk the plank?"},
		{"f": "10_vinny_asked", "who": "Vinny", "say": "You asked for it."},
		{"f": "11_drink", "hold": 1.0},
		{"f": "12_glow", "hold": 1.4},
		{"f": "13_fart", "hold": 1.0},
		{"f": "14_vinny_degas", "who": "Vinny", "say": "...I brought the Degas Potion."},
		{"f": "15_laugh", "hold": 1.8},
		{"f": "16_crowsnest", "who": "Crow's Nest", "say": "CAPTAIN! ONE NAVY VESSEL AHEAD. IT DOESN'T LOOK LIKE A GALLEON."},
		{"f": "17_captain_tieup", "who": "Captain", "say": "Tie him up. Let's do what we do best. Pirating."},
		{"f": "18_return_split", "layout": 1, "left": "JACK_WARY.png", "stage": "STAGE_SHIP_TURNING.png", "hold": 1.0},
		{"f": "19_jack_sailing", "who": "Jack", "say": "Uh. I think they're sailing towards us now."},
	]

	for beat: Dictionary in beats:
		var line := CutsceneLine.new()
		line.speaker = beat.get("who", "")
		line.text = beat.get("say", "")
		line.layout = beat.get("layout", 0)
		line.hold_time = beat.get("hold", 0.0)
		line.left_portrait = _tex(beat.get("left", ""))
		line.stage_image = _tex(beat.get("stage", ""))

		var path: String = OUT_DIR + beat["f"] + ".tres"
		var err: int = ResourceSaver.save(line, path)
		if err != OK:
			push_error("Failed to save %s (error %d)" % [path, err])
		else:
			print("wrote ", path)

	EditorInterface.get_resource_filesystem().scan()
	print("Done. 19 lines written.")


func _tex(file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null
	var path := PH + file_name
	if not ResourceLoader.exists(path):
		push_warning("Missing placeholder: " + path)
		return null
	return load(path)
