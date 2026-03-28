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

# Combat - Kill Streaks
generate "combo_starter" "a chain of 5 golden links glowing with fire, combo streak beginning"
generate "streak_master" "a flaming sword cutting through 10 enemies in a line, kill streak"
generate "unstoppable" "a berserker warrior with glowing red eyes surrounded by fallen enemies, 25 streak"
generate "rampage" "a tornado of blades shredding through a horde, unstoppable rampage, 50 streak"
generate "god_of_war" "a godlike warrior floating above a destroyed army, golden aura, 100 streak"
generate "endless_fury" "an infinite spiral of destruction with a warrior at the center, 200 streak"

# Combat - Challenges
generate "iron_wall" "an impenetrable iron fortress wall with arrows bouncing off, zero lives lost"
generate "wave_veteran" "a grizzled veteran warrior with battle scars holding a broken sword, 200 waves"
generate "wave_legend" "a legendary champion with a golden cape standing on a mountain of conquered waves"
generate "wave_god" "a god of war sitting on a throne made of wave banners, 1000 waves completed"
generate "hard_mode_warrior" "a warrior fighting through thorns and fire, hard difficulty skull badge"
generate "hard_mode_master" "a master warrior with a blood-red crown of thorns, 10 hard completions"
generate "pure_mode_survivor" "a single life heart protected by a crystal shield, pure mode, 1 life"
generate "pure_mode_legend" "a diamond heart with wings, surviving on a single life, legendary achievement"
generate "no_sell_challenge" "tower foundations permanently cemented into ground, no selling, commitment"

# Combat - Survival
generate "last_stand" "a lone warrior on one knee with a single health point remaining, last stand"
generate "close_call" "a barely intact shield cracking with one life remaining, close call victory"
generate "comeback_king" "a phoenix rising from near-death flames, comeback from the brink"
generate "endurance_runner" "a marathon runner silhouette against an endless desert horizon, 30 waves endless"
generate "marathon_runner" "an ultra marathon champion with a golden wreath, 50 waves endless"
generate "eternal_defender" "an eternal guardian made of living stone standing watch forever, 100 waves endless"

echo "=== Batch 2 complete ==="
