#!/usr/bin/env python3
"""Generates the PLACEHOLDER pixel-art used by Green Haven during early phases.

All output goes to ``assets/placeholder/`` and is meant to be replaced by
hand-made final art in ``assets/sprites/`` (see docs/ASSET_GUIDE.md).

Usage (from the GreenHaven/ folder):
    python3 tools/generate_placeholder_art.py

Requires Pillow. Output is deterministic (fixed random seed), so re-running
produces byte-identical images unless this script changes.

Geometry conventions (must match the Godot TileSet):
    * Isometric tile: 32x16 px diamond, 2:1 pixel lines.
    * Object sprites: the footprint diamond centre is at (W/2, H-8).
    * Wall segments: 16 px wide, WALL_HEIGHT px tall walls + 8 px slope.
"""

from __future__ import annotations

import os
import random
from typing import Iterable

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "placeholder")

TILE_W = 32
TILE_H = 16
WALL_HEIGHT = 56

# --- Palette (see docs/ASSET_GUIDE.md) --------------------------------------
OUTLINE = (59, 42, 32, 255)
WOOD_HI = (222, 178, 124, 255)
WOOD = (200, 148, 94, 255)
WOOD_MID = (176, 124, 74, 255)
WOOD_DARK = (138, 90, 54, 255)
WOOD_DEEP = (104, 66, 42, 255)
CREAM = (246, 232, 200, 255)
CREAM_DARK = (226, 205, 166, 255)
RUG = (214, 160, 128, 255)
RUG_DARK = (186, 128, 104, 255)
WALL_GREEN = (168, 198, 159, 255)
WALL_GREEN_DARK = (147, 181, 138, 255)
WALL_GREEN_SHADE = (128, 162, 122, 255)
LEAF_HI = (156, 201, 122, 255)
LEAF = (111, 163, 90, 255)
LEAF_DARK = (79, 138, 68, 255)
LEAF_DEEP = (58, 107, 53, 255)
METAL_HI = (222, 226, 216, 255)
METAL = (190, 196, 186, 255)
METAL_DARK = (140, 148, 138, 255)
METAL_DEEP = (100, 108, 100, 255)
LED = (255, 244, 204, 255)
GLASS = (196, 228, 236, 255)
GLASS_HI = (236, 250, 250, 255)
SKY = (170, 214, 230, 255)
TERRACOTTA = (204, 118, 82, 255)
TERRACOTTA_DARK = (164, 88, 62, 255)
WATER = (120, 182, 214, 255)
COIN = (240, 196, 84, 255)
TRANSPARENT = (0, 0, 0, 0)

rng = random.Random(20261108)


# --- Helpers -----------------------------------------------------------------
def new_image(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), TRANSPARENT)


def in_diamond(px: int, py: int, w: int = TILE_W, h: int = TILE_H) -> bool:
    """True if pixel (px, py) lies inside a w x h diamond (tileable rule)."""
    dx = abs(px + 0.5 - w / 2) / (w / 2)
    dy = abs(py + 0.5 - h / 2) / (h / 2)
    return dx + dy <= 1.0


def diamond_points(cx: float, cy: float, hw: float, hh: float) -> list[tuple[float, float]]:
    return [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]


def iso_box(img: Image.Image, cx: int, base_y: int, hw: int, hh: int, height: int,
            top, left, right, outline=OUTLINE) -> None:
    """Draws an isometric box whose footprint diamond centre is (cx, base_y)."""
    d = ImageDraw.Draw(img)
    ty = base_y - height
    # Left face: left vertex -> bottom vertex, extruded upwards.
    d.polygon([(cx - hw, ty), (cx, ty + hh), (cx, base_y + hh), (cx - hw, base_y)], fill=left)
    # Right face: bottom vertex -> right vertex.
    d.polygon([(cx, ty + hh), (cx + hw, ty), (cx + hw, base_y), (cx, base_y + hh)], fill=right)
    d.polygon(diamond_points(cx, ty, hw, hh), fill=top)
    if outline is not None:
        d.line([(cx - hw, ty), (cx - hw, base_y), (cx, base_y + hh), (cx + hw, base_y), (cx + hw, ty)],
               fill=outline)
        d.line(diamond_points(cx, ty, hw, hh) + [(cx, ty - hh)], fill=outline)
        d.line([(cx, ty + hh), (cx, base_y + hh)], fill=outline)


def blob(img: Image.Image, cx: int, cy: int, r: int, colors: Iterable) -> None:
    """Small pixel 'leaf cluster': shaded disc with a highlight."""
    dark, mid, hi = colors
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=dark)
    d.ellipse([cx - r + 1, cy - r, cx + r - 1, cy + r - 2], fill=mid)
    d.point([(cx - 1, cy - r + 1), (cx, cy - r + 1)], fill=hi)


def save(img: Image.Image, rel_path: str) -> None:
    path = os.path.join(OUT, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


# --- Floor tiles ---------------------------------------------------------------
def floor_tile(kind: str) -> Image.Image:
    img = new_image(TILE_W, TILE_H)
    px = img.load()
    for y in range(TILE_H):
        for x in range(TILE_W):
            if not in_diamond(x, y):
                continue
            if kind == "rug":
                # Checker-ish woven rug with a cream border band.
                u = (x / 2 + y)  # axis along one iso direction
                v = (x / 2 - y)
                c = RUG if (int(u // 4) + int(v // 4)) % 2 == 0 else RUG_DARK
                px[x, y] = c
            else:
                # Planks run along the down-right iso axis: v = x/2 - y.
                v = x / 2 - y
                band = int((v + 64) // 4)
                base = WOOD if band % 2 == 0 else WOOD_MID
                if kind == "plank_b":
                    base = WOOD_MID if band % 2 == 0 else WOOD
                c = base
                if (v + 64) % 4 < 0.5:
                    c = WOOD_DARK  # plank seam
                elif rng.random() < 0.025:
                    c = WOOD_HI
                px[x, y] = c
    return img


def build_floor_atlas() -> None:
    kinds = ["plank_a", "plank_b", "rug"]
    atlas = new_image(TILE_W * len(kinds), TILE_H)
    for i, k in enumerate(kinds):
        atlas.paste(floor_tile(k), (i * TILE_W, 0))
    save(atlas, "tilesets/home_floor_tiles.png")


# --- Walls -------------------------------------------------------------------
def wall_segment(side: str) -> Image.Image:
    """16 px wide wall slice standing on one back edge of a floor tile.

    side == "left": edge from the tile's left vertex up to its top vertex.
    side == "right": edge from the tile's top vertex down to its right vertex.
    """
    w, h = TILE_W // 2, WALL_HEIGHT + TILE_H // 2
    img = new_image(w, h)
    px = img.load()
    shade = 0 if side == "right" else 1  # light comes from the right window
    for i in range(w):
        slope = i // 2 if side == "right" else (w - 1 - i) // 2
        bottom = h - (TILE_H // 2) + slope  # exclusive
        top = bottom - WALL_HEIGHT
        for y in range(max(top, 0), min(bottom, h)):
            from_floor = bottom - 1 - y
            if from_floor < 2:
                c = WOOD_DEEP  # baseboard
            elif from_floor < 16:
                c = WOOD_MID if (i % 4 != 0) else WOOD_DARK  # wainscot panels
                if from_floor == 15:
                    c = WOOD_HI
            elif from_floor >= WALL_HEIGHT - 3:
                c = WOOD_DARK if from_floor == WALL_HEIGHT - 1 else WOOD  # top trim
            else:
                c = WALL_GREEN if (i % 6) < 4 else WALL_GREEN_DARK  # stripes
            if shade and c[3]:
                c = tuple(max(0, int(ch * 0.88)) for ch in c[:3]) + (255,)
            px[i, y] = c
    return img


def sheared_rect(w: int, h: int, side: str) -> tuple[Image.Image, callable]:
    """Returns an image tall enough for a w x h rect sheared along a wall."""
    extra = w // 2
    img = new_image(w, h + extra)

    def put(x: int, y: int, c) -> None:
        off = x // 2 if side == "right" else (w - 1 - x) // 2
        if 0 <= x < w and 0 <= y + off < h + extra:
            img.putpixel((x, y + off), c)

    return img, put


def window_sprite() -> Image.Image:
    w, h = 24, 30
    img, put = sheared_rect(w, h, "right")
    for x in range(w):
        for y in range(h):
            edge = x in (0, w - 1) or y in (0, h - 1)
            frame = x in (1, w - 2) or y in (1, h - 2) or x in (11, 12) or y == 14
            if edge:
                c = WOOD_DEEP
            elif frame:
                c = CREAM
            else:
                c = SKY if y > 4 else GLASS
                if (x + y) % 9 == 0 or (x + y) % 9 == 1:
                    c = GLASS_HI
            put(x, y, c)
    # Sill
    for x in range(-1, w + 1):
        put(max(0, min(w - 1, x)), h - 1, WOOD_DARK)
    return img


def poster_sprite() -> Image.Image:
    """A small 'plant growth chart' poster for the left wall."""
    w, h = 14, 18
    img, put = sheared_rect(w, h, "left")
    for x in range(w):
        for y in range(h):
            if x in (0, w - 1) or y in (0, h - 1):
                c = WOOD_DARK
            else:
                c = CREAM
            put(x, y, c)
    # Five little sprout stages drawn as stems of increasing height.
    for stage in range(5):
        x = 2 + stage * 2
        for k in range(stage + 2):
            put(x, h - 3 - k, LEAF_DARK)
        put(x, h - 4 - stage, LEAF_HI)
    put(3, 2, TERRACOTTA)
    put(4, 2, TERRACOTTA)
    put(5, 2, TERRACOTTA)
    return img


# --- Objects -----------------------------------------------------------------
def object_canvas(height: int) -> tuple[Image.Image, int, int]:
    img = new_image(TILE_W, height)
    return img, TILE_W // 2, height - TILE_H // 2


def hydro_rack() -> Image.Image:
    img, cx, by = object_canvas(60)
    d = ImageDraw.Draw(img)
    hw, hh = 14, 7
    post_h = 46
    # Back post (mostly hidden) then shelves, then front posts.
    d.line([(cx, by - hh - post_h), (cx, by - hh)], fill=METAL_DEEP)
    for level, z in enumerate((4, 19, 34)):
        iso_box(img, cx, by - z, hw, hh, 2, METAL, METAL_DARK, METAL_DEEP)
        # Tray of greens on the shelf.
        sy = by - z - 4
        for k, (ox, oy) in enumerate(((-7, 0), (-2, -2), (3, 0), (7, 1), (0, 2), (-4, 2), (5, -2))):
            col = (LEAF_DEEP, LEAF, LEAF_HI) if (k + level) % 3 else (LEAF_DEEP, LEAF_DARK, LEAF)
            blob(img, cx + ox, sy + oy, 2, col)
        # LED strip under the shelf above.
        if level < 2:
            led_y = by - (z + 15)
            d.line([(cx - hw + 3, led_y + 1), (cx, led_y + hh - 2)], fill=LED)
            d.line([(cx, led_y + hh - 2), (cx + hw - 3, led_y + 1)], fill=LED)
    for x in (cx - hw, cx + hw):
        d.line([(x, by - post_h), (x, by)], fill=METAL_DEEP)
        d.point((x, by - post_h), fill=METAL_HI)
    d.line([(cx, by + hh - post_h), (cx, by + hh)], fill=OUTLINE)
    d.line([(cx + 1, by + hh - post_h), (cx + 1, by + hh)], fill=METAL_HI)
    # Top cap with LED lamp.
    iso_box(img, cx, by - post_h, hw, hh, 2, METAL_HI, METAL, METAL_DARK)
    d.line([(cx - hw + 3, by - post_h + 1), (cx, by - post_h + hh - 2)], fill=LED)
    d.line([(cx, by - post_h + hh - 2), (cx + hw - 3, by - post_h + 1)], fill=LED)
    return img


def storage_crate() -> Image.Image:
    img, cx, by = object_canvas(40)
    iso_box(img, cx, by, 13, 6, 14, WOOD_HI, WOOD_MID, WOOD_DARK)
    d = ImageDraw.Draw(img)
    # Plank seams on the side faces.
    for z in (5, 10):
        d.line([(cx - 13, by - z), (cx, by - z + 6)], fill=WOOD_DEEP)
        d.line([(cx, by - z + 6), (cx + 13, by - z)], fill=WOOD_DEEP)
    # Seed sack on top.
    sy = by - 14 - 4
    d.ellipse([cx - 7, sy - 8, cx + 5, sy + 3], fill=CREAM_DARK, outline=OUTLINE)
    d.ellipse([cx - 5, sy - 7, cx + 2, sy], fill=CREAM)
    d.line([(cx - 3, sy - 9), (cx, sy - 9)], fill=WOOD_DARK)
    blob(img, cx - 1, sy - 3, 1, (LEAF_DEEP, LEAF, LEAF_HI))
    return img


def work_table() -> Image.Image:
    img, cx, by = object_canvas(40)
    d = ImageDraw.Draw(img)
    hw, hh, top_z = 14, 7, 16
    for x, y in ((cx - hw + 2, by), (cx, by + hh - 2), (cx + hw - 2, by)):
        d.line([(x, y - top_z), (x, y)], fill=WOOD_DEEP)
    iso_box(img, cx, by - top_z, hw, hh, 3, WOOD_HI, WOOD, WOOD_DARK)
    # Small terracotta pot with a seedling + a watering can on the table.
    ty = by - top_z - 3
    iso_box(img, cx - 5, ty, 3, 2, 4, TERRACOTTA, TERRACOTTA_DARK, TERRACOTTA_DARK)
    blob(img, cx - 5, ty - 7, 2, (LEAF_DARK, LEAF, LEAF_HI))
    iso_box(img, cx + 5, ty + 1, 3, 2, 5, WATER, (96, 150, 186, 255), (80, 128, 164, 255))
    d.line([(cx + 8, ty - 3), (cx + 11, ty - 6)], fill=(80, 128, 164, 255))
    return img


def decor_monstera() -> Image.Image:
    img, cx, by = object_canvas(44)
    iso_box(img, cx, by, 7, 4, 9, TERRACOTTA, TERRACOTTA_DARK, (140, 74, 54, 255))
    leaves = [(-6, -16, 4), (5, -18, 4), (0, -24, 5), (-8, -25, 3), (8, -26, 3), (1, -32, 4)]
    for ox, oy, r in leaves:
        blob(img, cx + ox, by + oy, r, (LEAF_DEEP, LEAF_DARK, LEAF_HI))
    d = ImageDraw.Draw(img)
    d.line([(cx, by - 9), (cx - 4, by - 15)], fill=LEAF_DEEP)
    d.line([(cx, by - 9), (cx + 3, by - 17)], fill=LEAF_DEEP)
    return img


def shipping_box() -> Image.Image:
    img, cx, by = object_canvas(36)
    iso_box(img, cx, by, 13, 6, 12, WOOD, WOOD_MID, WOOD_DARK)
    d = ImageDraw.Draw(img)
    # Green ribbon + coin badge: this is where produce will be sold (Phase 4).
    d.line([(cx - 13, by - 6), (cx, by)], fill=LEAF_DARK)
    d.line([(cx, by), (cx + 13, by - 6)], fill=LEAF_DARK)
    d.ellipse([cx + 5, by - 7, cx + 9, by - 3], fill=COIN, outline=OUTLINE)
    # Open lid leaning backwards.
    d.polygon([(cx - 13, by - 12), (cx, by - 18), (cx, by - 24), (cx - 13, by - 18)], fill=WOOD_HI,
              outline=OUTLINE)
    return img


# --- UI ----------------------------------------------------------------------
def ui_panel() -> Image.Image:
    """24x24 nine-patch: wooden frame, cream inside (margins 8 px)."""
    s = 24
    img = new_image(s, s)
    d = ImageDraw.Draw(img)
    d.rectangle([1, 0, s - 2, s - 1], fill=OUTLINE)
    d.rectangle([0, 1, s - 1, s - 2], fill=OUTLINE)
    d.rectangle([1, 1, s - 2, s - 2], fill=WOOD_MID)
    d.line([(2, 1), (s - 3, 1)], fill=WOOD_HI)
    d.line([(2, s - 2), (s - 3, s - 2)], fill=WOOD_DARK)
    d.rectangle([4, 4, s - 5, s - 5], fill=WOOD_DEEP)
    d.rectangle([5, 5, s - 6, s - 6], fill=CREAM)
    return img


def ui_button(state: str) -> Image.Image:
    """18x18 nine-patch button (margins 6 px)."""
    s = 18
    img = new_image(s, s)
    d = ImageDraw.Draw(img)
    face = {"normal": LEAF, "hover": LEAF_HI, "pressed": LEAF_DARK, "disabled": METAL_DARK}[state]
    hi = {"normal": LEAF_HI, "hover": (190, 226, 160, 255), "pressed": LEAF, "disabled": METAL}[state]
    lo = {"normal": LEAF_DEEP, "hover": LEAF_DARK, "pressed": LEAF_DEEP, "disabled": METAL_DEEP}[state]
    d.rectangle([1, 0, s - 2, s - 1], fill=OUTLINE)
    d.rectangle([0, 1, s - 1, s - 2], fill=OUTLINE)
    d.rectangle([1, 1, s - 2, s - 2], fill=face)
    if state == "pressed":
        d.line([(2, 1), (s - 3, 1)], fill=lo)
    else:
        d.line([(2, 1), (s - 3, 1)], fill=hi)
        d.line([(1, s - 3), (s - 2, s - 3)], fill=lo)
        d.line([(2, s - 2), (s - 3, s - 2)], fill=lo)
    return img


def ui_icon_recenter() -> Image.Image:
    """12x12 'frame the room' icon: four corner brackets around a dot."""
    img = new_image(12, 12)
    d = ImageDraw.Draw(img)
    c = CREAM
    for x0, y0, sx, sy in ((0, 0, 1, 1), (11, 0, -1, 1), (0, 11, 1, -1), (11, 11, -1, -1)):
        d.line([(x0, y0), (x0 + 3 * sx, y0)], fill=c)
        d.line([(x0, y0), (x0, y0 + 3 * sy)], fill=c)
    d.rectangle([4, 4, 7, 7], fill=c)
    return img


def app_icon() -> Image.Image:
    """32x32 sprout in a pot, upscaled x4 with nearest filtering."""
    img = new_image(32, 32)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, 31, 31], radius=6, fill=WALL_GREEN)
    d.rectangle([9, 19, 22, 27], fill=TERRACOTTA, outline=OUTLINE)
    d.rectangle([8, 17, 23, 19], fill=TERRACOTTA_DARK, outline=OUTLINE)
    d.line([(15, 17), (15, 10)], fill=LEAF_DEEP)
    d.ellipse([7, 7, 15, 13], fill=LEAF, outline=LEAF_DEEP)
    d.ellipse([15, 4, 24, 11], fill=LEAF_HI, outline=LEAF_DEEP)
    return img.resize((128, 128), Image.NEAREST)


def main() -> None:
    build_floor_atlas()
    save(wall_segment("left"), "environment/wall_left.png")
    save(wall_segment("right"), "environment/wall_right.png")
    save(window_sprite(), "environment/window_right_wall.png")
    save(poster_sprite(), "environment/poster_left_wall.png")
    save(hydro_rack(), "objects/hydro_rack_basic.png")
    save(storage_crate(), "objects/storage_crate.png")
    save(work_table(), "objects/work_table.png")
    save(decor_monstera(), "objects/decor_monstera.png")
    save(shipping_box(), "objects/shipping_box.png")
    save(ui_panel(), "ui/panel_wood.png")
    for st in ("normal", "hover", "pressed", "disabled"):
        save(ui_button(st), f"ui/button_{st}.png")
    save(ui_icon_recenter(), "ui/icon_recenter.png")
    icon = app_icon()
    icon.save(os.path.join(ROOT, "icon.png"))
    print("wrote icon.png")


if __name__ == "__main__":
    main()
