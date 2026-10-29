class_name CloudSync
extends Node
## Cópia do save na nuvem (Supabase). O jogo continua salvando no arquivo local (SaveGame); este nó:
## 1) entra com login anônimo (a sessão fica em user://nuvem.cfg, então é sempre a mesma conta neste PC);
## 2) ao abrir, baixa o save da nuvem e usa ele se for mais novo que o local;
## 3) a cada save, envia uma cópia (sem travar o jogo).
## Configuração em res://supabase.cfg ([supabase] url e anon_key). Sem o arquivo, fica desligado.
## Tabela e regras: supabase/schema.sql.

signal ready_done(pulled: bool)

const CFG := "res://supabase.cfg"
const SESSION := "user://nuvem.cfg"

var url := ""
var key := ""
var token := ""
var refresh := ""
var user_id := ""
var enabled := false
var status := "desligado"
var _busy := false
var _pending: Dictionary = {}


func _ready() -> void:
	var c := ConfigFile.new()
	if OS.get_environment("VALE_TESTE") != "" or c.load(CFG) != OK:
		return
	url = String(c.get_value("supabase", "url", "")).trim_suffix("/")
	key = String(c.get_value("supabase", "anon_key", ""))
	enabled = url != "" and key != ""
	if enabled:
		start()


func start() -> void:
	status = "entrando..."
	var s := ConfigFile.new()
	if s.load(SESSION) == OK:
		refresh = String(s.get_value("auth", "refresh", ""))
	var ok := false
	if refresh != "":
		ok = await _auth("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh})
	if not ok:
		ok = await _auth("/auth/v1/signup", {"data": {"jogo": "vale_das_lendas"}})   # login anônimo
	if not ok:
		status = "sem conexão"
		ready_done.emit(false)
		return
	status = "conectado"
	ready_done.emit(await pull())


func _auth(path: String, body: Dictionary) -> bool:
	var r := await _req(path, HTTPClient.METHOD_POST, body, false)
	if int(r["code"]) != 200 or not (r["json"] is Dictionary) or not r["json"].has("access_token"):
		return false
	token = String(r["json"]["access_token"])
	refresh = String(r["json"]["refresh_token"])
	user_id = String(r["json"]["user"]["id"])
	var s := ConfigFile.new()
	s.set_value("auth", "refresh", refresh)
	s.set_value("auth", "user_id", user_id)
	s.save(SESSION)
	return true


## Baixa o save da nuvem; se for mais novo que o local, grava no local. Devolve true se trocou.
func pull() -> bool:
	var r := await _req("/rest/v1/saves?select=data,saved_at&user_id=eq." + user_id, HTTPClient.METHOD_GET, null)
	if int(r["code"]) != 200 or not (r["json"] is Array) or (r["json"] as Array).is_empty():
		return false
	var cloud: Dictionary = r["json"][0]["data"]
	var local := SaveGame.read()
	if String(cloud.get("saved_at", "")) > String(local.get("saved_at", "")):
		SaveGame.backend.write(cloud)
		return true
	return false


## Envia o save (o último pedido vence; não trava o jogo).
func push(data: Dictionary) -> void:
	if not enabled or token == "":
		return
	_pending = data.duplicate(true)
	if _busy:
		return
	_busy = true
	while not _pending.is_empty():
		var d := _pending
		_pending = {}
		var row := {"user_id": user_id, "data": d, "level": int(d.get("level", 1)), "class": String(d.get("class", "")),
			"saved_at": String(d.get("saved_at", "")), "updated_at": Time.get_datetime_string_from_system(true) + "Z"}
		var r := await _req("/rest/v1/saves?on_conflict=user_id", HTTPClient.METHOD_POST, row, true, ["Prefer: resolution=merge-duplicates,return=minimal"])
		if int(r["code"]) == 401 and await _auth("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh}):
			_pending = d if _pending.is_empty() else _pending
		status = "salvo na nuvem" if int(r["code"]) < 300 else "erro %d" % int(r["code"])
	_busy = false


func _req(path: String, method: int, body: Variant, auth := true, extra: Array = []) -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 15.0
	add_child(h)
	var headers := PackedStringArray(["apikey: " + key, "Content-Type: application/json",
		"Authorization: Bearer " + (token if auth and token != "" else key)])
	for e in extra:
		headers.append(String(e))
	var err := h.request(url + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		h.queue_free()
		return {"code": 0, "json": null}
	var res: Array = await h.request_completed
	h.queue_free()
	var txt := (res[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(res[1]), "json": JSON.parse_string(txt) if txt != "" else null}
