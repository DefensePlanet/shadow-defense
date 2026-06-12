#!/usr/bin/env python3
"""Generate ElevenLabs voice clips for 6 new Shadow Defense characters."""

import requests
import time
import os
import sys

API_KEY = "sk_7472e6cf195bf8edad6a3e987b5db9afb81da520947f023e"
BASE_URL = "https://api.elevenlabs.io/v1/text-to-speech"
VOICES_DIR = os.path.dirname(os.path.abspath(__file__))

HEADERS = {
    "xi-api-key": API_KEY,
    "Content-Type": "application/json",
}

VOICE_SETTINGS = {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.4,
    "use_speaker_boost": True,
}

CHARACTERS = {
    "captain_hook": {
        "voice_id": "dUercWozs0yhe4xBCgZ0",
        "place": [
            "Good form demands I take this position.",
            "The Jolly Roger anchors HERE.",
            "Captain James Hook, at your service.",
            "Where's that infernal ticking?",
            "No one outfights Captain Hook!",
            "This spot will do. A captain knows strategic ground.",
            "Pan isn't here? Pity. I'll settle for lesser prey.",
        ],
        "fight": [
            "Have at you!",
            "Taste my HOOK!",
            "Bad form! Very BAD form!",
            "To Davy Jones with you!",
            "The captain STRIKES!",
            "You fight like a Lost Boy!",
            "PREPARE TO BE BOARDED!",
        ],
    },
    "queen_of_hearts": {
        "voice_id": "flHkNRp1BlvT73UL6gyz",
        "place": [
            "OFF WITH THEIR HEADS!",
            "I am the QUEEN. This is MY domain now.",
            "Card soldiers, fall in line!",
            "This garden needs... painting RED.",
            "Who dares place me here? Oh. Very well.",
            "I rule here now. ALL of you, BOW.",
            "The trial begins. And I am JUDGE.",
        ],
        "fight": [
            "OFF WITH YOUR HEAD!",
            "GUILTY! The sentence is DEATH!",
            "My cards will DESTROY you!",
            "NO ONE defies the QUEEN!",
            "PAINT THEM RED!",
            "The croquet match is OVER!",
            "EXECUTIONER!",
        ],
    },
    "clayton": {
        "voice_id": "goT3UYdM9bhm0n2lmKQx",
        "place": [
            "The hunt begins.",
            "I've tracked more dangerous prey than this.",
            "Strategic position. Good sight lines.",
            "My rifle is loaded. Let them come.",
            "Every hunter needs a vantage point.",
            "I see the tracks. They'll come through here.",
            "Clayton doesn't miss.",
        ],
        "fight": [
            "Target acquired.",
            "Clean shot.",
            "Nowhere to hide.",
            "The trap is sprung.",
            "Big game.",
            "Down you go.",
            "Trophy kill.",
        ],
    },
    "headless_horseman": {
        "voice_id": "vfaqCOvlrKi4Zp7C2IAm",
        "place": [
            "The ride begins again.",
            "Fear follows where I tread.",
            "This hollow will be mine.",
            "The bridge awaits its guardian.",
            "Darkness falls. I rise.",
            "My sword hungers.",
            "The legend never dies.",
        ],
        "fight": [
            "RIDE!",
            "BURN!",
            "FEAR ME!",
            "The hollow claims another!",
            "HELLFIRE!",
            "No escape!",
            "THE LEGEND STRIKES!",
        ],
    },
    "medusa": {
        "voice_id": "eVItLK1UvXctxuaRV2Oq",
        "place": [
            "Look upon me, if you dare.",
            "My garden grows with every battle.",
            "The serpents are hungry.",
            "Do not meet my gaze. You won't survive it.",
            "I was beautiful once. Now I am powerful.",
            "Stone is forever. So am I.",
            "The Gorgon takes her throne.",
        ],
        "fight": [
            "STONE!",
            "Look at me!",
            "My serpents STRIKE!",
            "Turn to STONE!",
            "Venom and fury!",
            "PETRIFY!",
            "The Gorgon's wrath!",
        ],
    },
    "anubis": {
        "voice_id": "kqVT88a5QfII1HNAEPTJ",
        "place": [
            "The scales are balanced. For now.",
            "I am the judge. I am the reckoning.",
            "Your hearts will be weighed.",
            "Ma'at demands justice.",
            "Five thousand years of judgment. What are a few more?",
            "The gate between life and death stands here.",
            "Ammit hungers for the unworthy.",
        ],
        "fight": [
            "JUDGMENT!",
            "Your heart is HEAVY!",
            "Ammit DEVOURS!",
            "The scales TIP!",
            "DEATH CLAIMS YOU!",
            "Unworthy!",
            "TO THE DUAT!",
        ],
    },
}


def generate_clip(voice_id: str, text: str, output_path: str) -> bool:
    """Generate a single voice clip. Returns True on success."""
    url = f"{BASE_URL}/{voice_id}"
    body = {
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": VOICE_SETTINGS,
    }

    for attempt in range(2):
        try:
            resp = requests.post(url, headers=HEADERS, json=body, timeout=30)
            if resp.status_code == 200:
                with open(output_path, "wb") as f:
                    f.write(resp.content)
                size_kb = len(resp.content) / 1024
                print(f"  OK  {os.path.basename(output_path)} ({size_kb:.1f} KB)")
                return True
            else:
                print(f"  ERR {os.path.basename(output_path)} - HTTP {resp.status_code}: {resp.text[:120]}")
                if attempt == 0:
                    print("       Retrying in 3s...")
                    time.sleep(3)
        except Exception as e:
            print(f"  ERR {os.path.basename(output_path)} - {e}")
            if attempt == 0:
                print("       Retrying in 3s...")
                time.sleep(3)

    return False


def main():
    total = 0
    success = 0
    failed = []

    for char_name, char_data in CHARACTERS.items():
        voice_id = char_data["voice_id"]
        char_dir = os.path.join(VOICES_DIR, char_name)
        os.makedirs(char_dir, exist_ok=True)

        print(f"\n{'='*60}")
        print(f"CHARACTER: {char_name} (voice: {voice_id})")
        print(f"{'='*60}")

        for clip_type in ["place", "fight"]:
            lines = char_data[clip_type]
            print(f"\n  --- {clip_type} lines ---")
            for i, text in enumerate(lines):
                filename = f"{clip_type}_{i}.mp3"
                output_path = os.path.join(char_dir, filename)
                total += 1

                print(f"  [{total:02d}/84] \"{text[:50]}{'...' if len(text)>50 else ''}\"")

                if generate_clip(voice_id, text, output_path):
                    success += 1
                else:
                    failed.append(f"{char_name}/{filename}")

                # 2 second sleep between API calls
                if total < 84:
                    time.sleep(2)

    print(f"\n{'='*60}")
    print(f"COMPLETE: {success}/{total} clips generated successfully")
    if failed:
        print(f"FAILED ({len(failed)}):")
        for f in failed:
            print(f"  - {f}")
    print(f"{'='*60}")

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
