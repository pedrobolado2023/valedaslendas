class_name SaveGame
extends RefCounted
## Salva o progresso. Todo o jogo chama só SaveGame.write / read / exists / erase; QUEM guarda é o "backend".
## Hoje: arquivo JSON local (LocalBackend). Para ligar o banco de dados: criar outra classe com os mesmos
## métodos (write/read/exists/erase, recebendo e devolvendo o mesmo Dictionary) que fala com o servidor, e
## trocar `backend` no começo do jogo. O Dictionary já tem "schema", "account_id" (id local do jogador, para
## virar o id da conta) e "purchases" (registro das compras da loja, ver shop.gd).

const SCHEMA := 3
const REAL_PATH := "user://vale_das_lendas_save.json"
## Testes automáticos (variável de ambiente VALE_TESTE) usam outro arquivo para nunca apagar o progresso do jogador.
const TEST_PATH := "user://teste_save.json"
static var PATH: String = TEST_PATH if OS.get_environment("VALE_TESTE") != "" else REAL_PATH
static var backend: Object = LocalBackend.new()


## Conta com vários heróis: o arquivo guarda {"chars": [save, ...], "cur": índice}. read()/write() continuam
## lendo/gravando o herói ATUAL (o resto do jogo não muda). Saves antigos (um herói só) viram o herói 1.
const MAX_CHARS := 4
static var cur := 0


static func account() -> Dictionary:
	var d: Dictionary = backend.read()
	return normalize(d)


static func normalize(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return {"chars": [], "cur": 0}
	if not d.has("chars"):
		return {"chars": [d], "cur": 0, "saved_at": String(d.get("saved_at", ""))}
	return d


static func exists() -> bool:
	return not (account()["chars"] as Array).is_empty()


static func count() -> int:
	return (account()["chars"] as Array).size()


static func select(i: int) -> void:
	cur = clampi(i, 0, MAX_CHARS - 1)


static func remove(i: int) -> void:
	var acc := account()
	var ch: Array = acc["chars"]
	if i >= 0 and i < ch.size():
		ch.remove_at(i)
		backend.write(acc)


static func write(data: Dictionary) -> bool:
	data["schema"] = SCHEMA
	if not data.has("account_id"):
		data["account_id"] = account_id()
	var acc := account()
	var ch: Array = acc["chars"]
	if cur >= ch.size():
		ch.append(data)
		cur = ch.size() - 1
	else:
		ch[cur] = data
	acc["cur"] = cur
	acc["saved_at"] = String(data.get("saved_at", Time.get_datetime_string_from_system()))
	acc["schema"] = SCHEMA
	return backend.write(acc)


static func read() -> Dictionary:
	var ch: Array = account()["chars"]
	return ch[cur] if cur < ch.size() else {}


## Gravar a conta inteira (vinda da nuvem/servidor).
static func write_account(acc: Dictionary) -> bool:
	return backend.write(normalize(acc))


static func erase() -> void:
	backend.erase()


## Id deste jogador neste computador (fica igual entre partidas; vira o id da conta quando houver banco).
static func account_id() -> String:
	var path := "user://conta.id"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var s := f.get_as_text().strip_edges()
			if s != "":
				return s
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var id := "local-%08x%08x" % [rng.randi(), rng.randi()]
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w != null:
		w.store_string(id)
	return id


## Backend local: JSON em user://, guardando uma cópia do save anterior (.bak) caso o arquivo novo estrague.
class LocalBackend:
	extends RefCounted

	func exists() -> bool:
		return FileAccess.file_exists(SaveGame.PATH) or FileAccess.file_exists(SaveGame.PATH + ".bak")

	func write(data: Dictionary) -> bool:
		if FileAccess.file_exists(SaveGame.PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SaveGame.PATH), ProjectSettings.globalize_path(SaveGame.PATH + ".bak"))
		var tmp := SaveGame.PATH + ".tmp"
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(JSON.stringify(data, "  "))
		f.close()
		if FileAccess.file_exists(SaveGame.PATH):   # o Windows não troca por cima: o anterior já está no .bak
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.PATH))
		return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SaveGame.PATH)) == OK

	func read() -> Dictionary:
		for p in [SaveGame.PATH, SaveGame.PATH + ".bak"]:
			if not FileAccess.file_exists(p):
				continue
			var f := FileAccess.open(p, FileAccess.READ)
			if f == null:
				continue
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				return parsed
		return {}

	func erase() -> void:
		for p in [SaveGame.PATH, SaveGame.PATH + ".bak"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
