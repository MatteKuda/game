class_name NeighborEvents
## Mahalle olayları: small decisions that pop up 2–3 times a day so there is always
## something to react to — a wholesaler bargain, a bulk order, match night, an inspection.

const MATCH_FROM := 19 * 60
const NAMES := ["Selim Bey", "Nuriye Hanım", "Muhtar Ahmet", "Kerime Teyze", "Hakan Abi", "Sevgi Hanım"]
static var _next_id := 1
static func next_id() -> int:
	_next_id += 1
	return _next_id - 1

## returns {id, kind, title, text, icon, expires, choices: [{label, hint, primary, disabled}], data} or {}
static func roll(g) -> Dictionary:
	var stocked: Array = g.unlocked_products().filter(func(p): return g.is_stocked(p["id"]))
	if stocked.is_empty(): return {}
	var kinds := ["deal", "deal", "bulk", "bulk", "praise"]
	if g.clock < 16 * 60 and g.match_night.get("day", -1) != g.day: kinds.append("match")
	if g.clock < 18 * 60: kinds.append("inspect")
	var kind: String = kinds.pick_random()
	var scale: float = [1.0, 1.8, 3.0, 4.0][g.stage]
	var now: float = g.abs_minutes()
	var ev := {"id": _next_id, "kind": kind, "expires": now + 45.0}
	_next_id += 1
	match kind:
		"deal":
			var pool := stocked.filter(func(p): return not DB.BAKERY.has(p["id"]))
			var p: Dictionary = (pool if not pool.is_empty() else stocked).pick_random()
			var qty := int(round((24 + randf() * 24) * scale / 6.0)) * 6
			var off: float = [0.3, 0.35, 0.4].pick_random()
			var cost := int(round(qty * g.cost_of(p["id"]) * (1.0 - off)))
			var room: int = g.depot_capacity() - g.backstock_total() - g.incoming_total()
			ev.merge({"title": "Toptancıdan fırsat", "icon": "truck",
				"text": "Toptancının elinde fazla %s kaldı: %d adet %%%d indirimle, 1 saat içinde getirir." % [p["name"], qty, int(off * 100)],
				"choices": [{"label": "Al · ₺%d" % cost, "primary": true, "disabled": room < qty or g.money < cost, "hint": "Depoda yer yok" if room < qty else ""}, {"label": "Geç"}],
				"data": {"pid": p["id"], "qty": qty, "cost": cost}})
		"bulk":
			var items := {}
			var pool2 := stocked.duplicate(); pool2.shuffle()
			for p in pool2.slice(0, 2): items[p["id"]] = maxi(4, int(round((6 + randf() * 10) * scale / 2.0)) * 2)
			var pay := 0.0
			var parts := []
			var enough := true
			for pid in items:
				pay += items[pid] * int(g.prices[pid])
				parts.append("%d %s" % [items[pid], (DB.product(pid)["name"] as String).to_lower()])
				if int(g.backstock[pid]) + g.shelf_stock(pid) < items[pid]: enough = false
			var total := int(round(pay * 1.2))
			ev["expires"] = now + 60.0
			ev.merge({"title": "Toplu sipariş", "icon": "people",
				"text": "%s apartmana %s istiyor, %%20 fazlasını öder. Depodan ve raftan düşülür." % [NAMES.pick_random(), " + ".join(parts)],
				"choices": [{"label": "Hazırla · +₺%d" % total, "primary": true, "disabled": not enough, "hint": "" if enough else "Stok yetmiyor"}, {"label": "Reddet"}],
				"data": {"pay": total, "items": items}})
		"match":
			ev["expires"] = now + 90.0
			ev.merge({"title": "Bu akşam derbi var!", "icon": "star",
				"text": "Mahalle maç için toplanacak: 19:00–22:00 arası kola ve cips talebi 2,5 katı. Stok yap, istersen vitrine afiş as.",
				"choices": [{"label": "Afiş as · ₺150 (akşam +%30 müşteri)", "primary": true, "disabled": g.money < 150}, {"label": "Tamam, stok yaparım"}], "data": {}})
		"inspect":
			ev["expires"] = now + 60.0
			ev.merge({"title": "Zabıta denetimi geliyor", "icon": "alert",
				"text": "Belediye 1 saat içinde denetime gelecek. Yerde çöp ya da boş raf varsa ceza keser; temiz dükkâna puan artar.",
				"choices": [{"label": "Hazırız"}, {"label": "Temizlikçi çağır · ₺120", "primary": true, "disabled": g.money < 120}], "data": {}})
		_:
			ev["expires"] = now + 30.0
			ev.merge({"title": "Muhtar dükkânı övdü", "icon": "heart",
				"text": "Muhtar kahvede dükkânından bahsetmiş. Bugün mahalleden biraz daha fazla müşteri gelecek.",
				"choices": [{"label": "Harika!", "primary": true}], "data": {}})
	return ev

## apply the player's choice; returns a short result line for the alert log
static func resolve(g, ev: Dictionary, choice: int) -> String:
	var d: Dictionary = ev["data"]
	match ev["kind"]:
		"deal":
			if choice != 0: return ""
			if g.money < d["cost"]: return "Para yetmedi."
			g.money -= d["cost"]; g.stats["purchases"] += int(d["cost"])
			g.orders.append({"pid": d["pid"], "qty": int(d["qty"]), "eta": g.abs_minutes() + 60.0, "urgent": true})
			return "%s fırsatı alındı, 1 saat içinde geliyor." % DB.product(d["pid"])["name"]
		"bulk":
			if choice != 0: return ""
			var items: Dictionary = d["items"]
			for pid in items:
				var need: int = items[pid]
				var from_back := mini(need, int(g.backstock[pid]))
				g.backstock[pid] -= from_back; need -= from_back
				for f in g.fixtures:
					for s in f.slots:
						if need > 0 and s["pid"] == pid:
							var t := mini(need, int(s["stock"])); s["stock"] -= t; need -= t
				g.stats["sold"][pid] = int(g.stats["sold"].get(pid, 0)) + int(items[pid])
			g.money += d["pay"]; g.stats["revenue"] += int(d["pay"]); g.totals["revenue"] += int(d["pay"])
			g.refresh_all(); g.depot_changed()
			GameAudio.play("cash", -4.0)
			return "Toplu sipariş teslim edildi: +₺%d." % d["pay"]
		"match":
			g.match_night = {"day": g.day, "poster": choice == 0}
			if choice == 0: g.money -= 150; g.stats["other"] += 150
			return "Maç afişi asıldı: akşam kalabalık olacak." if choice == 0 else "Maç akşamı: kola ve cipsi doldurmayı unutma."
		"inspect":
			if choice == 1:
				g.money -= 120; g.stats["other"] += 120
				for L in g.litter.duplicate(): g.remove_litter(L)
			g.inspection_at = g.abs_minutes() + 60.0
			return "Temizlikçi yerleri pırıl pırıl yaptı." if choice == 1 else "Denetim 1 saat içinde."
		"raise":
			var s: Staff = g.staff_by_iid(int(d["staff"]))
			if s == null: return ""
			if choice == 0:
				s.base_wage = int(d["wage"]); s.set_shift(s.shift); s.morale = minf(100.0, s.morale + 20.0)
				return "%s'e zam yapıldı, çok memnun." % s.person_name
			s.morale -= 25.0
			if s.morale < 35.0 and randf() < 0.6:
				s.quit_day = g.day + 2
				g.alert("notice%d" % s.get_instance_id(), "staff", "%s kırıldı ve istifasını verdi: 2 gün sonra ayrılıyor." % s.person_name, "bad", null, 0.0)
			return "%s zam alamadı, morali bozuk." % s.person_name
		"cat":
			if choice == 0:
				g.cat.adopt(g)
				return "%s artık dükkânın kedisi! Maması kapının yanında." % g.cat.cat_name
			g.cat.shoo(g)
			return ""
		_:
			g.praise_until = g.abs_minutes() + 360.0
	return ""
