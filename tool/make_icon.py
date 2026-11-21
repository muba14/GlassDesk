"""GlassDesk logosunu üretir: assets/icon/icon.png ve app_icon.ico.

Kullanım:  python3 tool/make_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 1024
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icon"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def gradient(size, c1, c2):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = lerp(c1, c2, t) + (255,)
    return img


def rounded_mask(size, box, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def glass_card(base, box, radius, alpha=70):
    # Arkayı bulanıklaştırıp beyazla hafifçe örterek "cam" görünümü.
    blurred = base.filter(ImageFilter.GaussianBlur(28))
    tint = Image.new("RGBA", base.size, (255, 255, 255, alpha))
    frosted = Image.alpha_composite(blurred, tint)
    mask = rounded_mask(base.size[0], box, radius)
    # Gölge
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    x0, y0, x1, y1 = box
    sd.rounded_rectangle((x0 + 10, y0 + 26, x1 + 10, y1 + 26), radius=radius,
                         fill=(20, 8, 60, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    base = Image.alpha_composite(base, shadow)
    base.paste(frosted, (0, 0), mask)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 150),
                        width=6)
    return base


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bg = gradient(S, (120, 76, 255), (40, 214, 224))

    # Arka plana renkli lekeler (camın arkasında bulanık görünsün diye).
    blobs = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blobs)
    bd.ellipse((560, 120, 900, 460), fill=(255, 120, 200, 230))
    bd.ellipse((150, 560, 470, 880), fill=(255, 190, 100, 210))
    blobs = blobs.filter(ImageFilter.GaussianBlur(40))
    bg = Image.alpha_composite(bg, blobs)

    # Arka cam kart
    bg = glass_card(bg, (300, 210, 820, 640), 70, alpha=55)
    # Ön cam kart
    bg = glass_card(bg, (200, 380, 720, 810), 70, alpha=80)

    d = ImageDraw.Draw(bg)
    # Ön kartın üzerinde saat ve çubuklar
    d.ellipse((260, 450, 400, 590), outline=(255, 255, 255, 235), width=14)
    d.line((330, 520, 330, 475), fill=(255, 255, 255, 235), width=14)
    d.line((330, 520, 368, 540), fill=(255, 255, 255, 235), width=14)
    for i, w in enumerate((250, 190, 130)):
        y = 640 + i * 46
        d.rounded_rectangle((262, y, 262 + w, y + 20), radius=10,
                            fill=(255, 255, 255, 200))
    d.rounded_rectangle((440, 470, 650, 494), radius=12,
                        fill=(255, 255, 255, 210))
    d.rounded_rectangle((440, 520, 590, 544), radius=12,
                        fill=(255, 255, 255, 150))
    # Arka kartta küçük güneş
    d.ellipse((690, 260, 770, 340), fill=(255, 214, 102, 255))

    # Yuvarlatılmış kare uygulama simgesi
    mask = rounded_mask(S, (0, 0, S - 1, S - 1), 230)
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    icon.paste(bg, (0, 0), mask)

    icon.save(OUT / "icon.png")
    icon.save(OUT / "app_icon.ico",
              sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64),
                     (128, 128), (256, 256)])
    print("ok", OUT)


if __name__ == "__main__":
    main()
