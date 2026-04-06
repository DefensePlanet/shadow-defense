#!/usr/bin/env python3
"""
Generate ALL story voice-over clips for Shadow Defense using ElevenLabs v3.
- Narrator lines → Brian voice (deep, resonant)
- Shadow Author lines → Dominic voice (dark, brooding)

Clip naming: {dialog_key}_{speaker}_{per_speaker_index}.mp3
This matches the runtime lookup in main.gd exactly.

Run: pip install elevenlabs && python generate_all_story_voices.py
Requires ELEVENLABS_API_KEY environment variable.
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

# === VOICE CONFIGURATION ===
NARRATOR_VOICE_ID = "nPczCjzI2devNBz1zQrb"  # Brian — Deep, Resonant
SHADOW_AUTHOR_VOICE_ID = "yhf80q1381zd2JJQ4tM7"  # Dominic — British, Dark, Brooding
MODEL_ID = "eleven_v3"  # Highest quality model

NARRATOR_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio", "voices", "narrator")
SHADOW_AUTHOR_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio", "voices", "shadow_author")


def parse_story_lines(main_gd_path: str) -> list[tuple[str, str, str, str]]:
    """
    Parse main.gd _init_story_dialogs() to extract narrator and shadow_author lines.
    Returns list of (speaker, clip_key, text, output_dir) tuples.
    """
    with open(main_gd_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Find _init_story_dialogs function
    sd_start = content.find("func _init_story_dialogs")
    if sd_start == -1:
        print("ERROR: Could not find _init_story_dialogs in main.gd")
        return []

    sd_block = content[sd_start:]

    # Pattern: story_dialogs["dialog_key"] = [ ... ]
    dialog_pattern = re.compile(
        r'story_dialogs\["([\w]+)"\]\s*=\s*\[(.*?)\](?=\s*(?:story_dialogs\[|func |var |$))',
        re.DOTALL
    )

    line_pattern = re.compile(
        r'"speaker":\s*"(\w+)".*?"text":\s*"([^"]+)"',
    )

    results = []

    for dialog_match in dialog_pattern.finditer(sd_block):
        dialog_key = dialog_match.group(1)
        dialog_body = dialog_match.group(2)

        # Per-speaker counting
        narrator_idx = 0
        shadow_idx = 0

        for line_match in line_pattern.finditer(dialog_body):
            speaker = line_match.group(1)
            text = line_match.group(2)
            # Unescape GDScript string escapes
            text = text.replace(" -- ", " — ").replace("\\n", " ")

            if speaker == "narrator":
                clip_key = f"{dialog_key}_narrator_{narrator_idx}"
                results.append(("narrator", clip_key, text, NARRATOR_DIR))
                narrator_idx += 1
            elif speaker == "shadow_author":
                clip_key = f"{dialog_key}_shadow_author_{shadow_idx}"
                results.append(("shadow_author", clip_key, text, SHADOW_AUTHOR_DIR))
                shadow_idx += 1

    return results


def generate_clip(client, voice_id: str, text: str, output_path: str) -> bool:
    """Generate a single MP3 voice clip via ElevenLabs API."""
    try:
        audio = client.text_to_speech.convert(
            voice_id=voice_id,
            text=text,
            model_id=MODEL_ID,
            output_format="mp3_44100_128",
        )
        with open(output_path, "wb") as f:
            for chunk in audio:
                f.write(chunk)
        return True
    except Exception as e:
        print(f"  ERROR: {e}")
        return False


def main():
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("ERROR: Set ELEVENLABS_API_KEY environment variable")
        sys.exit(1)

    client = ElevenLabs(api_key=api_key)

    main_gd = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts", "main.gd")
    print(f"Parsing story lines from {main_gd}...")
    lines = parse_story_lines(main_gd)

    narrator_count = sum(1 for l in lines if l[0] == "narrator")
    shadow_count = sum(1 for l in lines if l[0] == "shadow_author")
    print(f"Found {narrator_count} narrator + {shadow_count} shadow_author = {len(lines)} total lines.\n")

    if not lines:
        print("No lines found. Check parsing.")
        sys.exit(1)

    os.makedirs(NARRATOR_DIR, exist_ok=True)
    os.makedirs(SHADOW_AUTHOR_DIR, exist_ok=True)

    # Clear old clips with wrong naming
    for d in [NARRATOR_DIR, SHADOW_AUTHOR_DIR]:
        for f in os.listdir(d):
            if f.endswith(".mp3"):
                os.remove(os.path.join(d, f))
        print(f"Cleared old clips in {d}")

    generated = 0
    failed = 0

    for speaker, clip_key, text, out_dir in lines:
        voice_id = NARRATOR_VOICE_ID if speaker == "narrator" else SHADOW_AUTHOR_VOICE_ID
        output_path = os.path.join(out_dir, f"{clip_key}.mp3")

        print(f"  [{speaker:15s}] {clip_key}")
        print(f"    {text[:80]}{'...' if len(text) > 80 else ''}")

        if generate_clip(client, voice_id, text, output_path):
            generated += 1
            print(f"    OK")
        else:
            failed += 1

        time.sleep(0.3)

    print(f"\nDone! Generated: {generated}, Failed: {failed}")


if __name__ == "__main__":
    main()
