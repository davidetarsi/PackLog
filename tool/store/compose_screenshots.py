"""Mette gli screenshot grezzi dello Store nel formato di Google Play.

Legge `build/store-screenshots/<lingua>/` (vedi
`test/screenshots/store_screenshots_test.dart`) e scrive PNG 1080x1920 con
la didascalia sopra il telefono.

    python3 tool/store/compose_screenshots.py <cartella-flutter> <uscita> \
        [<lingua>:<numero>=<png> ...]

Le coppie finali sostituiscono una schermata con una cattura dal telefono,
già senza barra di stato e barra dei gesti (es. `it-IT:3=scansione.png`).

`<uscita>/<lingua>/images/phoneScreenshots/` è la cartella della scheda.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1080, 1920
BACKGROUND = (244, 128, 31)  # primary del tema chiaro, #F4801F
TEXT = (24, 24, 27)  # onSurface
OUTLINE = (228, 228, 231)  # outlineVariant
PHONE_TOP = 400
PHONE_BOTTOM_MARGIN = 80
RADIUS = 44

CAPTIONS = {
    "it-IT": [
        "La valigia si prepara da sola",
        "Ogni scelta ha il suo perché",
        "Aggiungi i vestiti con una foto",
        "Con i vestiti che hai già",
        "Il meteo di ogni tappa",
        "Spunta mentre prepari",
        "Sai dove sono le tue cose",
    ],
    "en-US": [
        "Your suitcase, packed for you",
        "Every pick has a reason",
        "Add clothes from a photo",
        "With the clothes you already own",
        "Weather for every stop",
        "Check off as you pack",
        "Know where your things are",
    ],
}


def _wrap(draw, text, font, width):
    """Una riga se ci sta, altrimenti due righe di lunghezza simile: niente
    parola sola sulla seconda."""
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


def compose(raw_path, caption, font):
    canvas = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    lines = _wrap(draw, caption, font, WIDTH - 160)
    line_height = font.size * 1.18
    block = line_height * len(lines)
    y = (PHONE_TOP - block) / 2
    for line in lines:
        x = (WIDTH - draw.textlength(line, font=font)) / 2
        draw.text((x, y), line, font=font, fill=TEXT)
        y += line_height

    # Il telefono intero, così si vedono anche i fogli in basso e i bottoni.
    shot = Image.open(raw_path).convert("RGB")
    height = HEIGHT - PHONE_TOP - PHONE_BOTTOM_MARGIN
    phone_width = round(shot.width * height / shot.height)
    shot = shot.resize((phone_width, height), Image.LANCZOS)
    left = (WIDTH - phone_width) // 2

    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, shot.width - 1, shot.height - 1), RADIUS, fill=255
    )

    shadow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, PHONE_TOP + 12, left + phone_width, PHONE_TOP + height + 12),
        RADIUS,
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.paste(shadow, (0, 0), shadow)

    canvas.paste(shot, (left, PHONE_TOP), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (left, PHONE_TOP, left + phone_width - 1, PHONE_TOP + height - 1),
        RADIUS,
        outline=OUTLINE,
        width=2,
    )
    return canvas


def main(flutter_root, out_root, replacements):
    font_path = os.path.join(
        flutter_root, "bin/cache/artifacts/material_fonts/Roboto-Bold.ttf"
    )
    font = ImageFont.truetype(font_path, 76)
    for lang, captions in CAPTIONS.items():
        raws = sorted(glob.glob(f"build/store-screenshots/{lang}/*.png"))
        if len(raws) != len(captions):
            sys.exit(f"{lang}: {len(raws)} screenshot, {len(captions)} didascalie")
        out_dir = os.path.join(out_root, lang, "images", "phoneScreenshots")
        os.makedirs(out_dir, exist_ok=True)
        for old in glob.glob(os.path.join(out_dir, "*.png")):
            os.remove(old)
        for index, (raw, caption) in enumerate(zip(raws, captions), start=1):
            raw = replacements.get((lang, index), raw)
            out = os.path.join(out_dir, f"{index}_{lang}.png")
            compose(raw, caption, font).save(out, optimize=True)
            print(out)


if __name__ == "__main__":
    replacements = {}
    for arg in sys.argv[3:]:
        key, path = arg.split("=", 1)
        lang, index = key.split(":")
        replacements[(lang, int(index))] = path
    main(sys.argv[1], sys.argv[2], replacements)
