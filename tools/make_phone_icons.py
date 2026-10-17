"""Draws every phone icon (original artwork, CC0): apps, 13 sector tiles, 71 job tiles (glyph per job on the sector colour),
pet and avatar layers, HUD smartphone. Run after tools/gen_content.py: python3 tools/make_phone_icons.py"""
from PIL import Image, ImageDraw, ImageFont
import os, math, json
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ui/phone"); os.makedirs(OUT, exist_ok=True)
S = 1024; W = (255, 255, 255, 255)
FB = os.path.join(ROOT, "fonts/Nunito.ttf")
def font(sz):
    f = ImageFont.truetype(FB, sz)
    try: f.set_variation_by_axes([900])
    except Exception: pass
    return f
def tile(c1, c2):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); g = Image.new("RGBA", (S, S))
    for y in range(S):
        t = y / S; g.paste(tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,), (0, y, S, y + 1))
    m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, S - 1, S - 1), 230, fill=255)
    im.paste(g, (0, 0), m); return im, ImageDraw.Draw(im)
def save(im, n, sz=256): im.resize((sz, sz), Image.LANCZOS).save(f"{OUT}/{n}.png")
def E(d, cx, cy, r, f): d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=f)
def RR(d, b, r, f): d.rounded_rectangle(b, r, fill=f)
def cross(d, cx, cy, a, b, col): RR(d, (cx - a, cy - b, cx + a, cy + b), a * .4, col); RR(d, (cx - b, cy - a, cx + b, cy + a), a * .4, col)
def wheel(d, cx, cy, r, col, hub): E(d, cx, cy, r, col); E(d, cx, cy, r * .45, hub)
def star(d, cx, cy, ro, ri, col, n=5):
    pts = [(cx + (ro if i % 2 == 0 else ri) * math.cos(-math.pi / 2 + i * math.pi / n), cy + (ro if i % 2 == 0 else ri) * math.sin(-math.pi / 2 + i * math.pi / n)) for i in range(2 * n)]
    d.polygon(pts, fill=col)
# ---------------- glyphs: g(d, bg) draws white artwork; bg = dark accent of the tile
def g_house(d, bg): d.polygon([(512, 150), (880, 470), (144, 470)], fill=W); RR(d, (230, 440, 794, 860), 40, W); RR(d, (450, 620, 574, 860), 30, bg); RR(d, (300, 540, 400, 640), 16, bg); RR(d, (624, 540, 724, 640), 16, bg)
def g_cross(d, bg): cross(d, 512, 512, 110, 300, W)
def g_stethoscope(d, bg):
    d.arc((300, 180, 724, 640), 0, 180, fill=W, width=60); d.line((330, 200, 330, 410), fill=W, width=60); d.line((694, 200, 694, 410), fill=W, width=60)
    d.line((512, 640, 512, 720), fill=W, width=60); d.arc((512, 560, 780, 860), 90, 180, fill=W, width=60); E(d, 770, 650, 90, W); E(d, 770, 650, 40, bg)
    E(d, 330, 200, 40, W); E(d, 694, 200, 40, W)
def g_nursecap(d, bg): d.polygon([(220, 640), (290, 300), (734, 300), (804, 640)], fill=W); RR(d, (200, 600, 824, 720), 40, W); cross(d, 512, 460, 48, 120, bg)
def g_tooth(d, bg):
    E(d, 390, 380, 170, W); E(d, 634, 380, 170, W); d.rectangle((260, 380, 764, 560), fill=W)
    d.polygon([(260, 500), (764, 500), (700, 860), (600, 860), (540, 640), (484, 640), (424, 860), (324, 860)], fill=W)
def g_pill(d, bg):
    pill = Image.new("RGBA", (S, S)); pd = ImageDraw.Draw(pill); RR(pd, (180, 400, 844, 624), 112, W); pd.rectangle((512, 400, 844, 624), fill=(255, 255, 255, 150))
    return pill.rotate(40, center=(512, 512))
def g_paw(d, bg):
    E(d, 512, 640, 180, W); d.ellipse((330, 500, 694, 820), fill=W)
    for x, y in [(300, 420), (430, 300), (594, 300), (724, 420)]: E(d, x, y, 80, W)
def g_ambulance(d, bg):
    RR(d, (130, 320, 700, 740), 50, W); d.polygon([(700, 420), (820, 420), (900, 560), (900, 740), (700, 740)], fill=W)
    RR(d, (730, 450, 830, 560), 20, bg); cross(d, 410, 520, 40, 120, bg); wheel(d, 300, 760, 80, (50, 50, 60), (200, 200, 205)); wheel(d, 740, 760, 80, (50, 50, 60), (200, 200, 205))
def g_board(d, bg):
    RR(d, (170, 230, 854, 700), 50, W); RR(d, (210, 270, 814, 660), 30, (46, 125, 90))
    d.text((512, 465), "ABC", font=font(230), fill=W, anchor="mm"); d.rectangle((300, 700, 340, 820), fill=W); d.rectangle((684, 700, 724, 820), fill=W)
def g_gradcap(d, bg):
    d.polygon([(512, 230), (900, 420), (512, 610), (124, 420)], fill=W); d.polygon([(300, 520), (724, 520), (724, 720), (512, 800), (300, 720)], fill=W)
    d.line((860, 420, 860, 680), fill=W, width=30); E(d, 860, 700, 45, W)
def g_books(d, bg):
    for x, h, c in [(200, 560, W), (360, 500, (255, 255, 255, 210)), (520, 600, W)]: RR(d, (x, 820 - h, x + 140, 820), 20, c); d.rectangle((x + 20, 820 - h + 60, x + 120, 820 - h + 90), fill=bg)
    p = Image.new("RGBA", (S, S)); ImageDraw.Draw(p).rounded_rectangle((680, 300, 820, 820), 20, fill=(255, 255, 255, 230)); return p.rotate(-14, center=(750, 820))
def g_blocks(d, bg):
    for (x, y, t) in [(190, 520, "A"), (520, 520, "B"), (355, 210, "C")]: RR(d, (x, y, x + 310, y + 310), 40, W); d.text((x + 155, y + 155), t, font=font(220), fill=bg, anchor="mm")
def g_chefhat(d, bg):
    for cx, cy, r in [(360, 400, 150), (512, 330, 175), (664, 400, 150)]: E(d, cx, cy, r, W)
    d.rectangle((300, 420, 724, 690), fill=W); RR(d, (290, 700, 734, 800), 30, W)
def g_pan(d, bg):
    E(d, 420, 540, 260, W); E(d, 420, 540, 190, bg); E(d, 420, 540, 150, W); RR(d, (640, 500, 930, 580), 40, W)
def g_cloche(d, bg):
    d.chord((210, 300, 814, 900), 180, 360, fill=W); RR(d, (150, 610, 874, 680), 30, W); E(d, 512, 290, 50, W); RR(d, (120, 720, 904, 760), 20, W)
def g_bread(d, bg):
    d.chord((150, 330, 874, 900), 180, 360, fill=W); d.rectangle((180, 610, 844, 760), fill=W)
    for x in [370, 512, 654]: d.line((x - 40, 450, x + 40, 560), fill=bg, width=36)
def g_cup(d, bg):
    RR(d, (230, 380, 700, 820), 90, W); d.rectangle((230, 380, 700, 520), fill=W); d.arc((600, 460, 860, 700), 270, 90, fill=W, width=60)
    for x in [370, 512]: d.arc((x - 40, 140, x + 40, 340), 90, 270, fill=W, width=34)
def g_cleaver(d, bg):
    RR(d, (180, 280, 700, 620), 40, W); E(d, 290, 380, 40, bg); RR(d, (680, 380, 900, 500), 40, W)
def g_bus(d, bg):
    RR(d, (170, 220, 854, 760), 80, W); RR(d, (230, 290, 494, 500), 30, (110, 170, 240)); RR(d, (530, 290, 794, 500), 30, (110, 170, 240))
    RR(d, (230, 560, 330, 620), 20, (255, 190, 40)); RR(d, (694, 560, 794, 620), 20, (255, 190, 40))
    wheel(d, 320, 770, 85, (50, 50, 60), (200, 200, 205)); wheel(d, 704, 770, 85, (50, 50, 60), (200, 200, 205))
def g_taxi(d, bg):
    RR(d, (400, 200, 624, 290), 30, W); d.polygon([(270, 330), (754, 330), (850, 540), (174, 540)], fill=W); RR(d, (120, 500, 904, 740), 70, W)
    d.polygon([(320, 380), (500, 380), (500, 520), (260, 520)], fill=bg); d.polygon([(524, 380), (704, 380), (764, 520), (524, 520)], fill=bg)
    wheel(d, 300, 750, 90, (50, 50, 60), (200, 200, 205)); wheel(d, 724, 750, 90, (50, 50, 60), (200, 200, 205))
def g_plane(d, bg):
    p = Image.new("RGBA", (S, S)); pd = ImageDraw.Draw(p)
    RR(pd, (452, 120, 572, 900), 60, W); pd.polygon([(140, 600), (512, 380), (884, 600), (884, 660), (512, 540), (140, 660)], fill=W)
    pd.polygon([(340, 880), (512, 780), (684, 880), (684, 920), (340, 920)], fill=W); return p.rotate(-45, center=(512, 512))
def g_suitcase(d, bg):
    d.rounded_rectangle((400, 180, 624, 320), 50, outline=W, width=50); RR(d, (220, 290, 804, 820), 70, W)
    for x in [370, 654]: d.rectangle((x - 20, 290, x + 20, 820), fill=bg)
def g_train(d, bg):
    RR(d, (250, 160, 774, 760), 110, W); RR(d, (310, 240, 714, 470), 40, bg); E(d, 370, 620, 50, bg); E(d, 654, 620, 50, bg)
    d.polygon([(330, 760), (410, 760), (300, 900), (220, 900)], fill=W); d.polygon([(614, 760), (694, 760), (804, 900), (724, 900)], fill=W)
def g_box(d, bg):
    d.polygon([(512, 180), (860, 340), (512, 500), (164, 340)], fill=W); d.polygon([(164, 380), (490, 530), (490, 880), (164, 730)], fill=(255, 255, 255, 230))
    d.polygon([(860, 380), (534, 530), (534, 880), (860, 730)], fill=W); d.polygon([(330, 260), (680, 420), (680, 520), (330, 360)], fill=bg)
def g_star(d, bg): star(d, 512, 530, 340, 150, (255, 210, 80)); E(d, 512, 530, 80, bg); E(d, 512, 530, 50, (255, 210, 80))
def g_flame(d, bg):
    d.polygon([(512, 140), (760, 470), (800, 640), (512, 900), (224, 640), (300, 420), (400, 540)], fill=W); E(d, 512, 680, 220, W)
    d.polygon([(512, 520), (640, 700), (512, 840), (384, 700)], fill=bg)
def g_shield(d, bg): d.polygon([(512, 140), (840, 260), (800, 600), (512, 890), (224, 600), (184, 260)], fill=W); d.polygon([(512, 230), (750, 320), (720, 580), (512, 790)], fill=(255, 255, 255, 160))
def g_shieldstar(d, bg): g_shield(d, bg); star(d, 512, 500, 190, 80, bg)
def g_buoy(d, bg):
    E(d, 512, 512, 330, W); E(d, 512, 512, 160, bg)
    for a in [45, 135, 225, 315]: d.pieslice((182, 182, 842, 842), a - 18, a + 18, fill=(255, 110, 100))
    E(d, 512, 512, 160, bg)
def g_bag(d, bg):
    d.arc((372, 180, 652, 460), 180, 360, fill=W, width=50); d.polygon([(250, 330), (774, 330), (820, 830), (204, 830)], fill=W)
    E(d, 385, 435, 35, bg); E(d, 639, 435, 35, bg)
def g_cart(d, bg):
    d.line((130, 250, 260, 250, 340, 640, 800, 640), fill=W, width=60, joint="curve"); d.polygon([(250, 320), (880, 320), (820, 560), (310, 560)], fill=W)
    E(d, 380, 760, 70, W); E(d, 760, 760, 70, W)
def g_stall(d, bg):
    for i in range(5): d.chord((150 + i * 145, 250, 150 + (i + 1) * 145, 420), 0, 180, fill=W if i % 2 == 0 else (255, 120, 110))
    d.rectangle((150, 200, 875, 330), fill=W); d.rectangle((190, 420, 230, 860), fill=W); d.rectangle((794, 420, 834, 860), fill=W)
    RR(d, (150, 640, 874, 720), 20, W); E(d, 360, 580, 70, (255, 110, 100)); E(d, 520, 580, 70, (255, 200, 60)); E(d, 680, 580, 70, (120, 210, 90))
def g_flower(d, bg):
    d.line((512, 520, 512, 900), fill=W, width=50); d.chord((512, 640, 760, 820), 90, 270, fill=W)
    for a in range(0, 360, 60): E(d, 512 + 140 * math.cos(math.radians(a)), 380 + 140 * math.sin(math.radians(a)), 105, W)
    E(d, 512, 380, 90, (255, 210, 80))
def g_book(d, bg):
    d.polygon([(150, 260), (500, 300), (500, 820), (150, 780)], fill=W); d.polygon([(874, 260), (524, 300), (524, 820), (874, 780)], fill=W)
    for y in [400, 500, 600]: d.line((210, y, 440, y + 20), fill=bg, width=22); d.line((584, y + 20, 814, y), fill=bg, width=22)
def g_building(d, bg):
    RR(d, (260, 150, 764, 880), 30, W)
    for r in range(5):
        for c in range(3): RR(d, (320 + c * 140, 220 + r * 120, 400 + c * 140, 290 + r * 120), 10, bg)
def g_calculator(d, bg):
    RR(d, (250, 130, 774, 890), 70, W); RR(d, (320, 200, 704, 380), 30, bg)
    for r in range(3):
        for c in range(3): RR(d, (320 + c * 135, 440 + r * 140, 430 + c * 135, 540 + r * 140), 24, bg)
def g_envelope(d, bg): RR(d, (150, 260, 874, 760), 50, W); d.line((180, 300, 512, 560, 844, 300), fill=bg, width=40, joint="curve")
def g_tie(d, bg):
    d.polygon([(420, 160), (604, 160), (560, 300), (464, 300)], fill=W); d.polygon([(464, 320), (560, 320), (660, 760), (512, 900), (364, 760)], fill=W)
    d.line((380, 600, 640, 480), fill=bg, width=30)
def g_scales(d, bg):
    d.rectangle((492, 180, 532, 820), fill=W); RR(d, (330, 800, 694, 860), 20, W); d.rectangle((180, 270, 844, 310), fill=W); E(d, 512, 200, 50, W)
    for x in [260, 764]: d.line((x, 300, x - 100, 560), fill=W, width=14); d.line((x, 300, x + 100, 560), fill=W, width=14); d.chord((x - 140, 460, x + 140, 660), 0, 180, fill=W)
def g_bell(d, bg):
    d.chord((200, 280, 824, 900), 180, 360, fill=W); RR(d, (140, 590, 884, 680), 30, W); RR(d, (470, 220, 554, 300), 20, W); RR(d, (180, 720, 844, 780), 20, W)
def g_bank(d, bg):
    d.polygon([(512, 150), (880, 350), (144, 350)], fill=W); RR(d, (160, 760, 864, 850), 20, W)
    for x in [220, 380, 540, 700]: RR(d, (x, 390, x + 100, 740), 20, W)
def g_code(d, bg): d.text((512, 500), "</>", font=font(400), fill=W, anchor="mm")
def g_gear(d, bg):
    for i in range(8):
        a = i * math.pi / 4; d.line((512 + 210 * math.cos(a), 512 + 210 * math.sin(a), 512 + 330 * math.cos(a), 512 + 330 * math.sin(a)), fill=W, width=130)
    E(d, 512, 512, 280, W); E(d, 512, 512, 110, bg)
def g_monitor(d, bg):
    RR(d, (140, 200, 884, 680), 50, W); RR(d, (200, 260, 824, 620), 20, bg); d.polygon([(450, 680), (574, 680), (614, 820), (410, 820)], fill=W); RR(d, (330, 800, 694, 860), 25, W)
    RR(d, (260, 320, 560, 360), 15, W); RR(d, (260, 400, 760, 440), 15, (255, 255, 255, 170)); RR(d, (260, 480, 660, 520), 15, (255, 255, 255, 170))
def g_flask(d, bg):
    RR(d, (400, 150, 624, 210), 20, W); d.rectangle((440, 200, 584, 420), fill=W); d.polygon([(440, 400), (584, 400), (820, 820), (204, 820)], fill=W)
    RR(d, (190, 780, 834, 860), 40, W); d.polygon([(330, 620), (694, 620), (790, 800), (234, 800)], fill=(120, 230, 160))
def g_laptop(d, bg):
    RR(d, (220, 220, 804, 640), 40, W); RR(d, (270, 270, 754, 590), 20, bg); d.polygon([(120, 680), (904, 680), (840, 790), (184, 790)], fill=W)
    d.line((420, 360, 360, 430, 420, 500), fill=W, width=30); d.line((604, 360, 664, 430, 604, 500), fill=W, width=30)
def g_palette(d, bg):
    d.ellipse((140, 200, 884, 840), fill=W); E(d, 700, 640, 80, bg)
    for (x, y, c) in [(330, 430, (255, 90, 90)), (470, 320, (255, 200, 60)), (640, 360, (90, 180, 255)), (330, 610, (110, 200, 110))]: E(d, x, y, 65, c)
def g_note(d, bg):
    E(d, 330, 760, 120, W); E(d, 690, 680, 120, W); d.rectangle((410, 260, 450, 760), fill=W); d.rectangle((770, 180, 810, 680), fill=W); d.polygon([(410, 260), (810, 180), (810, 300), (410, 380)], fill=W)
def g_mic(d, bg):
    RR(d, (400, 140, 624, 560), 112, W); d.arc((300, 300, 724, 700), 0, 180, fill=W, width=44); d.rectangle((492, 690, 532, 830), fill=W); RR(d, (350, 810, 674, 870), 25, W)
    for y in [260, 340, 420]: d.line((430, y, 594, y), fill=bg, width=16)
def g_masks(d, bg):
    d.chord((150, 200, 560, 700), 0, 180, fill=W); d.rectangle((150, 200, 560, 450), fill=W); E(d, 260, 380, 40, bg); E(d, 450, 380, 40, bg); d.arc((250, 450, 460, 600), 20, 160, fill=bg, width=30)
    d.chord((470, 330, 880, 830), 0, 180, fill=(255, 255, 255, 220)); d.rectangle((470, 330, 880, 580), fill=(255, 255, 255, 220)); E(d, 580, 510, 40, bg); E(d, 770, 510, 40, bg); d.arc((570, 660, 780, 800), 200, 340, fill=bg, width=30)
def g_camera(d, bg):
    RR(d, (130, 300, 894, 800), 80, W); RR(d, (360, 220, 600, 320), 30, W); E(d, 512, 550, 190, bg); E(d, 512, 550, 120, W); E(d, 512, 550, 70, bg); E(d, 780, 390, 35, bg)
def g_newspaper(d, bg):
    RR(d, (160, 200, 864, 840), 40, W); RR(d, (220, 260, 804, 360), 15, bg); RR(d, (220, 420, 480, 640), 15, bg)
    for y in [430, 500, 570, 640, 720]: RR(d, (530, y, 804, y + 30), 10, bg)
    RR(d, (220, 720, 480, 750), 10, bg)
def g_pen(d, bg):
    p = Image.new("RGBA", (S, S)); pd = ImageDraw.Draw(p); RR(pd, (430, 120, 594, 700), 40, W); pd.polygon([(430, 700), (594, 700), (512, 900)], fill=W)
    pd.rectangle((430, 230, 594, 270), fill=bg); return p.rotate(-35, center=(512, 512))
def g_hardhat(d, bg):
    d.chord((200, 260, 824, 900), 180, 360, fill=W); RR(d, (130, 560, 894, 650), 40, W); RR(d, (470, 250, 554, 590), 30, (255, 255, 255, 170))
def g_bolt(d, bg): d.polygon([(600, 120), (260, 580), (480, 580), (400, 900), (760, 420), (540, 420)], fill=W)
def g_drop(d, bg):
    d.polygon([(512, 130), (760, 520), (264, 520)], fill=W); E(d, 512, 620, 260, W); E(d, 430, 640, 60, (255, 255, 255, 140))
def g_wrench(d, bg):
    p = Image.new("RGBA", (S, S)); pd = ImageDraw.Draw(p); RR(pd, (452, 300, 572, 900), 60, W); E(pd, 512, 280, 190, W); pd.rectangle((462, 60, 562, 300), fill=(0, 0, 0, 0))
    return p.rotate(-40, center=(512, 512))
def g_hammer(d, bg):
    p = Image.new("RGBA", (S, S)); pd = ImageDraw.Draw(p); RR(pd, (470, 300, 554, 900), 40, W); RR(pd, (260, 160, 764, 340), 50, W); return p.rotate(-35, center=(512, 512))
def g_roller(d, bg):
    RR(d, (180, 160, 760, 360), 60, W); d.line((760, 260, 860, 260, 860, 470, 512, 520, 512, 620), fill=W, width=40, joint="curve"); RR(d, (470, 600, 554, 900), 40, W)
def g_tractor(d, bg):
    RR(d, (200, 430, 640, 640), 40, W); RR(d, (460, 250, 700, 520), 30, W); RR(d, (510, 290, 650, 430), 20, bg); d.rectangle((300, 330, 340, 440), fill=W)
    wheel(d, 640, 660, 160, (45, 60, 50), W); wheel(d, 300, 700, 110, (45, 60, 50), W)
def g_leaf(d, bg):
    p = Image.new("RGBA", (S, S)); pd = ImageDraw.Draw(p); pd.ellipse((300, 120, 724, 880), fill=W); pd.line((512, 220, 512, 960), fill=bg, width=36)
    for y in [380, 520, 660]: pd.line((512, y + 60, 400, y), fill=bg, width=24); pd.line((512, y + 60, 624, y), fill=bg, width=24)
    return p.rotate(-30, center=(512, 512))
def g_fish(d, bg):
    d.ellipse((150, 330, 700, 700), fill=W); d.polygon([(640, 512), (880, 330), (880, 700)], fill=W); E(d, 300, 470, 40, bg)
def g_scissors(d, bg):
    d.ellipse((200, 600, 440, 840), outline=W, width=50); d.ellipse((584, 600, 824, 840), outline=W, width=50)
    d.line((370, 620, 700, 160), fill=W, width=70); d.line((654, 620, 324, 160), fill=W, width=70); E(d, 512, 430, 30, bg)
def g_comb(d, bg):
    RR(d, (140, 300, 884, 460), 50, W)
    for i in range(10): RR(d, (170 + i * 70, 430, 210 + i * 70, 760), 20, W)
def g_heart(d, bg): E(d, 370, 400, 190, W); E(d, 654, 400, 190, W); d.polygon([(190, 460), (834, 460), (512, 860)], fill=W)
def g_pram(d, bg):
    d.pieslice((180, 220, 700, 740), 180, 270, fill=W); d.chord((180, 300, 840, 740), 0, 180, fill=W); d.rectangle((180, 470, 840, 520), fill=W)
    d.line((840, 520, 900, 300), fill=W, width=40); wheel(d, 330, 800, 80, W, bg); wheel(d, 700, 800, 80, W, bg)
def g_bucket(d, bg):
    d.polygon([(220, 380), (804, 380), (720, 860), (304, 860)], fill=W); d.arc((260, 180, 764, 600), 180, 360, fill=W, width=40); RR(d, (200, 350, 824, 420), 30, W)
    for x, y, r in [(420, 300, 60), (540, 260, 70), (650, 320, 50)]: E(d, x, y, r, (255, 255, 255, 180))
def g_ball(d, bg):
    E(d, 512, 512, 340, W); BK = (40, 50, 60)
    d.regular_polygon((512, 512, 120), 5, rotation=0, fill=BK)
    for k in range(5):
        a = -math.pi / 2 + k * 2 * math.pi / 5; x = 512 + 300 * math.cos(a); y = 512 + 300 * math.sin(a)
        d.regular_polygon((x, y, 85), 5, rotation=36, fill=BK); d.line((512 + 120 * math.cos(a), 512 + 120 * math.sin(a), 512 + 230 * math.cos(a), 512 + 230 * math.sin(a)), fill=BK, width=22)
    m = Image.new("RGBA", (S, S)); md = ImageDraw.Draw(m); md.ellipse((0, 0, S, S), fill=(0, 0, 0, 0))
def g_whistle(d, bg):
    E(d, 420, 600, 230, W); RR(d, (420, 370, 900, 540), 40, W); E(d, 420, 600, 90, bg); d.arc((150, 120, 500, 470), 120, 300, fill=W, width=30)
def g_dumbbell(d, bg):
    RR(d, (300, 470, 724, 554), 30, W)
    for x in [180, 744]: RR(d, (x, 300, x + 100, 724), 40, W)
    for x in [110, 844]: RR(d, (x, 380, x + 70, 644), 30, W)
def g_racket(d, bg):
    p = Image.new("RGBA", (S, S)); pd = ImageDraw.Draw(p); pd.ellipse((280, 100, 744, 620), outline=W, width=56); RR(pd, (472, 600, 552, 920), 40, W)
    for i in range(1, 6): pd.line((280 + i * 78, 130, 280 + i * 78, 590), fill=(255, 255, 255, 160), width=14); pd.line((300, 100 + i * 87, 724, 100 + i * 87), fill=(255, 255, 255, 160), width=14)
    q = p.rotate(-35, center=(512, 512)); ImageDraw.Draw(q).ellipse((700, 640, 860, 800), fill=(230, 250, 90)); return q
def g_waves(d, bg):
    for k, y in enumerate([380, 560, 740]):
        pts = [(x, y + 60 * math.sin(x / 70.0)) for x in range(140, 885, 10)]; d.line(pts, fill=W if k != 1 else (255, 255, 255, 190), width=70, joint="curve")
GLY = {k[2:]: v for k, v in globals().items() if k.startswith("g_")}
def draw(glyph, c1, c2, name, sz=256):
    im, d = tile(c1, c2); bg = tuple(max(0, int(c * .78)) for c in c2) + (255,)
    r = GLY[glyph](d, bg)
    if r is not None: im.alpha_composite(r)
    # keep the art inside the rounded tile
    m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, S - 1, S - 1), 230, fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(im, (0, 0), m); save(out, name, sz)
spec = json.load(open("/tmp/icon_spec.json")) if os.path.exists("/tmp/icon_spec.json") else None
data = json.load(open(os.path.join(ROOT, "data/jobs.json")))
SC = {}
import importlib.util
for sid, sg, c1, c2 in [(s[0], s[1], s[2], s[3]) for s in json.load(open("/tmp/icon_spec.json"))["sectors"]]:
    SC[sid] = (c1, c2); draw(sg, c1, c2, "s_" + sid, 160)
for j in data["jobs"]:
    g, s = j["icon"][2:].rsplit("_", 1); draw(g, *SC[s], j["icon"], 192)
for n, g, c1, c2 in json.load(open("/tmp/icon_spec.json")).get("tiles", []): draw(g, c1, c2, n, 192)
# ---------------- apps
def app(glyph_fn, c1, c2, n):
    im, d = tile(c1, c2); bg = tuple(int(c * .78) for c in c2) + (255,); glyph_fn(d, bg)
    m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, S - 1, S - 1), 230, fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(im, (0, 0), m); save(out, n)
def a_jobs(d, bg):
    d.rounded_rectangle((390, 220, 634, 380), 50, outline=W, width=50); RR(d, (170, 330, 854, 790), 70, W); d.rectangle((170, 520, 854, 560), fill=bg); RR(d, (462, 490, 562, 590), 20, bg)
def a_grammar(d, bg):
    d.polygon([(150, 260), (500, 300), (500, 820), (150, 780)], fill=W); d.polygon([(874, 260), (524, 300), (524, 820), (874, 780)], fill=W)
    d.text((330, 540), "A", font=font(260), fill=bg, anchor="mm"); d.text((700, 560), "a", font=font(260), fill=bg, anchor="mm")
def a_words(d, bg): RR(d, (150, 200, 874, 700), 140, W); d.polygon([(300, 650), (480, 680), (260, 860)], fill=W); d.text((512, 455), "abc", font=font(240), fill=bg, anchor="mm")
def a_me(d, bg): E(d, 512, 310, 140, W); d.chord((210, 500, 814, 1100), 180, 360, fill=W)
def a_family(d, bg):
    E(d, 330, 330, 110, W); d.chord((150, 470, 510, 900), 180, 360, fill=W); E(d, 694, 330, 110, W); d.chord((514, 470, 874, 900), 180, 360, fill=W)
    E(d, 512, 560, 85, (255, 255, 255, 235)); d.chord((372, 670, 652, 1000), 180, 360, fill=(255, 255, 255, 235))
def a_calendar(d, bg):
    RR(d, (170, 220, 854, 850), 70, W); d.rounded_rectangle((170, 220, 854, 400), 70, fill=(240, 80, 80)); d.rectangle((170, 330, 854, 400), fill=(240, 80, 80))
    RR(d, (300, 150, 360, 290), 25, W); RR(d, (664, 150, 724, 290), 25, W); d.text((512, 630), "7", font=font(380), fill=(60, 60, 75), anchor="mm")
app(a_jobs, (255, 170, 60), (245, 110, 40), "app_jobs"); app(a_grammar, (80, 200, 160), (30, 150, 120), "app_grammar")
app(a_words, (90, 160, 255), (60, 100, 235), "app_words"); app(a_me, (170, 130, 255), (120, 80, 230), "app_me")
app(a_family, (255, 140, 120), (235, 85, 100), "app_family"); app(a_calendar, (245, 245, 250), (220, 224, 235), "app_calendar")
# ---------------- pets: white silhouette (tinted in game) + dark detail layer
def pet(name, body, detail):
    a = Image.new("RGBA", (S, S)); body(ImageDraw.Draw(a)); save(a, "pet_" + name, 256)
    b = Image.new("RGBA", (S, S)); detail(ImageDraw.Draw(b)); save(b, "pet_" + name + "_d", 256)
K = (40, 34, 30, 255); PK = (255, 150, 160, 255)
def dog_b(d): d.ellipse((260, 520, 800, 860), fill=W); E(d, 400, 400, 210, W); d.ellipse((150, 260, 290, 560), fill=W); d.ellipse((500, 250, 640, 560), fill=W); RR(d, (300, 760, 380, 920), 30, W); RR(d, (640, 760, 720, 920), 30, W); d.line((790, 640, 900, 480), fill=W, width=50)
def dog_d(d): E(d, 340, 380, 28, K); E(d, 470, 380, 28, K); E(d, 405, 480, 40, K); d.arc((355, 470, 455, 560), 20, 160, fill=K, width=14)
def cat_b(d): d.ellipse((280, 520, 780, 880), fill=W); E(d, 450, 420, 200, W); d.polygon([(270, 330), (300, 140), (420, 260)], fill=W); d.polygon([(630, 330), (600, 140), (480, 260)], fill=W); d.arc((640, 450, 920, 860), 270, 90, fill=W, width=50)
def cat_d(d): E(d, 380, 400, 26, K); E(d, 520, 400, 26, K); d.polygon([(430, 470), (470, 470), (450, 495)], fill=PK)
def bird_b(d): E(d, 480, 560, 260, W); E(d, 600, 350, 150, W); d.polygon([(260, 560), (100, 470), (140, 650)], fill=W); RR(d, (420, 800, 450, 900), 10, W); RR(d, (520, 800, 550, 900), 10, W)
def bird_d(d): E(d, 630, 330, 26, K); d.polygon([(730, 330), (840, 370), (730, 400)], fill=(255, 170, 40)); d.arc((330, 470, 600, 700), 200, 340, fill=(0, 0, 0, 70), width=24)
def fish_b(d): d.ellipse((150, 330, 700, 700), fill=W); d.polygon([(640, 512), (880, 330), (880, 700)], fill=W); d.polygon([(380, 340), (520, 220), (560, 360)], fill=W)
def fish_d(d): E(d, 290, 470, 34, K); d.arc((360, 360, 520, 660), 300, 60, fill=(0, 0, 0, 60), width=20)
def rabbit_b(d): d.ellipse((270, 520, 760, 880), fill=W); E(d, 450, 450, 180, W); d.ellipse((330, 80, 430, 360), fill=W); d.ellipse((470, 80, 570, 360), fill=W); E(d, 770, 720, 70, W)
def rabbit_d(d): E(d, 390, 430, 24, K); E(d, 510, 430, 24, K); E(d, 450, 500, 20, PK); d.ellipse((355, 130, 405, 330), fill=(255, 170, 180, 160)); d.ellipse((495, 130, 545, 330), fill=(255, 170, 180, 160))
def hamster_b(d): d.ellipse((200, 330, 824, 860), fill=W); E(d, 330, 330, 80, W); E(d, 694, 330, 80, W)
def hamster_d(d): E(d, 410, 520, 28, K); E(d, 614, 520, 28, K); E(d, 512, 600, 22, PK); E(d, 330, 330, 40, PK); E(d, 694, 330, 40, PK); d.ellipse((380, 640, 644, 820), fill=(255, 255, 255, 180))
def turtle_b(d): E(d, 820, 560, 100, W); d.chord((200, 300, 800, 900), 180, 360, fill=W); RR(d, (180, 590, 820, 650), 30, W); RR(d, (260, 620, 340, 760), 30, W); RR(d, (660, 620, 740, 760), 30, W)
def turtle_d(d):
    E(d, 850, 540, 18, K)
    for (x, y) in [(400, 480), (600, 480), (500, 380)]: d.regular_polygon((x, y, 70), 6, fill=(0, 0, 0, 55))
for n in ["dog", "cat", "bird", "fish", "rabbit", "hamster", "turtle"]: pet(n, globals()[n + "_b"], globals()[n + "_d"])
# ---------------- avatar layers (tinted in game): body (clothes), head (skin), hair styles
def lay(n, f): a = Image.new("RGBA", (S, S)); f(ImageDraw.Draw(a)); save(a, n, 256)
lay("av_body", lambda d: d.chord((200, 600, 824, 1240), 180, 360, fill=W))
lay("av_head", lambda d: (E(d, 512, 450, 200, W), RR(d, (462, 560, 562, 700), 30, W)))
lay("av_face", lambda d: (E(d, 445, 460, 22, K), E(d, 579, 460, 22, K), d.arc((452, 480, 572, 570), 30, 150, fill=K, width=14)))
lay("av_hair0", lambda d: (d.chord((300, 230, 724, 600), 180, 360, fill=W), d.rectangle((300, 380, 340, 470), fill=W), d.rectangle((684, 380, 724, 470), fill=W)))
lay("av_hair1", lambda d: (d.chord((290, 220, 734, 620), 160, 380, fill=W), d.polygon([(300, 400), (520, 250), (420, 420)], fill=W)))
lay("av_hair2", lambda d: (d.chord((290, 220, 734, 620), 180, 360, fill=W), RR(d, (290, 380, 360, 760), 30, W), RR(d, (664, 380, 734, 760), 30, W)))
# ---------------- HUD: modern touchscreen smartphone (slim rounded body, edge-to-edge screen, no keypad)
im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
RR(d, (300, 70, 724, 954), 90, (32, 38, 58, 255)); RR(d, (322, 92, 702, 932), 72, (98, 132, 236, 255))
g = Image.new("RGBA", (S, S)); gd = ImageDraw.Draw(g); gd.polygon([(322, 92), (702, 92), (702, 300), (322, 640)], fill=(255, 255, 255, 50))
m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).rounded_rectangle((322, 92, 702, 932), 72, fill=255); im.paste(Image.alpha_composite(im, g), (0, 0), m)
d = ImageDraw.Draw(im); RR(d, (462, 118, 562, 146), 14, (32, 38, 58, 255)); RR(d, (452, 896, 572, 908), 6, (255, 255, 255, 200))
for i, (x, y) in enumerate([(370, 230), (470, 230), (570, 230), (370, 330), (470, 330), (570, 330)]): RR(d, (x, y, x + 76, y + 76), 20, (255, 255, 255, 225))
save(im, "hud_phone", 128)
print("icons:", len(os.listdir(OUT)))
