"""
Generate all 52 enemy sprites for Shadow Defense using Gemini image generation.
13 factions x 4 tiers = 52 sprites in chibi tower-defense style.
"""
import subprocess
import os
import sys
import time

# Gemini API key
API_KEY = os.environ.get("GEMINI_API_KEY", "")

# Base style prompt that matches our tower heroes (chibi sticker, like Alice & Peter Pan sprites)
BASE_STYLE = (
    "Super cute chibi kawaii cartoon character sticker, extremely big head tiny body proportions like a funko pop, "
    "thick clean black outlines like a vinyl sticker, bright saturated colors, simple flat cel-shading, "
    "big expressive anime eyes, standing front-facing idle pose, single character on pure white background, "
    "digital cartoon illustration NOT pixel art, smooth clean vector-like rendering, "
    "mobile game character art style, 1024x1024, "
    "NO pixel art, NO dark palette, NO realistic proportions, NO detailed shading, "
    "NO text, NO watermark, NO background elements, NO ground shadow"
)

# All 52 enemy descriptions organized by faction
ENEMIES = {
    # 0: Sherwood (Robin Hood - "The Merry Adventures of Robin Hood" 1883)
    "sherwood": [
        "A small greedy medieval tax collector, pudgy chibi figure with a coin purse and scroll, wearing brown robes and a floppy hat, sneaky expression",
        "A Nottingham castle guard soldier, chibi knight with chainmail armor, red tabard with sheriff crest, holding a spear, stern face",
        "A heavily armored Nottingham knight, chibi elite warrior with full plate armor, red plume helmet, wielding a longsword, intimidating",
        "The Sheriff's champion warrior, large chibi knight in ornate black and red armor, cape flowing, wielding a massive two-handed sword, menacing golden visor",
    ],
    # 1: Wonderland (Alice - "Alice's Adventures in Wonderland" 1865)
    "wonderland": [
        "A playing card soldier with spade suit marking, chibi figure with flat card-like body, red and white, carrying a small spear, silly expression",
        "Tweedledee from Alice in Wonderland, chibi round jolly figure in red propeller hat and striped shirt, mischievous grin, holding a rattle",
        "The March Hare from Alice in Wonderland, chibi anthropomorphic hare in a waistcoat, wild crazy eyes, holding a teacup, messy fur, unhinged smile",
        "The Knave of Hearts from Alice in Wonderland, chibi tall elegant card soldier in heart-patterned armor, crown, holding stolen tarts, smug expression",
    ],
    # 2: Oz (Wicked Witch - "The Wonderful Wizard of Oz" 1900)
    "oz": [
        "A Winkie guard soldier from Wizard of Oz, chibi figure in yellow uniform and tall fur hat, carrying a spear, loyal but dim expression",
        "A Flying Monkey from Wizard of Oz, chibi winged monkey with blue vest and red fez cap, bat-like wings, mischievous sharp-toothed grin",
        "A Winkie Captain elite soldier from Wizard of Oz, chibi armored figure in ornate golden yellow armor with green witch emblems, wielding a halberd",
        "A Nome King warrior from Wizard of Oz, chibi rocky stone creature with crystal crown, glowing orange eyes, jagged stone body, powerful and ancient",
    ],
    # 3: Neverland (Peter Pan - "Peter and Wendy" 1911)
    "neverland": [
        "A pirate deckhand from Peter Pan, chibi scruffy sailor in torn striped shirt, bandana, holding a mop and cutlass, missing teeth, scared expression",
        "A pirate swordsman from Captain Hook's crew, chibi pirate in red coat, tricorn hat, wielding a curved cutlass, aggressive grin, eye patch",
        "A pirate cannoneer from Captain Hook's ship, chibi burly pirate with bandolier, holding a lit cannonball, sooty face, wild beard",
        "Smee the first mate from Peter Pan, chibi round jolly pirate in blue and white striped shirt, red hat with pom-pom, small glasses, holding a razor, nervous smile",
    ],
    # 4: Opera (Phantom - "The Phantom of the Opera" 1910)
    "opera": [
        "A small opera house rat creature, chibi anthropomorphic rat in a tiny tattered tuxedo, glowing red eyes, standing upright, creepy but cute",
        "A masquerade phantom from Phantom of the Opera, chibi figure in elegant black cape and ornate Venetian mask, top hat, mysterious and theatrical",
        "An opera chandelier ghost, chibi ghostly transparent figure draped in crystal chandelier chains, glowing ethereal blue-white, floating, eerie smile",
        "The Persian stalker from Phantom of the Opera, chibi mysterious figure in dark Persian robes and turban, golden dagger, shadowed face, intense eyes",
    ],
    # 5: Victorian (Scrooge - "A Christmas Carol" 1843)
    "victorian": [
        "A workhouse wraith from A Christmas Carol, chibi small ghostly pale figure in ragged Victorian clothes, chains, transparent wispy body, sad hollow eyes",
        "The Ghost of Christmas Past from A Christmas Carol, chibi ethereal glowing figure with candle-flame hair, white flowing robes, gentle but unsettling, bright light aura",
        "The Ghost of Christmas Present from A Christmas Carol, chibi large jolly giant figure in green fur-trimmed robe, holly crown, holding a torch of plenty, booming laugh",
        "The Ghost of Christmas Future from A Christmas Carol, chibi tall dark hooded figure in pure black robes, no visible face, skeletal pointing hand, most terrifying of the three",
    ],
    # 6: Shadow Entities (Original)
    "shadow_entities": [
        "A small shadow wisp creature, chibi floating dark purple-black smoke orb with tiny glowing white eyes, wispy tendrils, ethereal and simple",
        "A shadow crawler creature, chibi four-legged dark beast made of living shadow, purple glowing cracks in body, hunched predatory pose, sharp claws",
        "A shadow knight warrior, chibi armored figure made entirely of dark shadow material, glowing purple visor, shadow sword, imposing dark presence",
        "A shadow titan colossus, chibi massive dark entity with swirling shadow body, multiple glowing purple eyes, dark crown of shadow thorns, overwhelming dark power",
    ],
    # 7: Sherlock (Holmes - "The Adventures of Sherlock Holmes" 1892)
    "sherlock": [
        "A Victorian London street thug, chibi rough figure in flat cap and shabby coat, holding a club, scar on face, menacing scowl, gaslit London feel",
        "One of Moriarty's spies, chibi figure in dark Victorian suit with bowler hat, monocle, concealed pistol, calculating cold expression, sinister",
        "Moriarty's assassin, chibi deadly figure in all-black Victorian clothing, top hat, wielding a thin rapier, cold emotionless face, elegant but lethal",
        "Colonel Sebastian Moran from Sherlock Holmes, chibi military figure with handlebar mustache, pith helmet, carrying a powerful air rifle, fierce predatory eyes, Moriarty's right hand",
    ],
    # 8: Merlin (Arthurian - "Le Morte d'Arthur" 1485)
    "merlin": [
        "A Saxon foot soldier, chibi barbarian warrior with round shield and short sword, fur cape, iron helmet, rough and aggressive, medieval dark age",
        "A dark knight of Mordred's army, chibi knight in tarnished black armor with red dragon emblem, wielding a mace, corrupted and menacing",
        "The Black Knight from Arthurian legend, chibi imposing knight in pitch-black full plate armor, red glowing visor, massive black shield, unbreakable warrior",
        "Mordred's champion knight, chibi sinister knight in ornate dark gold and black armor, twisted crown, wielding a cursed red sword, betrayal incarnate",
    ],
    # 9: Tarzan (Tarzan - "Tarzan of the Apes" 1912)
    "tarzan": [
        "A poacher scout from Tarzan, chibi figure in khaki safari outfit and pith helmet, binoculars, hunting knife, sneaky crouching pose, greedy eyes",
        "A poacher rifleman from Tarzan, chibi hunter in brown leather vest and boots, carrying a large elephant gun, ammunition belt, cruel expression",
        "A rogue ape warrior, chibi large aggressive gorilla with battle scars, bared fangs, pounding chest, red angry eyes, massive forearms",
        "Kerchak the rogue ape king from Tarzan, chibi enormous silverback gorilla with grey-white fur on back, scarred face, towering dominant pose, ancient and powerful",
    ],
    # 10: Dracula (Bram Stoker's "Dracula" 1897)
    "dracula": [
        "A bat swarm creature from Dracula, chibi cluster of vampire bats forming a vaguely humanoid shape, red glowing eyes, dark purple-black wings spread",
        "A vampire bride from Dracula, chibi beautiful but deadly pale woman in flowing white gown, fangs bared, red glowing eyes, long dark hair, seductive and terrifying",
        "Renfield the vampire thrall from Dracula, chibi wild-eyed madman in tattered asylum clothes, eating insects, hunched posture, crazed devoted expression",
        "A vampire knight guard, chibi armored undead warrior in ornate Transylvanian armor with bat wing motifs, glowing red eyes, wielding a cursed halberd, pale blue skin",
    ],
    # 11: Frankenstein (Mary Shelley's "Frankenstein" 1818)
    "frankenstein": [
        "A grave robber from Frankenstein, chibi hunched figure in dirty coat and lantern, shovel over shoulder, shifty nervous eyes, graveyard dirt on clothes",
        "A reanimated corpse from Frankenstein, chibi stitched-together zombie-like figure with visible bolts and stitches, green-grey skin, lurching pose, groaning expression",
        "Igor's creation, chibi mismatched body parts stitched together, one arm larger than the other, metal plates on skull, electrical sparks, shambling but strong",
        "The Bride of Frankenstein, chibi iconic figure with tall streaked black and white hair, white burial gown, stitches on neck, electrical bolts, beautiful but tragic and eerie",
    ],
    # 12: Shadow Author (Original - John's custom faction)
    "shadow_author": [
        "A tiny mischievous elf creature with black skin and bright green glowing markings, cute pointed ears, big round green glowing eyes, impish toothy grin, small horns, wisps of dark smoke around feet, playful troublemaker vibe",
        "A shadowy humanoid silhouette figure made of dark purple-black smoke, featureless smooth face with just two bright green glowing dot eyes, wearing a tattered dark cloak, mysterious floating pose, smoke wisps trailing off body",
        "A strange starfish-shaped insect creature with five pointed arms, shiny black chitinous shell body, bright green bioluminescent glowing joints and spots, multiple tiny cute eyes on center body, alien but adorable, compact star shape",
        "A creepy smiling entity with a round pure white face and huge wide grin showing teeth, empty black dot eyes, dark shadowy body in green-trimmed black robes, the white face contrasts against the dark body, unsettling but cute chibi proportions",
    ],
}

OUTPUT_BASE = "C:/Users/johnh/shadow-defense/assets/enemy_sprites"

def generate_sprite(faction: str, tier: int, description: str):
    """Generate a single enemy sprite using nano-banana."""
    output_dir = os.path.join(OUTPUT_BASE, faction)
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"tier_{tier}.png")

    full_prompt = f"{description}. {BASE_STYLE}"

    print(f"\n{'='*60}")
    print(f"Generating: {faction}/tier_{tier}.png")
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

    # Parse command line for optional faction filter
    faction_filter = None
    if len(sys.argv) > 1:
        faction_filter = sys.argv[1]
        print(f"Filtering to faction: {faction_filter}")

    total = 0
    success = 0
    failed = []

    for faction, descriptions in ENEMIES.items():
        if faction_filter and faction != faction_filter:
            continue
        for tier, desc in enumerate(descriptions):
            total += 1
            if generate_sprite(faction, tier, desc):
                success += 1
                # Rate limit - be nice to Gemini API
                time.sleep(2)
            else:
                failed.append(f"{faction}/tier_{tier}")
                time.sleep(5)  # Longer wait after failure

    print(f"\n{'='*60}")
    print(f"COMPLETE: {success}/{total} sprites generated")
    if failed:
        print(f"FAILED ({len(failed)}):")
        for f in failed:
            print(f"  - {f}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
