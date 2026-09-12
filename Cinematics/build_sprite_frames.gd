# build_sprite_frames.gd
#
# WHAT IT DOES
# Builds one SpriteFrames resource per cutscene, with one looping animation per scene folder inside it, named after that folder.
#
# Frames/savingvinny/scene01/*.webp  ->  SpriteFrames/savingvinny.tres
#                                          animation "scene01"
#
# HOW TO USE
# 1. Put the CUTSCENE folder name in ONLY below. Not a scene folder. Leave the list empty to build every cutscene under Frames/.
# 2. Run with Ctrl+Shift+X.
# 3. Check the Output panel lists every scene with a sensible frame count.
#
# NOTES
# Frame order is filename order, so scene folders must be zero padded (scene01, not scene1) once a cutscene has ten or more shots.
# Only cutscenes played through CutscenePlayer belong here. Use build_segments.gd to generate CutsceneSegment resources instead.
@tool
extends EditorScript
const ONLY := ["savingvinny"] 


const ROOT := "res://Assets/Cinematics/Frames"
const OUT := "res://Assets/Cinematics/SpriteFrames"
const FPS := 12.0


func _run() -> void:
	print("build_sprite_frames: starting")
	DirAccess.make_dir_recursive_absolute(OUT)
	var root := DirAccess.open(ROOT)
	assert(root != null, "Missing " + ROOT)

	for cut in root.get_directories():
		if not ONLY.is_empty() and not ONLY.has(cut):
			continue
		var sf := SpriteFrames.new()
		sf.remove_animation("default")

		var cut_path := ROOT.path_join(cut)
		var cd := DirAccess.open(cut_path)
		var scenes := cd.get_directories()
		scenes.sort()

		for s in scenes:
			var folder := cut_path.path_join(s)
			var d := DirAccess.open(folder)
			if d == null:
				push_error("Cannot open " + folder)
				continue
			var names := d.get_files()
			names.sort()

			sf.add_animation(s)
			sf.set_animation_speed(s, FPS)
			sf.set_animation_loop(s, true)

			for n in names:
				if n.ends_with(".import"):
					continue
				sf.add_frame(s, load(folder.path_join(n)))

			print("%s / %s : %d frames" % [cut, s, sf.get_frame_count(s)])

		var err := ResourceSaver.save(sf, OUT.path_join(cut + ".tres"))
		if err != OK:
			push_error("Save failed for %s: %d" % [cut, err])
