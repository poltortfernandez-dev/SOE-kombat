extends RefCounted

# Quick Tunnels forwards just the game's loopback WebSocket listener.
var pid := -1
var log_path := ""
var config_path := ""
var poll_delay := 0.0

func executable() -> String:
	var system := OS.get_name()
	var helpers := {"macOS":"macos","Linux":"linux-amd64","Windows":"windows-amd64.exe"}
	if not helpers.has(system):
		return ""
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://tools/room/" + str(helpers[system]))
	var folder := OS.get_executable_path().get_base_dir()
	if system == "macOS":
		return folder.path_join("../Helpers/cloudflared").simplify_path()
	return folder.path_join("dojo-room.exe" if system == "Windows" else "dojo-room")

func start(port: int) -> bool:
	var binary := executable()
	if binary.is_empty() or not FileAccess.file_exists(binary):
		return false
	var unique := Crypto.new().generate_random_bytes(10).hex_encode()
	var base := OS.get_cache_dir().path_join("combpov-" + unique)
	log_path = base + ".log"
	config_path = base + ".yml"
	var config := FileAccess.open(config_path,FileAccess.WRITE)
	if config == null:
		return false
	config.store_string("{}\n")
	config.close()
	pid = OS.create_process(binary,["tunnel","--config",config_path,"--no-autoupdate",
		"--metrics","127.0.0.1:0","--logfile",log_path,
		"--url","http://127.0.0.1:%d" % port])
	return pid > 0

func ready_slug(dt: float) -> String:
	poll_delay -= dt
	if poll_delay > 0:
		return ""
	poll_delay = 0.25
	var file := FileAccess.open(log_path,FileAccess.READ)
	if file == null:
		return ""
	var raw := file.get_buffer(mini(file.get_length(),131072)).get_string_from_utf8()
	if not raw.contains("Registered tunnel connection"):
		return ""
	var pattern := RegEx.new()
	pattern.compile("https://([a-z0-9-]{1,63})\\.trycloudflare\\.com")
	var hit := pattern.search(raw)
	return hit.get_string(1) if hit else ""

func stop() -> void:
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	pid = -1
	for path in [log_path,config_path]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	log_path = ""
	config_path = ""
