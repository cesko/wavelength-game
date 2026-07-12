"""Night sky image generator.

This module provides functionality to generate a simple night sky image
with randomly distributed stars, using a cell-based grid system to ensure
even distribution across the image. Larger stars are rendered with an
additional soft glow and a 4-pointed sparkle (diffraction spike) effect.
"""

import math
import random
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from PIL import Image, ImageDraw, ImageFilter


@dataclass
class StarColorOption:
    """Represents a single star color and its relative likelihood of occurring.

    Attributes:
        color: An RGB or RGBA tuple representing the star color.
        weight: A positive float representing the relative likelihood of
            this color being chosen. Weights are relative to each other,
            not required to sum to 1.0.
    """

    color: tuple[int, int, int] | tuple[int, int, int, int]
    weight: float = 1.0


@dataclass
class NightSkyConfig:
    """Configuration options for generating a night sky image.

    Attributes:
        image_size: The (width, height) of the output image in pixels.
        background_color: The RGB or RGBA background color of the sky.
        cell_size: The size (in pixels) of each square grid cell used for
            distributing stars. Smaller cells combined with a fixed number
            of stars per cell produce more evenly spread stars.
        stars_per_cell: Number of stars placed in each grid cell.
        star_colors: A list of StarColorOption entries describing possible
            star colors and their relative likelihood.
        min_star_size: Minimum star radius in pixels.
        max_star_size: Maximum star radius in pixels.
        sparkle_size_threshold: Minimum star radius required for a star to
            receive a glow and 4-pointed sparkle effect. Stars smaller than
            this are rendered as plain filled circles.
        glow_radius_multiplier: Multiplier applied to star radius to
            determine the blur radius of the glow halo.
        glow_intensity: Opacity multiplier (0.0-1.0) applied to the glow
            layer before compositing.
        spike_length_multiplier: Multiplier applied to star radius to
            determine the length of the 4-pointed sparkle spikes.
        spike_width: Width in pixels of the sparkle spikes at their base.
        image_format: Output image format, e.g. "PNG", "JPEG", "BMP".
        seed: Optional random seed for reproducible output.
    """

    image_size: tuple[int, int] = (800, 600)
    background_color: tuple[int, int, int] = (5, 5, 20)
    cell_size: int = 50
    stars_per_cell: int = 2
    star_colors: list[StarColorOption] = field(
        default_factory=lambda: [
            StarColorOption((255, 255, 255), 0.6),
            StarColorOption((200, 220, 255), 0.2),
            StarColorOption((255, 244, 214), 0.15),
            StarColorOption((255, 200, 200), 0.05),
        ]
    )
    min_star_size: float = 0.5
    max_star_size: float = 2.5
    sparkle_size_threshold: float = 1.6
    glow_radius_multiplier: float = 4.0
    glow_intensity: float = 0.55
    spike_length_multiplier: float = 6.0
    spike_width: float = 1.0
    image_format: str = "PNG"
    seed: Optional[int] = None


class NightSkyGenerator:
    """Generates procedural night sky images composed of scattered stars."""

    def __init__(self, config: NightSkyConfig) -> None:
        """Initializes the generator with the given configuration.

        Args:
            config: A NightSkyConfig instance describing generation
                parameters.
        """
        self._config = config
        self._rng = random.Random(config.seed)

    def generate(self) -> Image.Image:
        """Generates a night sky image based on the current configuration.

        Returns:
            A PIL Image instance containing the rendered night sky.
        """
        width, height = self._config.image_size

        base = Image.new("RGBA", (width, height), self._to_rgba(self._config.background_color))
        overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay, "RGBA")

        self._draw_stars(overlay, draw, width, height)

        composited = Image.alpha_composite(base, overlay)

        if self._config.background_color and len(self._config.background_color) == 3:
            composited = composited.convert("RGB")

        return composited

    def save(self, output_path: str | Path) -> None:
        """Generates the night sky image and saves it to disk.

        Args:
            output_path: File path where the image will be saved. The
                extension does not need to match image_format, since
                image_format is passed explicitly to PIL's save method.
        """
        image = self.generate()
        image.save(str(output_path), format=self._config.image_format)

    @staticmethod
    def _to_rgba(
        color: tuple[int, int, int] | tuple[int, int, int, int]
    ) -> tuple[int, int, int, int]:
        """Converts an RGB or RGBA tuple into a full RGBA tuple.

        Args:
            color: An RGB or RGBA color tuple.

        Returns:
            An RGBA tuple with alpha defaulted to 255 if not provided.
        """
        if len(color) == 4:
            return color
        r, g, b = color
        return (r, g, b, 255)

    def _draw_stars(
        self,
        overlay: Image.Image,
        draw: ImageDraw.ImageDraw,
        width: int,
        height: int,
    ) -> None:
        """Draws all stars onto the given overlay using a grid-cell layout.

        Args:
            overlay: The RGBA overlay image that stars are composited onto.
            draw: The ImageDraw context bound to the overlay, used for
                plain (non-sparkle) stars.
            width: Width of the target image in pixels.
            height: Height of the target image in pixels.
        """
        cell_size = max(1, self._config.cell_size)
        cols = (width + cell_size - 1) // cell_size
        rows = (height + cell_size - 1) // cell_size

        for row in range(rows):
            for col in range(cols):
                cell_x0 = col * cell_size
                cell_y0 = row * cell_size
                cell_x1 = min(cell_x0 + cell_size, width)
                cell_y1 = min(cell_y0 + cell_size, height)

                for _ in range(self._config.stars_per_cell):
                    self._draw_single_star(
                        overlay, draw, cell_x0, cell_y0, cell_x1, cell_y1, width, height
                    )

    def _draw_single_star(
        self,
        overlay: Image.Image,
        draw: ImageDraw.ImageDraw,
        x0: int,
        y0: int,
        x1: int,
        y1: int,
        width: int,
        height: int,
    ) -> None:
        """Draws a single star at a random position within the given bounds.

        Args:
            overlay: The RGBA overlay image that stars are composited onto.
            draw: The ImageDraw context bound to the overlay.
            x0: Left bound of the cell.
            y0: Top bound of the cell.
            x1: Right bound of the cell.
            y1: Bottom bound of the cell.
            width: Width of the full target image, used for glow bounds.
            height: Height of the full target image, used for glow bounds.
        """
        if x1 <= x0 or y1 <= y0:
            return

        cx = self._rng.uniform(x0, x1)
        cy = self._rng.uniform(y0, y1)
        radius = self._rng.uniform(
            self._config.min_star_size, self._config.max_star_size
        )
        color = self._to_rgba(self._choose_color())

        if radius >= self._config.sparkle_size_threshold:
            self._draw_glow(overlay, cx, cy, radius, color, width, height)
            self._draw_sparkle(overlay, cx, cy, radius, color)
            self._draw_star_core(draw, cx, cy, radius, color)
        else:
            self._draw_star_core(draw, cx, cy, radius, color)

    @staticmethod
    def _draw_star_core(
        draw: ImageDraw.ImageDraw,
        cx: float,
        cy: float,
        radius: float,
        color: tuple[int, int, int, int],
    ) -> None:
        """Draws the solid circular core of a star.

        Args:
            draw: The ImageDraw context to draw onto.
            cx: X coordinate of the star's center.
            cy: Y coordinate of the star's center.
            radius: Radius of the star core in pixels.
            color: RGBA color of the star.
        """
        bbox = (cx - radius, cy - radius, cx + radius, cy + radius)
        draw.ellipse(bbox, fill=color)

    def _draw_glow(
        self,
        overlay: Image.Image,
        cx: float,
        cy: float,
        radius: float,
        color: tuple[int, int, int, int],
        width: int,
        height: int,
    ) -> None:
        """Draws a soft radial glow halo around a star and composites it.

        The glow is rendered on a small temporary layer sized to the glow
        radius, blurred with a Gaussian filter, and alpha-composited onto
        the main overlay at the star's position.

        Args:
            overlay: The RGBA overlay image to composite the glow onto.
            cx: X coordinate of the star's center.
            cy: Y coordinate of the star's center.
            radius: Radius of the star core in pixels, used to scale glow.
            color: RGBA color of the star, used as the glow tint.
            width: Width of the full target image.
            height: Height of the full target image.
        """
        glow_radius = radius * self._config.glow_radius_multiplier
        blur_amount = max(1.0, glow_radius / 2.0)
        patch_size = int(glow_radius * 2 + blur_amount * 4)
        if patch_size <= 0:
            return

        patch = Image.new("RGBA", (patch_size, patch_size), (0, 0, 0, 0))
        patch_draw = ImageDraw.Draw(patch, "RGBA")

        center = patch_size / 2.0
        glow_alpha = int(255 * self._config.glow_intensity)
        glow_color = (color[0], color[1], color[2], glow_alpha)

        bbox = (
            center - glow_radius,
            center - glow_radius,
            center + glow_radius,
            center + glow_radius,
        )
        patch_draw.ellipse(bbox, fill=glow_color)
        patch = patch.filter(ImageFilter.GaussianBlur(radius=blur_amount))

        paste_x = int(cx - center)
        paste_y = int(cy - center)

        target_region = (
            max(0, paste_x),
            max(0, paste_y),
            min(width, paste_x + patch_size),
            min(height, paste_y + patch_size),
        )
        if target_region[2] <= target_region[0] or target_region[3] <= target_region[1]:
            return

        overlay.alpha_composite(patch, dest=(paste_x, paste_y))

    def _draw_sparkle(
        self,
        overlay: Image.Image,
        cx: float,
        cy: float,
        radius: float,
        color: tuple[int, int, int, int],
    ) -> None:
        """Draws a 4-pointed sparkle (diffraction spike) effect for a star.

        Two crossed, tapered spikes are rendered (horizontal/vertical) with
        soft, faded tips, then composited onto the overlay.

        Args:
            overlay: The RGBA overlay image to composite the sparkle onto.
            cx: X coordinate of the star's center.
            cy: Y coordinate of the star's center.
            radius: Radius of the star core in pixels, used to scale spikes.
            color: RGBA color of the star, used as the sparkle tint.
        """
        spike_length = radius * self._config.spike_length_multiplier
        spike_width = max(0.5, self._config.spike_width)

        patch_size = int(spike_length * 2 + 4)
        if patch_size <= 0:
            return

        patch = Image.new("RGBA", (patch_size, patch_size), (0, 0, 0, 0))
        patch_draw = ImageDraw.Draw(patch, "RGBA")
        center = patch_size / 2.0

        max_alpha = min(255, color[3])
        sparkle_color = (color[0], color[1], color[2], max_alpha)

        for angle_deg in (0, 90):
            self._draw_tapered_spike(
                patch_draw, center, center, spike_length, spike_width, angle_deg, sparkle_color
            )

        blur_amount = max(0.5, spike_width / 2.0)
        patch = patch.filter(ImageFilter.GaussianBlur(radius=blur_amount))

        paste_x = int(cx - center)
        paste_y = int(cy - center)
        overlay.alpha_composite(patch, dest=(paste_x, paste_y))

    @staticmethod
    def _draw_tapered_spike(
        draw: ImageDraw.ImageDraw,
        cx: float,
        cy: float,
        length: float,
        width: float,
        angle_deg: float,
        color: tuple[int, int, int, int],
    ) -> None:
        """Draws a single tapered spike (diamond shape) from a center point.

        The spike is rendered as two triangles forming an elongated diamond
        pointing outward in both directions along the given angle, tapering
        from full opacity at the center to zero at the tips.

        Args:
            draw: The ImageDraw context to draw onto.
            cx: X coordinate of the spike's center.
            cy: Y coordinate of the spike's center.
            length: Half-length of the spike from center to each tip.
            width: Width of the spike at its widest point (the center).
            angle_deg: Angle in degrees defining the spike's orientation.
            color: RGBA color of the spike at full opacity.
        """
        angle_rad = math.radians(angle_deg)
        dx = math.cos(angle_rad)
        dy = math.sin(angle_rad)
        px = -dy
        py = dx

        half_width = width / 2.0

        tip1 = (cx + dx * length, cy + dy * length)
        tip2 = (cx - dx * length, cy - dy * length)
        side1 = (cx + px * half_width, cy + py * half_width)
        side2 = (cx - px * half_width, cy - py * half_width)

        steps = 12
        for i in range(steps):
            t0 = i / steps
            t1 = (i + 1) / steps

            alpha0 = int(color[3] * (1.0 - t0))
            alpha1 = int(color[3] * (1.0 - t1))
            segment_alpha = max(0, min(255, (alpha0 + alpha1) // 2))
            if segment_alpha <= 0:
                continue

            segment_color = (color[0], color[1], color[2], segment_alpha)

            p_center0 = (cx + dx * length * t0, cy + dy * length * t0)
            p_center1 = (cx + dx * length * t1, cy + dy * length * t1)
            w0 = half_width * (1.0 - t0)
            w1 = half_width * (1.0 - t1)

            poly = [
                (p_center0[0] + px * w0, p_center0[1] + py * w0),
                (p_center1[0] + px * w1, p_center1[1] + py * w1),
                (p_center1[0] - px * w1, p_center1[1] - py * w1),
                (p_center0[0] - px * w0, p_center0[1] - py * w0),
            ]
            draw.polygon(poly, fill=segment_color)

            neg_center0 = (cx - dx * length * t0, cy - dy * length * t0)
            neg_center1 = (cx - dx * length * t1, cy - dy * length * t1)
            neg_poly = [
                (neg_center0[0] + px * w0, neg_center0[1] + py * w0),
                (neg_center1[0] + px * w1, neg_center1[1] + py * w1),
                (neg_center1[0] - px * w1, neg_center1[1] - py * w1),
                (neg_center0[0] - px * w0, neg_center0[1] - py * w0),
            ]
            draw.polygon(neg_poly, fill=segment_color)

        _ = (tip1, tip2, side1, side2)

    def _choose_color(self) -> tuple[int, ...]:
        """Chooses a star color based on configured weighted options.

        Returns:
            An RGB or RGBA color tuple.

        Raises:
            ValueError: If no star colors are configured.
        """
        options = self._config.star_colors
        if not options:
            raise ValueError("star_colors must contain at least one entry.")

        colors = [opt.color for opt in options]
        weights = [max(0.0, opt.weight) for opt in options]

        if sum(weights) <= 0:
            return colors[0]

        return self._rng.choices(colors, weights=weights, k=1)[0]


def main() -> None:
    """Example entry point demonstrating night sky generation."""
    config_1 = NightSkyConfig(
        image_size=(1920, 1200),
        background_color=(10, 10, 10),
        cell_size=256,
        stars_per_cell=4,
        star_colors=[
            StarColorOption((255, 255, 255), 0.55),
            StarColorOption((100, 255, 255), 0.20), # turqoise
            StarColorOption((255, 100, 255), 0.15), # magneta
            StarColorOption((255, 255, 100), 0.10), # yellow
        ],
        min_star_size=0.4,
        max_star_size=2.5,
        sparkle_size_threshold=2.4,
        glow_radius_multiplier=4.5,
        glow_intensity=0.5,
        spike_length_multiplier=6.5,
        spike_width=1.2,
        image_format="PNG",
        seed=43,
    )

    config_2 = NightSkyConfig(
        image_size=(1920, 1200),
        background_color=(10, 10, 10),
        cell_size=256,
        stars_per_cell=10,
        star_colors=[
            StarColorOption((255, 255, 255), 0.55),
            StarColorOption((100, 255, 255), 0.20), # turqoise
            StarColorOption((255, 100, 255), 0.15), # magneta
            StarColorOption((255, 255, 100), 0.10), # yellow
        ],
        min_star_size=0.4,
        max_star_size=3.5,
        sparkle_size_threshold=3.0,
        glow_radius_multiplier=4.5,
        glow_intensity=0.5,
        spike_length_multiplier=6.5,
        spike_width=1.2,
        image_format="PNG",
        seed=43,
    )

    generator = NightSkyGenerator(config_2)
    generator.save("night_sky.png")


if __name__ == "__main__":
    main()