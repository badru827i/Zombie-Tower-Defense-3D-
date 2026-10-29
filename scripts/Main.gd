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
var forest_props: Array[Dictionary] = []
var cull_timer := 0.0
var hud: Label
var status_label: Label
var hud_layer: CanvasLayer
var menu_layer: CanvasLayer
var menu_root: Control
var settings_root: Control
var settings_panel: PanelContainer
var game_started := false
var graphics_quality := "Medium"
var master_volume := 0.8
var sfx_volume := 0.8
var music_volume := 0.55
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var world_environment: Environment
var cull_distance := 24.0

func _ready() -> void:
	_load_settings()
	_load_progress()
	_ensure_audio_buses()
	_make_environment()
	_make_arena()
	_make_forest_decor()
	_make_hud()
	_make_main_menu()
	_apply_graphics_quality()
	_apply_audio_settings()
	_play_ambient_music()

func _process(delta: float) -> void:
	_update_zombies(delta)
	_update_turrets(delta)
	cull_timer += delta
	if cull_timer >= 0.35:
		cull_timer = 0.0
		_update_forest_culling()
	if wave_active:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and enemies_to_spawn > 0:
			_spawn_zombie()
			enemies_to_spawn -= 1
			spawn_timer = maxf(0.35, 1.15 - float(episode) * 0.006)
		if enemies_to_spawn <= 0 and zombies.is_empty():
			wave_active = false
			money += 35
			if wave < 5:
				wave += 1
				status_label.text = "Wave cleared! +$35 • Next: Wave %d" % wave
			elif episode >= 100:
				status_label.text = "CAMPAIGN COMPLETE — Episode 100 defeated!"
				_save_progress()
				_show_main_menu()
			else:
				episode += 1
				wave = 1
				status_label.text = "Episode %d unlocked! +$35 • Prepare your defenses." % episode
				_save_progress()
			_update_hud()
	_update_hud()

func _make_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.025, 0.04, 0.075)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.58, 0.75)
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color(0.055, 0.075, 0.09)
	e.fog_density = 0.018
	env.environment = e
	world_environment = e
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


func _make_forest_decor() -> void:
	# Locally generated low-poly forest props: no map download or remote assets.
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.12, 0.075, 0.055)
	trunk_mat.roughness = 1.0
	var leaf_mats: Array[StandardMaterial3D] = []
	for color in [Color(0.025, 0.09, 0.065), Color(0.035, 0.12, 0.075), Color(0.07, 0.13, 0.075)]:
		var leaf := StandardMaterial3D.new()
		leaf.albedo_color = color
		leaf.roughness = 1.0
		leaf_mats.append(leaf)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.12, 0.14, 0.14)
	rock_mat.roughness = 1.0
	var blood_mat := StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.28, 0.008, 0.018)
	blood_mat.roughness = 0.3

	# Trees form a forest border, keeping turret cells and the zombie route readable.
	var rng := RandomNumberGenerator.new()
	rng.seed = 74129
	for i in range(42):
		var side := i % 4
		var x := 0.0
		var z := 0.0
		match side:
			0:
				x = rng.randf_range(-2.0, GRID_W * TILE_SIZE + 2.0)
				z = rng.randf_range(-2.8, -1.6)
			1:
				x = rng.randf_range(-2.0, GRID_W * TILE_SIZE + 2.0)
				z = GRID_H * TILE_SIZE + rng.randf_range(1.6, 2.8)
			2:
				x = rng.randf_range(-2.8, -1.6)
				z = rng.randf_range(0.0, GRID_H * TILE_SIZE)
			3:
				x = GRID_W * TILE_SIZE + rng.randf_range(1.6, 2.8)
				z = rng.randf_range(0.0, GRID_H * TILE_SIZE)
		var tree := Node3D.new()
		tree.position = Vector3(x, 0.0, z)
		add_child(tree)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.12
		trunk_mesh.bottom_radius = 0.22
		trunk_mesh.height = rng.randf_range(1.8, 2.8)
		trunk.mesh = trunk_mesh
		trunk.position.y = trunk_mesh.height * 0.5
		trunk.material_override = trunk_mat
		tree.add_child(trunk)
		for crown_index in range(2):
			var crown := MeshInstance3D.new()
			var crown_mesh := SphereMesh.new()
			crown_mesh.radius = rng.randf_range(0.65, 1.0)
			crown_mesh.height = crown_mesh.radius * 1.7
			crown.mesh = crown_mesh
			crown.position = Vector3(0, trunk_mesh.height * 0.65 + crown_index * 0.48, 0)
			crown.scale = Vector3(1.0, 1.25, 1.0)
			crown.material_override = leaf_mats[rng.randi_range(0, leaf_mats.size() - 1)]
			tree.add_child(crown)
		forest_props.append({"node": tree, "position": Vector2(x, z), "kind": "tree"})

	# Scattered rocks at the forest edge.
	for i in range(18):
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = rng.randf_range(0.22, 0.48)
		rock_mesh.height = rock_mesh.radius * 1.2
		rock.mesh = rock_mesh
		var edge_x := rng.randf_range(-1.8, GRID_W * TILE_SIZE + 1.8)
		var edge_z := -1.15 if i % 2 == 0 else GRID_H * TILE_SIZE + 1.15
		rock.position = Vector3(edge_x, rock_mesh.radius * 0.35, edge_z)
		rock.scale = Vector3(1.3, 0.65, 0.9)
		rock.material_override = rock_mat
		add_child(rock)
		forest_props.append({"node": rock, "position": Vector2(edge_x, edge_z), "kind": "rock"})

	# Stylized blood marks along the dirt route; these are flat decals made from meshes.
	for i in range(13):
		var path_cell: Vector2i = PATH_CELLS[mini(i + 2, PATH_CELLS.size() - 1)]
		var stain := MeshInstance3D.new()
		var stain_mesh := CylinderMesh.new()
		stain_mesh.top_radius = rng.randf_range(0.12, 0.23)
		stain_mesh.bottom_radius = stain_mesh.top_radius
		stain_mesh.height = 0.012
		stain.mesh = stain_mesh
		stain.position = _cell_world(path_cell) + Vector3(rng.randf_range(-0.35, 0.35), 0.075, rng.randf_range(-0.35, 0.35))
		stain.scale = Vector3(1.4, 1.0, 0.65)
		stain.material_override = blood_mat
		add_child(stain)

func _update_forest_culling() -> void:
	# Keep nearby scenery active; distant props are hidden. The camera still renders
	# only what is in its view. This is distance culling, not map downloading.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var camera_xz := Vector2(camera.global_position.x, camera.global_position.z)
	for prop in forest_props:
		var node := prop["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var prop_pos: Vector2 = prop["position"]
		var distance := camera_xz.distance_to(prop_pos)
		node.visible = distance <= cull_distance

func _make_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.visible = false
	add_child(hud_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(330, 0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	hud_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var hud_title := Label.new()
	hud_title.text = "NIGHTFALL  //  DEFENSE"
	hud_title.add_theme_font_size_override("font_size", 19)
	hud_title.add_theme_color_override("font_color", Color(0.45, 0.82, 1.0))
	column.add_child(hud_title)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 16)
	column.add_child(hud)
	var selector := OptionButton.new()
	for weapon_name in WEAPONS.keys():
		selector.add_item("%s ($%d)" % [weapon_name, WEAPONS[weapon_name]["cost"]])
	selector.item_selected.connect(func(index: int) -> void:
		selected_weapon = WEAPONS.keys()[index]
	)
	column.add_child(selector)
	var place_button := Button.new()
	place_button.text = "BUILD TURRET  •  TAP EMPTY TILE"
	_style_button(place_button)
	place_button.pressed.connect(func() -> void:
		status_label.text = "Selected %s — tap a free tile." % selected_weapon
	)
	column.add_child(place_button)
	var wave_button := Button.new()
	wave_button.text = "▶  START NEXT WAVE"
	_style_button(wave_button)
	wave_button.pressed.connect(_start_wave)
	column.add_child(wave_button)
	var save_button := Button.new()
	save_button.text = "SAVE PROGRESS"
	_style_button(save_button)
	save_button.pressed.connect(_save_progress)
	column.add_child(save_button)
	var menu_button := Button.new()
	menu_button.text = "Ⅱ  PAUSE / SETTINGS"
	_style_button(menu_button)
	menu_button.pressed.connect(_show_main_menu)
	column.add_child(menu_button)
	status_label = Label.new()
	status_label.text = "Choose a turret, then tap a free grid tile."
	status_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.91))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse works in desktop builds; ScreenTouch supports Android taps.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_board_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_board_tap(event.position)

func _handle_board_tap(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
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
		_upgrade_turret(grid[cell])
		return
	var data: Dictionary = WEAPONS[selected_weapon]
	if money < int(data["cost"]):
		status_label.text = "Not enough cash for %s." % selected_weapon
		return
	money -= int(data["cost"])
	var mesh_node := Node3D.new()
	mesh_node.position = _cell_world(cell)
	add_child(mesh_node)
	var turret := {"cell": cell, "position": _cell_world(cell), "node": mesh_node, "type": selected_weapon, "level": 1, "cooldown": 0.0}
	_rebuild_turret_visual(turret)
	turrets.append(turret)
	grid[cell] = turret
	status_label.text = "%s placed at Level 1. Tap it again to upgrade." % selected_weapon


func _rebuild_turret_visual(turret: Dictionary) -> void:
	# Rebuild the local 3D model on every upgrade so its silhouette changes by level.
	var root := turret["node"] as Node3D
	for child in root.get_children():
		child.queue_free()
	var level := int(turret["level"])
	var weapon_name: String = turret["type"]
	var weapon_data: Dictionary = WEAPONS[weapon_name]
	var accent: Color = weapon_data["color"]

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.15, 0.18).lerp(accent, 0.12 * float(level - 1))
	metal.metallic = 0.72
	metal.roughness = 0.34
	var weapon_mat := StandardMaterial3D.new()
	weapon_mat.albedo_color = accent
	weapon_mat.metallic = 0.48
	weapon_mat.roughness = 0.28
	var glow := StandardMaterial3D.new()
	glow.albedo_color = accent
	glow.emission_enabled = true
	glow.emission = accent * (0.45 + 0.18 * float(level - 1))

	# Heavy armored base grows at each tier.
	var base := CylinderMesh.new()
	base.top_radius = 0.27 + 0.025 * float(level - 1)
	base.bottom_radius = 0.43 + 0.035 * float(level - 1)
	base.height = 0.28 + 0.035 * float(level - 1)
	_add_turret_part(root, base, Vector3(0, 0.16, 0), metal)

	var head := BoxMesh.new()
	head.size = Vector3(0.42 + 0.08 * float(level - 1), 0.22 + 0.025 * float(level - 1), 0.42 + 0.08 * float(level - 1))
	_add_turret_part(root, head, Vector3(0, 0.39, 0), metal)

	# Additional armor plates make upgrades visibly change the silhouette.
	if level >= 2:
		for side in [-1.0, 1.0]:
			var plate := BoxMesh.new()
			plate.size = Vector3(0.13 + 0.025 * float(level - 2), 0.28 + 0.035 * float(level - 2), 0.34)
			_add_turret_part(root, plate, Vector3(side * (0.27 + 0.035 * float(level - 2)), 0.43, 0), weapon_mat)
	if level >= 4:
		var rear := BoxMesh.new()
		rear.size = Vector3(0.5, 0.16, 0.22)
		_add_turret_part(root, rear, Vector3(0, 0.53, 0.23), metal)
	if level == 5:
		var crown := SphereMesh.new()
		crown.radius = 0.16
		crown.height = 0.32
		_add_turret_part(root, crown, Vector3(0, 0.67, 0), glow)

	# Each weapon keeps its identity; barrels or energy cores grow with upgrades.
	if weapon_name == "Tesla":
		var core := SphereMesh.new()
		core.radius = 0.19 + 0.035 * float(level - 1)
		core.height = core.radius * 2.0
		_add_turret_part(root, core, Vector3(0, 0.66, -0.08), glow)
		if level >= 3:
			for side in [-1.0, 1.0]:
				var prong := CylinderMesh.new()
				prong.top_radius = 0.035
				prong.bottom_radius = 0.065
				prong.height = 0.38 + 0.05 * float(level - 3)
				_add_turret_part(root, prong, Vector3(side * 0.25, 0.69, -0.08), weapon_mat)
	else:
		var barrel_count := level if weapon_name == "Gatling" else (1 + int((level - 1) / 2))
		barrel_count = mini(barrel_count, 5)
		for barrel_index in range(barrel_count):
			var barrel := CylinderMesh.new()
			barrel.top_radius = 0.055 if weapon_name != "Heavy Cannon" else 0.09
			barrel.bottom_radius = barrel.top_radius * 1.25
			barrel.height = 0.52 + 0.10 * float(level - 1)
			var x_offset := (float(barrel_index) - float(barrel_count - 1) * 0.5) * 0.14
			_add_turret_part(root, barrel, Vector3(x_offset, 0.48, -0.32), weapon_mat, Vector3.ONE, Vector3(PI / 2.0, 0, 0))
		if weapon_name == "Rocket" and level >= 3:
			for side in [-1.0, 1.0]:
				var pod := BoxMesh.new()
				pod.size = Vector3(0.12, 0.16, 0.38 + 0.04 * float(level - 3))
				_add_turret_part(root, pod, Vector3(side * 0.28, 0.48, -0.12), metal)

	# Small glowing tier indicator: higher levels are easier to identify in RTS view.
	var indicator := SphereMesh.new()
	indicator.radius = 0.055 + 0.012 * float(level - 1)
	indicator.height = indicator.radius * 2.0
	_add_turret_part(root, indicator, Vector3(0, 0.82 + 0.025 * float(level - 1), 0.1), glow)

func _add_turret_part(parent: Node3D, mesh: Mesh, local_position: Vector3, material: Material, local_scale: Vector3 = Vector3.ONE, local_rotation: Vector3 = Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = local_position
	part.scale = local_scale
	part.rotation = local_rotation
	part.material_override = material
	parent.add_child(part)

func _upgrade_turret(turret: Dictionary) -> void:
	var level := int(turret["level"])
	if level >= 5:
		status_label.text = "%s is already max Level 5." % turret["type"]
		return
	var next_level := level + 1
	var cost := int(WEAPONS[turret["type"]]["cost"] * 0.55 * level)
	if money < cost:
		status_label.text = "Upgrade to Lv.%d costs $%d; not enough cash." % [next_level, cost]
		return
	money -= cost
	turret["level"] = next_level
	_rebuild_turret_visual(turret)
	status_label.text = "%s evolved to Level %d • Damage x%.2f." % [turret["type"], next_level, 1.0 + 0.35 * float(next_level - 1)]

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
				wave_active = false
				status_label.text = "BASE LOST — choose RESTART RUN from the menu."
				_show_main_menu()
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
	elif wave == 5:
		type_name = "Armored" if episode >= 15 else "Runner"
	elif wave == 4:
		type_name = "Toxic" if episode >= 8 else "Armored"
	elif wave == 3:
		type_name = "Armored" if episode >= 4 else "Runner"
	elif wave == 2:
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
	if not game_started:
		return
	if wave_active or base_health <= 0:
		return
	if episode >= 100 and wave == 5:
		enemies_to_spawn = 1
	else:
		enemies_to_spawn = mini(5 + episode + wave, 28) if wave < 5 else mini(9 + int(episode * 0.8), 38)
	spawn_timer = 0.25
	wave_active = true
	status_label.text = "EPISODE %d  •  WAVE %d incoming!" % [episode, wave]
	_play_sfx(220.0, 0.22)

func _cell_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, 0, cell.y * TILE_SIZE)

func _remove_zombie(zombie: Dictionary) -> void:
	if zombies.has(zombie):
		zombies.erase(zombie)
		if is_instance_valid(zombie["node"]):
			(zombie["node"] as Node3D).queue_free()

func _update_hud() -> void:
	hud.text = "ZOMBIE DEFENSE 3D\nEpisode %d/100 • Wave %d/5\nCash: $%d   Base HP: %d\nTurrets: %d   Enemies: %d" % [episode, wave, money, base_health, turrets.size(), zombies.size()]

func _load_progress() -> void:
	if not FileAccess.file_exists("user://savegame.json"):
		return
	var file := FileAccess.open("user://savegame.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		episode = clampi(int(parsed.get("episode", 1)), 1, 100)
		wave = clampi(int(parsed.get("wave", 1)), 1, 5)
		money = maxi(0, int(parsed.get("money", 350)))
		base_health = clampi(int(parsed.get("base_health", 20)), 0, 20)

func _save_progress() -> void:
	var data := {"episode": episode, "wave": wave, "money": money, "base_health": base_health}
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		if is_instance_valid(status_label):
			status_label.text = "Progress saved locally on this device."

func _make_main_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(menu_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.012, 0.02, 0.035, 0.96)
	menu_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(340, 0)
	stack.add_theme_constant_override("separation", 12)
	center.add_child(stack)
	var eyebrow := Label.new()
	eyebrow.text = "SURVIVAL STRATEGY  •  OFFLINE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(0.42, 0.75, 0.91))
	stack.add_child(eyebrow)
	var title := Label.new()
	title.text = "NIGHTFALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ZOMBIE TOWER DEFENSE 3D"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	stack.add_child(subtitle)
	var divider := HSeparator.new()
	stack.add_child(divider)
	var play_button := Button.new()
	play_button.text = "▶   PLAY / CONTINUE"
	play_button.custom_minimum_size = Vector2(0, 48)
	_style_button(play_button)
	play_button.pressed.connect(_start_or_resume_game)
	stack.add_child(play_button)
	var settings_button := Button.new()
	settings_button.text = "⚙   SETTINGS"
	settings_button.custom_minimum_size = Vector2(0, 44)
	_style_button(settings_button)
	settings_button.pressed.connect(_show_settings)
	stack.add_child(settings_button)
	var restart_button := Button.new()
	restart_button.text = "↻   RESTART RUN"
	restart_button.custom_minimum_size = Vector2(0, 44)
	_style_button(restart_button)
	restart_button.pressed.connect(_restart_campaign)
	stack.add_child(restart_button)
	var footer := Label.new()
	footer.text = "EPISODES 01–100   •   BUILD • DEFEND • SURVIVE"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.38, 0.48, 0.58))
	stack.add_child(footer)
	_make_settings_panel()
	_show_main_menu()

func _make_settings_panel() -> void:
	settings_root = Control.new()
	settings_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_root.visible = false
	menu_root.add_child(settings_root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.014, 0.026, 0.98)
	settings_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_root.add_child(center)
	settings_panel = PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(340, 0)
	settings_panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(settings_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	settings_panel.add_child(stack)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.45, 0.82, 1.0))
	stack.add_child(heading)
	var quality_label := Label.new()
	quality_label.text = "GRAPHICS QUALITY"
	stack.add_child(quality_label)
	var quality := OptionButton.new()
	quality.add_item("Low  •  smoother FPS")
	quality.add_item("Medium  •  balanced")
	quality.add_item("High  •  more scenery")
	quality.select(1 if graphics_quality == "Medium" else (0 if graphics_quality == "Low" else 2))
	quality.item_selected.connect(func(index: int) -> void:
		graphics_quality = ["Low", "Medium", "High"][index]
		_apply_graphics_quality()
		_save_settings()
	)
	stack.add_child(quality)
	_add_volume_slider(stack, "MASTER VOLUME", "master", master_volume)
	_add_volume_slider(stack, "SOUND EFFECTS", "sfx", sfx_volume)
	_add_volume_slider(stack, "AMBIENT MUSIC", "music", music_volume)
	var note := Label.new()
	note.text = "Settings save locally on this device."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.56, 0.66, 0.76))
	stack.add_child(note)
	var back := Button.new()
	back.text = "←  BACK TO MENU"
	back.custom_minimum_size = Vector2(0, 42)
	_style_button(back)
	back.pressed.connect(func() -> void:
		settings_root.visible = false
	)
	stack.add_child(back)

func _add_volume_slider(parent: VBoxContainer, label_text: String, key: String, initial_value: float) -> void:
	var label := Label.new()
	label.text = "%s  %d%%" % [label_text, roundi(initial_value * 100.0)]
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(0, 22)
	slider.value_changed.connect(func(value: float) -> void:
		match key:
			"master": master_volume = value
			"sfx": sfx_volume = value
			"music": music_volume = value
		label.text = "%s  %d%%" % [label_text, roundi(value * 100.0)]
		_apply_audio_settings()
		_save_settings()
	)
	parent.add_child(slider)

func _show_main_menu() -> void:
	get_tree().paused = game_started
	if is_instance_valid(menu_root):
		menu_root.visible = true
		settings_root.visible = false
	if is_instance_valid(hud_layer):
		hud_layer.visible = false
	if is_instance_valid(music_player) and not music_player.playing:
		music_player.play()

func _show_settings() -> void:
	if is_instance_valid(menu_root):
		menu_root.visible = true
		settings_root.visible = true
	if is_instance_valid(hud_layer):
		hud_layer.visible = false

func _start_or_resume_game() -> void:
	if base_health <= 0:
		_restart_campaign()
		return
	get_tree().paused = false
	game_started = true
	menu_root.visible = false
	settings_root.visible = false
	hud_layer.visible = true
	if not wave_active:
		_start_wave()

func _restart_campaign() -> void:
	for zombie in zombies.duplicate():
		_remove_zombie(zombie)
	for turret in turrets:
		if is_instance_valid(turret["node"]):
			(turret["node"] as Node3D).queue_free()
	turrets.clear()
	for cell in grid.keys():
		grid[cell] = null
	episode = 1
	wave = 1
	money = 350
	base_health = 20
	enemies_to_spawn = 0
	wave_active = false
	game_started = true
	_save_progress()
	_start_or_resume_game()

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.07, 0.97)
	style.border_color = Color(0.12, 0.32, 0.45, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.045, 0.09, 0.14)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.07, 0.16, 0.23)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.09, 0.22, 0.29)))

func _make_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.13, 0.36, 0.5, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		graphics_quality = str(cfg.get_value("graphics", "quality", "Medium"))
		master_volume = float(cfg.get_value("audio", "master", 0.8))
		sfx_volume = float(cfg.get_value("audio", "sfx", 0.8))
		music_volume = float(cfg.get_value("audio", "music", 0.55))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save("user://settings.cfg")

func _apply_graphics_quality() -> void:
	match graphics_quality:
		"Low":
			cull_distance = 13.0
			Engine.max_fps = 30
			if world_environment != null:
				world_environment.fog_density = 0.028
		"High":
			cull_distance = 38.0
			Engine.max_fps = 60
			if world_environment != null:
				world_environment.fog_density = 0.014
		_:
			cull_distance = 24.0
			Engine.max_fps = 60
			if world_environment != null:
				world_environment.fog_density = 0.018
	_update_forest_culling()

func _ensure_audio_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _apply_audio_settings() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(master_volume, 0.001)))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(sfx_volume, 0.001)))
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(music_volume, 0.001)))

func _make_tone(frequency: float, duration: float, volume: float, is_loop: bool = false) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var envelope := 1.0 if is_loop else maxf(0.0, 1.0 - t / duration)
		var sample := sin(TAU * frequency * t) * volume * envelope
		if is_loop:
			sample = (sample + sin(TAU * (frequency * 1.47) * t) * volume * 0.28) * 0.5
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.mix_rate = sample_rate
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = bytes
	if is_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream

func _play_ambient_music() -> void:
	if music_player != null:
		return
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.stream = _make_tone(48.0, 6.0, 0.10, true)
	add_child(music_player)
	music_player.play()

func _play_sfx(frequency: float, duration: float) -> void:
	if sfx_player == null:
		sfx_player = AudioStreamPlayer.new()
		sfx_player.bus = "SFX"
		add_child(sfx_player)
	sfx_player.stream = _make_tone(frequency, duration, 0.12)
	sfx_player.play()
