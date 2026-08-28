extends Node

var _checkpoint: RunCheckpoint

var has_checkpoint: bool:
	get:
		return _checkpoint != null


func reset_run() -> void:
	_checkpoint = null


func capture_checkpoint(player: Player) -> void:
	if player == null:
		return
	_checkpoint = player.export_checkpoint()


func restore_checkpoint(player: Player) -> bool:
	if player == null or _checkpoint == null:
		return false
	return player.import_checkpoint(_checkpoint)
