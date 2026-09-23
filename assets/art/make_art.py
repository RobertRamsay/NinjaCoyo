import math
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_PATH = "Fredoka-var.ttf"  # Fredoka (SIL Open Font License), from github.com/google/fonts
S = 2  # supersampling factor
random.seed(11)


def font(size):
    f = ImageFont.truetype(FONT_PATH, int(size * S))
    f.set_variation_by_name("Bold")
    return f


def sc(points):
    return [(x * S, y * S) for x, y in points]


def shade(colour, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in colour[:3])


def vertical_gradient(img, box, top, bottom):
    x0, y0, x1, y1 = [v * S for v in box]
    draw = ImageDraw.Draw(img)
    height = y1 - y0
    for i in range(height):
        t = i / max(1, height - 1)
        c = tuple(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3))
        draw.line([(x0, y0 + i), (x1, y0 + i)], fill=c)


def radial_glow(img, centre, radius, colour, strength):
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    cx, cy = centre
    steps = 60
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(strength * (1 - i / steps) ** 1.6)
        d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=colour + (a,))
    img.alpha_composite(glow)


def block(draw, x, y, w, h, colour, depth=0.0, outline=True):
    """Blocky Roblox-style box: front face with a lighter top and darker right side."""
    d = depth
    if d > 0:
        top = [(x, y), (x + w, y), (x + w + d, y - d), (x + d, y - d)]
        side = [(x + w, y), (x + w + d, y - d), (x + w + d, y + h - d), (x + w, y + h)]
        draw.polygon(sc(top), fill=shade(colour, 1.18), outline=(25, 20, 30) if outline else None)
        draw.polygon(sc(side), fill=shade(colour, 0.72), outline=(25, 20, 30) if outline else None)
    draw.rectangle([x * S, y * S, (x + w) * S, (y + h) * S], fill=colour, outline=(25, 20, 30) if outline else None, width=S * 2 if outline else 0)


def rotated_rect(cx, cy, length, width, angle_deg, anchor_start=True):
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)
    px, py = -uy, ux
    if anchor_start:
        sx, sy = cx, cy
    else:
        sx, sy = cx - ux * length / 2, cy - uy * length / 2
    ex, ey = sx + ux * length, sy + uy * length
    hw = width / 2
    return [(sx + px * hw, sy + py * hw), (ex + px * hw, ey + py * hw), (ex - px * hw, ey - py * hw), (sx - px * hw, sy - py * hw)], (ex, ey)


def coin(img, x, y, r, tilt=0.0):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    squash = max(0.25, abs(math.cos(tilt)))
    rw, rh = r * squash, r
    # edge
    d.ellipse([(x - rw + 6 * squash) * S, (y - rh) * S, (x + rw + 6 * squash) * S, (y + rh) * S], fill=(200, 140, 20, 255))
    d.ellipse([(x - rw) * S, (y - rh) * S, (x + rw) * S, (y + rh) * S], fill=(255, 205, 50, 255), outline=(150, 95, 10, 255), width=S * 3)
    d.ellipse([(x - rw * 0.72) * S, (y - rh * 0.72) * S, (x + rw * 0.72) * S, (y + rh * 0.72) * S], outline=(235, 170, 30, 255), width=S * 3)
    # scroll across the face
    d.rounded_rectangle([(x - rw * 0.55) * S, (y - rh * 0.16) * S, (x + rw * 0.55) * S, (y + rh * 0.16) * S], radius=int(rh * 0.14 * S), fill=(245, 232, 195, 255), outline=(150, 110, 60, 255), width=S * 2)
    # shine
    d.ellipse([(x - rw * 0.55) * S, (y - rh * 0.7) * S, (x - rw * 0.15) * S, (y - rh * 0.35) * S], fill=(255, 245, 200, 170))
    img.alpha_composite(layer)


def sparkle(img, x, y, size, colour=(255, 250, 210)):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i
        rr = size if i % 2 == 0 else size * 0.25
        pts.append((x + math.cos(ang) * rr, y + math.sin(ang) * rr))
    d.polygon(sc(pts), fill=colour + (235,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(S * 0.6)))


def sakura_tree(img, x, base_y, height, flip=False):
    d = ImageDraw.Draw(img)
    trunk = (95, 60, 45)
    lean = -40 if flip else 40
    d.polygon(sc([(x - 18, base_y), (x + 18, base_y), (x + 10 + lean, base_y - height), (x - 10 + lean, base_y - height)]), fill=trunk)
    d.polygon(sc([(x + lean * 0.6, base_y - height * 0.6), (x + lean * 0.6 + (70 if not flip else -70), base_y - height * 0.95), (x + lean * 0.6 + (60 if not flip else -60), base_y - height), (x + lean * 0.6 - 10, base_y - height * 0.62)]), fill=trunk)
    cx, cy = x + lean, base_y - height
    for i in range(26):
        r = random.uniform(55, 95)
        ox, oy = random.uniform(-170, 170), random.uniform(-90, 70)
        colour = random.choice([(255, 183, 206), (255, 160, 195), (255, 200, 220), (245, 150, 185)])
        d.ellipse([(cx + ox - r) * S, (cy + oy - r) * S, (cx + ox + r) * S, (cy + oy + r) * S], fill=colour)


def petals(img, count, area):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = area
    for i in range(count):
        x, y = random.uniform(x0, x1), random.uniform(y0, y1)
        r = random.uniform(5, 11)
        d.ellipse([(x - r) * S, (y - r * 0.6) * S, (x + r) * S, (y + r * 0.6) * S], fill=(255, 190, 215, random.randint(150, 230)))
    img.alpha_composite(layer)


def outlined_text(img, xy, text, size, fill_top, fill_bottom, stroke, stroke_colour, anchor="mm", shadow=True):
    f = font(size)
    x, y = xy[0] * S, xy[1] * S
    if shadow:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((x + 10 * S, y + 12 * S), text, font=f, fill=(20, 10, 30, 170), anchor=anchor, stroke_width=stroke * S, stroke_fill=(20, 10, 30, 170))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6 * S)))
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(base).text((x, y), text, font=f, fill=stroke_colour, anchor=anchor, stroke_width=stroke * S, stroke_fill=stroke_colour)
    img.alpha_composite(base)
    # gradient fill clipped to the glyphs
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=f, fill=255, anchor=anchor)
    bbox = mask.getbbox()
    grad = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    top, bottom = bbox[1], bbox[3]
    for yy in range(top, bottom):
        t = (yy - top) / max(1, bottom - top - 1)
        c = tuple(int(fill_top[k] + (fill_bottom[k] - fill_top[k]) * t) for k in range(3))
        gd.line([(bbox[0], yy), (bbox[2], yy)], fill=c + (255,))
    img.paste(grad, (0, 0), mask)


# ----------------------------------------------------------------------------
# Characters
# ----------------------------------------------------------------------------

NINJA_DARK = (38, 38, 46)
NINJA_RED = (200, 30, 40)
SKIN = (234, 184, 146)
GOLD = (250, 195, 45)


def draw_ninja(img, fx, fy, k):
    """Blocky ninja standing with feet at (fx, fy); k = scale."""
    d = ImageDraw.Draw(img)
    dep = 22 * k
    leg_w, leg_h = 58 * k, 170 * k
    torso_w, torso_h = 150 * k, 175 * k
    head = 132 * k
    # legs
    block(d, fx - leg_w - 4 * k, fy - leg_h, leg_w, leg_h, NINJA_DARK, dep)
    block(d, fx + 4 * k, fy - leg_h, leg_w, leg_h, NINJA_DARK, dep)
    # shoes
    block(d, fx - leg_w - 8 * k, fy - 24 * k, leg_w + 8 * k, 24 * k, (20, 20, 24), dep * 0.6)
    block(d, fx + 4 * k, fy - 24 * k, leg_w + 8 * k, 24 * k, (20, 20, 24), dep * 0.6)
    # left arm (down, holding nothing)
    tx = fx - torso_w / 2
    ty = fy - leg_h - torso_h
    block(d, tx - 56 * k, ty + 6 * k, 54 * k, 160 * k, NINJA_DARK, dep)
    block(d, tx - 56 * k, ty + 150 * k, 54 * k, 34 * k, SKIN, dep * 0.8)
    # torso
    block(d, tx, ty, torso_w, torso_h, NINJA_DARK, dep)
    # red sash
    block(d, tx, ty + torso_h - 52 * k, torso_w, 34 * k, NINJA_RED, dep)
    d.polygon(sc([(tx + torso_w * 0.62, ty + torso_h - 20 * k), (tx + torso_w * 0.78, ty + torso_h - 20 * k), (tx + torso_w * 0.84, ty + torso_h + 40 * k), (tx + torso_w * 0.66, ty + torso_h + 34 * k)]), fill=NINJA_RED, outline=(25, 20, 30))
    # collar V
    d.polygon(sc([(tx + torso_w * 0.3, ty), (tx + torso_w * 0.5, ty + 50 * k), (tx + torso_w * 0.7, ty)]), fill=(60, 60, 72))
    # head
    hx = fx - head / 2 + 6 * k
    hy = ty - head - 4 * k
    block(d, hx, hy, head, head, NINJA_DARK, dep)
    # face opening with eyes
    d.rectangle([(hx + 14 * k) * S, (hy + head * 0.36) * S, (hx + head - 14 * k) * S, (hy + head * 0.58) * S], fill=SKIN)
    for ex in (hx + head * 0.3, hx + head * 0.7):
        d.rounded_rectangle([(ex - 16 * k) * S, (hy + head * 0.41) * S, (ex + 16 * k) * S, (hy + head * 0.53) * S], radius=int(5 * k * S), fill=(255, 255, 255))
        d.ellipse([(ex - 7 * k) * S, (hy + head * 0.42) * S, (ex + 9 * k) * S, (hy + head * 0.53) * S], fill=(20, 20, 30))
    # determined eyebrows
    d.line(sc([(hx + head * 0.16, hy + head * 0.35), (hx + head * 0.42, hy + head * 0.4)]), fill=(20, 20, 26), width=int(6 * k * S))
    d.line(sc([(hx + head * 0.84, hy + head * 0.35), (hx + head * 0.58, hy + head * 0.4)]), fill=(20, 20, 26), width=int(6 * k * S))
    # headband with flowing ties
    block(d, hx - 3 * k, hy + head * 0.12, head + 6 * k, head * 0.16, NINJA_RED, dep)
    tie1, _ = rotated_rect(hx + head + dep, hy + head * 0.18, 120 * k, 18 * k, -8)
    tie2, _ = rotated_rect(hx + head + dep, hy + head * 0.22, 100 * k, 16 * k, 14)
    d.polygon(sc(tie1), fill=NINJA_RED, outline=(25, 20, 30))
    d.polygon(sc(tie2), fill=shade(NINJA_RED, 0.8), outline=(25, 20, 30))
    # right arm raised holding the katana
    shoulder = (tx + torso_w + 10 * k, ty + 26 * k)
    arm, hand = rotated_rect(shoulder[0], shoulder[1], 150 * k, 54 * k, -52)
    d.polygon(sc(arm), fill=NINJA_DARK, outline=(25, 20, 30))
    d.ellipse([(hand[0] - 26 * k) * S, (hand[1] - 26 * k) * S, (hand[0] + 26 * k) * S, (hand[1] + 26 * k) * S], fill=SKIN, outline=(25, 20, 30), width=S * 2)
    # katana: grip, guard, long blade
    grip, grip_end = rotated_rect(hand[0] - 30 * k, hand[1] + 40 * k, 90 * k, 16 * k, -55)
    d.polygon(sc(grip), fill=(30, 20, 20), outline=(10, 10, 10))
    guard, _ = rotated_rect(grip_end[0] - 22 * k, grip_end[1] - 14 * k, 44 * k, 16 * k, 35)
    d.polygon(sc(guard), fill=GOLD, outline=(120, 80, 10))
    blade, tip = rotated_rect(grip_end[0], grip_end[1], 185 * k, 18 * k, -55)
    d.polygon(sc(blade), fill=(225, 232, 240), outline=(90, 100, 115))
    edge, _ = rotated_rect(grip_end[0] + 3 * k, grip_end[1] + 2 * k, 175 * k, 5 * k, -55)
    d.polygon(sc(edge), fill=(255, 255, 255))
    return tip


def draw_coyo(img, fx, fy, k):
    """Blocky Coyo (side view facing left) with feet at fy, body centred on fx."""
    d = ImageDraw.Draw(img)
    fur = (190, 145, 95)
    dark = (115, 85, 58)
    light = (238, 220, 190)
    dep = 20 * k
    bw, bh = 250 * k, 110 * k
    leg_h = 80 * k
    bx, by = fx - bw / 2, fy - leg_h - bh
    # tail (behind), raised and bushy
    tail, _ = rotated_rect(bx + bw - 10 * k, by + 30 * k, 115 * k, 52 * k, -38)
    d.polygon(sc(tail), fill=dark, outline=(25, 20, 30))
    # back legs (far side)
    for lx in (bx + 20 * k, bx + bw - 60 * k):
        block(d, lx + 14 * k, fy - leg_h, 34 * k, leg_h, shade(fur, 0.8), 0)
    # body
    block(d, bx, by, bw, bh, fur, dep)
    # chest patch
    d.rectangle([(bx) * S, (by + bh * 0.45) * S, (bx + 70 * k) * S, (by + bh) * S], fill=light)
    # near legs
    for lx in (bx + 12 * k, bx + bw - 70 * k):
        block(d, lx, fy - leg_h, 36 * k, leg_h, fur, dep * 0.5)
        block(d, lx - 2 * k, fy - 18 * k, 42 * k, 18 * k, dark, dep * 0.4)
    # head
    head = 118 * k
    hx, hy = bx - head * 0.55, by - head * 0.62
    # ears
    for ex in (hx + head * 0.18, hx + head * 0.62):
        d.polygon(sc([(ex, hy + 4 * k), (ex + 26 * k, hy - 52 * k), (ex + 44 * k, hy + 4 * k)]), fill=dark, outline=(25, 20, 30))
    block(d, hx, hy, head, head, fur, dep)
    # snout
    block(d, hx - 58 * k, hy + head * 0.46, 64 * k, head * 0.4, light, dep * 0.7)
    d.rounded_rectangle([(hx - 64 * k) * S, (hy + head * 0.44) * S, (hx - 40 * k) * S, (hy + head * 0.6) * S], radius=int(6 * k * S), fill=(25, 20, 25))
    # happy open mouth with tongue
    d.polygon(sc([(hx - 50 * k, hy + head * 0.86), (hx - 8 * k, hy + head * 0.86), (hx - 18 * k, hy + head * 1.02), (hx - 40 * k, hy + head * 1.02)]), fill=(120, 30, 40))
    d.ellipse([(hx - 42 * k) * S, (hy + head * 0.9) * S, (hx - 16 * k) * S, (hy + head * 1.12) * S], fill=(240, 110, 130))
    # eye
    d.ellipse([(hx + head * 0.18) * S, (hy + head * 0.3) * S, (hx + head * 0.38) * S, (hy + head * 0.52) * S], fill=(20, 20, 26))
    d.ellipse([(hx + head * 0.21) * S, (hy + head * 0.32) * S, (hx + head * 0.28) * S, (hy + head * 0.39) * S], fill=(255, 255, 255))
    # headband and ties
    block(d, hx - 2 * k, hy + head * 0.08, head + 4 * k, head * 0.17, NINJA_RED, dep)
    tie1, _ = rotated_rect(hx + head + dep * 0.7, hy + head * 0.14, 100 * k, 16 * k, -12)
    tie2, _ = rotated_rect(hx + head + dep * 0.7, hy + head * 0.18, 80 * k, 14 * k, 12)
    d.polygon(sc(tie1), fill=NINJA_RED, outline=(25, 20, 30))
    d.polygon(sc(tie2), fill=shade(NINJA_RED, 0.8), outline=(25, 20, 30))


def draw_torii(img, cx, base_y, width, height):
    d = ImageDraw.Draw(img)
    red = (205, 38, 38)
    black = (28, 26, 30)
    post_w = width * 0.085
    for side in (-1, 1):
        px = cx + side * width * 0.36 - post_w / 2
        block(d, px, base_y - height, post_w, height, red, post_w * 0.25)
        block(d, px - post_w * 0.2, base_y - height * 0.1, post_w * 1.4, height * 0.1, black, post_w * 0.25)
    # tie beam (nuki)
    block(d, cx - width * 0.46, base_y - height * 0.78, width * 0.92, height * 0.07, red, post_w * 0.2)
    # top beams: red shimaki and black upswept kasagi
    block(d, cx - width * 0.54, base_y - height * 1.0, width * 1.08, height * 0.08, red, post_w * 0.2)
    lift = height * 0.09
    top = base_y - height * 1.0
    kasagi = [
        (cx - width * 0.62, top - lift * 1.9), (cx, top - lift * 0.95), (cx + width * 0.62, top - lift * 1.9),
        (cx + width * 0.6, top - lift * 1.1), (cx, top - lift * 0.05), (cx - width * 0.6, top - lift * 1.1),
    ]
    d.polygon(sc(kasagi), fill=black, outline=(10, 10, 12))
    # central tablet
    block(d, cx - width * 0.06, base_y - height * 0.93, width * 0.12, height * 0.16, black, 0)
    d.rectangle([(cx - width * 0.045) * S, (base_y - height * 0.91) * S, (cx + width * 0.045) * S, (base_y - height * 0.79) * S], fill=GOLD)


# ----------------------------------------------------------------------------
# Thumbnail 1920x1080
# ----------------------------------------------------------------------------

def make_thumbnail(path):
    W, H = 1920, 1080
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 255))
    vertical_gradient(img, (0, 0, W, 680), (55, 125, 225), (205, 232, 255))
    radial_glow(img, (1340, 360), 420, (255, 240, 180), 230)
    d = ImageDraw.Draw(img)

    # far mountains with snow caps
    far = [(0, 640), (120, 470), (260, 560), (420, 400), (600, 560), (760, 450), (930, 590), (1100, 430), (1300, 580), (1480, 410), (1680, 560), (1820, 470), (1920, 540), (1920, 700), (0, 700)]
    d.polygon(sc(far), fill=(135, 172, 205))
    for peak in [(120, 470), (420, 400), (760, 450), (1100, 430), (1480, 410), (1820, 470)]:
        px, py = peak
        d.polygon(sc([(px, py), (px - 45, py + 50), (px - 20, py + 40), (px, py + 58), (px + 22, py + 40), (px + 48, py + 52)]), fill=(245, 248, 255))
    near = [(0, 700), (180, 560), (380, 650), (560, 590), (760, 680), (980, 610), (1180, 690), (1420, 600), (1640, 680), (1920, 580), (1920, 760), (0, 760)]
    d.polygon(sc(near), fill=(78, 140, 92))

    # ground
    vertical_gradient(img, (0, 690, W, H), (120, 190, 85), (62, 128, 50))
    d = ImageDraw.Draw(img)
    # stone path to the torii
    d.polygon(sc([(1310, 765), (1470, 765), (1700, 1080), (1080, 1080)]), fill=(168, 160, 145))
    for i in range(70):
        t = random.random()
        yy = 770 + t * 300
        half = 90 + t * 230
        xx = 1390 + random.uniform(-half, half) * 0.9
        r = 8 + t * 22
        d.ellipse([(xx - r) * S, (yy - r * 0.5) * S, (xx + r) * S, (yy + r * 0.5) * S], fill=random.choice([(150, 142, 128), (185, 178, 162), (140, 134, 120)]))

    draw_torii(img, 1390, 770, 470, 360)
    sakura_tree(img, 95, 900, 420, flip=False)
    sakura_tree(img, 1840, 880, 400, flip=True)

    # grass tufts
    d = ImageDraw.Draw(img)
    for i in range(160):
        x = random.uniform(0, W)
        y = random.uniform(760, H)
        h = random.uniform(14, 34)
        c = random.choice([(90, 165, 65), (70, 145, 55), (110, 185, 75)])
        d.polygon(sc([(x - 5, y), (x, y - h), (x + 5, y)]), fill=c)

    # soft ground shadows under the heroes
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.ellipse([370 * S, 1000 * S, 730 * S, 1060 * S], fill=(20, 40, 20, 110))
    sd.ellipse([880 * S, 990 * S, 1270 * S, 1045 * S], fill=(20, 40, 20, 110))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10 * S)))

    draw_coyo(img, 1110, 1015, 1.25)
    tip = draw_ninja(img, 540, 1030, 1.15)
    sparkle(img, tip[0], tip[1], 46)

    # flying scroll-coins
    for (x, y, r, tilt) in [(900, 560, 46, 0.3), (1000, 450, 36, 1.0), (1180, 600, 30, 0.6), (1270, 470, 28, 1.25), (250, 580, 40, 0.2), (170, 420, 30, 0.9), (1590, 470, 42, 0.5), (1720, 640, 32, 1.1), (1500, 690, 26, 0.4), (220, 760, 30, 0.7)]:
        coin(img, x, y, r, tilt)
    for (x, y, s) in [(950, 500, 22), (300, 500, 18), (1640, 420, 20), (880, 310, 14), (1760, 600, 16)]:
        sparkle(img, x, y, s)

    petals(img, 90, (0, 0, W, H))

    # title and tagline
    outlined_text(img, (960, 150), "NinjaCoyo", 210, (255, 235, 120), (255, 150, 30), 16, (45, 20, 55, 255))
    banner_w, banner_y = 900, 300
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([(960 - banner_w / 2) * S, (banner_y - 36) * S, (960 + banner_w / 2) * S, (banner_y + 36) * S], radius=36 * S, fill=(200, 30, 40), outline=(45, 20, 55), width=6 * S)
    outlined_text(img, (960, banner_y + 2), "Collect  •  Fight  •  Grow Your Wolf Pack", 44, (255, 255, 255), (255, 240, 220), 5, (45, 20, 55, 255), shadow=False)

    final = img.resize((W, H), Image.LANCZOS).convert("RGB")
    final.save(path, quality=95)


# ----------------------------------------------------------------------------
# Icon 512x512
# ----------------------------------------------------------------------------

def make_icon(path):
    W = 512
    img = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 255))
    vertical_gradient(img, (0, 0, W, W), (220, 45, 50), (120, 15, 30))
    # sunburst
    rays = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    cx, cy = 256, 250
    for i in range(18):
        a0 = i * (2 * math.pi / 18)
        a1 = a0 + math.pi / 18
        rd.polygon(sc([(cx, cy), (cx + math.cos(a0) * 500, cy + math.sin(a0) * 500), (cx + math.cos(a1) * 500, cy + math.sin(a1) * 500)]), fill=(255, 200, 80, 55))
    img.alpha_composite(rays)
    radial_glow(img, (256, 250), 230, (255, 220, 120), 160)

    d = ImageDraw.Draw(img)
    # katana crossing behind the head
    blade, _ = rotated_rect(70, 440, 470, 22, -45)
    d.polygon(sc(blade), fill=(225, 232, 240), outline=(80, 90, 105))
    grip, _ = rotated_rect(40, 470, 70, 22, -45)
    d.polygon(sc(grip), fill=(30, 20, 20))
    guard, _ = rotated_rect(98, 412, 60, 18, 45, anchor_start=False)
    d.polygon(sc(guard), fill=GOLD, outline=(120, 80, 10))

    # Coyo's face, front view
    fur = (195, 150, 100)
    dark = (115, 85, 58)
    light = (240, 222, 192)
    hx, hy, hs = 146, 150, 220
    # pointy ears with a lighter inner ear
    d.polygon(sc([(hx + 4, hy + 16), (hx + 30, hy - 72), (hx + 92, hy + 16)]), fill=dark, outline=(25, 20, 30))
    d.polygon(sc([(hx + 26, hy + 12), (hx + 36, hy - 38), (hx + 70, hy + 12)]), fill=(230, 170, 150))
    d.polygon(sc([(hx + hs - 4, hy + 16), (hx + hs - 30, hy - 72), (hx + hs - 92, hy + 16)]), fill=dark, outline=(25, 20, 30))
    d.polygon(sc([(hx + hs - 26, hy + 12), (hx + hs - 36, hy - 38), (hx + hs - 70, hy + 12)]), fill=(230, 170, 150))
    block(d, hx, hy, hs, hs, fur, 0)
    # muzzle
    block(d, hx + 55, hy + 118, 110, 80, light, 0)
    d.rounded_rectangle([(hx + 88) * S, (hy + 118) * S, (hx + 132) * S, (hy + 146) * S], radius=10 * S, fill=(25, 20, 25))
    d.line(sc([(hx + 110, hy + 146), (hx + 110, hy + 168)]), fill=(25, 20, 25), width=5 * S)
    d.arc([(hx + 80) * S, (hy + 150) * S, (hx + 112) * S, (hy + 182) * S], 0, 150, fill=(25, 20, 25), width=5 * S)
    d.arc([(hx + 108) * S, (hy + 150) * S, (hx + 140) * S, (hy + 182) * S], 30, 180, fill=(25, 20, 25), width=5 * S)
    d.ellipse([(hx + 98) * S, (hy + 172) * S, (hx + 122) * S, (hy + 200) * S], fill=(240, 110, 130))
    # eyes
    for ex in (hx + 62, hx + 158):
        d.ellipse([(ex - 20) * S, (hy + 70) * S, (ex + 20) * S, (hy + 112) * S], fill=(20, 20, 26))
        d.ellipse([(ex - 12) * S, (hy + 76) * S, (ex - 2) * S, (hy + 88) * S], fill=(255, 255, 255))
    # headband with ties
    block(d, hx - 6, hy + 22, hs + 12, 36, NINJA_RED, 0)
    tie1, _ = rotated_rect(hx + hs + 4, hy + 40, 90, 20, 20)
    tie2, _ = rotated_rect(hx + hs + 4, hy + 44, 80, 18, 50)
    d.polygon(sc(tie1), fill=NINJA_RED, outline=(25, 20, 30))
    d.polygon(sc(tie2), fill=shade(NINJA_RED, 0.8), outline=(25, 20, 30))
    d.ellipse([(hx + hs / 2 - 16) * S, (hy + 24) * S, (hx + hs / 2 + 16) * S, (hy + 56) * S], fill=GOLD, outline=(120, 80, 10), width=2 * S)

    coin(img, 410, 410, 62, 0.25)
    sparkle(img, 452, 350, 22)
    sparkle(img, 90, 120, 18)

    final = img.resize((W, W), Image.LANCZOS).convert("RGB")
    final.save(path)


make_thumbnail("NinjaCoyo_Thumbnail.png")
make_icon("NinjaCoyo_Icon.png")
print("done")
