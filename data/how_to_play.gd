extends RefCounted
## HOW TO PLAY text. There are two versions: keyboard words on desktop, touch
## words on phones (GameState.is_mobile_ui()), never mixed. Edit the text
## here; the title screen fills its How to Play window from text().

const BLUE := "#5aa8ff"
const RED := "#ff6155"
const GOLD := "#ffd24d"
const GREEN := "#6be38a"


static func _key(k: String) -> String:
	return "[bgcolor=#33405e][color=#ffffff][b] %s [/b][/color][/bgcolor]" % k


static func _c(text: String, color: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [color, text]


static func text(mobile: bool, head_size: int) -> String:
	var T := _c("Tubig", BLUE)
	var S := _c("Sili", RED)
	var h := func(title: String, color: String) -> String:
		return "[font_size=%d][b][color=%s]%s[/color][/b][/font_size]\n" % [head_size, color, title]
	var out := "[center][color=#9aa4b8][i]A Filipino quiz maze: run, answer, and save your friends![/i][/color][/center]\n\n"

	out += h.call("ROLES", GOLD)
	out += "• 2 players → both are %s and a [b]bot Sili[/b] chases you.\n" % T
	out += "• 3–4 players → %s   ·   5–6 players → %s. Everyone else is %s.\n" % [_c("1 Sili", RED), _c("2 Silis", RED), T]
	out += "• The %s role rotates every round. A countdown shows your role before each round.\n\n" % S

	out += h.call("TUBIG TEAM", BLUE)
	out += "• Goal: answer %s about Filipino culture before time runs out.\n" % _c("10 questions", GREEN)
	out += "• Time: [b]3:00[/b] for 1 %s, [b]20 s less[/b] for each extra %s — you can answer at the same time.\n" % [T, T]
	if mobile:
		out += "• Walk into a [b]? scroll[/b] to get a question. [b]Tap[/b] answer A, B, C or D.\n"
	else:
		out += "• Walk into a [b]? scroll[/b] to get a question. Click an answer or press %s %s %s %s.\n" % [_key("A"), _key("B"), _key("C"), _key("D")]
	out += "• %s on your MAPA show where the scrolls are. The %s can't see them — but may be waiting there!\n" % [_c("Yellow dots", GOLD), S]
	out += "• While you answer you [b]can't move[/b] and [b]can't be tagged[/b].\n"
	out += "• A %s is near? You get a warning: %s then %s\n" % [S, _c("SILI NEARBY!", "#ffa53d"), _c("RUN!", RED)]
	out += "• Caught %ss freeze into an [b]ice block[/b].\n" % T
	out += "• %s touch a frozen teammate and answer [b]1 question[/b] to splash them free.\n" % _c("Buhos-Tubig:", GREEN)
	out += "• %s nobody can save you? Answer [b]2 hard questions in a row[/b] to thaw yourself.\n\n" % _c("Huling Hirit:", GREEN)

	out += h.call("QUIZ STATIONS", GOLD)
	if mobile:
		out += "Stations are in [b]new spots every round[/b]. Stand at one and tap [b]USE[/b] to get its question.\n"
	else:
		out += "Stations are in [b]new spots every round[/b]. Stand at one and press %s to get its question.\n" % _key("E")
	out += "• %s (%s only): [b]Yelo Shield[/b] for 10 s. A %s who tags you is [b]extinguished[/b] for 5 s!\n" % [_c("Halo-Halo coolers", "#8fdcff"), T, S]
	out += "• %s (%s only): solve a [b]bugtong[/b] for [b]Extra Anghang[/b] — faster, wider reach for 6 s.\n" % [_c("Bicol Express peppers", RED), S]
	out += "• %s (anyone): answer to squeeze through the shortcut. Wrong = sour spray, slowed 3 s.\n\n" % _c("Kalamansi gates", "#c4f040")

	out += h.call("ASKING FOR HELP", GREEN)
	if mobile:
		out += "• Stuck? Tap [b]ASK A TEAMMATE FOR HELP[/b].\n"
		out += "• The [b]first free teammate[/b] who taps [b]YES[/b] gets your question — and you are free to run.\n\n"
	else:
		out += "• Stuck? Click [b]ASK A TEAMMATE FOR HELP[/b] or press %s.\n" % _key("H")
		out += "• The [b]first free teammate[/b] who says YES (%s) gets your question — and you are free to run. %s = no.\n\n" % [_key("Y"), _key("N")]

	out += h.call("SILI", RED)
	out += "• Touch %ss to freeze them. Win by freezing [b]ALL[/b] of them at the same time, or when time runs out.\n" % T
	out += "• The top bar shows [b]Frozen: 1 / 3[/b].\n\n"

	out += h.call("PLAYING", GOLD)
	out += "• [b]SOLO VS BOT[/b]: 4 rounds, easy to difficult (1–3 bots). Win to unlock the next round; lose and retry. Your round is saved: next time choose RESUME or NEW GAME.\n"
	out += "• [b]LAN[/b]: one player picks [b]HOST GAME[/b]; the others pick [b]JOIN GAME[/b] (same Wi-Fi or phone hotspot).\n"
	out += "• [b]Leaving[/b]: the door button asks first. Solo — any time. LAN host — any time, but it [b]ends the game for everyone[/b]. Other players — after the round.\n\n"

	out += h.call("CONTROLS", GOLD)
	if mobile:
		out += "• [b]Drag on the right half[/b] of the screen to move. Hold [b]RUN[/b] (bottom left) to sprint.\n"
		out += "• Tap [b]USE[/b] at a station. Tap an answer. Tap [b]YES / NO[/b] on a help request.\n"
		out += "• Top right: [b]door[/b] = leave, [b]pause[/b] (host), [b]gear[/b] = settings. The phone's [b]Back[/b] button pauses or closes a window."
	else:
		out += "%s or arrows — move      %s or %s — sprint\n" % [_key("W A S D"), _key("Shift"), _key("Space")]
		out += "%s %s %s %s — answer (1–4 also work)      %s — use a station\n" % [_key("A"), _key("B"), _key("C"), _key("D"), _key("E")]
		out += "%s — ask for help      %s / %s — answer a help request\n" % [_key("H"), _key("Y"), _key("N")]
		out += "%s — pause (host) or close a window"  % _key("Esc")
	return out
