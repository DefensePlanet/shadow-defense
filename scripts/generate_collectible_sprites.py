"""
Generate collectible sprites (gold coin, quill, crystal shard) for Shadow Defense.
Matches the chibi sticker style of tower heroes and enemy sprites.
"""
import subprocess
import os
import sys
import time

API_KEY = os.environ.get("GEMINI_API_KEY", "")

# Same base style as our tower/enemy sprites for visual consistency
BASE_STYLE = (
    "Super cute chibi kawaii cartoon game item icon sticker, "
    "thick clean black outlines like a vinyl sticker, bright saturated colors, simple flat cel-shading, "
    "single item on pure white background, centered, "
    "digital cartoon illustration NOT pixel art, smooth clean vector-like rendering, "
    "mobile game collectible icon art style, 512x512, "
    "NO pixel art, NO dark palette, NO realistic proportions, NO detailed shading, "
    "NO text, NO watermark, NO background elements, NO ground shadow"
)

COLLECTIBLES = {
    "gold_coin": (
        "A shiny magical golden coin game collectible, thick chunky cartoon gold coin with a glowing star emblem in the center, "
        "sparkles and golden light rays emanating from it, bright yellow-gold metallic shine, "
        "cartoon treasure coin like from a mobile game, thick rim with decorative edge pattern, "
        "warm golden glow aura around the coin"
    ),
    "quill": (
        "A magical feather quill pen game collectible, elegant long peacock-blue and teal feather with golden shaft, "
        "glowing magical ink drops floating around the nib, enchanted writing quill with sparkles, "
        "the feather has iridescent blue-green-purple shimmer, golden metal nib tip with ink drop, "
        "magical aura glow around it, fantasy storybook quill pen"
    ),
    "crystal_shard": (
        "A glowing magical crystal shard game collectible, beautiful faceted purple amethyst crystal gem, "
        "bright purple and violet with inner magical glow, light refracting through crystal facets, "
        "sparkles and magical energy wisps around it, fantasy game power crystal, "
        "vibrant purple-pink-violet gradient crystal with bright white sparkle highlights"
    ),
}

OUTPUT_DIR = "C:/Users/johnh/shadow-defense/assets/collectible_sprites"


def generate_sprite(name: str, description: str):
    """Generate a single collectible sprite using nano-banana."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, f"{name}.png")

    full_prompt = f"{description}. {BASE_STYLE}"

    print(f"\n{'='*60}")
    print(f"Generating: {name}.png")
    print(f"Prompt: {description[:80]}...")
    print(f"{'='*60}")

    cmd = [
        "cmd", "//c",
        "nano-banana",
        full_prompt,
        "--output", output_path
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            env={**os.environ, "GEMINI_API_KEY": API_KEY}
        )
        if result.returncode == 0:
            print(f"  SUCCESS: {output_path}")
            return True
        else:
            print(f"  FAILED (exit {result.returncode}): {result.stderr[:200]}")
            return False
    except subprocess.TimeoutExpired:
        print(f"  TIMEOUT after 120s")
        return False
    except Exception as e:
        print(f"  ERROR: {e}")
        return False


def main():
    if not API_KEY:
        print("ERROR: GEMINI_API_KEY not set!")
        sys.exit(1)

    total = 0
    success = 0
    for name, desc in COLLECTIBLES.items():
        total += 1
        if generate_sprite(name, desc):
            success += 1
            time.sleep(3)
        else:
            time.sleep(5)

    print(f"\n{'='*60}")
    print(f"COMPLETE: {success}/{total} collectible sprites generated")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
