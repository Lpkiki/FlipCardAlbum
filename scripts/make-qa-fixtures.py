"""Create synthetic PhotosPicker fixtures. Requires Python 3 and Pillow."""

from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

output = Path(sys.argv[1] if len(sys.argv) > 1 else "build/qa-fixtures")
output.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 700)
colors = ["#DA496B", "#377DBD", "#52A381", "#DA9B47", "#9172C9"]

for index, color in enumerate(colors, 1):
    image = Image.new("RGBA", (2400, 1800), (0, 0, 0, 0))
    drawing = ImageDraw.Draw(image)
    drawing.rounded_rectangle((240, 180, 2160, 1620), radius=160, fill=color)
    drawing.text((900, 600), str(index), fill="white", font=font)
    image.save(output / f"qa-photo-{index}.png")

print(f"Created five synthetic PNG fixtures in {output}")
