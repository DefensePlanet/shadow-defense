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
    sleep 5
}

# Failed character mastery icons
generate "witch_master" "Wicked Witch's broomstick wreathed in green lightning, master witch"
generate "peter_master" "Peter Pan's shadow blade glowing with golden fairy dust, master swordsman"
generate "phantom_master" "Phantom's golden mask with red rose and musical notes, opera master"
generate "scrooge_master" "Scrooge's overflowing golden coins from a treasure chest, master miser"
generate "dracula_master" "Dracula's blood chalice overflowing with crimson energy, vampire master"
generate "merlin_master" "Merlin's crystal staff glowing with ancient blue arcane power, wizard"
generate "frank_master" "Frankenstein's lightning rod crackling with green electrical energy"
generate "shadow_master" "Shadow Author's dark quill dripping with void ink, writing reality"
generate "sherlock_master" "Sherlock's magnifying glass with blue deduction light, detective master"
generate "tarzan_master" "Tarzan's golden vine whip with jungle leaves and primal energy"
generate "alice_arc_full" "golden rabbit hole portal with 3 golden stars, Alice perfect"

# Failed economy icons
generate "star_gazer" "an astronomer looking through telescope at 25 glowing storybook stars"
generate "star_collector" "a constellation map with 100 connected glowing stars"
generate "trophy_winner" "a trophy case with 50 golden trophies on display"
generate "trophy_champion" "a champion hall of fame with 200 trophies on walls"
generate "first_gear" "a single glowing gear piece being equipped onto armor slot"
generate "gear_collector" "a gear rack with 10 weapons and armor pieces displayed"
generate "gear_hoarder" "an overflowing armory with 25 legendary gear pieces"
generate "full_set" "a complete matching armor set glowing with set bonus energy"
generate "salvage_beginner" "a hammer breaking down old gear into glowing salvage shards"
generate "salvage_expert" "master blacksmith anvil surrounded by 25 salvaged components"
generate "forge_apprentice" "a blacksmith forging a golden chest from raw materials"
generate "forge_master" "a master forge with 20 golden chests cooling on racks"
generate "knowledge_sage" "a wise sage surrounded by 25 floating knowledge rune stones"
generate "instrument_owner" "a single magical instrument glowing on a pedestal"
generate "orchestra" "five magical instruments playing themselves in mystical orchestra"

# Failed bond icons
generate "bond_phantom_merlin" "a musical note intertwined with a magic rune, music meets magic"
generate "bond_scrooge_frank" "a golden coin resting on lightning bolt, unlikely friendship"
generate "bond_sherlock_tarzan" "a magnifying glass wrapped in jungle vines, brains and brawn"
generate "bond_dracula_merlin" "a blood chalice next to a crystal staff, immortal minds"
generate "all_bonds" "six interlocking golden rings forming a complete chain"

# Failed sidekick/special icons
generate "taunt_10" "a megaphone blasting at enemies with sound waves, trash talk"
generate "taunt_50" "a war horn blasting a massive shockwave, battle cry"
generate "panic_survive" "a heart monitor flatline that spikes back to life"
generate "idle_observer" "an eye watching through keyhole at tower animations"
generate "banter_listener" "two speech bubbles intertwined with golden light"
generate "first_sidekick" "a small companion creature emerging from golden egg"
generate "sidekick_collector" "six small companion creatures in group photo"
generate "sidekick_master" "twelve companion creatures in battle formation"
generate "all_sidekicks" "massive army of 36 tiny companion creatures"
generate "battle_power_first" "a fist slamming a glowing red power button"
generate "battle_power_10" "ten lightning bolts striking in sequence"
generate "battle_power_50" "supernova explosion of combined battle powers"
generate "loot_crate_first" "a glowing treasure crate cracking open with light"
generate "loot_crate_25" "room full of opened loot crates with treasures"
generate "collectible_first" "golden collectible coin floating with sparkle"
generate "collectible_25" "display case with 25 golden collectible artifacts"
generate "collectible_all" "grand museum hall with every collectible displayed"

# Failed chapter-specific icons
generate "robin_arc_full" "golden Sherwood Forest with 3 golden stars"
generate "oz_arc_full" "golden ruby slippers on yellow brick road with 3 stars"
generate "peter_arc_full" "golden Neverland island with 3 stars"
generate "phantom_arc_full" "golden opera stage with chandelier and 3 stars"
generate "scrooge_arc_full" "golden Christmas bells with 3 stars"
generate "speed_run" "stopwatch being shattered by speed, fast completion"
generate "multi_kill_10" "ten skulls exploding simultaneously, multi kill"
generate "multi_kill_25" "massive explosion consuming 25 enemies, obliteration"
generate "all_easy" "green ribbon badge, all levels completed easy"
generate "all_medium" "silver medal, all levels completed medium difficulty"
generate "all_hard" "blood-red diamond trophy with skull, shadow champion"

echo "=== RETRY COMPLETE ==="
echo "Checking remaining..."
cd "C:/Users/johnh/shadow-defense"
MISSING=0
while read id; do
    if [ ! -f "assets/achievement_icons/${id}.png" ]; then
        MISSING=$((MISSING + 1))
    fi
done < /tmp/retry_icons.txt
echo "Still missing: $MISSING icons"

# Auto-commit
git add assets/achievement_icons/*.png
git commit -m "art: retry batch — additional achievement icons

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
