class_name LootRegistry
extends RefCounted


const PICKUP_DIRECTORY := "res://Data/Pickups"


static func build() -> Dictionary:
	var pickups_by_id: Dictionary = {}
	var duplicate_ids: Dictionary = {}
	_scan_directory(PICKUP_DIRECTORY, pickups_by_id, duplicate_ids)
	return pickups_by_id


static func _scan_directory(
	directory_path: String,
	pickups_by_id: Dictionary,
	duplicate_ids: Dictionary
) -> void:
	for entry_name: String in ResourceLoader.list_directory(directory_path):
		if entry_name.ends_with("/"):
			_scan_directory(
				directory_path.path_join(entry_name.trim_suffix("/")),
				pickups_by_id,
				duplicate_ids
			)
			continue
		if not entry_name.ends_with(".tres"):
			continue

		var resource_path := directory_path.path_join(entry_name)
		var pickup := ResourceLoader.load(resource_path) as PickupData
		if pickup == null:
			continue
		if pickup.item_id.is_empty():
			push_error("Pickup is missing item_id: %s" % resource_path)
			continue
		if duplicate_ids.has(pickup.item_id):
			push_error("Pickup item_id remains duplicated: %s" % pickup.item_id)
			continue
		if pickups_by_id.has(pickup.item_id):
			var existing := pickups_by_id[pickup.item_id] as PickupData
			push_error(
				"Duplicate pickup item_id '%s': %s and %s"
				% [pickup.item_id, existing.resource_path, resource_path]
			)
			pickups_by_id.erase(pickup.item_id)
			duplicate_ids[pickup.item_id] = true
			continue
		pickups_by_id[pickup.item_id] = pickup
