extends Node2D

# CRUMB - tiny ant, giant house. Attach to a Node2D (640x360 viewport).
# Journey through 3 settings, grab crumbs (+time), dodge giant feet, get home before time runs out.
# Playable with placeholder shapes. Drop PNGs into res://art/ and they replace the shapes:
#   ant.png  ant_carrying.png  ant_squished.png  crumb.png  giant_foot.png
#   floor_1.png  floor_2.png  floor_3.png  nest.png  nest_ending.png
# Optional font: res://art/Itim-Regular.ttf

const W = 640
const H = 360
const STAGES = 3          # how many settings (needs floor_1 ... floor_N)
const NEED = 5            # crumbs you must carry to the final nest
const TIME_START = 40.0   # seconds on the clock at the start
const TIME_BONUS = 3.0    # seconds gained per crumb
const HIT_RADIUS = 45.0

var STAGE_NAMES = ["the kitchen", "the living room", "the backyard"]
var TILE_A = [Color("#FAFAFA"), Color("#DDB08F"), Color("#98DB90")]
var TILE_B = [Color("#D9D4D7"), Color("#D99490"), Color("#6EA36E")]

var WHITE = Color("#FAFAFA")
var GREY = Color("#D9D4D7")
var DARK = Color("#2E2A30")
var BROWN = Color("#4F4A47")
var PINK = Color("#DB90D2")
var TEAL = Color("#009E8C")
var SALMON = Color("#D99490")
var PEACH = Color("#DDB08F")
var GREEN = Color("#98DB90")
var PURPLE = Color("#745EB0")
var BERRY = Color("#96557A")

var state = "title"
var over_reason = "stomp"
var stage = 0
var ant = Vector2(40, 200)
var face = 1
var moving = false
var walk_t = 0.0
var carried = 0
var time_left = TIME_START
var stage_banner = 0.0
var spawn_timer = 2.0
var time = 0.0
var end_time = 0.0
var crumbs_on_floor = []
var stomps = []
var tex = {}
var font = null
var panel_style = null
var green_style = null
var art_style = null


func _ready():
	randomize()
	if ResourceLoader.exists("res://art/Itim-Regular.ttf"):
		font = load("res://art/Itim-Regular.ttf")
	else:
		font = ThemeDB.fallback_font
	panel_style = make_box(WHITE, DARK, 3, 12)
	green_style = make_box(GREEN, DARK, 3, 10)
	art_style = make_box(PEACH, DARK, 3, 14)
	new_run()


func make_box(fill, border, width, radius):
	var sb = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


func new_run():
	stage = 0
	ant = Vector2(40, 200)
	carried = 0
	time_left = TIME_START
	stage_banner = 2.0
	spawn_timer = 2.0
	stomps = []
	spawn_crumbs()


func next_stage():
	stage += 1
	ant.x = 20.0
	stomps = []
	spawn_timer = 1.5
	stage_banner = 2.0
	spawn_crumbs()


func spawn_crumbs():
	crumbs_on_floor = []
	for i in range(6):
		crumbs_on_floor.append(Vector2(randf_range(80.0, 540.0), randf_range(90.0, 340.0)))


func get_tex(n):
	if not tex.has(n):
		var path = "res://art/" + n + ".png"
		if ResourceLoader.exists(path):
			tex[n] = load(path)
		else:
			tex[n] = null
	return tex[n]


func lose(reason):
	state = "over"
	over_reason = reason
	end_time = time


func _process(delta):
	time += delta
	if state != "play":
		if Input.is_action_just_pressed("ui_accept") and time - end_time > 0.4:
			new_run()
			state = "play"
		queue_redraw()
		return

	# the clock
	time_left -= delta
	stage_banner -= delta
	if time_left <= 0.0:
		time_left = 0.0
		lose("time")
		queue_redraw()
		return

	# movement: arrows or wasd, hold shift to sneak
	var dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1
	if dir.x != 0:
		face = 1 if dir.x > 0 else -1
	var sneak = Input.is_physical_key_pressed(KEY_SHIFT)
	var speed = max(50.0, 150.0 - carried * 12.0)
	if sneak:
		speed *= 0.5
	ant += dir.normalized() * speed * delta
	moving = dir != Vector2.ZERO
	if moving:
		walk_t += delta * speed / 150.0 * 3.0
	ant.x = clamp(ant.x, 10.0, W - 10.0)
	ant.y = clamp(ant.y, 80.0, H - 10.0)

	# pick up crumbs (+time)
	for i in range(crumbs_on_floor.size() - 1, -1, -1):
		if ant.distance_to(crumbs_on_floor[i]) < 16.0:
			crumbs_on_floor.remove_at(i)
			carried += 1
			time_left += TIME_BONUS

	# reach the right edge: next setting, or home on the last one
	if stage < STAGES - 1:
		if ant.x >= W - 12.0:
			next_stage()
	else:
		if ant.x > W - 60.0 and carried >= NEED:
			state = "win"
			end_time = time

	# giant feet: harder in later settings, aim near you, worse aim if you sneak
	var diff = stage * 2.5
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = max(0.7, 2.2 - diff * 0.2)
		var spread = 130.0 if sneak else 25.0
		var target = ant + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * spread
		target.x = clamp(target.x, 50.0, W - 50.0)
		target.y = clamp(target.y, 90.0, H - 40.0)
		stomps.append({"pos": target, "t": 0.0, "warn": max(0.6, 1.3 - diff * 0.08), "hit": false})

	for s in stomps:
		s["t"] += delta
		if not s["hit"] and s["t"] >= s["warn"]:
			s["hit"] = true
			if ant.distance_to(s["pos"]) < HIT_RADIUS:
				lose("stomp")
	stomps = stomps.filter(func(s): return s["t"] < s["warn"] + 0.4)

	queue_redraw()


# ---------- drawing helpers ----------

func text_in(rect, msg, size, color):
	var y = rect.position.y + rect.size.y / 2.0 + size * 0.35
	draw_string(font, Vector2(rect.position.x, y), msg, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


func draw_button(rect, msg):
	draw_style_box(green_style, rect)
	text_in(rect, msg, 20, DARK)


func draw_img(n, pos, size, fallback_color, flip = false, rot = 0.0):
	var tx = get_tex(n)
	if flip:
		draw_set_transform(pos, rot, Vector2(-1.0, 1.0))
	else:
		draw_set_transform(pos, rot, Vector2(1.0, 1.0))
	if tx != null:
		var sc = min(size.x / tx.get_width(), size.y / tx.get_height())
		var sz = Vector2(tx.get_width(), tx.get_height()) * sc
		draw_texture_rect(tx, Rect2(-sz / 2.0, sz), false)
	else:
		draw_circle(Vector2.ZERO, min(size.x, size.y) / 2.0, fallback_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))


func draw_art(n, rect):
	var tx = get_tex(n)
	if tx != null:
		var sc = min(rect.size.x / tx.get_width(), rect.size.y / tx.get_height())
		var sz = Vector2(tx.get_width(), tx.get_height()) * sc
		draw_texture_rect(tx, Rect2(rect.position + (rect.size - sz) / 2.0, sz), false)
	else:
		draw_style_box(art_style, rect)
		text_in(rect, "[ " + n + " ]", 14, DARK)


func draw_full(n):
	# keeps the picture's own shape; any leftover side space gets a soft peach color
	var tx = get_tex(n)
	draw_rect(Rect2(0, 0, W, H), Color("#EFD5C9"))
	var sc = min(float(W) / tx.get_width(), float(H) / tx.get_height())
	var sz = Vector2(tx.get_width(), tx.get_height()) * sc
	draw_texture_rect(tx, Rect2((Vector2(W, H) - sz) / 2.0, sz), false)


func draw_world():
	var floor_tex = get_tex("floor_" + str(stage + 1))
	if floor_tex != null:
		draw_texture_rect(floor_tex, Rect2(0, 0, W, H), false)
	else:
		draw_rect(Rect2(0, 0, W, H), TILE_B[stage])
		for gx in range(0, W, 64):
			for gy in range(0, H, 64):
				if (gx / 64 + gy / 64) % 2 == 0:
					draw_rect(Rect2(gx, gy, 64, 64), TILE_A[stage])
	if stage == STAGES - 1:
		draw_img("home", Vector2(W - 40, 200), Vector2(120, 120), DARK)
	else:
		var bob = sin(time * 6.0) * 4.0
		draw_string(font, Vector2(W - 44 + bob, 210), ">>", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, BROWN)
	for c in crumbs_on_floor:
		draw_img("crumb", c, Vector2(18, 18), PINK, false, time * 1.5 + c.x)


func draw_ant_game():
	var flip = face < 0
	var base = "ant"
	if carried > 0 and get_tex("ant_carrying") != null:
		base = "ant_carrying"
	var img = base
	var bob = 0.0
	var tilt = 0.0
	# no standing picture drawn? stand still using walk frame 1
	if get_tex(base) == null and get_tex(base + "_walk_1") != null:
		img = base + "_walk_1"
	if moving:
		# use drawn walk frames if they exist: ant_walk_1/2, ant_carrying_walk_1/2
		var frame_name = base + "_walk_" + str(int(walk_t * 2.0) % 2 + 1)
		if get_tex(frame_name) != null:
			img = frame_name
		else:
			# no frames drawn: hop and wiggle the single sprite instead
			bob = -abs(sin(walk_t * TAU)) * 2.5
			tilt = sin(walk_t * TAU) * 0.12
	var size = Vector2(84, 84)
	if base == "ant_carrying":
		size = Vector2(88, 88)
	draw_img(img, ant + Vector2(0, bob), size, TEAL, flip, tilt)
	if base == "ant":
		for i in range(min(carried, 8)):
			draw_img("crumb", ant + Vector2(0, -22.0 - i * 10.0 + bob), Vector2(14, 14), PINK)


func draw_hud():
	# left panel: crumbs + journey bar
	draw_style_box(panel_style, Rect2(12, 12, 236, 56))
	draw_img("crumb", Vector2(36, 40), Vector2(22, 22), PINK)
	draw_string(font, Vector2(58, 32), "carrying", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DARK)
	draw_string(font, Vector2(58, 58), str(carried), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, DARK)
	draw_line(Vector2(124, 24), Vector2(124, 56), GREY, 2.0)
	draw_rect(Rect2(136, 27, 14, 8), PEACH)
	draw_colored_polygon(PackedVector2Array([Vector2(133, 27), Vector2(143, 19), Vector2(153, 27)]), SALMON)
	draw_string(font, Vector2(160, 34), "home", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DARK)
	# journey progress: which setting you're in + how far across it
	var progress = clamp((stage + clamp(ant.x / W, 0.0, 1.0)) / float(STAGES), 0.0, 1.0)
	draw_style_box(make_box(GREY, DARK, 2, 8), Rect2(134, 42, 104, 16))
	if progress > 0.0:
		var fill_w = max(16.0, 104.0 * progress)
		draw_style_box(make_box(GREEN, DARK, 2, 8), Rect2(134, 42, fill_w, 16))

	# timer panel
	draw_style_box(panel_style, Rect2(W - 100, 12, 88, 44))
	var tcol = BERRY if time_left < 10.0 else DARK
	text_in(Rect2(W - 100, 12, 88, 44), str(int(ceil(time_left))) + "s", 26, tcol)

	# setting name banner
	if stage_banner > 0.0:
		draw_style_box(panel_style, Rect2(210, 76, 220, 30))
		text_in(Rect2(210, 76, 220, 30), STAGE_NAMES[stage], 18, DARK)

	# last setting: remind how many crumbs the colony needs
	if stage == STAGES - 1 and ant.x > W - 200.0 and carried < NEED:
		draw_style_box(panel_style, Rect2(120, 300, 400, 34))
		text_in(Rect2(120, 300, 400, 34), "need " + str(NEED) + " crumbs to feed the colony!", 16, DARK)


func _draw():
	# full-screen drawn endings (optional): gameover.png and win.png
	if state == "over" and get_tex("gameover") != null:
		draw_full("gameover")
		return
	if state == "win":
		if get_tex("win") != null:
			draw_full("win")
			return
		if get_tex("winning") != null:
			draw_full("winning")
			return

	if state == "over":
		draw_rect(Rect2(0, 0, W, H), WHITE)
		draw_style_box(panel_style, Rect2(6, 6, W - 12, H - 12))
		if over_reason == "time":
			text_in(Rect2(120, 40, 400, 42), "out of time!", 32, DARK)
			draw_art("ant", Rect2(230, 98, 180, 80))
		else:
			text_in(Rect2(120, 40, 400, 42), "squished!", 32, DARK)
			draw_art("ant_squished", Rect2(230, 98, 180, 80))
		text_in(Rect2(100, 194, 440, 28), "you made it to " + STAGE_NAMES[stage] + ".", 16, DARK)
		draw_button(Rect2(150, 252, 340, 44), "press space to try again")
		return

	if state == "win":
		draw_rect(Rect2(0, 0, W, H), WHITE)
		draw_style_box(panel_style, Rect2(6, 6, W - 12, H - 12))
		text_in(Rect2(50, 28, 540, 40), "the colony eats tonight", 32, DARK)
		draw_art("nest_ending", Rect2(120, 86, 400, 150))
		text_in(Rect2(150, 244, 340, 24), "you brought " + str(carried) + " crumbs home.", 16, DARK)
		draw_button(Rect2(210, 292, 220, 44), "play again")
		return

	if state == "title" and get_tex("title") != null:
		draw_full("title")
		return

	draw_world()

	if state == "title":
		var title_ant = "ant_carrying" if get_tex("ant_carrying") != null else "ant"
		draw_img(title_ant, Vector2(320, 185), Vector2(90, 90), TEAL)
		text_in(Rect2(190, 38, 260, 58), "crumb", 48, DARK)
		text_in(Rect2(180, 100, 280, 24), "i'm just a little guy", 16, BROWN)
		draw_button(Rect2(170, 246, 300, 48), "press space to start")
		text_in(Rect2(100, 310, 440, 24), "arrows / wasd to move  -  shift to sneak  -  crumbs = +time", 14, BROWN)
		return

	draw_ant_game()

	# giant feet: growing shadow circle, then the foot lands
	for s in stomps:
		if not s["hit"]:
			var r = lerp(12.0, HIT_RADIUS, s["t"] / s["warn"])
			draw_circle(s["pos"], r, Color(DARK, 0.45))
		else:
			draw_img("giant_foot", s["pos"], Vector2(110, 110), PURPLE)

	draw_hud()
