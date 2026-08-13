#!/usr/bin/env python3
"""Normalize every project PNG to Flapjack's canonical pixel-art grid.

The checked-in PNGs use a two-source-pixel grid. At the 1920x1080 design
resolution, each logical art pixel is therefore a uniform 2x2 block. The
player source uses a 4x4 grid because its scene deliberately renders at 50%.

This is an asset-authoring tool, not a runtime dependency. It requires Pillow:

    python3 -m pip install Pillow
    python3 tools/normalize_pixel_art.py
    python3 tools/normalize_pixel_art.py --check
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

# These assets were previously stretched by Control/Sprite nodes. Baking the
# final dimensions into the PNG keeps their scene scale at 1 and avoids mixels.
OUTPUT_SIZES = {
    "Assets/Cinematics/Cinematic_Sky_Intro_169.png": (1920, 668),
    "Assets/Cinematics/cinematic_ocean_overlay1.png": (1920, 668),
    "Assets/Cinematics/cinematic_ocean_overlay2.png.png": (1920, 668),
    "Assets/Cinematics/cinematic_ocean_overlay3.png": (2496, 668),
    "Assets/UI/MainMenu/title.png": (720, 360),
    "Assets/UI/Pause/panel_background.png": (640, 820),
    "Assets/UI/Pause/bottom_text.png": (394, 72),
    "Assets/UI/Pause/divider_skull.png": (434, 56),
    "Assets/UI/Pause/divider_small.png": (354, 26),
    "Assets/UI/Pause/resume_button.png": (444, 110),
    "Assets/UI/Pause/resume_icon.png": (68, 92),
    "Assets/UI/Coin/coin_frame.png": (206, 68),
    "Assets/UI/Coin/coin_icon.png": (48, 46),
}

# Translucency is part of these effects. It is kept, but restricted to four
# deliberate alpha levels instead of antialiased, subpixel fringes.
SOFT_ASSET_MARKERS = (
    "/Effects/",
    "cinematic_ocean_overlay",
    "Opening_Sea.png",
    "Intro_Sun.png",
    "Cloud Tileset.png",
)

ALPHA_LEVELS = (0, 85, 170, 255)


def png_paths() -> Iterable[Path]:
    return sorted(
        path
        for path in ROOT.rglob("*.png")
        if ".git" not in path.parts and ".godot" not in path.parts
    )


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def grid_size(path: Path) -> int:
    # The Player scene renders its sprite through a 0.5 parent transform, so a
    # 4x4 source block becomes a uniform 2x2 screen pixel.
    if relative(path) == "Assets/Boat/Player.png":
        return 4
    return 2


def palette_size(path: Path, width: int, height: int) -> int:
    name = relative(path)
    if "/Backgrounds/" in name or width * height >= 500_000:
        return 64
    if "/UI/" in name or width * height >= 80_000:
        return 48
    return 32


def is_soft_asset(path: Path) -> bool:
    name = "/" + relative(path)
    return any(marker in name for marker in SOFT_ASSET_MARKERS)


def snap_alpha(image: Image.Image, soft: bool) -> None:
    alpha = image.getchannel("A")
    if soft:
        alpha = alpha.point(
            lambda value: min(ALPHA_LEVELS, key=lambda level: abs(level - value))
        )
    else:
        alpha = alpha.point(lambda value: 255 if value >= 96 else 0)
    image.putalpha(alpha)


def normalize(path: Path) -> None:
    # Never repeatedly resample artwork that already satisfies the contract.
    # Besides making the tool fast, this prevents cumulative palette drift.
    if not check(path):
        return

    source = Image.open(path).convert("RGBA")
    name = relative(path)
    width, height = OUTPUT_SIZES.get(name, source.size)
    grid = grid_size(path)

    # Six legacy UI files had odd heights. Extend them to the next complete
    # logical pixel instead of leaving a one-source-pixel sliver.
    width += (-width) % grid
    height += (-height) % grid

    logical_size = (width // grid, height // grid)
    logical = source.resize(logical_size, Image.Resampling.BOX)
    logical = logical.quantize(
        colors=palette_size(path, width, height),
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    snap_alpha(logical, is_soft_asset(path))

    output = logical.resize((width, height), Image.Resampling.NEAREST)
    output.save(path, optimize=True)


def check(path: Path) -> list[str]:
    errors: list[str] = []
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    grid = grid_size(path)

    expected_size = OUTPUT_SIZES.get(relative(path))
    if expected_size is not None and image.size != expected_size:
        errors.append(f"dimensions {image.size} do not match {expected_size}")

    if width % grid or height % grid:
        errors.append(f"dimensions {width}x{height} are off the {grid}px grid")
        return errors

    pixels = image.load()
    for top in range(0, height, grid):
        for left in range(0, width, grid):
            expected = pixels[left, top]
            if any(
                pixels[x, y] != expected
                for y in range(top, top + grid)
                for x in range(left, left + grid)
            ):
                errors.append(f"mixed block at ({left}, {top})")
                return errors

    allowed_alpha = set(ALPHA_LEVELS if is_soft_asset(path) else (0, 255))
    actual_alpha = {
        value
        for value, count in enumerate(image.getchannel("A").histogram())
        if count
    }
    unexpected_alpha = actual_alpha - allowed_alpha
    if unexpected_alpha:
        errors.append(f"unexpected alpha values: {sorted(unexpected_alpha)}")

    palette_limit = palette_size(path, width, height)
    if image.getcolors(maxcolors=palette_limit) is None:
        errors.append(f"uses more than {palette_limit} RGBA colors")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the source grid without rewriting assets",
    )
    args = parser.parse_args()

    paths = list(png_paths())
    if not args.check:
        for path in paths:
            normalize(path)

    failures = []
    for path in paths:
        for error in check(path):
            failures.append(f"{relative(path)}: {error}")

    if failures:
        print("\n".join(failures))
        return 1

    print(f"Verified {len(paths)} PNGs on the canonical pixel grid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
