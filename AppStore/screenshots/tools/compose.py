"""Builds the App Store slides from the raw window captures.

Reads AppStore/screenshots/<locale>/raw/*.png and writes AppStore/screenshots/<locale>/APP_DESKTOP/NN.png.
usage: [LOCALES="en-US uk"] python3 compose.py [outdir]   (outdir replaces AppStore/screenshots for a dry run; LOCALES limits the run)
Needs Pillow and the system SF Pro font (/System/Library/Fonts/SFNS.ttf).
"""
import itertools
import os
import sys

from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageFont

SHOTS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = sys.argv[1] if len(sys.argv) > 1 else SHOTS

W, H = 2880, 1800
ACCENT = (255, 214, 10)
FLAG_BLUE, FLAG_YELLOW = (0, 87, 183), (255, 215, 0)
# Flag bands at 45 degrees in the bottom-left corner, bounded by the lines x - y = k.
FLAG_K = (-1340, -1490, -1640)
X_RIGHT, Y0, Y1 = 2820, 50, 1750
LEFT, GAP_TEXT, GAP_WINDOWS = 170, 80, 44

SLIDES = {
    "en-US": [
        (["menu-popover"], "Catch Whoever Touches Your Mac", "A photo or short video, taken silently"),
        (["settings-capture"], "Photo or Short Video", "Choose the type, quality and size"),
        (["settings-triggers"], "Triggers That Work While Locked", "Wake-up, login, USB and keyboard input"),
        (["settings-sync"], "Straight to Your Own Cloud", "iCloud, Dropbox and saved files"),
        (["settings-notifications"], "Alerts on Your iPhone", "Pair once, get every capture as a push"),
    ],
    "uk": [
        (["menu-popover"], "Побачте, хто чіпав ваш Mac", "Фото або коротке відео — тихо й миттєво"),
        (["settings-capture"], "Фото або коротке відео", "Тип, якість і розмір — на ваш вибір"),
        (["settings-triggers"], "Працює, поки Mac заблоковано", "Пробудження, вхід, USB і введення з клавіатури"),
        (["settings-sync"], "Одразу у вашу хмару", "iCloud, Dropbox і збережені файли"),
        (["settings-notifications"], "Сповіщення на iPhone", "Один раз сполучіть — і отримуйте кожен знімок"),
    ],
}

# Layouts tried in order until headline and subline both fit: (max window width, headline sizes, max headline lines).
LAYOUTS = (
    (1700, (124, 116, 108), 2),
    (1584, (124, 116, 108), 2),
    (1700, (124, 116, 108), 3),
    (1584, (124, 116, 108), 3),
    (1584, (100, 96), 3),
)


def font(size, weight):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
    f.set_variation_by_name(weight)
    return f


_background = None


def background():
    global _background
    if _background is None:
        bg = Image.new("RGB", (W, H))
        px = bg.load()
        for y in range(H):
            for x in range(W):
                k = x / W * 0.45 + y / H * 0.55
                px[x, y] = (int(27 - 16 * k), int(34 - 18 * k), int(51 - 26 * k))
        glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([1500, 150, 2850, 1650], fill=(*ACCENT, 30))
        glow = glow.filter(ImageFilter.GaussianBlur(220))
        bg.paste(glow, (0, 0), glow)
        d = ImageDraw.Draw(bg)
        for (top, bottom), fill in zip(zip(FLAG_K, FLAG_K[1:]), (FLAG_BLUE, FLAG_YELLOW)):
            d.polygon([(0, -top), (0, -bottom), (H + bottom, H), (H + top, H)], fill=fill)
        _background = bg
    return _background.copy()


def shadowed(canvas, img, x, y):
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 255), (x, y + 34), img.getchannel("A").point(lambda v: int(v * 0.6)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(44))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(img, (x, y), img)


def tokens(text):
    out = []
    for w in text.split():
        if w in ("—", "–") and out:
            out[-1] += " " + w  # a dash ends a line, never starts one
        else:
            out.append(w)
    return out


def balanced(draw, text, sizes, weight, max_lines, width):
    """Fewest lines, then the largest font, then the narrowest widest line; never a one-word last line."""
    words = tokens(text)
    for size in sizes:
        f = font(size, weight)
        for k in range(1, max_lines + 1):
            best = None
            for cuts in itertools.combinations(range(1, len(words)), k - 1):
                idx = (0, *cuts, len(words))
                if k > 1 and idx[-1] - idx[-2] < 2:
                    continue
                lines = [" ".join(words[a:b]) for a, b in zip(idx, idx[1:])]
                widest = max(draw.textlength(line, font=f) for line in lines)
                if widest <= width and (best is None or widest < best[0]):
                    best = (widest, lines)
            if best:
                return size, best[1]
    return None


def compose(locale, number, names, headline, sub):
    imgs = [Image.open(os.path.join(SHOTS, locale, "raw", f"{n}.png")).convert("RGBA") for n in names]
    tw = max(i.width for i in imgs)
    th = sum(i.height for i in imgs) + GAP_WINDOWS * (len(imgs) - 1)
    canvas = background()
    d = ImageDraw.Draw(canvas)
    for max_w, hsizes, hlines in LAYOUTS:
        scale = min(max_w / tw, (Y1 - Y0) / th)
        text_w = X_RIGHT - round(tw * scale) - LEFT - GAP_TEXT
        hres = balanced(d, headline, hsizes, "Bold", hlines, text_w)
        sres = balanced(d, sub, (60, 56, 52), "Regular", 2, text_w)
        if hres and sres:
            break
    else:
        raise SystemExit(f"{locale} {number:02d}: cannot wrap {headline!r}")
    (hs, h_lines), (ss, s_lines) = hres, sres

    imgs = [i.resize((round(i.width * scale), round(i.height * scale)), Image.LANCZOS) for i in imgs]
    gap = round(GAP_WINDOWS * scale)
    total_w = max(i.width for i in imgs)
    total_h = sum(i.height for i in imgs) + gap * (len(imgs) - 1)
    x = X_RIGHT - total_w
    y = Y0 + (Y1 - Y0 - total_h) // 2

    hf, sf = font(hs, "Bold"), font(ss, "Regular")
    hl, sl = round(hs * 1.19), round(ss * 1.4)
    ty = (H - (56 + len(h_lines) * hl + 36 + len(s_lines) * sl)) // 2
    d.rounded_rectangle([LEFT, ty, LEFT + 130, ty + 14], radius=7, fill=ACCENT)
    ty += 56
    for line in h_lines:
        d.text((LEFT, ty), line, font=hf, fill=(255, 255, 255))
        ty += hl
    ty += 36
    for line in s_lines:
        d.text((LEFT, ty), line, font=sf, fill=(190, 198, 214))
        ty += sl
    for im in imgs:
        shadowed(canvas, im, x + (total_w - im.width) // 2, y)
        y += im.height + gap

    out_dir = os.path.join(OUT, locale, "APP_DESKTOP")
    os.makedirs(out_dir, exist_ok=True)
    srgb = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    canvas.convert("RGB").save(os.path.join(out_dir, f"{number:02d}.png"), "PNG", icc_profile=srgb)
    print(f"{locale} {number:02d} window={total_w}px ({total_w / W * 100:.0f}%) "
          f"headline={' / '.join(h_lines)} ({hs}pt) | subline={' / '.join(s_lines)} ({ss}pt)")


if __name__ == "__main__":
    wanted = os.environ.get("LOCALES", "").split()
    for locale, slides in SLIDES.items():
        if wanted and locale not in wanted:
            continue
        for number, (names, headline, sub) in enumerate(slides, 1):
            compose(locale, number, names, headline, sub)
