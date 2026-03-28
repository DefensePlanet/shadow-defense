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

# Tower - Building
generate "architect" "a grand blueprint with golden compass and protractor, 500 towers placed"
generate "grand_architect" "a magnificent cathedral built from tower designs, 1000 towers, master builder"
generate "full_army" "twelve different tower silhouettes standing in formation, complete army"

# Tower - Synergies
generate "synergy_chain" "three interlocking magical rings creating a chain reaction, triple synergy"
generate "synergy_overload" "five energy beams converging into a supernova explosion, synergy overload"

# Tower - Upgrades
generate "first_upgrade" "a hammer striking a tower with sparks and a level up arrow, first upgrade"
generate "upgrade_addict" "a tower covered in glowing upgrade runes and gems, 50 upgrades"
generate "upgrade_maniac" "a tower made entirely of stacked upgrade crystals, 200 upgrades obsession"
generate "ability_unlocked" "a sealed magic book opening with light bursting out, ability unlock"
generate "ability_collector" "six floating ability orbs arranged in a circle, purple and blue energy"
generate "ability_master" "twelve golden ability crowns arranged in a grand circle, all abilities mastered"

# Tower - Per-Character Mastery (12)
generate "robin_master" "Robin Hood's golden longbow with emerald arrows, master archer, green energy"
generate "alice_master" "Alice's enchanted looking glass with purple wonderland magic swirling"
generate "witch_master" "Wicked Witch's broomstick wreathed in green lightning, master witch"
generate "peter_master" "Peter Pan's shadow blade glowing with golden fairy dust, master swordsman"
generate "phantom_master" "Phantom's golden mask with red rose and musical notes, opera master"
generate "scrooge_master" "Scrooge's overflowing golden coins pouring from a treasure chest"
generate "sherlock_master" "Sherlock's magnifying glass revealing hidden clues with blue deduction light"
generate "tarzan_master" "Tarzan's golden vine whip with jungle leaves and primal energy"
generate "dracula_master" "Dracula's blood chalice overflowing with crimson energy, vampire master"
generate "merlin_master" "Merlin's crystal staff glowing with ancient blue arcane power"
generate "frank_master" "Frankenstein's lightning rod crackling with green electrical energy"
generate "shadow_master" "Shadow Author's dark quill dripping with void ink, writing reality"

echo "=== Batch 3 complete ==="
