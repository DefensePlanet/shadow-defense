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

# Tower - Per-Character Legend (12)
generate "robin_max" "a legendary golden longbow wreathed in emerald fire, Robin Hood legend tier 20"
generate "alice_max" "a legendary wonderland crown with swirling purple dimensional portals"
generate "witch_max" "a legendary witch hat crackling with green apocalyptic storm energy"
generate "peter_max" "a legendary golden shadow blade with rainbow fairy dust aurora"
generate "phantom_max" "a legendary golden opera mask with crimson rose petals and haunting notes"
generate "scrooge_max" "a legendary golden vault door overflowing with infinite treasure"
generate "sherlock_max" "a legendary golden magnifying glass revealing the fabric of reality itself"
generate "tarzan_max" "a legendary golden jungle crown with primal beast spirits surrounding it"
generate "dracula_max" "a legendary blood moon with Dracula's crimson eyes, ultimate vampire power"
generate "merlin_max" "a legendary Excalibur sword embedded in a glowing arcane stone"
generate "frank_max" "a legendary lightning storm channeled through a colossal iron golem"
generate "shadow_max" "a legendary void quill rewriting the cosmos, ultimate dark author power"

# Tower - Selling & Strategy
generate "first_sale" "a tower crumbling into gold coins, first tower sold"
generate "tower_flipper" "a real estate sign with gold coins, buying and selling towers"
generate "real_estate_mogul" "a golden mansion built from recycled tower materials, 100 towers sold"
generate "tower_hoarder" "eight towers packed tightly together on a small island, tower hoarding"

# Tower - Per-Character Kill Counts (12)
generate "robin_1k" "a tally board with 1000 marks and Robin Hood's green arrow, kill count"
generate "alice_1k" "a wonderland tea party table with 1000 skull teacups, Alice kills"
generate "witch_1k" "a witch's cauldron bubbling with 1000 enemy souls, green smoke"
generate "peter_1k" "a Neverland scoreboard with 1000 carved notches in a tree"
generate "phantom_1k" "an opera stage with 1000 phantom notes written in blood"
generate "scrooge_1k" "a ledger book with 1000 entries in red ink, Scrooge counting kills"
generate "sherlock_1k" "a detective case board with 1000 solved cases, red string connections"
generate "tarzan_1k" "jungle vines with 1000 bone trophies hanging, Tarzan's hunt tally"
generate "dracula_1k" "a blood pool reflecting 1000 crimson moons, Dracula's feast count"
generate "merlin_1k" "a crystal ball showing 1000 magical prophecies fulfilled"
generate "frank_1k" "lightning bolts striking a counter showing 1000, Frankenstein's fury"
generate "shadow_1k" "a dark manuscript with 1000 crossed out character names, author's edits"

echo "=== Batch 4 complete ==="
