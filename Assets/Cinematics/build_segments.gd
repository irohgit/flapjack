@tool
extends EditorScript

const ROOT := "res://Cinematics/Frames"
const OUT := "res://Cinematics/Segments"

#This is a tool to stitch together compressed frames.
#Godot does not have a way to render videos. MP4 is locked behind a patent.
#OGV which GODOT supports is very poor to work with.
#What i have done is instead
#1. Converted the video into a GIF
#2. Converted the GIF into PNG
#3. Comrpessed the PNG to .webp format cutting file size by 90%
#4. Further reimported the frames once they were in GODOT to lossy format as, if we left
#at webp without converting to lossy then the frames would be higher because of the GPU requiring

func _run() -> void:
	var root := DirAccess.open(ROOT)
	assert(root != null, "Missing " + ROOT)

	for cut in root.get_directories():
		var cut_path := ROOT.path_join(cut)
		var out_dir := OUT.path_join(cut)
		DirAccess.make_dir_recursive_absolute(out_dir)

		var cd := DirAccess.open(cut_path)
		var scenes := cd.get_directories()
		scenes.sort()

		for s in scenes:
			var folder := cut_path.path_join(s)
			var d := DirAccess.open(folder)
			var names := d.get_files()
			names.sort()

			var paths := PackedStringArray()
			for n in names:
				if n.ends_with(".import"):
					continue
				paths.append(folder.path_join(n))

			if paths.is_empty():
				push_warning("No frames in " + folder)
				continue

			var seg := CutsceneSegment.new()
			seg.frames = paths
			var err := ResourceSaver.save(seg, out_dir.path_join(s + ".tres"))
			if err != OK:
				push_error("Save failed on %s: %d" % [folder, err])
			else:
				print("%s / %s : %d frames" % [cut, s, paths.size()])
