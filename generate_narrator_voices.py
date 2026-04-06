#!/usr/bin/env python3
"""
Generate narrator voice-over MP3 files using ElevenLabs API.
Voice: Strong American male — direct, commanding, authoritative.

Run: pip install elevenlabs && python generate_narrator_voices.py
Requires ELEVENLABS_API_KEY environment variable.

Outputs MP3 files into audio/voices/narrator/ with keys matching
the narrator clip loading system in main.gd.
"""

import os
import re
import sys
import time

try:
    from elevenlabs import ElevenLabs
except ImportError:
    print("ERROR: elevenlabs package not installed. Run: pip install elevenlabs")
    sys.exit(1)

# === CONFIGURATION ===
# "Clyde" — deep, gruff, war veteran, commanding American military
VOICE_ID = "2EiwWnXFnvU5JabPnv8n"
MODEL_ID = "eleven_turbo_v2_5"
# Voice settings for commanding narrator delivery
VOICE_SETTINGS = {
    "stability": 0.70,          # Steady, authoritative
    "similarity_boost": 0.75,   # Natural but distinctive
    "style": 0.30,              # Some dramatic flair without overdoing it
    "use_speaker_boost": True,
}

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio", "voices", "narrator")


def parse_narrator_lines(main_gd_path: str) -> list[tuple[str, str]]:
    """
    Parse main.gd to extract all narrator dialog lines with their clip keys.
    Returns list of (clip_key, text) tuples.
    Handles format: story_dialogs["key"] = [ {speaker, text, voice_type}, ... ]
    """
    with open(main_gd_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Pattern: story_dialogs["dialog_key"] = [ ... ]
    dialog_pattern = re.compile(
        r'story_dialogs\["([\w]+)"\]\s*=\s*\[(.*?)\](?=\s*(?:story_dialogs|func |var |#))',
        re.DOTALL
    )

    # Pattern for individual lines within a dialog
    line_pattern = re.compile(
        r'"speaker":\s*"(\w+)".*?"text":\s*"([^"]+)"',
    )

    results = []
    sd_start = content.find("func _init_story_dialogs")
    if sd_start == -1:
        print("ERROR: Could not find _init_story_dialogs in main.gd")
        return results

    sd_block = content[sd_start:]

    for dialog_match in dialog_pattern.finditer(sd_block):
        dialog_key = dialog_match.group(1)
        dialog_body = dialog_match.group(2)

        # Count narrator/shadow_author lines together (combined index for clip keys)
        combined_idx = 0
        for line_match in line_pattern.finditer(dialog_body):
            speaker = line_match.group(1)
            text = line_match.group(2)
            if speaker == "narrator":
                clip_key = f"{dialog_key}_{combined_idx}"
                results.append((clip_key, text))
                combined_idx += 1
            elif speaker == "shadow_author":
                combined_idx += 1  # Count but don't generate

    return results


def generate_clip(client: "ElevenLabs", text: str, output_path: str) -> bool:
    """Generate a single MP3 voice clip via ElevenLabs API."""
    try:
        audio = client.text_to_speech.convert(
            voice_id=VOICE_ID,
            text=text,
            model_id=MODEL_ID,
            voice_settings=VOICE_SETTINGS,
            output_format="mp3_44100_128",
        )
        with open(output_path, "wb") as f:
            for chunk in audio:
                f.write(chunk)
        return True
    except Exception as e:
        print(f"  ERROR generating {output_path}: {e}")
        return False


def main():
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("ERROR: Set ELEVENLABS_API_KEY environment variable")
        print("  Get your key at: https://elevenlabs.io/app/settings/api-keys")
        sys.exit(1)

    client = ElevenLabs(api_key=api_key)

    # Parse narrator lines from main.gd
    main_gd = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts", "main.gd")
    print(f"Parsing narrator lines from {main_gd}...")
    lines = parse_narrator_lines(main_gd)
    print(f"Found {len(lines)} narrator lines to generate.\n")

    if not lines:
        print("No narrator lines found. Check main.gd parsing.")
        sys.exit(1)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    generated = 0
    skipped = 0
    failed = 0

    for clip_key, text in lines:
        output_path = os.path.join(OUTPUT_DIR, f"{clip_key}.mp3")

        # Skip if already generated
        if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
            print(f"  SKIP (exists): {clip_key}")
            skipped += 1
            continue

        print(f"  Generating: {clip_key}")
        print(f"    Text: {text[:80]}{'...' if len(text) > 80 else ''}")

        if generate_clip(client, text, output_path):
            generated += 1
            print(f"    OK -> {output_path}")
        else:
            failed += 1

        # Rate limit: ElevenLabs free tier = ~3 req/s
        time.sleep(0.4)

    print(f"\nDone! Generated: {generated}, Skipped: {skipped}, Failed: {failed}")
    print(f"Output directory: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
