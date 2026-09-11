# build_segments.gd
#
# WHAT IT DOES
# Builds one CutsceneSegment resource per scene folder, holding the ordered
# frame paths for that shot. Frames are loaded on demand at playback, so a long
# cutscene does not sit in memory all at once.
#
# Frames/SavingGin/gin1/*.webp  ->  Segments/SavingGin/gin1.tres
#
# HOW TO USE
# 1. Put the CUTSCENE folder name in ONLY below. Leave the list empty to build
#    every cutscene under Frames/.
# 2. Run with Ctrl+Shift+X.
# 3. Every line must end in OK. A FAIL means that segment did not save properly.
#
# WHY take_over_path
# Godot caches loaded resources by path. Saving a new object to a path that is
# already cached lets the cached object win, and an empty CutsceneSegment gets
# written instead of the built one. take_over_path claims the cache slot first.
#
# WHY THE CHECK READS TEXT
# Loading the saved file back through ResourceLoader does not reliably return
# what is on disk, even with CACHE_MODE_IGNORE. Counting the paths in the file
# itself cannot be fooled by any cache.
#
# NOTES
# Frame order is filename order, so folders and frame files must be zero padded
# once there are ten or more of them.
# Cutscenes played through CutscenePlayer use build_sprite_frames.gd instead.
#
# WHY FRAMES AT ALL
# Godot cannot play video. MP4 is locked behind a patent and OGV, which Godot
# does support, is very poor to work with. The pipeline is instead:
# 1. Convert the video to a GIF
# 2. Convert the GIF to PNG frames
# 3. Compress the PNGs to .webp, cutting file size by about 90%
# 4. Reimport those frames in Godot as lossy, because webp alone still costs
#    full size once the GPU has it
@tool
extends EditorScript

const ONLY := ["SavingGin"]

const ROOT := "res://Assets/Cinematics/Frames"
const OUT := "res://Assets/Cinematics/Segments"

const FRAMES_MARKER := "frames = PackedStringArray("


func _run() -> void:
	print("build_segments: starting")
	var root := DirAccess.open(ROOT)
	assert(root != null, "Missing " + ROOT)

	var failures := 0

	for cut in root.get_directories():
		if not ONLY.is_empty() and not ONLY.has(cut):
			continue

		var cut_path := ROOT.path_join(cut)
		var out_dir := OUT.path_join(cut)
		DirAccess.make_dir_recursive_absolute(out_dir)

		var cd := DirAccess.open(cut_path)
		if cd == null:
			push_error("Cannot open " + cut_path)
			continue
		var scenes := cd.get_directories()
		scenes.sort()

		for s in scenes:
			var folder := cut_path.path_join(s)
			var d := DirAccess.open(folder)
			if d == null:
				push_error("Cannot open " + folder)
				failures += 1
				continue

			var names := d.get_files()
			names.sort()

			var paths := PackedStringArray()
			for n in names:
				if n.ends_with(".import"):
					continue
				paths.append(folder.path_join(n))

			if paths.is_empty():
				push_warning("No frames in " + folder)
				failures += 1
				continue

			var out_path := out_dir.path_join(s + ".tres")

			var seg := CutsceneSegment.new()
			seg.frames = paths
			# Claim the cache slot before saving, or a stale cached resource at
			# this path can be written instead of this one.
			seg.take_over_path(out_path)

			var err := ResourceSaver.save(seg, out_path)
			if err != OK:
				push_error("Save failed on %s: %d" % [folder, err])
				print("%s / %s : SAVE FAILED %d" % [cut, s, err])
				failures += 1
				continue

			var written := _count_paths_in_file(out_path)
			if written != paths.size():
				print("%s / %s : FAIL, built %d frames but file holds %d" % [
					cut, s, paths.size(), written
				])
				failures += 1
			else:
				print("%s / %s : %d frames  OK" % [cut, s, paths.size()])

	if failures == 0:
		print("build_segments: done, all segments verified")
	else:
		print("build_segments: done with %d FAILURES, see above" % failures)


## Counts the res:// entries inside the frames array of a saved .tres, by
## reading the file as text. Immune to the resource cache.
func _count_paths_in_file(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1

	var text := file.get_as_text()
	file.close()

	var start := text.find(FRAMES_MARKER)
	if start == -1:
		return 0

	return text.substr(start).count("\"res://")
