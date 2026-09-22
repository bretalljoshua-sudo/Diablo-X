class_name GameUI
extends CanvasLayer
## Die gesamte Oberfläche als eine Szene (ui/game_ui.tscn). AP9 hängt sie in jede Spielszene.
##
## Enthält HUD, Lebensbalken über Gegnern, Beute-Beschriftungen (Alt), Inventar (I),
## Skillbaum (K), Karte (M), Händler und Pausenmenü (Esc) sowie den Gegenstands-Tooltip.
## Die Spielerfigur kommt aus Game.player; Inventory und Equipment (AP4) werden als Kindknoten
## gesucht. Wechselt Game.player, verbindet sich die UI neu.

const LAYER := 10

var hud: Hud
var enemy_bars: EnemyHealthBars
var ground_labels: GroundLabels
var inventory_window: InventoryWindow
var skill_tree_window: SkillTreeWindow
var merchant_window: MerchantWindow
var pause_menu: PauseMenu
var tooltip: ItemTooltip

var bound_player: Node


func _init() -> void:
	name = "GameUI"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.name = "Root"
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	enemy_bars = EnemyHealthBars.new()
	root.add_child(enemy_bars)
	ground_labels = GroundLabels.new()
	root.add_child(ground_labels)
	hud = Hud.new()
	hud.menu_requested.connect(toggle_window)
	root.add_child(hud)

	inventory_window = InventoryWindow.new()
	inventory_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	inventory_window.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	inventory_window.offset_right = -24
	root.add_child(inventory_window)
	skill_tree_window = SkillTreeWindow.new()
	skill_tree_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	skill_tree_window.offset_left = 24
	root.add_child(skill_tree_window)
	merchant_window = MerchantWindow.new()
	merchant_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	merchant_window.offset_left = 24
	root.add_child(merchant_window)
	for window: UiWindow in [inventory_window, skill_tree_window, merchant_window]:
		window.grow_vertical = Control.GROW_DIRECTION_BOTH
		window.opened.connect(_on_window_opened.bind(window))

	pause_menu = PauseMenu.new()
	root.add_child(pause_menu)
	tooltip = ItemTooltip.new()
	root.add_child(tooltip)

	inventory_window.tooltip = tooltip
	inventory_window.merchant = merchant_window
	merchant_window.tooltip = tooltip
	merchant_window.closed.connect(func() -> void: inventory_window.close_window())
	ground_labels.tooltip = tooltip
	EventBus.merchant_opened.connect(open_merchant)


func _ready() -> void:
	bind_player(_current_player())


func _process(_delta: float) -> void:
	var player := _current_player()
	if player != bound_player:
		bind_player(player)


## Verbindet Inventar- und Händlerfenster mit Inventory und Equipment der Figur.
func bind_player(player: Node) -> void:
	bound_player = player
	var inventory := Inventory.find_on(player)
	var equipment := Equipment.find_on(player)
	inventory_window.bind(inventory, equipment, player)
	merchant_window.bind(inventory, equipment)


## Öffnet oder schließt ein Fenster: &"inventory", &"skills", &"map", &"pause".
func toggle_window(window_id: StringName) -> void:
	match window_id:
		&"inventory":
			inventory_window.toggle()
		&"skills":
			skill_tree_window.toggle()
		&"map":
			set_map_open(not hud.minimap.big)
		&"pause":
			if pause_menu.is_open():
				pause_menu.close_menu()
			else:
				close_all_windows()
				pause_menu.open_menu()


func set_map_open(open: bool) -> void:
	if hud.minimap.big == open:
		return
	hud.minimap.big = open
	EventBus.ui_window_toggled.emit(&"map", open)


func open_merchant(merchant_name: String, stock: Array[ItemInstance]) -> void:
	merchant_window.open_merchant(merchant_name, stock)
	inventory_window.open_window()


## Ist ein Fenster offen, das Klicks ins Spiel abfangen sollte?
func is_any_window_open() -> bool:
	return (
		inventory_window.is_open()
		or skill_tree_window.is_open()
		or merchant_window.is_open()
		or pause_menu.is_open()
		or hud.minimap.big
	)


func close_all_windows() -> void:
	for window: UiWindow in [merchant_window, skill_tree_window, inventory_window]:
		window.close_window()
	set_map_open(false)
	tooltip.hide_tooltip()


## Game.player, oder null, wenn es keinen (gültigen) Spieler gibt.
static func _current_player() -> Node:
	return Game.player if is_instance_valid(Game.player) else null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"pause"):
		_on_cancel()
	elif pause_menu.is_open():
		return
	elif event.is_action_pressed(&"open_inventory"):
		toggle_window(&"inventory")
	elif event.is_action_pressed(&"open_skills"):
		toggle_window(&"skills")
	elif event.is_action_pressed(&"open_map"):
		toggle_window(&"map")
	else:
		return
	get_viewport().set_input_as_handled()


func _on_cancel() -> void:
	if pause_menu.is_open():
		pause_menu.handle_cancel()
	elif is_any_window_open():
		close_all_windows()
	else:
		pause_menu.open_menu()


func _on_window_opened(window: UiWindow) -> void:
	# Links ist Platz für ein Fenster: Skillbaum und Händler schließen sich gegenseitig.
	if window == skill_tree_window:
		merchant_window.close_window()
	elif window == merchant_window:
		skill_tree_window.close_window()
