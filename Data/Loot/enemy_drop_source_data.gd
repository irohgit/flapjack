class_name EnemyDropSourceData
extends Resource


@export_group("Loot")
## Flat JSON array containing this enemy's drops.
@export var loot: JSON


func get_loot_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if loot == null:
		return rows
	if not loot.data is Array:
		push_error("Enemy loot JSON must contain an array: %s" % loot.resource_path)
		return rows

	for row_index: int in loot.data.size():
		var row: Variant = loot.data[row_index]
		if not row is Dictionary:
			push_error(
				"Enemy loot row %d must be an object: %s"
				% [row_index, loot.resource_path]
			)
			continue
		rows.append(row)
	return rows


func get_loot_path() -> String:
	return loot.resource_path if loot != null else ""
