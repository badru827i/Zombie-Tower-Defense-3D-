extends Node3D

const GRID_W := 12
const GRID_H := 8
const TILE_SIZE := 1.5
const PATH_CELLS: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(3, 4), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(7, 3),
	Vector2i(8, 3), Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5),
	Vector2i(10, 5), Vector2i(11, 5)
]
const WEAPONS := {
	"Sentry": {"damage": 20.0, "range": 6.0, "cooldown": 0.8, "color": Color(0.2, 0.8, 1.0), "cost": 50},
	"Heavy Cannon": {"damage": 100.0, "range": 8.0, "cooldown": 2.2, "color": Color(1.0, 0.55, 0.15), "cost": 140},
	"Gatling": {"damage": 8.0, "range": 7.0, "cooldown": 0.16, "color": Color(1.0, 0.85, 0.2), "cost": 110},
	"Rocket": {"damage": 80.0, "range": 10.0, "cooldown": 2.0, "color": Color(1.0, 0.25, 0.2), "cost": 180},
	"Tesla": {"damage": 25.0, "range": 6.0, "cooldown": 0.55, "color": Color(0.7, 0.35, 1.0), "cost": 160}
}
const ZOMBIE_TYPES := {
	"Walker": {"hp": 70.0, "speed": 1.2, "reward": 10, "color": Color(0.35, 0.8, 0.35)},
	"Runner": {"hp": 45.0, "speed": 2.5, "reward": 12, "color": Color(0.9, 0.85, 0.25)},
	"Armored": {"hp": 220.0, "speed": 0.75, "reward": 20, "color": Color(0.45, 0.5, 0.58)},
	"Toxic": {"hp": 130.0, "speed": 1.0, "reward": 18, "color": Color(0.2, 0.9, 0.45)},
	"Mutant Boss": {"hp": 1600.0, "speed": 0.55, "reward": 150, "color": Color(0.75, 0.15, 0.2)}
}

var selected_weapon := "Sentry"
var money := 350
var base_health := 20
var episode := 1
var wave := 1
var spawn_timer := 0.0
var enemies_to_spawn := 0
var wave_active := false
var grid: Dictionary = {}
var turrets: Array[Dictionary] = []
var zombies: Array[Dictionary] = []
var hud: Label
var status_label: Label

func _ready() -> void:
	_make_environment()
	_make_arena()
	_make_hud()
	_start_wave()

func _process(delta: float) -> void:
	_update_zombies(delta)
	_update_turrets(delta)
	if wave_active:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and enemies_to_spawn > 0:
			_spawn_zombie()
			enemies_to_spawn -= 1
			spawn_timer = maxf(0.35, 1.15 - float(episode) * 0.006)
		if enemies_to_spawn <= 0 and zombies.is_empty():
			wave_active = false
			wave += 1
			if wave > 5:
				wave = 1
				episode = mini(100, episode + 1)
			money += 35
			status_label.text = "Wave cleared! +$35 • Tap START WAVE"
	_update_hud()

func _make_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.025, 0.04, 0.075)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.58, 0.75)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.25
	add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(8.25, 17.0, 11.0)
	camera.look_at(Vector3(8.25, 0, 5.25), Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.5
	add_child(camera)

func _make_arena() -> void:
	for z in range(GRID_H):
		for x in range(GRID_W):
			var cell := Vector2i(x, z)
			var tile := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(TILE_SIZE - 0.05, 0.12, TILE_SIZE - 0.05)
			tile.mesh = mesh
			tile.position = _cell_world(cell)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.08, 0.13, 0.19) if (x + z) % 2 == 0 else Color(0.10, 0.16, 0.22)
			mat.roughness = 0.85
			if PATH_CELLS.has(cell):
				mat.albedo_color = Color(0.26, 0.18, 0.13)
			tile.material_override = mat
			add_child(tile)
			grid[cell] = null
	for cell in PATH_CELLS:
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.03, 0.12)
		marker.mesh = box
		marker.position = _cell_world(cell) + Vector3(0, 0.09, 0)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.55, 0.18)
		m.emission_enabled = true
		m.emission = Color(0.7, 0.18, 0.03)
		marker.material_override = m
		add_child(marker)

func _make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(310, 0)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 18)
	column.add_child(hud)
	var selector := OptionButton.new()
	for weapon_name in WEAPONS.keys():
		selector.add_item("%s ($%d)" % [weapon_name, WEAPONS[weapon_name]["cost"]])
	selector.item_selected.connect(func(index: int) -> void:
		selected_weapon = WEAPONS.keys()[index]
	)
	column.add_child(selector)
	var place_button := Button.new()
	place_button.text = "PLACE MODE: tap empty tile"
	place_button.pressed.connect(func() -> void:
		status_label.text = "Selected %s — tap a free tile." % selected_weapon
	)
	column.add_child(place_button)
	var wave_button := Button.new()
	wave_button.text = "START WAVE"
	wave_button.pressed.connect(_start_wave)
	column.add_child(wave_button)
	var save_button := Button.new()
	save_button.text = "SAVE PROGRESS"
	save_button.pressed.connect(_save_progress)
	column.add_child(save_button)
	status_label = Label.new()
	status_label.text = "Choose a turret, then tap a free grid tile."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return
		var origin := camera.project_ray_origin(event.position)
		var direction := camera.project_ray_normal(event.position)
		if absf(direction.y) < 0.0001:
			return
		var distance := -origin.y / direction.y
		if distance < 0:
			return
		var hit := origin + direction * distance
		var cell := Vector2i(roundi(hit.x / TILE_SIZE), roundi(hit.z / TILE_SIZE))
		if cell.x < 0 or cell.y < 0 or cell.x >= GRID_W or cell.y >= GRID_H:
			return
		_place_turret(cell)

func _place_turret(cell: Vector2i) -> void:
	if PATH_CELLS.has(cell):
		status_label.text = "Blocked: zombies need this path."
		return
	if grid[cell] != null:
		status_label.text = "This tile already has a turret."
		return
	var data: Dictionary = WEAPONS[selected_weapon]
	if money < int(data["cost"]):
		status_label.text = "Not enough cash for %s." % selected_weapon
		return
	money -= int(data["cost"])
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.25
	mesh.bottom_radius = 0.42
	mesh.height = 0.55
	mesh_node.mesh = mesh
	mesh_node.position = _cell_world(cell) + Vector3(0, 0.42, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["color"]
	mat.metallic = 0.55
	mat.roughness = 0.3
	mesh_node.material_override = mat
	add_child(mesh_node)
	var turret := {"cell": cell, "position": _cell_world(cell), "node": mesh_node, "type": selected_weapon, "level": 1, "cooldown": 0.0}
	turrets.append(turret)
	grid[cell] = turret
	status_label.text = "%s placed. Upgrade interaction is next milestone." % selected_weapon

func _update_turrets(delta: float) -> void:
	for turret in turrets:
		turret["cooldown"] = float(turret["cooldown"]) - delta
		if float(turret["cooldown"]) > 0:
			continue
		var data: Dictionary = WEAPONS[turret["type"]]
		var target: Dictionary = {}
		var nearest := INF
		for zombie in zombies:
			var d: float = turret["position"].distance_to(zombie["position"])
			if d <= float(data["range"]) and d < nearest:
				nearest = d
				target = zombie
		if not target.is_empty():
			var level_multiplier := 1.0 + 0.35 * (int(turret["level"]) - 1)
			target["hp"] = float(target["hp"]) - float(data["damage"]) * level_multiplier
			turret["cooldown"] = float(data["cooldown"])
			if float(target["hp"]) <= 0.0:
				money += int(target["reward"])
				_remove_zombie(target)

func _update_zombies(delta: float) -> void:
	for zombie in zombies.duplicate():
		var path_index: int = zombie["path_index"]
		var progress: float = float(zombie["progress"]) + float(zombie["speed"]) * delta / TILE_SIZE
		while progress >= 1.0:
			path_index += 1
			progress -= 1.0
		if path_index >= PATH_CELLS.size():
			base_health -= 1
			_remove_zombie(zombie)
			if base_health <= 0:
				status_label.text = "BASE LOST — restart the game to try again."
			continue
		zombie["path_index"] = path_index
		zombie["progress"] = progress
		var a := _cell_world(PATH_CELLS[path_index])
		var b := _cell_world(PATH_CELLS[mini(path_index + 1, PATH_CELLS.size() - 1)])
		zombie["position"] = a.lerp(b, progress)
		(zombie["node"] as Node3D).position = zombie["position"] + Vector3(0, 0.35, 0)

func _spawn_zombie() -> void:
	var type_name := "Walker"
	if episode >= 100 and wave == 5:
		type_name = "Mutant Boss"
	elif episode >= 31 and wave == 4:
		type_name = "Toxic"
	elif episode >= 21 and wave == 3:
		type_name = "Armored"
	elif episode >= 11 and wave == 2:
		type_name = "Runner"
	var data: Dictionary = ZOMBIE_TYPES[type_name]
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28 if type_name != "Mutant Boss" else 0.62
	mesh.height = 0.8 if type_name != "Mutant Boss" else 1.5
	body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["color"]
	body.material_override = mat
	add_child(body)
	body.position = _cell_world(PATH_CELLS[0]) + Vector3(0, 0.35, 0)
	zombies.append({"node": body, "position": _cell_world(PATH_CELLS[0]), "path_index": 0, "progress": 0.0, "hp": float(data["hp"]) * (1.0 + float(episode - 1) * 0.04), "speed": float(data["speed"]), "reward": data["reward"]})

func _start_wave() -> void:
	if wave_active:
		return
	enemies_to_spawn = mini(6 + episode, 30) if wave < 5 else mini(10 + episode, 40)
	spawn_timer = 0.25
	wave_active = true
	status_label.text = "Episode %d • Wave %d incoming!" % [episode, wave]

func _cell_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, 0, cell.y * TILE_SIZE)

func _remove_zombie(zombie: Dictionary) -> void:
	if zombies.has(zombie):
		zombies.erase(zombie)
		if is_instance_valid(zombie["node"]):
			(zombie["node"] as Node3D).queue_free()

func _update_hud() -> void:
	hud.text = "ZOMBIE DEFENSE 3D\nEpisode %d/100 • Wave %d/5\nCash: $%d   Base HP: %d\nTurrets: %d   Enemies: %d" % [episode, wave, money, base_health, turrets.size(), zombies.size()]

func _save_progress() -> void:
	var data := {"episode": episode, "wave": wave, "money": money, "base_health": base_health}
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		status_label.text = "Progress saved locally on this device."
