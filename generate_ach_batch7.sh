#!/bin/bash
export GEMINI_API_KEY="AIzaSyBr_MLM8yTB7bntayesxQ0LTZi7CuiibA0"
cd "C:/Users/johnh/shadow-defense/assets/achievement_icons"

STYLE="fantasy RPG game achievement badge icon, dark background, centered subject, stylized digital painting, glowing magical lighting, game asset art style like World of Warcraft or Diablo achievement icons, NOT photorealistic, NOT a photograph"

generate() {
    local id="$1"
    local desc="$2"
    if [ -f "${id}.png" ]; then
        echo "SKIP: ${id}.png exists"
        return
    fi
    echo "GEN: ${id}"
    nano-banana "${STYLE}, ${desc}" --output "${id}.png" 2>/dev/null
    if [ -f "${id}.png" ]; then
        echo "OK: ${id}.png"
    else
        echo "FAIL: ${id}"
    fi
    sleep 2
}

# Bonds & Personality
generate "bond_robin_peter" "Robin Hood's bow crossed with Peter Pan's dagger, outlaw alliance"
generate "bond_alice_witch" "Alice's teacup next to Witch's crystal ball, strange alliance"
generate "bond_phantom_merlin" "a musical note intertwined with a magic rune, music meets magic"
generate "bond_scrooge_frank" "a golden coin resting on Frankenstein's bolt, unlikely friendship"
generate "bond_sherlock_tarzan" "a magnifying glass wrapped in jungle vines, brains and brawn"
generate "bond_dracula_merlin" "a blood chalice next to a crystal staff, immortal minds"
generate "all_bonds" "six interlocking golden rings forming a complete chain, all bonds forged"
generate "taunt_10" "a megaphone blasting at enemies with sound waves, trash talk"
generate "taunt_50" "a war horn blasting a massive shockwave at an army, battle cry"
generate "panic_survive" "a heart monitor flatline that spikes back to life, panic survived"
generate "idle_observer" "an eye watching through a keyhole at tower animations, observer"
generate "banter_listener" "two speech bubbles intertwined with golden light, listening to banter"

# Sidekicks & Special
generate "first_sidekick" "a small companion creature emerging from a golden egg, first sidekick"
generate "sidekick_collector" "six small companion creatures in a group photo, sidekick collection"
generate "sidekick_master" "twelve companion creatures arranged in battle formation, sidekick master"
generate "all_sidekicks" "a massive army of 36 tiny companion creatures, full entourage"
generate "battle_power_first" "a fist slamming a glowing red power button, first battle power"
generate "battle_power_10" "ten lightning bolts striking in sequence, 10 battle powers used"
generate "battle_power_50" "a supernova explosion of combined battle powers, 50 uses power addict"
generate "loot_crate_first" "a glowing treasure crate cracking open with light beaming out"
generate "loot_crate_25" "a room full of opened loot crates with treasures spilling out"
generate "collectible_first" "a golden collectible coin floating with a sparkle, first find"
generate "collectible_25" "a display case with 25 golden collectible artifacts, treasure seeker"
generate "collectible_all" "a grand museum hall with every collectible displayed, museum curator"

# Chapter-Specific & Hidden
generate "robin_arc_full" "a golden Sherwood Forest with 3 golden stars, Robin Hood perfect arc"
generate "alice_arc_full" "a golden rabbit hole portal with 3 stars, Alice perfect arc"
generate "oz_arc_full" "golden ruby slippers on a yellow brick road with 3 stars, Oz perfect"
generate "peter_arc_full" "a golden Neverland island with 3 stars, Peter Pan perfect arc"
generate "phantom_arc_full" "a golden opera stage with falling chandelier and 3 stars, Phantom perfect"
generate "scrooge_arc_full" "golden Christmas bells with 3 stars, Scrooge perfect arc"
generate "speed_run" "a stopwatch being shattered by speed, fast completion under 3 minutes"
generate "multi_kill_10" "ten skulls exploding simultaneously in a burst of red, multi kill"
generate "multi_kill_25" "a massive explosion consuming 25 enemies at once, obliteration"
generate "all_easy" "a green ribbon badge with easy mode symbol, all levels easy"
generate "all_medium" "a silver medal with medium difficulty symbol, all levels medium"
generate "all_hard" "a blood-red diamond trophy with hard mode skull, shadow champion"

echo "=== Batch 7 complete ==="
echo "ALL BATCHES DEFINED"
