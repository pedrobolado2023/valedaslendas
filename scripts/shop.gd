class_name Shop
extends RefCounted
## Loja com gemas. TODA compra passa por aqui (buy), e cada compra fica registrada em player.purchases.
## Quando o banco de dados for ligado: trocar `_charge` para pedir ao servidor (que confere o saldo e grava a
## compra) e só aplicar o efeito quando ele responder OK. Créditos de gemas vindos de pagamento: `credit_gems`.


static func item(id: String) -> Dictionary:
	for it in GameData.SHOP:
		if String(it["id"]) == id:
			return it
	return {}


static func owned(p: Player, id: String) -> int:
	return int(p.shop_counts.get(id, 0))


## Motivo de não poder comprar ("" = pode).
static func why_not(p: Player, id: String) -> String:
	var it := item(id)
	if it.is_empty():
		return "Item não existe"
	var mx := int(it.get("max", 0))
	if mx > 0 and owned(p, id) >= mx:
		return "Já tem o máximo"
	if String(it["kind"]) == "level" and p.level >= GameData.MAX_LEVEL:
		return "Nível máximo"
	if p.gems < int(it["price"]):
		return "Gemas insuficientes"
	return ""


static func buy(p: Player, id: String) -> String:
	var err := why_not(p, id)
	if err != "":
		return err
	var it := item(id)
	if not _charge(p, int(it["price"]), id):
		return "Falha na compra"
	p.shop_counts[id] = owned(p, id) + 1
	_apply(p, it)
	p.recalc()
	p.stats_changed.emit()
	return ""


static func _charge(p: Player, price: int, id: String) -> bool:
	p.gems -= price
	p.purchases.append({"id": id, "price": price, "at": Time.get_datetime_string_from_system()})
	return true


static func _apply(p: Player, it: Dictionary) -> void:
	match String(it["kind"]):
		"bonus":
			p.shop_bonus[String(it["stat"])] = float(p.shop_bonus.get(String(it["stat"]), 0.0)) + float(it["amount"])
		"item":
			var slots: Array = {"armor_set": ["helmet", "chest", "pants", "gloves", "boots"],
				"jewel_set": ["necklace", "earring", "ring", "ring"]}.get(String(it["slot"]), [String(it["slot"])])
			for sl in slots:
				p.add_item(p.new_item(String(sl), String(it["rarity"])))
		"level":
			for i in int(it["amount"]):
				if p.level < GameData.MAX_LEVEL:
					p.gain_xp_raw(GameData.xp_need(p.level) - p.xp)
		"xp_boost":
			var now := Time.get_unix_time_from_system()
			p.xp_boost_until = maxf(p.xp_boost_until, now) + float(it["minutes"]) * 60.0
		"gold":
			p.gold += int(it["amount"])
		"mount":
			p.mount = String(it["id"])
			p.set_riding(true)
		"pet":
			p.pet = String(it["id"])
			p.rebuild_visuals()


## Gemas recebidas de fora (pagamento, recompensa, admin).
static func credit_gems(p: Player, n: int, reason: String) -> void:
	p.gems += n
	p.purchases.append({"id": "credito:" + reason, "price": -n, "at": Time.get_datetime_string_from_system()})
	p.stats_changed.emit()


## Bônus de XP dos mascotes e do pergaminho.
static func xp_mult(p: Player) -> float:
	var m := 1.0
	if p.pet != "":
		m += float(item(p.pet).get("xp", 0.0))
	if Time.get_unix_time_from_system() < p.xp_boost_until:
		m *= 2.0
	return m
