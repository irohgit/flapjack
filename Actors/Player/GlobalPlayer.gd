extends Node

var weapons: Array[WeaponData] = []
var _weapon_states: Array[WeaponState] = []

func read_from_player(player: Player):
	weapons = player.weapons
	_weapon_states = player._weapon_states
	
func write_to_player(player: Player):
	player.weapons = weapons
	player._weapon_states = _weapon_states
