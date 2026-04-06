#!/usr/bin/env python3
"""
Generate Shadow Author fight taunts and placement quotes.
Kallixis main voice + Matthew Demon glitch at 75% through each line.
"""
import os, time, sys

try:
    from elevenlabs import ElevenLabs
    from pydub import AudioSegment
except ImportError:
    print("pip install elevenlabs pydub")
    sys.exit(1)

KALLIXIS = "cPoqAvGWCPfCfyPMwe4z"
MATTHEW_DEMON = "rCYFsCX2waxtHCgVD0e8"
MODEL = "eleven_v3"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio", "voices", "shadow_author")
TMP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "shadow-audition")

FIGHT_QUOTES = [
    "Your stories end here... in MY pages!",
    "I have rewritten stronger heroes than you... into oblivion!",
    "Every word you speak... feeds my power!",
    "You cannot defeat your own author... I created this world!",
    "Run back to your chapters... before I erase you entirely!",
    "I am every nightmare... you were never brave enough to face!",
    "The ink is drying... and YOUR story ends in darkness!",
]

PLACE_QUOTES = [
    "I'm REWRITING your ending!",
    "Your story ENDS here!",
    "Every word you speak feeds MY power!",
]


def gen_clip(client, voice_id, text, path):
    audio = client.text_to_speech.convert(
        voice_id=voice_id, text=text, model_id=MODEL, output_format="mp3_44100_128",
    )
    with open(path, "wb") as f:
        for chunk in audio:
            f.write(chunk)
    time.sleep(0.3)


def gen_glitch_clip(client, key, text):
    words = text.split()
    total = len(words)
    glitch_start = int(total * 0.75)
    glitch_len = min(3, total - glitch_start)
    if glitch_len < 2:
        glitch_len = 2
    if glitch_start + glitch_len > total:
        glitch_start = max(0, total - glitch_len)

    part_before = " ".join(words[:glitch_start])
    part_glitch = " ".join(words[glitch_start : glitch_start + glitch_len])
    part_after = " ".join(words[glitch_start + glitch_len :])

    p_a = os.path.join(TMP, f"{key}_a.mp3")
    p_g = os.path.join(TMP, f"{key}_g.mp3")
    p_c = os.path.join(TMP, f"{key}_c.mp3")

    if part_before:
        gen_clip(client, KALLIXIS, part_before, p_a)
    gen_clip(client, MATTHEW_DEMON, part_glitch, p_g)
    if part_after:
        gen_clip(client, KALLIXIS, part_after, p_c)

    combined = AudioSegment.empty()
    if part_before and os.path.exists(p_a):
        combined += AudioSegment.from_mp3(p_a)
    if os.path.exists(p_g):
        combined += AudioSegment.from_mp3(p_g) + 3
    if part_after and os.path.exists(p_c):
        combined += AudioSegment.from_mp3(p_c)

    final = os.path.join(OUT, f"{key}.mp3")
    combined.export(final, format="mp3", bitrate="128k")

    for p in [p_a, p_g, p_c]:
        if os.path.exists(p):
            os.remove(p)

    print(f"  {key}: {text[:60]}")
    print(f"    GLITCH: {part_glitch}")
    print(f"    OK")


def main():
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("Set ELEVENLABS_API_KEY")
        sys.exit(1)

    client = ElevenLabs(api_key=api_key)
    os.makedirs(TMP, exist_ok=True)

    print("=== FIGHT TAUNTS ===")
    for i, text in enumerate(FIGHT_QUOTES):
        gen_glitch_clip(client, f"fight_{i}", text)

    print("\n=== PLACEMENT QUOTES ===")
    for i, text in enumerate(PLACE_QUOTES):
        gen_glitch_clip(client, f"place_{i}", text)

    print(f"\nDone! Generated {len(FIGHT_QUOTES)} fight + {len(PLACE_QUOTES)} place clips")


if __name__ == "__main__":
    main()
