@tool
extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const AstronautModel = preload("res://assets/astronaut.glb")
const PlanetModel = preload("res://assets/habitat/planet.glb")
const MoonModel = preload("res://assets/habitat/moon.glb")
const PodModel = preload("res://assets/habitat/scifi_pod.glb")
const RoverModel = preload("res://assets/habitat/space_rover.glb")
const ProbeModel = preload("res://assets/habitat/space_probe.glb")
const StationModel = preload("res://assets/habitat/space_station.glb")
const FlowerModel = preload("res://assets/habitat/cactus_flowers.glb")
const LEVEL_CENTERS := [Vector2(0, 5), Vector2(0, -3), Vector2(2, -11), Vector2(2, -19), Vector2(-1, -27), Vector2(0, -35)]

var stage := 1
var collected := 0
var required := 6
var deaths := 0
var finished := false
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var help: Label
var notice: Label
var banner: Label
var progress: ProgressBar
var win_overlay: ColorRect
var win_details: Label
var restart_button: Button
var gems: Array[Area3D] = []
var gem_origins: Dictionary = {}
var clock := 0.0
var portal_visual: Node3D
var portal_light: OmniLight3D
var notice_time := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		_build_stage(true)
		return
	_build_ui()
	_build_stage()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	clock += delta
	if camera != null and is_instance_valid(player):
		var target := player.global_position + Vector3(0, 6.5, 11.5)
		camera.global_position = camera.global_position.lerp(target, min(1.0, 4.5 * delta))
		camera.look_at(player.global_position + Vector3(0, 0.8, -4.0), Vector3.UP)
	for gem in gems:
		if is_instance_valid(gem):
			gem.rotate_y(1.7 * delta)
			gem.position.y = gem_origins[gem] + sin(clock * 3.0 + gem.position.z) * 0.17
	if portal_visual != null and is_instance_valid(portal_visual):
		portal_visual.rotate_y(0.22 * delta)
		portal_light.light_energy = 1.2 + 0.4 * sin(clock * 3.0)
	if notice_time > 0.0:
		notice_time -= delta
		if notice_time <= 0.0:
			notice.text = ""
	if Input.is_key_pressed(KEY_R) and not _restart_held:
		if finished:
			_restart_game()
		else:
			_respawn()
	_restart_held = Input.is_key_pressed(KEY_R)

var _restart_held := false

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status_panel := _panel(root, Vector2(18, 15), Vector2(860, 103), Color("091b36e8"), Color("4ed8ee"))
	var title := _label(status_panel, Vector2(20, 11), 27, Color("e9fbff"))
	title.text = "SKYWARD ASTRONAUT"
	hud = _label(status_panel, Vector2(21, 51), 20, Color("c7e9f5"))
	progress = ProgressBar.new()
	progress.position = Vector2(622, 63)
	progress.size = Vector2(213, 18)
	progress.show_percentage = false
	progress.max_value = 6
	progress.add_theme_stylebox_override("background", _style(Color("112d49"), Color("315b73"), 9))
	progress.add_theme_stylebox_override("fill", _style(Color("5ce6ed"), Color("8df7fb"), 9))
	status_panel.add_child(progress)
	var controls_panel := _panel(root, Vector2(18, 126), Vector2(650, 45), Color("091b36d9"), Color("416a82"))
	help = _label(controls_panel, Vector2(15, 11), 16, Color("d4eaf2"))
	help.text = "WASD / ARROWS  MOVE      SPACE / ENTER  DOUBLE JUMP      R  RETRY"
	var notice_panel := _panel(root, Vector2(686, 126), Vector2(474, 45), Color("1b2546e5"), Color("8c7be9"))
	notice = _label(notice_panel, Vector2(15, 9), 18, Color("ffe5a5"))
	notice.clip_text = true
	notice.size = Vector2(445, 28)
	win_overlay = ColorRect.new()
	win_overlay.color = Color("020917d9")
	root.add_child(win_overlay)
	win_overlay.size = root.size
	win_overlay.visible = false
	win_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var card := _panel(win_overlay, Vector2.ZERO, Vector2(590, 370), Color("102346f5"), Color("64dcec"))
	card.position = (win_overlay.size - card.size) * 0.5
	var eyebrow := _label(card, Vector2(40, 29), 19, Color("65e9f2"))
	eyebrow.text = "MISSION COMPLETE  /  SPACE EXPLORER"
	banner = _label(card, Vector2(40, 76), 50, Color("ffffff"))
	banner.text = "GALAXY SAVED!"
	win_details = _label(card, Vector2(42, 151), 22, Color("cde7f3"))
	win_details.size = Vector2(500, 72)
	var line := ColorRect.new()
	line.position = Vector2(42, 239)
	line.size = Vector2(506, 2)
	line.color = Color("4a89a9")
	card.add_child(line)
	restart_button = Button.new()
	restart_button.text = "PLAY AGAIN"
	restart_button.position = Vector2(161, 271)
	restart_button.size = Vector2(268, 62)
	restart_button.add_theme_font_size_override("font_size", 23)
	restart_button.add_theme_color_override("font_color", Color("082039"))
	restart_button.add_theme_stylebox_override("normal", _style(Color("69e5ed"), Color("b8fcff"), 16))
	restart_button.add_theme_stylebox_override("hover", _style(Color("9ef8f2"), Color("ffffff"), 16))
	restart_button.add_theme_stylebox_override("pressed", _style(Color("44bfd5"), Color("9df1fa"), 16))
	restart_button.pressed.connect(_restart_game)
	card.add_child(restart_button)

func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _panel(parent: Control, at: Vector2, size: Vector2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill, border, 14))
	parent.add_child(panel)
	return panel

func _label(parent: Control, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.04, 0.08, 0.13, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_stage(editor_preview := false) -> void:
	if world != null:
		world.queue_free()
	if camera != null:
		camera.queue_free()
	world = Node3D.new()
	world.name = "EditorPreview_Level_%d" % stage if editor_preview else "Level_%d" % stage
	add_child(world)
	gems.clear()
	gem_origins.clear()
	collected = 0
	portal_visual = null
	portal_light = null
	if not editor_preview:
		win_overlay.visible = false
		notice.text = ""
	var is_night := stage == 2
	var sky_color := Color("100e29") if is_night else Color("081c35")
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = sky_color
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("aaa3ed") if is_night else Color("a6d8e9")
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("b7b0ff") if is_night else Color("c2f2ff")
	sun.light_energy = 1.1 if is_night else 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	_make_space_background(is_night)
	for index in LEVEL_CENTERS.size():
		var point: Vector2 = LEVEL_CENTERS[index]
		_make_island(point.x, point.y, index, is_night)
		_make_gem(Vector3(point.x + (1.2 if index % 2 == 0 else -1.2), 1.45, point.y - (0.8 if index == 5 else 0.0)))
		if index > 0 and index < 5:
			_make_hazard(Vector3(point.x + (0.9 if index % 2 == 0 else -0.9), 0.13, point.y - 1.7), is_night)
		if stage == 2 and index == 5:
			_make_hazard(Vector3(point.x - 1.5, 0.13, point.y + 0.9), true)
	_make_portal(Vector3(0, 0.0, -37.0), is_night)
	if editor_preview:
		_place_model(AstronautModel, Vector3(0, 0.06, 6.0), 0.87, 0.0, "Astronaut_Preview")
		return
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = Vector3(0, 1.3, 6.0)
	player.fell.connect(_respawn)
	world.add_child(player)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 62.0
	camera.position = Vector3(0, 7.8, 17.0)
	add_child(camera)
	_update_hud()
	_show_notice("Orbital Outpost" if stage == 1 else "Moonbase Crossing", 4.0)

func _make_island(x: float, z: float, index: int, night: bool) -> void:
	var land := StaticBody3D.new()
	land.name = "Island_%d" % (index + 1)
	land.position = Vector3(x, -0.45, z)
	world.add_child(land)
	var top_color := Color("5c6587") if night else Color("607f9a")
	var side_color := Color("252342") if night else Color("1c364e")
	_box_mesh(land, Vector3(7.0, 0.9, 6.5), Vector3.ZERO, side_color)
	_box_mesh(land, Vector3(7.05, 0.18, 6.55), Vector3(0, 0.51, 0), top_color)
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 0.9, 6.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	land.add_child(collision)
	_make_deck_details(x, z, index, night)
	for side in [-1, 1]:
		_place_model(PodModel, Vector3(x + side * 2.65, 0.08, z + 1.85), 0.47 if night else 0.42, float(index * 35 + side * 30), "HabitatPod")
		_box_mesh(world, Vector3(0.16, 0.08, 5.4), Vector3(x + side * 3.25, 0.12, z), Color("b683ff") if night else Color("57d9ea"), true)
		if night and index % 2 == 0:
			_place_model(FlowerModel, Vector3(x + side * 2.0, 0.08, z - 1.6), 1.4, float(side * 70), "HabitatGarden")
	if index == 0 or index == 3:
		_place_model(RoverModel, Vector3(x - 2.0, 0.1, z - 1.2), 0.24, 135.0, "ExplorationRover")
	if index == 1 or index == 4:
		_box_mesh(world, Vector3(0.5, 1.0, 0.5), Vector3(x + 2.45, 0.6, z - 1.6), Color("617c99") if not night else Color("6e689c"))
		_box_mesh(world, Vector3(0.7, 0.12, 0.7), Vector3(x + 2.45, 1.15, z - 1.6), Color("55e5f7") if not night else Color("c090ff"), true)
	if index > 0:
		var trim_color := Color("c490ff") if night else Color("55e5f7")
		_box_mesh(world, Vector3(6.2, 0.05, 0.12), Vector3(x, 0.09, z + 3.05), trim_color, true)
		_box_mesh(world, Vector3(6.2, 0.05, 0.12), Vector3(x, 0.09, z - 3.05), trim_color, true)

func _make_deck_details(x: float, z: float, index: int, night: bool) -> void:
	var steel := Color("344264") if night else Color("315572")
	var line_color := Color("b998ff") if night else Color("65e5ed")
	var lamp_color := Color("ffd789") if night else Color("a0f7ff")
	# A layered landing pad, panel seams and numbered runway lights make each island read as a station module.
	_box_mesh(world, Vector3(3.55, 0.025, 2.1), Vector3(x, 0.105, z + 0.15), steel)
	for side in [-1, 1]:
		_box_mesh(world, Vector3(0.07, 0.035, 4.7), Vector3(x + side * 1.92, 0.135, z), line_color, true)
		for row in [-1, 0, 1]:
			_box_mesh(world, Vector3(0.57, 0.035, 0.17), Vector3(x + side * 2.55, 0.135, z + row * 1.6), lamp_color, true)
		# The lamps sit on the outer rim so the walkway stays clear for jumping.
		var lamp_x: float = x + side * 3.05
		var lamp_z := z - 2.45
		_box_mesh(world, Vector3(0.17, 0.86, 0.17), Vector3(lamp_x, 0.47, lamp_z), steel)
		_box_mesh(world, Vector3(0.32, 0.14, 0.32), Vector3(lamp_x, 0.98, lamp_z), lamp_color, true)
	for row in [-1, 1]:
		_box_mesh(world, Vector3(3.1, 0.035, 0.075), Vector3(x, 0.135, z + row * 1.2), line_color, true)
		_box_mesh(world, Vector3(0.78, 0.035, 0.38), Vector3(x, 0.135, z + row * 2.5), Color("6b7897") if night else Color("577790"))
	# Underside struts and solar wings give the floating platforms a visible structure.
	_box_mesh(world, Vector3(4.8, 0.26, 0.5), Vector3(x, -1.22, z), steel)
	_box_mesh(world, Vector3(0.5, 0.26, 4.4), Vector3(x, -1.22, z), steel)
	if index % 2 == 1:
		var wing_side: int = -1 if index % 4 == 1 else 1
		var wing_x: float = x + wing_side * 5.25
		_box_mesh(world, Vector3(0.18, 0.18, 1.4), Vector3(x + wing_side * 3.8, -0.13, z), steel)
		_box_mesh(world, Vector3(2.5, 0.09, 1.8), Vector3(wing_x, -0.07, z), Color("27398c") if night else Color("194d8b"))
		for stripe in [-0.65, 0.0, 0.65]:
			_box_mesh(world, Vector3(0.045, 0.014, 1.66), Vector3(wing_x + stripe, -0.015, z), line_color, true)
	else:
		# Service crates and a compact antenna add depth without blocking the main route.
		var antenna_x := x + 4.4
		_box_mesh(world, Vector3(0.16, 1.65, 0.16), Vector3(antenna_x, 0.55, z + 1.2), steel)
		_box_mesh(world, Vector3(1.3, 0.07, 0.12), Vector3(antenna_x, 1.28, z + 1.2), line_color, true)
		_box_mesh(world, Vector3(0.25, 0.25, 0.25), Vector3(antenna_x, 1.43, z + 1.2), lamp_color, true)

func _place_model(scene: PackedScene, at: Vector3, size: float, yaw: float, label: String) -> Node3D:
	var prop: Node3D = scene.instantiate()
	prop.name = label
	prop.position = at
	prop.scale = Vector3.ONE * size
	prop.rotation_degrees.y = yaw
	world.add_child(prop)
	return prop

func _make_space_background(night: bool) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 28371 + stage * 101
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.08
	star_mesh.height = 0.16
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	star_mesh.material = _material(Color("e7f2ff"), true)
	var field := MultiMesh.new()
	field.transform_format = MultiMesh.TRANSFORM_3D
	field.mesh = star_mesh
	field.instance_count = 180
	for i in field.instance_count:
		var position_3d := Vector3(random.randf_range(-65.0, 65.0), random.randf_range(5.0, 36.0), random.randf_range(-70.0, 30.0))
		var size := random.randf_range(0.55, 1.8)
		field.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), position_3d))
	var stars := MultiMeshInstance3D.new()
	stars.name = "Starfield"
	stars.multimesh = field
	world.add_child(stars)
	if night:
		_place_model(MoonModel, Vector3(-31, -8, -52), 0.23, 0, "Moon")
		_place_model(PlanetModel, Vector3(32, 17, -66), 3.1, 0, "DistantPlanet")
		_place_model(StationModel, Vector3(18, 0, -25), 0.23, 60, "OrbitalStation")
		_place_model(ProbeModel, Vector3(-22, 1, -12), 0.18, 30, "DeepSpaceProbe")
	else:
		_place_model(PlanetModel, Vector3(-35, 0, -60), 3.5, 0, "DistantPlanet")
		_place_model(MoonModel, Vector3(29, 8, -57), 0.18, 0, "Moon")
		_place_model(StationModel, Vector3(-18, -2, -24), 0.22, -35, "OrbitalStation")
		_place_model(ProbeModel, Vector3(24, 2, -14), 0.19, -45, "DeepSpaceProbe")

func _make_sign(at: Vector3, night: bool) -> void:
	_box_mesh(world, Vector3(0.13, 1.4, 0.13), at + Vector3(0, 0.7, 0), Color("6d5047") if not night else Color("7d86b7"))
	_box_mesh(world, Vector3(1.2, 0.55, 0.15), at + Vector3(0, 1.42, 0), Color("e8c481") if not night else Color("7ac6dc"))

func _tree(at: Vector3, index: int) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.19
	trunk_mesh.height = 1.1
	trunk_mesh.radial_segments = 5
	trunk.mesh = trunk_mesh
	trunk.material_override = _material(Color("845746"))
	trunk.position = at + Vector3(0, 0.57, 0)
	world.add_child(trunk)
	var leaves := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.68
	cone.height = 1.65
	cone.radial_segments = 5
	leaves.mesh = cone
	leaves.material_override = _material(Color("398d83") if index % 2 == 0 else Color("5ca48b"))
	leaves.position = at + Vector3(0, 1.6, 0)
	world.add_child(leaves)

func _crystal(at: Vector3, tint: Color) -> void:
	var mesh := MeshInstance3D.new()
	var prism := CylinderMesh.new()
	prism.top_radius = 0.0
	prism.bottom_radius = 0.4
	prism.height = 1.55
	prism.radial_segments = 4
	mesh.mesh = prism
	mesh.material_override = _material(tint, true)
	mesh.position = at + Vector3(0, 0.8, 0)
	mesh.rotation_degrees.y = 45
	world.add_child(mesh)

func _make_gem(at: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Star"
	area.position = at
	world.add_child(area)
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	var collider := CollisionShape3D.new()
	collider.shape = shape
	area.add_child(collider)
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	mesh.radial_segments = 6
	mesh.rings = 3
	body.mesh = mesh
	body.material_override = _material(Color("ffe17b") if stage == 1 else Color("81f2eb"), true)
	area.add_child(body)
	var halo := OmniLight3D.new()
	halo.light_color = Color("ffd673") if stage == 1 else Color("69eee9")
	halo.light_energy = 0.55
	halo.omni_range = 3.2
	area.add_child(halo)
	area.body_entered.connect(_on_gem.bind(area))
	gems.append(area)
	gem_origins[area] = at.y

func _make_hazard(at: Vector3, night: bool) -> void:
	var area := Area3D.new()
	area.name = "SpikeTrap"
	area.position = at
	world.add_child(area)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 0.5, 1.45)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	area.add_child(collider)
	_box_mesh(area, Vector3(1.7, 0.12, 1.45), Vector3(0, -0.12, 0), Color("8c3156") if night else Color("b35d4d"))
	for offset in [-0.5, 0.0, 0.5]:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.18
		cone.height = 0.54
		cone.radial_segments = 4
		spike.mesh = cone
		spike.position = Vector3(offset, 0.13, 0)
		spike.material_override = _material(Color("ff5c79") if night else Color("f5a25c"), true)
		area.add_child(spike)
	area.body_entered.connect(_on_hazard)

func _make_portal(at: Vector3, night: bool) -> void:
	var area := Area3D.new()
	area.name = "ExitPortal"
	area.position = at
	world.add_child(area)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.4, 1.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 1.2
	area.add_child(collider)
	portal_visual = Node3D.new()
	portal_visual.position = at
	world.add_child(portal_visual)
	var base := Color("92d9dd") if night else Color("f3d18f")
	_box_mesh(portal_visual, Vector3(0.35, 2.45, 0.4), Vector3(-1.12, 1.2, 0), base)
	_box_mesh(portal_visual, Vector3(0.35, 2.45, 0.4), Vector3(1.12, 1.2, 0), base)
	_box_mesh(portal_visual, Vector3(2.6, 0.35, 0.4), Vector3(0, 2.45, 0), base)
	_box_mesh(portal_visual, Vector3(1.85, 2.15, 0.08), Vector3(0, 1.25, 0), Color("55c9dd") if night else Color("8be6d4"), true)
	portal_light = OmniLight3D.new()
	portal_light.position = at + Vector3(0, 1.2, 0)
	portal_light.light_color = Color("6fefff") if night else Color("d6fff1")
	portal_light.omni_range = 5.0
	world.add_child(portal_light)
	area.body_entered.connect(_on_portal)

func _box_mesh(parent: Node3D, size: Vector3, at: Vector3, tint: Color, glow := false) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _material(tint, glow)
	instance.position = at
	parent.add_child(instance)

func _material(tint: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.8
	if glow:
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = 1.5
	return mat

func _on_gem(body: Node3D, area: Area3D) -> void:
	if body != player or area.get_meta("taken", false):
		return
	area.set_meta("taken", true)
	collected += 1
	area.queue_free()
	_update_hud()
	if collected == required:
		_show_notice("All stars found! The portal is open.", 4.0)

func _on_hazard(body: Node3D) -> void:
	if body == player and not finished:
		_respawn()

func _on_portal(body: Node3D) -> void:
	if body != player or finished:
		return
	if collected < required:
		_show_notice("Find %d more star(s) before leaving." % (required - collected), 2.5)
	else:
		call_deferred("_advance")

func _advance() -> void:
	if stage == 1:
		stage = 2
		_build_stage()
		_show_notice("Level 2: Moonbase Crossing", 4.0)
	else:
		finished = true
		player.controls_enabled = false
		win_details.text = "Both space habitats restored.\n12 stars collected  /  %d falls" % deaths
		win_overlay.visible = true
		restart_button.grab_focus()

func _restart_game() -> void:
	stage = 1
	deaths = 0
	finished = false
	_build_stage()

func _respawn() -> void:
	if not is_instance_valid(player) or finished:
		return
	deaths += 1
	player.global_position = Vector3(0, 1.4, 6.0)
	player.velocity = Vector3.ZERO
	player.can_double_jump = true
	_update_hud()
	_show_notice("Try again! Your stars are saved.", 2.5)

func _update_hud() -> void:
	hud.text = "LEVEL %02d / 02       STARS %d / %d       FALLS %d" % [stage, collected, required, deaths]
	progress.value = collected

func _show_notice(message: String, seconds: float) -> void:
	notice.text = message
	notice_time = seconds
