#!/usr/bin/env python3
"""Remove magenta spill and atlas labels from extracted Shop PNG files."""

from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


SHOP_DIR = Path(__file__).resolve().parent.parent


def clear_connected_magenta(rgba: np.ndarray) -> None:
    rgb = rgba[..., :3].astype(np.int16)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    possible = (
        (red > 70)
        & (blue > 70)
        & (green < 105)
        & (np.abs(red - blue) < 95)
        & (((red + blue) // 2 - green) > 42)
    )

    height, width = possible.shape
    connected = np.zeros((height, width), dtype=bool)
    pending: deque[tuple[int, int]] = deque()

    for x in range(width):
        for y in (0, height - 1):
            if possible[y, x] or rgba[y, x, 3] == 0:
                connected[y, x] = True
                pending.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if possible[y, x] or rgba[y, x, 3] == 0:
                connected[y, x] = True
                pending.append((y, x))

    while pending:
        y, x = pending.popleft()
        for next_y in range(max(0, y - 1), min(height, y + 2)):
            for next_x in range(max(0, x - 1), min(width, x + 2)):
                if connected[next_y, next_x]:
                    continue
                if not possible[next_y, next_x] and rgba[next_y, next_x, 3] != 0:
                    continue
                connected[next_y, next_x] = True
                pending.append((next_y, next_x))

    rgba[..., 3][connected] = 0


def keep_primary_row_band(rgba: np.ndarray) -> None:
    occupied = np.any(rgba[..., 3] > 0, axis=1)
    bands: list[tuple[int, int]] = []
    start = -1
    for row, has_pixels in enumerate(occupied):
        if has_pixels and start < 0:
            start = row
        elif not has_pixels and start >= 0:
            bands.append((start, row))
            start = -1
    if start >= 0:
        bands.append((start, len(occupied)))
    if len(bands) <= 1:
        return

    def band_weight(band: tuple[int, int]) -> int:
        top, bottom = band
        return int(np.count_nonzero(rgba[top:bottom, :, 3]))

    top, bottom = max(bands, key=band_weight)
    rgba[:top, :, 3] = 0
    rgba[bottom:, :, 3] = 0


def strip_magenta_edge(rgba: np.ndarray, passes: int = 1) -> None:
    """Remove the one-pixel chroma fringe left by the generated atlas."""
    for _pass in range(passes):
        visible = rgba[..., 3] > 0
        transparent = ~visible
        adjacent = np.zeros_like(visible)
        adjacent[1:, :] |= transparent[:-1, :]
        adjacent[:-1, :] |= transparent[1:, :]
        adjacent[:, 1:] |= transparent[:, :-1]
        adjacent[:, :-1] |= transparent[:, 1:]

        rgb = rgba[..., :3].astype(np.int16)
        red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        magenta_spill = (
            (red > 25)
            & (blue > 20)
            & (green < 55)
            & (np.abs(red - blue) < 65)
            & (((red + blue) // 2 - green) > 18)
        )
        rgba[..., 3][visible & adjacent & magenta_spill] = 0


def trim(image: Image.Image, padding: int = 3) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    return image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    )


def main() -> None:
    files = sorted(
        path
        for path in SHOP_DIR.rglob("*.png")
        if "_Source" not in path.parts
    )
    for path in files:
        rgba = np.asarray(Image.open(path).convert("RGBA")).copy()
        clear_connected_magenta(rgba)
        keep_primary_row_band(rgba)
        strip_magenta_edge(rgba)
        trim(Image.fromarray(rgba, "RGBA")).save(path, "PNG", optimize=True)
    print(f"Cleaned {len(files)} extracted Shop assets")


if __name__ == "__main__":
    main()
