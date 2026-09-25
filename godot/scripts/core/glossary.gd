class_name Glossary
## In English, some words stay Turkish on purpose (simit, veresiye, bayram…). The first time one
## shows up on screen, a small card explains it; afterwards the explanation lives in tooltips and in
## the Glossary page of the menu. Seen words are remembered across games (Progress).

const TERMS := {
	"Simit": "A sesame-crusted bread ring — Turkey's favourite breakfast on the go.",
	"Ayran": "A cold, salty yoghurt drink; the classic partner to lunch.",
	"Salep": "A hot, thick winter drink made from orchid-root flour, dusted with cinnamon.",
	"Sucuk": "A spicy, garlicky dry-cured beef sausage, sold by the horseshoe at the deli.",
	"Kaşar": "A mild yellow cheese, great melted on toast.",
	"Pide": "A soft, round flatbread baked fresh for Ramadan evenings.",
	"Veresiye": "Buying on tab: the shopkeeper writes it in a notebook and the neighbour pays later — trust, not a credit card.",
	"Bayram": "A religious holiday (Eid). Families visit each other and children collect sweets.",
	"Ramazan": "Ramadan. People fast by day, so shops are quiet until the rush before iftar.",
	"Ramadan": "People fast by day, so shops are quiet until the rush before iftar.",
	"Iftar": "The evening meal that breaks the Ramadan fast; fresh pide and dates are a must.",
	"Arife": "The eve of a holiday: everyone is out shopping.",
	"Muhtar": "The elected head of a neighbourhood; knows everyone and everything.",
	"Zabıta": "The municipal inspectors who check shops for cleanliness and fair prices.",
	"Usta": "Master — a respectful title for a skilled tradesman, like Kemal Usta.",
	"Teyze": "Auntie — how you address an older woman in the neighbourhood.",
	"Amca": "Uncle — how you address an older man in the neighbourhood.",
	"Abi": "Big brother — a friendly title for a slightly older man.",
	"Hanım": "Mrs/Ms — a polite title after a woman's first name.",
	"Bey": "Mr — a polite title after a man's first name.",
	"Büfe": "A tiny corner kiosk selling newspapers, snacks and cold drinks.",
	"Köşebaşı": "\"Street corner\" — the name of your shop.",
	"Çay ocağı": "A tea corner: glasses of black tea keep the whole street going.",
	"Derbi": "A big football match between rival Istanbul clubs; the neighbourhood watches together.",
}

static var _pending: Array = []
static var _regex: RegEx

static func _rx() -> RegEx:
	if _regex == null:
		var keys := TERMS.keys()
		keys.sort_custom(func(a, b): return a.length() > b.length())
		_regex = RegEx.new()
		_regex.compile("(?i)(?<!\\p{L})(" + "|".join(keys.map(func(k): return _esc(k))) + ")(?!\\p{L})")
	return _regex

static func _esc(s: String) -> String:
	var o := ""
	for c in s: o += ("\\" + c) if "\\^$.|?*+()[]{}".contains(c) else c
	return o

## the canonical term for a match (case-insensitive, Turkish capital I handled by the table)
static func _key(m: String) -> String:
	for k in TERMS:
		if (k as String).to_lower() == m.to_lower(): return k
	return ""

## called for every translated UI string; queues words seen for the first time
static func scan(text: String) -> void:
	if Loc.lang != "en" or text.length() < 3: return
	for m in _rx().search_all(text):
		var k := _key(m.get_string(1))
		if k == "" or Progress.glossary_seen(k) or _pending.has(k): continue
		_pending.append(k)

static func pop() -> String:
	if _pending.is_empty(): return ""
	var k: String = _pending.pop_front()
	Progress.mark_glossary(k)
	return k

## the explanation appended to tooltips of cultural words
static func note(text: String) -> String:
	if Loc.lang != "en": return ""
	var out := []
	for m in _rx().search_all(text):
		var k := _key(m.get_string(1))
		if k != "" and not out.any(func(x): return x.begins_with(k)): out.append("%s: %s" % [k, TERMS[k]])
	return "\n".join(out)
