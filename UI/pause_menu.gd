extends MenuScreen

func close_menu()->void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),0.0)
	super()
