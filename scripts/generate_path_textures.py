"""
Generate path textures for Shadow Defense - one per novel faction (13 total).
These are horizontal strip textures that will be drawn along the enemy path curves.
Each texture matches the novel's world/theme for immersive visual storytelling.
"""
import subprocess
import os
import sys
import time

API_KEY = os.environ.get("GEMINI_API_KEY", "")

# Path textures need a different style - they're environment art, not character stickers
PATH_STYLE = (
    "Top-down view seamless horizontal path texture for a 2D tower defense game, "
    "painterly fantasy art style with rich colors and detail, "
    "the path should fill the entire image horizontally like a road/trail strip viewed from above, "
    "edges should blend to transparency or have natural ground edges (grass, dirt, rubble), "
    "1024x256 horizontal strip, high quality game environment art, "
    "NO characters, NO text, NO watermark, NO UI elements, "
    "detailed painted texture suitable for a storybook fantasy game"
)

# 13 faction path textures - one per novel world
PATH_TEXTURES = {
    "prologue": (
        "A magical glowing ink river path, dark purple-black flowing ink with golden sparkles and glowing rune symbols, "
        "ancient parchment edges crumbling on the sides, mystical storybook page aesthetic, "
        "swirling calligraphy ink patterns in the path surface, ethereal purple and gold glow"
    ),
    "sherlock": (
        "Victorian London cobblestone street path, wet dark grey-brown cobblestones glistening in gaslight, "
        "puddles reflecting warm yellow lamp light, fog wisps along edges, "
        "iron manhole covers and drainage grates, classic Baker Street atmosphere, dark moody Victorian"
    ),
    "merlin": (
        "Ancient Arthurian castle stone path with magical rune carvings glowing blue, "
        "weathered grey flagstones with moss growing between cracks, "
        "faint blue magical energy lines running through carved Celtic knot patterns, "
        "medieval castle courtyard feel with scattered autumn leaves"
    ),
    "tarzan": (
        "Dense jungle trail with packed earth and exposed tree roots, "
        "tropical vines and ferns encroaching from edges, dappled sunlight through canopy, "
        "rich brown-red earth with scattered exotic flowers, "
        "wooden log bridges and stepping stones, lush green vegetation borders"
    ),
    "dracula": (
        "Dark gothic Transylvanian castle corridor path, ancient cracked dark stone tiles, "
        "crimson red carpet runner down the center worn and frayed, "
        "blood-red candle wax drips and gothic iron torch brackets on edges, "
        "dark and foreboding with subtle red glow, cobwebs in corners"
    ),
    "frankenstein": (
        "Steampunk laboratory metal floor path with exposed copper wiring and electrical conduits, "
        "iron grating floor plates with green electrical sparks, "
        "tesla coil energy arcs across the surface, chemical stain marks, "
        "industrial Victorian science lab aesthetic with brass fittings and bolts"
    ),
    "robin_hood": (
        "Sherwood Forest sun-dappled dirt trail, warm brown-gold packed earth path, "
        "fallen oak leaves and acorns scattered on the trail, "
        "grass and wildflowers growing along edges, wooden arrow signs, "
        "warm golden sunlight filtering through forest canopy, fairy-tale woodland feel"
    ),
    "alice": (
        "Wonderland checkered garden path with alternating red and white diamond tiles, "
        "playing card suit symbols (hearts, spades, diamonds, clubs) embedded in tiles, "
        "oversized mushroom caps and rose bushes along edges, "
        "whimsical colorful mad tea party aesthetic, teacups and saucers scattered near edges"
    ),
    "oz": (
        "The famous Yellow Brick Road, bright golden-yellow bricks in a herringbone pattern, "
        "sparkling emerald green glow between brick joints, "
        "poppy flowers and emerald crystals along the edges, "
        "magical shimmering golden surface catching rainbow light, iconic and vibrant"
    ),
    "peter_pan": (
        "Pirate ship wooden deck plank path, weathered oak wood planks with rope coils and nautical knots, "
        "barnacles and sea salt stains, treasure map fragments scattered, "
        "brass compass rose embedded in the boards, "
        "Caribbean tropical ocean aesthetic with turquoise water glimpses at plank gaps"
    ),
    "phantom": (
        "Grand opera house hallway path, rich burgundy and gold ornate carpet with damask pattern, "
        "marble floor edges with gilded trim, scattered rose petals, "
        "dramatic candlelight reflections on polished surfaces, "
        "broken chandelier crystals glittering on the path, theatrical dark elegance"
    ),
    "scrooge": (
        "Snowy Victorian London cobblestone path, frost-covered grey stones with fresh snow, "
        "ice patches reflecting blue winter moonlight, "
        "holly berries and evergreen sprigs along edges, Christmas lantern warm glow spots, "
        "gentle snowfall accumulation, cozy yet eerie Christmas Eve atmosphere"
    ),
    "shadow_author": (
        "Ethereal shadow dimension path, floating dark obsidian platforms over a void, "
        "bright green eldritch energy lines connecting the platforms, "
        "dark smoky wisps and shadow tendrils curling up from edges, "
        "glowing green cracks in the dark stone surface, otherworldly and mysterious"
    ),
}

OUTPUT_DIR = "C:/Users/johnh/shadow-defense/assets/path_textures"


def generate_texture(faction: str, description: str):
    """Generate a single path texture using nano-banana."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, f"path_{faction}.png")

    full_prompt = f"{description}. {PATH_STYLE}"

    print(f"\n{'='*60}")
    print(f"Generating: path_{faction}.png")
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

    faction_filter = None
    if len(sys.argv) > 1:
        faction_filter = sys.argv[1]
        print(f"Filtering to faction: {faction_filter}")

    total = 0
    success = 0
    failed = []

    for faction, desc in PATH_TEXTURES.items():
        if faction_filter and faction != faction_filter:
            continue
        total += 1
        if generate_texture(faction, desc):
            success += 1
            time.sleep(3)
        else:
            failed.append(faction)
            time.sleep(5)

    print(f"\n{'='*60}")
    print(f"COMPLETE: {success}/{total} path textures generated")
    if failed:
        print(f"FAILED ({len(failed)}):")
        for f in failed:
            print(f"  - {f}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
