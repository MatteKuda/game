class_name Calendar
extends RefCounted
## A compressed year: four seasons of 14 days, a 7-day week, the school start, Ramazan and the
## two bayrams, plus daily weather with a forecast for tomorrow. It only answers questions —
## how busy the street is and how much people want each product today.

const SEASON_LEN := 14
const YEAR_LEN := 56
const SEASONS := ["İlkbahar", "Yaz", "Sonbahar", "Kış"]
const WEEKDAYS := ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
## day 1 is the 10th day of spring, so the first hot days come early
const START_OFFSET := 9
const WEATHER := {
	"gunes": {"name": "Güneşli", "icon": "sun", "traffic": 1.0},
	"sicak": {"name": "Sıcak hava", "icon": "sun", "traffic": 1.05},
	"bulut": {"name": "Bulutlu", "icon": "cloud", "traffic": 0.95},
	"yagmur": {"name": "Yağmurlu", "icon": "rain", "traffic": 0.78},
	"kar": {"name": "Karlı", "icon": "snow", "traffic": 0.62},
}
## weather odds per season [gunes, sicak, bulut, yagmur, kar]
const ODDS := [[0.45, 0.05, 0.25, 0.25, 0.0], [0.5, 0.3, 0.1, 0.1, 0.0], [0.35, 0.0, 0.3, 0.35, 0.0], [0.2, 0.0, 0.3, 0.25, 0.25]]

var weather := "gunes"
var tomorrow := "gunes"

func _cal(day: int) -> int: return day - 1 + START_OFFSET # calendar day index, 0-based
func year(day: int) -> int: return _cal(day) / YEAR_LEN + 1
func season(day: int) -> int: return (_cal(day) % YEAR_LEN) / SEASON_LEN
func season_day(day: int) -> int: return (_cal(day) % YEAR_LEN) % SEASON_LEN + 1
func weekday(day: int) -> int: return (day - 1) % 7
func is_weekend(day: int) -> bool: return weekday(day) >= 5

## Ramazan moves 4 days earlier every year, like the real one drifts through the seasons
func ramazan_start(y: int) -> int: return (y - 1) * YEAR_LEN + 36 - 4 * (y - 1)
func _abs(day: int) -> int: return _cal(day)
func is_ramazan(day: int) -> bool:
	var s := ramazan_start(year(day))
	var a := _abs(day)
	return a >= s and a < s + 10
func is_ramazan_bayram(day: int) -> bool:
	var s := ramazan_start(year(day)) + 10
	return _abs(day) >= s and _abs(day) < s + 3
func is_kurban_bayram(day: int) -> bool:
	var s := ramazan_start(year(day)) + 34
	return _abs(day) >= s and _abs(day) < s + 4
func is_bayram(day: int) -> bool: return is_ramazan_bayram(day) or is_kurban_bayram(day)
func is_arife(day: int) -> bool: return not is_bayram(day) and is_bayram(day + 1)
func is_school_start(day: int) -> bool: return season(day) == 2 and season_day(day) <= 5

func label(day: int) -> String:
	return "%s · %s %d" % [WEEKDAYS[weekday(day)], SEASONS[season(day)], season_day(day)]

## the special thing about this day, shown on the time pill and the day report
func special(day: int) -> Dictionary:
	if is_ramazan(day): return {"id": "ramazan", "name": "Ramazan", "desc": "Gündüz sakin, iftardan önce (17:30–19:30) ekmek ve pide kuyruğu. Hurma talebi dört katı.", "icon": "moon"}
	if is_ramazan_bayram(day): return {"id": "bayram", "name": "Ramazan Bayramı", "desc": "Bayram şekeri ve çikolata talebi 2,5 katı; mahallenin yarısı memlekette.", "icon": "star"}
	if is_kurban_bayram(day): return {"id": "bayram", "name": "Kurban Bayramı", "desc": "Mahalle sakin, bayram ziyaretine gidenler çikolata ve kola alıyor.", "icon": "star"}
	if is_arife(day): return {"id": "arife", "name": "Arife", "desc": "Bayram öncesi herkes alışverişte: müşteri +%30.", "icon": "cart"}
	if is_school_start(day): return {"id": "okul", "name": "Okullar açıldı", "desc": "Defter talebi dört katı, öğrenciler akın ediyor.", "icon": "book"}
	if is_weekend(day): return {"id": "haftasonu", "name": "Hafta sonu", "desc": "Aileler ve haftalık alışverişçiler daha çok, beyaz yakalar az.", "icon": "people"}
	return {}

# ------------------------------------------------------------------ weather
func roll_weather(day: int) -> String:
	var o: Array = ODDS[season(day)]
	var r := randf()
	var keys := ["gunes", "sicak", "bulut", "yagmur", "kar"]
	for i in keys.size():
		r -= float(o[i])
		if r <= 0.0: return keys[i]
	return "gunes"

## called when a new day starts: today's weather is yesterday's forecast (mostly right)
func advance(day: int) -> void:
	weather = tomorrow if randf() < 0.85 else roll_weather(day)
	tomorrow = roll_weather(day + 1)

func weather_info(w := "") -> Dictionary: return WEATHER[w if w != "" else weather]

# ------------------------------------------------------------------ demand
## multiplier on how many shoppers arrive right now
func traffic(day: int, hour: float, arch_id := "") -> float:
	var t: float = WEATHER[weather]["traffic"]
	if is_weekend(day):
		t *= 1.2
		if arch_id == "calisan": t *= 0.5
		elif arch_id == "aile" or arch_id == "haftalik": t *= 1.5
	if is_arife(day): t *= 1.3
	if is_bayram(day): t *= 0.85
	if is_school_start(day) and arch_id == "ogrenci": t *= 1.5
	if is_ramazan(day):
		if hour < 16.0: t *= 0.8
		elif hour >= 17.5 and hour < 19.5: t *= 1.8
	return t

## multiplier on how much a shopper wants a product today
func demand(day: int, hour: float, pid: String) -> float:
	var s := season(day)
	var m := 1.0
	match pid:
		"dondurma": m = [0.8, 2.0, 0.6, 0.15][s] * (1.7 if weather == "sicak" else (0.6 if weather in ["yagmur", "kar"] else 1.0))
		"salep": m = [0.6, 0.1, 1.0, 2.2][s] * (1.8 if weather == "kar" else 1.0)
		"su", "kola", "ayran": m = 1.5 if weather == "sicak" else (1.15 if s == 1 else 1.0)
		"defter": m = 4.0 if is_school_start(day) else 0.6
		"semsiye": m = 8.0 if weather == "yagmur" else (2.0 if weather == "kar" else 0.2)
		"hurma": m = 4.0 if is_ramazan(day) else 0.4
		"pide": m = (2.5 if hour >= 16.5 and hour < 19.5 else 1.0) if is_ramazan(day) else 0.0
		"ekmek": m = 1.8 if is_ramazan(day) and hour >= 16.5 and hour < 19.5 else 1.0
		"cikolata", "biskuvi": m = 2.5 if is_bayram(day) or is_arife(day) else 1.0
		"gazete": m = 1.3 if is_weekend(day) else 1.0
	return m

func product_active(day: int, pid: String) -> bool:
	return not DB.product(pid).get("only_season", false) or is_ramazan(day)

## is it worth ordering this for tomorrow? (keeps the auto-order from buying pide in July)
func expected(day: int, pid: String) -> float:
	var m := demand(day, 12.0, pid)
	if pid == "pide": m = 1.5 if is_ramazan(day) else 0.0
	return m
