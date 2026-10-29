class_name Sfx
extends Node
## Toca efeitos sonoros (audio/*.wav) e a música ambiente.

static var inst: Sfx
var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var muted := false


func _ready() -> void:
	inst = self
	for i in 20:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)
	_music.finished.connect(func() -> void: _music.play())


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := "res://audio/%s.wav" % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


static func play(name: String, vol_db: float = 0.0, pitch: float = 1.0, vary: float = 0.06) -> void:
	if inst == null or inst.muted:
		return
	var s := inst._stream(name)
	if s == null:
		return
	var p := inst._pool[inst._next]
	inst._next = (inst._next + 1) % inst._pool.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(1.0 - vary, 1.0 + vary)
	p.play()


static func music(name: String) -> void:
	if inst == null:
		return
	var s := inst._stream(name)
	if s == null:
		return
	inst._music.stream = s
	inst._music.play()


static func toggle_music() -> bool:
	if inst == null:
		return false
	inst._music.stream_paused = not inst._music.stream_paused
	return not inst._music.stream_paused
