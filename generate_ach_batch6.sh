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

# Progression - Campaign
generate "getting_started" "a path with 5 glowing milestones leading forward, getting started"
generate "sherlock_arc" "Baker Street 221B door with a golden key, Sherlock arc complete"
generate "merlin_arc" "Camelot castle with a golden grail on top, Merlin arc champion"
generate "tarzan_arc" "a jungle canopy with a golden crown of vines, Tarzan arc king"
generate "dracula_arc" "a vampire castle with a wooden stake through its heart, Dracula arc"
generate "frank_arc" "a lightning bolt striking a tower, Frankenstein arc completed"
generate "shadow_arc" "a dark quill writing THE END in golden ink, Shadow Author arc finale"

# Progression - Character Levels
generate "first_levelup" "a glowing level-up arrow bursting with golden particles, first level"
generate "legendary_survivor" "a legendary hero silhouette with a level 15 badge, golden aura"
generate "max_survivor" "a maximum power hero with level 20 crown, ultimate evolution reached"
generate "all_max" "twelve golden hero silhouettes standing in a V formation, all maxed"

# Progression - Stars
generate "first_star" "a single golden star being born from dark clouds, first star earned"
generate "star_student" "a student's desk with 25 golden stars pinned to a board"
generate "star_warrior" "a warrior's shield embedded with 50 glowing stars, battle-earned"
generate "star_legend" "a legendary constellation of 75 interconnected golden stars"
generate "star_master" "a master astronomer commanding 100 stars orbiting around them"
generate "constellation" "a complete night sky constellation map with all 111 stars connected"

# Progression - Daily & Meta
generate "daily_streak_7" "seven golden calendar pages glowing in sequence, weekly streak"
generate "daily_streak_30" "thirty golden calendar pages forming a golden monthly crown"
generate "quest_complete_5" "a quest scroll with 5 checkmarks, quest starter"
generate "quest_complete_25" "a hunter's quest board with 25 completed bounties"
generate "quest_complete_100" "a legendary quest master's hall with 100 golden quest banners"
generate "odyssey_complete" "a ship reaching a golden shore after an odyssey voyage"
generate "odyssey_master" "a fleet of 10 ships that have completed epic odyssey voyages"

# Progression - Meta
generate "achievement_hunter" "a hunter stalking a golden trophy through dark fog, 25 achievements"
generate "achievement_addict" "an obsessive collector surrounded by 50 floating golden medals"
generate "achievement_legend" "a legendary figure sitting on a throne of 100 golden achievement plaques"
generate "completionist" "a golden crown with ALL written in diamonds, 100 percent completion"

# Progression - Arena
generate "arena_first" "a gladiator entering a dark colosseum arena for the first time"
generate "arena_veteran" "a scarred arena veteran with 25 victory notches on their weapon"
generate "arena_champion" "a champion holding a golden trophy in a packed arena, 100 victories"
generate "commander_tier_5" "a military commander's badge with 5 golden stars, tier 5"
generate "commander_tier_10" "a decorated commander's medal with 10 golden stars, tier 10"
generate "commander_max" "a supreme commander's golden eagle badge with diamond center, max tier"

echo "=== Batch 6 complete ==="
