@tool
extends SceneTree

func _init():
	# Load export presets and check for configuration issues
	var config = ConfigFile.new()
	var err = config.load("res://export_presets.cfg")
	if err != OK:
		print("ERROR: Cannot load export_presets.cfg: ", err)
		quit(1)
		return

	print("=== Export Preset Diagnostic ===")
	print("Preset name: ", config.get_value("preset.0", "name", "MISSING"))
	print("Platform: ", config.get_value("preset.0", "platform", "MISSING"))

	# Check all options
	print("\n=== Preset 0 Options ===")
	if config.has_section("preset.0.options"):
		for key in config.get_section_keys("preset.0.options"):
			print("  ", key, " = ", config.get_value("preset.0.options", key))

	# Try to get export platform info
	print("\n=== Template Check ===")
	var templates_path = OS.get_data_dir().path_join("export_templates/4.6.1.stable")
	print("Templates dir: ", templates_path)

	var dir = DirAccess.open(templates_path)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if "web" in fname.to_lower():
				print("  Found: ", fname)
			fname = dir.get_next()
	else:
		print("  ERROR: Cannot open templates directory!")

	# Check main scene
	print("\n=== Project Checks ===")
	var main_scene = ProjectSettings.get_setting("application/run/main_scene", "")
	print("Main scene: ", main_scene)
	print("Main scene exists: ", FileAccess.file_exists(main_scene) if main_scene else false)

	# Check renderer
	var renderer = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	print("Renderer: ", renderer)

	# Check if icon exists
	var icon = ProjectSettings.get_setting("application/config/icon", "")
	print("Icon: ", icon)
	print("Icon exists: ", FileAccess.file_exists(icon) if icon else false)

	print("\n=== Done ===")
	quit(0)
