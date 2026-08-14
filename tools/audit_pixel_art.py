#!/usr/bin/env python3
"""Report PNG characteristics without rewriting source artwork.

Flapjack contains several independently authored art families. Some use native
one-pixel detail, some use larger repeated blocks, and some intentionally use
smooth gradients or translucent effects. A single automatic resampling rule is
therefore unsafe. This tool only inventories the files so an artist can review
each family on its own terms.

Requires Pillow:

    python3 -m pip install Pillow
    python3 tools/audit_pixel_art.py
    python3 tools/audit_pixel_art.py --verbose
"""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
GRIDS = (16, 8, 4, 2)


def png_paths() -> Iterable[Path]:
	return sorted(
		path
		for path in ROOT.rglob("*.png")
		if ".git" not in path.parts and ".godot" not in path.parts
	)


def relative(path: Path) -> str:
	return path.relative_to(ROOT).as_posix()


def exact_block_grid(image: Image.Image) -> int:
	"""Return the largest exact repeated-pixel grid, or 1 for native detail."""

	rgba = image.convert("RGBA")
	width, height = rgba.size
	for grid in GRIDS:
		if width % grid or height % grid:
			continue
		logical = rgba.resize(
			(width // grid, height // grid), Image.Resampling.NEAREST
		)
		rebuilt = logical.resize(rgba.size, Image.Resampling.NEAREST)
		if ImageChops.difference(rgba, rebuilt).getbbox() is None:
			return grid
	return 1


def color_count(image: Image.Image) -> int:
	colors = image.convert("RGBA").getcolors(maxcolors=image.width * image.height)
	return len(colors) if colors is not None else image.width * image.height


def alpha_level_count(image: Image.Image) -> int:
	return sum(1 for count in image.convert("RGBA").getchannel("A").histogram() if count)


def main() -> int:
	parser = argparse.ArgumentParser(
		description="Audit project PNGs without changing them."
	)
	parser.add_argument(
		"--verbose",
		action="store_true",
		help="print dimensions, exact block grid, colors, and alpha levels per file",
	)
	args = parser.parse_args()

	paths = list(png_paths())
	grids: Counter[int] = Counter()

	if args.verbose:
		print("path\tsize\texact_grid\tcolors\talpha_levels")

	for path in paths:
		with Image.open(path) as image:
			grid = exact_block_grid(image)
			grids[grid] += 1
			if args.verbose:
				print(
					f"{relative(path)}\t{image.width}x{image.height}\t"
					f"{grid}px\t{color_count(image)}\t{alpha_level_count(image)}"
				)

	print(f"Audited {len(paths)} PNGs (read-only).")
	for grid in (1, 2, 4, 8, 16):
		if grids[grid]:
			label = "native/mixed" if grid == 1 else "exact repeated blocks"
			print(f"  {grid}px {label}: {grids[grid]}")
	print("No files were changed.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
