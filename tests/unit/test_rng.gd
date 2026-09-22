extends GutTest


func test_same_seed_same_sequence() -> void:
	var a := Rng.make(1234)
	var b := Rng.make(1234)
	for i in 5:
		assert_eq(a.randi(), b.randi())


func test_stream_depends_on_master_seed_and_purpose() -> void:
	var old_seed := Rng.master_seed
	Rng.set_master_seed(1)
	var loot_a := Rng.stream(&"loot").randi()
	var world_a := Rng.stream(&"world").randi()
	Rng.set_master_seed(1)
	assert_eq(Rng.stream(&"loot").randi(), loot_a, "gleicher Seed, gleicher Strom")
	assert_ne(loot_a, world_a, "verschiedene Zwecke, verschiedene Ströme")
	Rng.set_master_seed(2)
	assert_ne(Rng.stream(&"loot").randi(), loot_a, "anderer master_seed, anderer Strom")
	Rng.set_master_seed(old_seed)


func test_next_seed_is_reproducible() -> void:
	var old_seed := Rng.master_seed
	Rng.set_master_seed(5)
	var first := [Rng.next_seed(&"dungeon"), Rng.next_seed(&"dungeon")]
	Rng.set_master_seed(5)
	var second := [Rng.next_seed(&"dungeon"), Rng.next_seed(&"dungeon")]
	assert_eq(first, second)
	assert_ne(first[0], first[1])
	Rng.set_master_seed(old_seed)


func test_seed_from_args() -> void:
	var script: GDScript = load("res://autoload/rng.gd")
	assert_eq(script._seed_from_args(PackedStringArray(["--scene=x", "--seed=77"])), 77)
	assert_eq(script._seed_from_args(PackedStringArray()), 0)
