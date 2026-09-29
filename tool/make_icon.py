#!/usr/bin/env python3
"""Gera o ícone do app Na Lata (lata de alimento + estrela de avaliação).

Marca: verde #176B4D, creme #F7F6F1, âmbar #805600.
Desenha em 1024px e exporta os mipmaps Android (launcher + round) e o
foreground do adaptive icon.
"""
import math
import os
from PIL import Image, ImageDraw

GREEN = (23, 107, 77, 255)
GREEN_DARK = (17, 82, 59, 255)
CREAM = (247, 246, 241, 255)
AMBER = (240, 179, 35, 255)  # âmbar mais vivo para brilhar sobre o verde
INK = (32, 41, 35, 255)

S = 1024


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_star(draw, cx, cy, r_out, r_in, fill, points=5, rotation=-90):
    pts = []
    for i in range(points * 2):
        ang = math.radians(rotation + i * (360 / (points * 2)))
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    draw.polygon(pts, fill=fill)


def draw_can(img, with_bg=True):
    d = ImageDraw.Draw(img)
    if with_bg:
        # fundo verde com cantos arredondados (o launcher aplica a máscara)
        rounded_rect(d, (0, 0, S, S), radius=int(S * 0.22), fill=GREEN)

    # Lata centralizada
    can_w = int(S * 0.44)
    can_h = int(S * 0.56)
    cx = S // 2
    top = int(S * 0.22)
    left = cx - can_w // 2
    right = cx + can_w // 2
    bottom = top + can_h

    # corpo da lata (creme)
    rounded_rect(d, (left, top, right, bottom), radius=int(can_w * 0.16), fill=CREAM)

    # tampa (elipse) e base sombreada
    lid_h = int(can_h * 0.14)
    d.ellipse((left, top - lid_h // 2, right, top + lid_h // 2), fill=CREAM)
    d.ellipse(
        (left, top - lid_h // 2, right, top + lid_h // 2),
        outline=GREEN_DARK,
        width=max(4, S // 180),
    )

    # rótulo verde no meio da lata
    label_top = top + int(can_h * 0.28)
    label_bottom = top + int(can_h * 0.74)
    d.rectangle((left, label_top, right, label_bottom), fill=GREEN)

    # estrela âmbar sobre o rótulo (avaliação)
    star_cx = cx
    star_cy = (label_top + label_bottom) // 2
    r_out = int(can_w * 0.30)
    draw_star(d, star_cx, star_cy, r_out, int(r_out * 0.45), AMBER)

    return img


def main():
    base = "android/app/src/main/res"
    # 1) ícone completo (com fundo) para launchers legados
    full = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_can(full, with_bg=True)

    # densidades do launcher legado
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in sizes.items():
        out_dir = os.path.join(base, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon = full.resize((px, px), Image.LANCZOS)
        icon.save(os.path.join(out_dir, "ic_launcher.png"))
        # round usa a mesma arte (a máscara é aplicada pelo sistema)
        icon.save(os.path.join(out_dir, "ic_launcher_round.png"))

    # 2) adaptive icon: foreground (lata sem fundo, com padding de segurança)
    #    O canvas do foreground é 108dp; o conteúdo seguro fica no centro 66dp.
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # desenha a lata um pouco menor para respeitar a área segura
    tmp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_can(tmp, with_bg=False)
    scale = 0.72
    small = tmp.resize((int(S * scale), int(S * scale)), Image.LANCZOS)
    fg.paste(small, ((S - small.width) // 2, (S - small.height) // 2), small)

    fg_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    for folder, px in fg_sizes.items():
        out_dir = os.path.join(base, folder)
        os.makedirs(out_dir, exist_ok=True)
        fg.resize((px, px), Image.LANCZOS).save(
            os.path.join(out_dir, "ic_launcher_foreground.png")
        )

    # master 1024 (útil para loja/documentação)
    full.save(os.path.join(base, "..", "ic_launcher-playstore.png"))
    print("ícones gerados:", ", ".join(sizes))


if __name__ == "__main__":
    main()
