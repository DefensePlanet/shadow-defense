#!/usr/bin/env python3
"""
Generate voice-over catchphrase MP3 files for all tower characters using edge-tts.
Run: pip install edge-tts && python generate_voices.py
Outputs 48 MP3 files into audio/voices/{character}/ directories.
"""

import asyncio
import os
import edge_tts

# Voice configuration per character
VOICES = {
    "robin_hood": {"voice": "en-GB-RyanNeural", "pitch": "+0Hz", "rate": "+0%"},
    "alice": {"voice": "en-GB-LibbyNeural", "pitch": "+5Hz", "rate": "+5%"},
    "wicked_witch": {"voice": "en-US-JennyNeural", "pitch": "-5Hz", "rate": "+15%"},
    "peter_pan": {"voice": "en-GB-ThomasNeural", "pitch": "+10Hz", "rate": "+10%"},
    "phantom": {"voice": "en-US-GuyNeural", "pitch": "-15Hz", "rate": "-10%"},
    "scrooge": {"voice": "en-GB-RyanNeural", "pitch": "-5Hz", "rate": "-10%"},
}

# Placement quotes (tower placed on map)
PLACEMENT_QUOTES = {
    "robin_hood": [
        "Rob the rich to feed the poor!",
        "I am Robin Hood!",
        "Come, come, my merry men all!",
        "Robin Hood, at your service.",
    ],
    "alice": [
        "Curiouser and curiouser!",
        "Who in the world am I? Ah, that's the great puzzle.",
        "Down the rabbit hole we go!",
        "We're all mad here, you know.",
    ],
    "wicked_witch": [
        "I'll get you, my pretty, and your little dog too!",
        "Surrender, Dorothy!",
        "Fly, my pretties, fly!",
        "Now I shall have those silver shoes!",
    ],
    "peter_pan": [
        "I'm youth, I'm joy, I'm a little bird that has broken out of the egg!",
        "I don't want ever to be a man!",
        "To die will be an awfully big adventure!",
        "I'll never grow up!",
    ],
    "phantom": [
        "I am your Angel of Music.",
        "The Music of the Night!",
        "The Opera Ghost is here.",
        "If I am the Phantom, it is because man's hatred has made me so.",
    ],
    "scrooge": [
        "Bah! Humbug!",
        "Are there no prisons? No workhouses?",
        "I wish to be left alone.",
        "Every penny counts!",
    ],
}

# Fighting quotes (random, during combat)
FIGHTING_QUOTES = {
    "robin_hood": [
        "For Sherwood!",
        "My arrows fly true!",
        "Steal from the rich, defend the path!",
        "Another shot for the poor!",
    ],
    "alice": [
        "Off with their heads!",
        "How puzzling all these changes are!",
        "I could tell you my adventures, beginning from this morning.",
        "It would be so nice if something made sense for a change.",
    ],
    "wicked_witch": [
        "How about a little fire?",
        "I'll use the Golden Cap!",
        "You cursed brat!",
        "My beautiful wickedness!",
    ],
    "peter_pan": [
        "I do believe in fairies!",
        "Second star to the right!",
        "Wendy, one girl is more use than twenty boys!",
        "Oh, the cleverness of me!",
    ],
    "phantom": [
        "Sing for me!",
        "I am dying of love!",
        "The chandelier! Beware the chandelier!",
        "Your most obedient servant, the Opera Ghost.",
    ],
    "scrooge": [
        "Humbug!",
        "I will honour Christmas in my heart!",
        "Every idiot who goes about with Merry Christmas on his lips!",
        "God bless us, every one!",
    ],
}


async def generate_clip(text: str, voice: str, pitch: str, rate: str, output_path: str):
    """Generate a single MP3 voice clip."""
    communicate = edge_tts.Communicate(text, voice, pitch=pitch, rate=rate)
    await communicate.save(output_path)
    print(f"  Generated: {output_path}")


async def main():
    base_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio", "voices")
    total = 0

    for character, voice_cfg in VOICES.items():
        char_dir = os.path.join(base_dir, character)
        os.makedirs(char_dir, exist_ok=True)

        # Placement quotes
        for i, quote in enumerate(PLACEMENT_QUOTES[character]):
            output_path = os.path.join(char_dir, f"place_{i}.mp3")
            await generate_clip(
                quote, voice_cfg["voice"], voice_cfg["pitch"], voice_cfg["rate"], output_path
            )
            total += 1

        # Fighting quotes
        for i, quote in enumerate(FIGHTING_QUOTES[character]):
            output_path = os.path.join(char_dir, f"fight_{i}.mp3")
            await generate_clip(
                quote, voice_cfg["voice"], voice_cfg["pitch"], voice_cfg["rate"], output_path
            )
            total += 1

    print(f"\nDone! Generated {total} voice clips in {base_dir}")


if __name__ == "__main__":
    asyncio.run(main())
