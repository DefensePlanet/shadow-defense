"""Generate tab nav icons for Shadow Defense."""
from PIL import Image, ImageDraw, ImageFont
import math, os

SIZE = 128
OUT = os.path.dirname(os.path.abspath(__file__))

def new(bg=(0,0,0,0)):
    return Image.new("RGBA", (SIZE, SIZE), bg)

def save(img, name):
    img.save(os.path.join(OUT, name))
    print(f"  Created {name}")

# Color palette - warm gold/amber to match the dark fantasy theme
GOLD = (218, 165, 32, 255)
LIGHT_GOLD = (255, 215, 100, 255)
DIM_GOLD = (160, 120, 20, 255)

def draw_survivors():
    """Three person silhouettes - group of survivors"""
    img = new()
    d = ImageDraw.Draw(img)
    # Center person (taller)
    d.ellipse([52, 18, 76, 42], fill=GOLD)  # head
    d.rounded_rectangle([46, 44, 82, 95], radius=8, fill=GOLD)  # body
    # Left person
    d.ellipse([20, 30, 40, 50], fill=DIM_GOLD)  # head
    d.rounded_rectangle([16, 52, 44, 95], radius=6, fill=DIM_GOLD)  # body
    # Right person
    d.ellipse([88, 30, 108, 50], fill=DIM_GOLD)  # head
    d.rounded_rectangle([84, 52, 112, 95], radius=6, fill=DIM_GOLD)  # body
    # Ground line
    d.line([10, 100, 118, 100], fill=LIGHT_GOLD, width=2)
    save(img, "tab_survivors.png")

def draw_gear():
    """Gear/cog wheel icon"""
    img = new()
    d = ImageDraw.Draw(img)
    cx, cy = 64, 60
    # Outer gear teeth
    for i in range(8):
        angle = i * math.pi / 4
        x1 = cx + 38 * math.cos(angle) - 8
        y1 = cy + 38 * math.sin(angle) - 8
        x2 = cx + 38 * math.cos(angle) + 8
        y2 = cy + 38 * math.sin(angle) + 8
        d.rectangle([x1, y1, x2, y2], fill=GOLD)
    # Outer circle
    d.ellipse([cx-30, cy-30, cx+30, cy+30], fill=GOLD)
    # Inner circle (hole)
    d.ellipse([cx-14, cy-14, cx+14, cy+14], fill=(0,0,0,0))
    # Center dot
    d.ellipse([cx-5, cy-5, cx+5, cy+5], fill=LIGHT_GOLD)
    save(img, "tab_gear.png")

def draw_chapters():
    """Open book icon"""
    img = new()
    d = ImageDraw.Draw(img)
    # Left page
    d.polygon([(64, 30), (18, 22), (18, 95), (64, 100)], fill=GOLD)
    # Right page
    d.polygon([(64, 30), (110, 22), (110, 95), (64, 100)], fill=DIM_GOLD)
    # Spine
    d.line([64, 28, 64, 102], fill=LIGHT_GOLD, width=3)
    # Page lines left
    for y in range(42, 88, 10):
        d.line([28, y, 58, y+2], fill=(40, 30, 10, 180), width=1)
    # Page lines right
    for y in range(42, 88, 10):
        d.line([70, y+2, 100, y], fill=(40, 30, 10, 180), width=1)
    save(img, "tab_chapters.png")

def draw_chronicles():
    """Scroll/parchment icon"""
    img = new()
    d = ImageDraw.Draw(img)
    # Main scroll body
    d.rounded_rectangle([30, 20, 98, 100], radius=4, fill=GOLD)
    # Top roll
    d.ellipse([26, 14, 102, 32], fill=LIGHT_GOLD)
    d.rectangle([30, 20, 98, 26], fill=GOLD)
    # Bottom roll
    d.ellipse([26, 92, 102, 108], fill=LIGHT_GOLD)
    d.rectangle([30, 96, 98, 100], fill=GOLD)
    # Text lines
    for y in range(38, 88, 10):
        w = 50 if y < 78 else 35
        d.line([42, y, 42+w, y], fill=(60, 40, 10, 200), width=2)
    save(img, "tab_chronicles.png")

def draw_emporium():
    """Shop/store bag icon"""
    img = new()
    d = ImageDraw.Draw(img)
    # Bag body
    d.rounded_rectangle([25, 45, 103, 105], radius=10, fill=GOLD)
    # Handle
    d.arc([40, 18, 88, 58], start=180, end=0, fill=LIGHT_GOLD, width=5)
    # Coin/diamond emblem in center
    d.regular_polygon((64, 75, 15), n_sides=4, rotation=45, fill=LIGHT_GOLD)
    d.regular_polygon((64, 75, 8), n_sides=4, rotation=45, fill=(100, 70, 10, 255))
    save(img, "tab_emporium.png")

def draw_achievements():
    """Trophy/star icon"""
    img = new()
    d = ImageDraw.Draw(img)
    # Star points
    points = []
    for i in range(10):
        angle = math.pi * 2 * i / 10 - math.pi / 2
        r = 40 if i % 2 == 0 else 20
        points.append((64 + r * math.cos(angle), 55 + r * math.sin(angle)))
    d.polygon(points, fill=GOLD)
    # Inner star glow
    inner = []
    for i in range(10):
        angle = math.pi * 2 * i / 10 - math.pi / 2
        r = 22 if i % 2 == 0 else 11
        inner.append((64 + r * math.cos(angle), 55 + r * math.sin(angle)))
    d.polygon(inner, fill=LIGHT_GOLD)
    # Base/pedestal
    d.rounded_rectangle([44, 96, 84, 108], radius=3, fill=DIM_GOLD)
    save(img, "tab_achievements.png")

print("Generating tab icons...")
draw_survivors()
draw_gear()
draw_chapters()
draw_chronicles()
draw_emporium()
draw_achievements()
print("Done! 6 icons created.")
