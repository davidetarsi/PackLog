"""Grafica in evidenza della scheda Google Play (1024x500).

Icona, nome e frase a sinistra; due schermate dell'app a destra, tagliate
dal bordo in basso.

    python3 tool/store/feature_graphic.py <cartella-flutter> <uscita.png> \
        <frase> <schermata-1.png> <schermata-2.png>
"""
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1024, 500
BACKGROUND = (255, 236, 220)  # come gli screenshot, #FFECDC
TEXT = (24, 24, 27)
TEXT_SECONDARY = (82, 82, 91)
OUTLINE = (228, 228, 231)


def _rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width - 1, image.height - 1), radius, fill=255
    )
    return mask


def _phone(canvas, path, left, top, width):
    shot = Image.open(path).convert("RGB")
    height = round(shot.height * width / shot.width)
    shot = shot.resize((width, height), Image.LANCZOS)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, top + 8, left + width, top + height + 8), 28, fill=(0, 0, 0, 60)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(shot, (left, top), _rounded(shot, 28))
    ImageDraw.Draw(canvas).rounded_rectangle(
        (left, top, left + width - 1, top + height - 1),
        28,
        outline=OUTLINE,
        width=2,
    )


def _wrap(draw, text, font, width):
    """Una riga se ci sta, altrimenti due righe di lunghezza simile."""
    if draw.textlength(text, font=font) <= width:
        return [text]
    words = text.split()
    splits = [
        (" ".join(words[:i]), " ".join(words[i:])) for i in range(1, len(words))
    ]
    return list(
        min(
            splits,
            key=lambda pair: max(draw.textlength(line, font=font) for line in pair),
        )
    )


def main(flutter_root, out, tagline, first, second):
    fonts = f"{flutter_root}/bin/cache/artifacts/material_fonts"
    title_font = ImageFont.truetype(f"{fonts}/Roboto-Bold.ttf", 64)
    tagline_font = ImageFont.truetype(f"{fonts}/Roboto-Medium.ttf", 34)

    canvas = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)
    _phone(canvas, second, 800, 120, 200)
    _phone(canvas, first, 590, 60, 220)

    icon = Image.open("assets/icon/app_icon.png").convert("RGB")
    icon = icon.resize((128, 128), Image.LANCZOS)
    canvas.paste(icon, (64, 92), _rounded(icon, 30))

    draw = ImageDraw.Draw(canvas)
    draw.text((64, 246), "PackLog", font=title_font, fill=TEXT)
    y = 330
    for line in _wrap(draw, tagline, tagline_font, 470):
        draw.text((64, y), line, font=tagline_font, fill=TEXT_SECONDARY)
        y += 44
    canvas.save(out, optimize=True)


if __name__ == "__main__":
    main(*sys.argv[1:6])
