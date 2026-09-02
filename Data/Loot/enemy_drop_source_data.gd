class_name EnemyDropSourceData
extends Resource


@export_group("Drops")
## Independent drop tables owned by this enemy. More than one table can apply
## to the same level, for example a boss reward table plus a coin table.
@export var drop_tables: Array[EnemyDropTableData] = []


func get_drop_tables_for_level(level_id: StringName) -> Array[EnemyDropTableData]:
	var matching_tables: Array[EnemyDropTableData] = []
	for table: EnemyDropTableData in drop_tables:
		if table != null and table.applies_to(level_id):
			matching_tables.append(table)
	return matching_tables
