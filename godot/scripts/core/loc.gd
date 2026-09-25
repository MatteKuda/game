class_name Loc
## Tiny translation layer. The game is written in Turkish; with English selected, every string that
## reaches the UI kit goes through t(). Exact phrases come from res://i18n/en.txt ("tr ⟶ en" per line);
## formatted phrases are matched by pattern (the %s/%d/%.1f parts become wildcards and are carried
## over, and translated themselves when they are known words such as product names).

static var lang := "tr"
static var _exact := {}
static var _patterns: Array = [] # [[RegEx, template, n_groups]]
static var _cache := {}
static var _loaded := false

static func set_lang(l: String) -> void:
	lang = l
	_cache.clear()
	if l == "en": _load()

static func _load() -> void:
	if _loaded: return
	_loaded = true
	var f := FileAccess.open("res://i18n/en.txt", FileAccess.READ)
	if f == null: return
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "" or line.begins_with("#"): continue
		var parts := line.split(" ⟶ ", false, 1)
		if parts.size() != 2: continue
		var src: String = parts[0].replace("\\n", "\n").replace("\\\"", "\"")
		var dst: String = parts[1].replace("\\n", "\n").replace("\\\"", "\"")
		if src.contains("%"):
			var rx := _to_regex(src)
			if rx != null: _patterns.append([rx, dst, _literal_len(src)])
			_exact[src] = dst
		else:
			_exact[src] = dst
	# longest patterns first so specific phrases win over generic ones
	_patterns.sort_custom(func(a, b): return int(a[2]) > int(b[2]))

## how much fixed text a pattern has: more literal text = more specific, tried first
static func _literal_len(src: String) -> int:
	var rx := RegEx.new(); rx.compile("%[-+.0-9]*[sdf]")
	return rx.sub(src, "", true).length()

static func _to_regex(src: String) -> RegEx:
	var out := "^"
	var i := 0
	while i < src.length():
		var c := src[i]
		if c == "%" and i + 1 < src.length():
			var j := i + 1
			if src[j] == "%":
				out += "%"; i += 2; continue
			while j < src.length() and ".0123456789-+".contains(src[j]): j += 1
			if j < src.length() and "sdf".contains(src[j]):
				out += "(.+?)" if src[j] == "s" else "(-?[\\d.,]+)"
				i = j + 1; continue
		out += _esc(c)
		i += 1
	out += "$"
	var rx := RegEx.new()
	if rx.compile(out) != OK: return null
	return rx

## a captured value: known words (product names, roles…) are translated, lower-case stays lower-case
static func _word(g: String) -> String:
	if _exact.has(g): return _exact[g]
	var cap := g.capitalize()
	if g != "" and g == g.to_lower() and _exact.has(cap): return (_exact[cap] as String).to_lower()
	if g.length() > 3 and not g.is_valid_float() and not g.begins_with("₺"): return t(g) # composite values ("Cuma · İlkbahar 14")
	return g

static func _esc(c: String) -> String:
	return ("\\" + c) if "\\^$.|?*+()[]{}".contains(c) else c

## translate a UI string (no-op in Turkish)
static func t(s: String) -> String:
	if lang == "tr" or s == "": return s
	if _exact.has(s): return _exact[s]
	if _cache.has(s): return _cache[s]
	# the second rival reuses every UCUZA sentence: translate with the old name, swap it back
	if s.contains("NOKTA") and not s.contains("NOKTA 7/24"):
		var alt := s.replace("NOKTA", "UCUZA")
		var r := t(alt)
		if r != alt:
			_cache[s] = r.replace("UCUZA", "NOKTA")
			return _cache[s]
	var res := s
	for p in _patterns:
		var m: RegExMatch = (p[0] as RegEx).search(s)
		if m == null: continue
		res = p[1]
		for k in range(m.get_group_count(), 0, -1):
			var g := m.get_string(k)
			res = res.replace("$%d" % k, _word(g))
		break
	if res == s and s.contains("\n"):
		var lines := []
		for l in s.split("\n"): lines.append(t(l))
		res = "\n".join(lines)
	if _cache.size() > 6000: _cache.clear()
	_cache[s] = res
	return res
