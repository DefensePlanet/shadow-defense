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

# Economy - Gold
generate "gold_digger" "a miner with a golden pickaxe striking a vein of pure gold, 5000 gold"
generate "treasure_hunter" "a treasure map with X marks leading to a golden chest, 25000 gold"
generate "gold_baron" "a golden throne room filled with mountains of coins, 100000 gold baron"
generate "lavish_spender" "gold coins raining down from hands, luxurious spending, 25000 spent"
generate "gold_mountain" "a literal mountain made of stacked gold coins, 500 gold at once"
generate "scrooges_vault" "Scrooge's massive vault door with overflowing gold, 1000 gold at once"

# Economy - Emporium
generate "emporium_addict" "a shopping cart overflowing with magical items, 50 purchases"
generate "emporium_whale" "a golden whale swimming through a sea of premium items, 100 purchases"
generate "chest_hoarder" "a room filled floor to ceiling with treasure chests, 100 chests opened"
generate "lucky_spin" "a spinning fortune wheel with golden prizes flying off, lucky winner"
generate "wheel_addict" "a dizzy character spinning next to a worn-out wheel, 25 spins"
generate "merchant_friend" "a hooded merchant and a buyer shaking hands over a rare item"

# Economy - Currencies
generate "quill_collector" "a collection of 100 enchanted feather quills glowing purple"
generate "quill_hoarder" "a massive library of enchanted quills covering every surface, 500 quills"
generate "shard_collector" "a collection of 500 glowing crystal gear shards, blue energy"
generate "shard_hoarder" "a crystal cave made entirely of gear shards, 2000 shards hoarded"
generate "star_gazer" "an astronomer looking through a telescope at 25 glowing storybook stars"
generate "star_collector" "a constellation map with 100 connected glowing stars"
generate "trophy_winner" "a trophy case with 50 golden trophies on display, winner"
generate "trophy_champion" "a champion's hall of fame with 200 trophies covering every wall"

# Economy - Gear
generate "first_gear" "a single glowing gear piece being equipped onto an armor slot"
generate "gear_collector" "a gear rack with 10 different weapons and armor pieces displayed"
generate "gear_hoarder" "an overflowing armory with 25 legendary gear pieces, hoarder"
generate "full_set" "a complete matching armor set glowing with set bonus energy, perfect fit"
generate "salvage_beginner" "a hammer breaking down old gear into glowing salvage shards"
generate "salvage_expert" "a master blacksmith's anvil surrounded by 25 salvaged components"
generate "forge_apprentice" "a blacksmith forging a golden chest from raw materials, apprentice"
generate "forge_master" "a master forge with 20 golden chests cooling on racks, master craftsman"

# Economy - Knowledge & Instruments
generate "knowledge_sage" "a wise sage surrounded by 25 floating knowledge rune stones"
generate "instrument_owner" "a single magical instrument glowing on a pedestal, first purchase"
generate "orchestra" "five magical instruments playing themselves in a mystical orchestra"

echo "=== Batch 5 complete ==="
