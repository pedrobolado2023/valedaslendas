class_name CloudSync
extends Node
## Cópia do save na nuvem (Supabase). O jogo continua salvando no arquivo local (SaveGame); este nó:
## 1) entra com e-mail e senha (tela LoginPanel); a sessão fica em user://nuvem.cfg e reabre sozinha;
## 2) ao abrir, baixa o save da nuvem e usa ele se for mais novo que o local;
## 3) a cada save, envia uma cópia (sem travar o jogo).
## Configuração em res://supabase.cfg ([supabase] url e anon_key). Sem o arquivo, fica desligado.
## Tabela e regras: supabase/schema.sql.

signal ready_done(pulled: bool)
signal need_login

const CFG := "res://supabase.cfg"
const SESSION := "user://nuvem.cfg"

var url := ""
var key := ""
var token := ""
var refresh := ""
var user_id := ""
var email := ""
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
		start.call_deferred()   # depois de o jogo ligar os sinais (need_login / ready_done)


func start() -> void:
	status = "entrando..."
	var s := ConfigFile.new()
	if s.load(SESSION) == OK:
		refresh = String(s.get_value("auth", "refresh", ""))
	var ok := false
	if refresh != "":
		ok = await _auth("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh})
	if not ok:
		status = "sem login"
		need_login.emit()
		return
	status = "conectado"
	ready_done.emit(await pull())


## Entrar com e-mail e senha (criar = true cria a conta). Devolve "" se deu certo, ou a mensagem de erro.
func login(mail: String, senha: String, criar: bool) -> String:
	var path := "/auth/v1/signup" if criar else "/auth/v1/token?grant_type=password"
	var r := await _req(path, HTTPClient.METHOD_POST, {"email": mail, "password": senha}, false)
	if int(r["code"]) == 200 and r["json"] is Dictionary and r["json"].has("access_token"):
		_take(r["json"])
		status = "conectado"
		ready_done.emit(await pull())
		return ""
	var j: Variant = r["json"]
	var msg := String(j.get("msg", j.get("error_description", j.get("message", "")))) if j is Dictionary else ""
	if int(r["code"]) == 0:
		return "Sem conexão com o servidor."
	if "Invalid login" in msg:
		return "E-mail ou senha errados."
	if "already registered" in msg:
		return "Esse e-mail já tem conta. Use Entrar."
	if "Password" in msg:
		return "A senha precisa ter pelo menos 6 letras/números."
	return msg if msg != "" else "Erro %d" % int(r["code"])


func logout() -> void:
	token = ""
	refresh = ""
	user_id = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION))


func _auth(path: String, body: Dictionary) -> bool:
	var r := await _req(path, HTTPClient.METHOD_POST, body, false)
	if int(r["code"]) != 200 or not (r["json"] is Dictionary) or not r["json"].has("access_token"):
		return false
	_take(r["json"])
	return true


func _take(j: Dictionary) -> void:
	token = String(j["access_token"])
	refresh = String(j["refresh_token"])
	user_id = String(j["user"]["id"])
	email = String(j["user"].get("email", ""))
	# conta marcada como admin no Supabase (app_metadata.admin = true; só o painel/servidor muda isso): liga o F1
	var meta: Variant = j["user"].get("app_metadata", {})
	if meta is Dictionary and bool(meta.get("admin", false)):
		GameData.ADMIN_ENABLED = true
	var s := ConfigFile.new()
	s.set_value("auth", "refresh", refresh)
	s.set_value("auth", "user_id", user_id)
	s.save(SESSION)


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
