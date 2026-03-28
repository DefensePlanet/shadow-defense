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
    # nano-banana saves to output/ dir, move it
    if [ -f "${id}.png" ]; then
        echo "OK: ${id}.png"
    else
        echo "FAIL: ${id}"
    fi
    sleep 2
}

# Combat - Kill Milestones
generate "bug_squasher" "a boot stomping on small creatures, green splatter, 10 kill count"
generate "exterminator" "a hooded figure surrounded by fallen enemies, red glow, 500 kills"
generate "warmonger" "a war hammer dripping with blood on a battlefield, orange fire"
generate "massacre" "a field of destruction with a dark warrior standing victorious, crimson energy"
generate "ten_thousand_strong" "an army of ten thousand skulls beneath a glowing champion, purple energy"
generate "army_breaker" "a massive war axe shattering a shield wall, golden lightning"
generate "genocide_protocol" "a dark vortex consuming an army, deep red and black swirl"
generate "the_reaper" "a hooded death figure with a glowing scythe, green soul energy"
generate "death_incarnate" "a skeletal king on a throne of bones, crimson crown, ultimate death"

# Combat - Boss Kills
generate "boss_slayer" "a fallen giant monster with a sword through its heart, first boss kill"
generate "boss_hunter" "a wall of mounted monster heads as trophies, hunter's collection"
generate "boss_executioner" "an executioner's axe on a chopping block with monster blood, 50 bosses"
generate "tyrant_slayer" "a crown of a fallen tyrant pierced by arrows, 100 bosses defeated"

# Combat - Damage
generate "damage_dealer" "a fist punching through stone with cracks radiating, 1000 damage"
generate "heavy_hitter" "a massive hammer striking an anvil with sparks flying, 10000 damage"
generate "wrecking_ball" "a giant iron wrecking ball smashing through a castle wall, 50000 damage"
generate "siege_engine" "a massive trebuchet launching a flaming boulder, siege warfare, 100000 damage"
generate "cataclysm" "a volcanic eruption destroying a landscape, apocalyptic destruction, 500000 damage"
generate "armageddon" "a meteor shower destroying a world, ultimate destruction, 1000000 damage"
generate "world_ender" "a planet cracking apart with energy beams, cosmic destruction"
generate "critical_strike" "a single precise dagger strike with a red critical hit burst"
generate "devastating_blow" "a massive sword slash with a shockwave, 500 damage single hit"
generate "one_shot_wonder" "a sniper crosshair with a golden bullet piercing through, 1000 damage"

echo "=== Batch 1 complete ==="
