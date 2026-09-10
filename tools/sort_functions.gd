@tool
extends EditorScript

## Reorders the functions in a .gd file into Engine callbacks, Public, then
## Private, alphabetised within each group. Everything above the first
## top-level `func` is left untouched, including exports, vars and signals.
##
## HOW TO RUN
##   1. Set TARGET to the script you want sorted.
##   2. Leave DRY_RUN true and press Ctrl+Shift+X. Read the Output panel.
##   3. When the output looks right, set DRY_RUN false and run again.
##
## SAFETY
##   Writes a .bak beside the original before overwriting. Commit your work
##   first anyway. This rewrites source files.
##
## LIMITS
##   Refuses any file with an inner class below its first function, because the
##   parser only understands top-level functions.


# STEP 1: point this at the script you want sorted.
const TARGET := "res://Levels/StageTutorial/tutorial_ui.gd"
# STEP 2: true prints the result only. false writes the file.
const DRY_RUN := false
# STEP 3: focus THIS script in the editor and press Ctrl+Shift+X.

const MAKE_BACKUP := true
const VERIFY := true

const ENGINE_CALLBACKS: Array[String] = [
	"_init", "_enter_tree", "_ready", "_exit_tree", "_notification",
	"_process", "_physics_process",
	"_input", "_unhandled_input", "_unhandled_key_input", "_shortcut_input",
	"_gui_input", "_draw",
	"_get_configuration_warnings", "_validate_property",
	"_get", "_set", "_get_property_list",
	"_property_can_revert", "_property_get_revert",
	"_get_minimum_size", "_has_point", "_make_custom_tooltip",
	"_get_drag_data", "_can_drop_data", "_drop_data",
	"_integrate_forces", "_to_string",
]


func _run() -> void:
	_banner()

	var text := _read(TARGET)
	if text.is_empty():
		return

	var lines := text.split("\n")

	var first_func := _find_first_function(lines)
	if first_func < 0:
		push_warning("No top-level functions found in %s" % TARGET)
		return

	if _has_inner_class(lines, first_func):
		push_error("%s contains an inner class below its first function. Sort it by hand, this tool would break it." % TARGET)
		return

	# Doc comments sitting directly above the first function belong to it,
	# not to the header, so walk back over them.
	var header_end := first_func
	while header_end > 0 and _is_comment(lines[header_end - 1]):
		header_end -= 1

	var header := _join(lines, 0, header_end)
	var blocks := _split_into_blocks(lines, header_end)

	var callbacks: Array[Dictionary] = []
	var public: Array[Dictionary] = []
	var private: Array[Dictionary] = []

	for block: Dictionary in blocks:
		var fn_name := block["name"] as String
		if fn_name in ENGINE_CALLBACKS:
			callbacks.append(block)
		elif fn_name.begins_with("_"):
			private.append(block)
		else:
			public.append(block)

	callbacks.sort_custom(_by_name)
	public.sort_custom(_by_name)
	private.sort_custom(_by_name)

	var sorted_blocks: Array[Dictionary] = []
	sorted_blocks.append_array(callbacks)
	sorted_blocks.append_array(public)
	sorted_blocks.append_array(private)

	_head(1, "Summary")
	print("  header lines:     %d" % header.split("\n").size())
	print("  functions found:  %d" % blocks.size())
	print("  engine callbacks: %d" % callbacks.size())
	print("  public:           %d" % public.size())
	print("  private:          %d" % private.size())

	if not _report(blocks, sorted_blocks):
		_head(6, "Result")
		print("  FAILED at the name check. Nothing written.")
		print("=".repeat(80))
		return

	var out := header.strip_edges(false, true)
	out += "\n\n"
	out += _section("Engine callbacks", callbacks)
	out += _section("Public", public)
	out += _section("Private", private)
	out = out.strip_edges(false, true) + "\n"

	_head(5, "Body verification")
	if VERIFY:
		if not _verify(header, blocks, out):
			_head(6, "Result")
			print("  FAILED verification. Nothing written.")
			print("=".repeat(80))
			return
		print("  header identical, %d function bodies unchanged: PASS" % blocks.size())
	else:
		print("  skipped, VERIFY is false")

	_head(6, "Result")
	if DRY_RUN:
		print("  DRY RUN. Nothing written. Sorted file follows.")
		print("=".repeat(80))
		print(out)
		print("=".repeat(80))
		print("END OF RUN")
		print("=".repeat(80))
		return

	if MAKE_BACKUP:
		_write(TARGET + ".bak", text)
	_write(TARGET, out)
	print("  WRITTEN to %s" % TARGET)
	print("  backup at  %s.bak" % TARGET)
	EditorInterface.get_resource_filesystem().scan()
	print("=".repeat(80))
	print("END OF RUN")
	print("=".repeat(80))

# --- Parsing -----------------------------------------------------------------

## A top-level function starts at column zero. Anything indented belongs to an
## inner class or is a syntax error, and either way we do not touch it.
func _find_first_function(lines: PackedStringArray) -> int:
	for index: int in lines.size():
		if _is_function_start(lines[index]):
			return index
	return -1


func _is_function_start(line: String) -> bool:
	return line.begins_with("func ") or line.begins_with("static func ")


func _is_comment(line: String) -> bool:
	var trimmed := line.strip_edges()
	return trimmed.begins_with("#") or trimmed.begins_with("@")


func _has_inner_class(lines: PackedStringArray, from: int) -> bool:
	for index: int in range(from, lines.size()):
		if lines[index].begins_with("class "):
			return true
	return false


## Each block is one function plus any comment lines directly above it.
func _split_into_blocks(lines: PackedStringArray, from: int) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var starts: Array[int] = []

	for index: int in range(from, lines.size()):
		if _is_function_start(lines[index]):
			var start := index
			while start > from and _is_comment(lines[start - 1]):
				start -= 1
			starts.append(start)

	for position: int in starts.size():
		var start: int = starts[position]
		var end: int = starts[position + 1] if position + 1 < starts.size() else lines.size()
		var body := _join(lines, start, end).strip_edges(false, true)
		blocks.append({
			"name": _function_name(lines, start),
			"body": body,
		})

	return blocks


func _function_name(lines: PackedStringArray, start: int) -> String:
	for index: int in range(start, lines.size()):
		if _is_function_start(lines[index]):
			var after := lines[index].replace("static func ", "").replace("func ", "")
			var bracket := after.find("(")
			return after.substr(0, bracket).strip_edges() if bracket > 0 else after.strip_edges()
	return ""


func _by_name(a: Dictionary, b: Dictionary) -> bool:
	return (a["name"] as String) < (b["name"] as String)


func _category(fn_name: String) -> String:
	if fn_name in ENGINE_CALLBACKS:
		return "callback"
	if fn_name.begins_with("_"):
		return "private"
	return "public"


# --- Output ------------------------------------------------------------------

func _section(title: String, blocks: Array[Dictionary]) -> String:
	if blocks.is_empty():
		return ""
	var rule := "# --- %s " % title
	while rule.length() < 79:
		rule += "-"
	var out := rule + "\n\n"
	for block: Dictionary in blocks:
		out += (block["body"] as String) + "\n\n\n"
	return out


func _join(lines: PackedStringArray, from: int, to: int) -> String:
	var slice := PackedStringArray()
	for index: int in range(from, to):
		slice.append(lines[index])
	return "\n".join(slice)


# --- Report ------------------------------------------------------------------

## Prints the before and after lists, then a name-by-name comparison. Order is
## expected to differ; membership is not. Anything missing on either side is a
## bug in this tool, not a style choice.
## Prints the before and after lists, then a name-by-name comparison. Order is
## expected to differ; membership is not. Anything missing on either side is a
## bug in this tool, not a style choice.
func _report(original: Array[Dictionary], sorted_blocks: Array[Dictionary]) -> bool:
	_head(2, "Old function list, file order")
	for index: int in original.size():
		var fn_name := original[index]["name"] as String
		print("  %2d. [%-8s] %s" % [index + 1, _category(fn_name), fn_name])

	_head(3, "New function list, sorted order")
	for index: int in sorted_blocks.size():
		var fn_name := sorted_blocks[index]["name"] as String
		print("  %2d. [%-8s] %s" % [index + 1, _category(fn_name), fn_name])

	var old_names := PackedStringArray()
	for block: Dictionary in original:
		old_names.append(block["name"] as String)
	var new_names := PackedStringArray()
	for block: Dictionary in sorted_blocks:
		new_names.append(block["name"] as String)

	var every_name := PackedStringArray()
	for fn_name: String in old_names:
		if not every_name.has(fn_name):
			every_name.append(fn_name)
	for fn_name: String in new_names:
		if not every_name.has(fn_name):
			every_name.append(fn_name)
	every_name.sort()

	_head(4, "Name check")
	print("  %-34s %-7s %-7s %s" % ["function", "in OLD", "in NEW", "result"])
	print("  " + "-".repeat(60))

	var passed := true
	for fn_name: String in every_name:
		var in_old := _count(old_names, fn_name)
		var in_new := _count(new_names, fn_name)
		var ok := in_old == 1 and in_new == 1
		if not ok:
			passed = false
		print("  %-34s %-7s %-7s %s" % [
			fn_name,
			"yes" if in_old == 1 else str(in_old),
			"yes" if in_new == 1 else str(in_new),
			"OK" if ok else "MISMATCH",
		])

	print("  " + "-".repeat(60))
	print("  RESULT: %s" % ("PASS" if passed else "FAIL"))
	return passed


func _count(names: PackedStringArray, wanted: String) -> int:
	var total := 0
	for fn_name: String in names:
		if fn_name == wanted:
			total += 1
	return total


# --- Verification ------------------------------------------------------------

## Re-parses our own output and proves it carries the same header and the same
## function bodies as the input. Order is allowed to differ. Anything else is a
## bug in this tool, and we refuse to write.
func _verify(header: String, original: Array[Dictionary], out: String) -> bool:
	var out_lines := out.split("\n")

	var first_func := _find_first_function(out_lines)
	if first_func < 0:
		print("[SORT] VERIFY FAIL: output has no functions at all")
		return false

	# Step back over this tool's own section rules and the blank lines around
	# them, as well as any doc comment attached to the first function.
	var out_header_end := first_func
	while out_header_end > 0:
		var previous := out_lines[out_header_end - 1].strip_edges()
		if previous.is_empty() or previous.begins_with("#") or previous.begins_with("@"):
			out_header_end -= 1
		else:
			break

	var out_header := _join(out_lines, 0, out_header_end)
	var want := header.strip_edges(false, true)
	var got := out_header.strip_edges(false, true)
	if want != got:
		print("[SORT] VERIFY FAIL: header changed")
		print("  original header lines: ", want.split("\n").size())
		print("  output   header lines: ", got.split("\n").size())
		_show_first_difference(want, got)
		return false

	var produced := _split_into_blocks(out_lines, out_header_end)
	if produced.size() != original.size():
		print("[SORT] VERIFY FAIL: function count changed, %d in, %d out" % [original.size(), produced.size()])
		return false

	var by_name: Dictionary = {}
	for block: Dictionary in produced:
		var fn_name := block["name"] as String
		if by_name.has(fn_name):
			print("[SORT] VERIFY FAIL: duplicate function in output: %s" % fn_name)
			return false
		by_name[fn_name] = _normalise(block["body"] as String)

	for block: Dictionary in original:
		var fn_name := block["name"] as String
		if not by_name.has(fn_name):
			print("[SORT] VERIFY FAIL: function lost: %s" % fn_name)
			return false
		if by_name[fn_name] != _normalise(block["body"] as String):
			print("[SORT] VERIFY FAIL: body changed: %s" % fn_name)
			_show_first_difference(_normalise(block["body"] as String), by_name[fn_name])
			return false

	return true


## Section rules are added by this tool, so they do not count as a body change.
## Trailing whitespace is normalised because the writer re-spaces the file.
func _normalise(body: String) -> String:
	var kept := PackedStringArray()
	for line: String in body.split("\n"):
		if line.begins_with("# --- "):
			continue
		kept.append(line)
	return "\n".join(kept).strip_edges()


## Prints the first line where two texts diverge, so a failure names itself
## instead of leaving you to diff two hundred lines by eye.
func _show_first_difference(want: String, got: String) -> void:
	var a := want.split("\n")
	var b := got.split("\n")
	var limit: int = mini(a.size(), b.size())
	for index: int in limit:
		if a[index] != b[index]:
			print("  first difference at line %d" % (index + 1))
			print("    original: '%s'" % a[index])
			print("    output:   '%s'" % b[index])
			return
	if a.size() != b.size():
		print("  identical up to line %d, then lengths differ: %d vs %d" % [limit, a.size(), b.size()])
	else:
		print("  no line difference found, so the mismatch is trailing whitespace")


# --- Files -------------------------------------------------------------------

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(text)
	file.close()

# --- Console layout ----------------------------------------------------------

func _banner() -> void:
	print("")
	print("=".repeat(80))
	print("SORT FUNCTIONS  |  %s" % Time.get_datetime_string_from_system(false, true))
	print("TARGET: %s" % TARGET)
	print("MODE:   %s" % ("DRY RUN, nothing will be written" if DRY_RUN else "LIVE, the file will be overwritten"))
	print("=".repeat(80))
	print("CONTENTS")
	print("  1. Summary")
	print("  2. OLD function list, file order")
	print("  3. NEW function list, sorted order")
	print("  4. Name check")
	print("  5. Body verification")
	print("  6. Result")
	print("=".repeat(80))


func _head(index: int, title: String) -> void:
	print("")
	print("[%d] %s" % [index, title.to_upper()])
	print("-".repeat(80))
