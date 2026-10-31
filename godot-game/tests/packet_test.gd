extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
func _initialize() -> void:
    var sim = Sim.new()
    var roster := [{"id":1,"tank":"steel","team":0},{"id":2,"tank":"wing","team":1},{"id":3,"tank":"steel","team":0},{"id":4,"tank":"wing","team":1}]
    sim.setup(roster, "ice")
    var maximum := 0
    for p in sim.players.values():
        p.firing = true
        p.aim = 0.0 if p.team == 0 else PI
    for i in range(180):
        sim.step(1.0 / 60.0)
        var size := var_to_bytes(sim.snapshot()).compress(FileAccess.COMPRESSION_DEFLATE).size()
        maximum = maxi(maximum, size)
    print("MAX_COMPRESSED_SNAPSHOT_BYTES=", maximum)
    if maximum > 1300:
        push_error("snapshot exceeds safe target")
        quit(1)
    else:
        quit(0)
