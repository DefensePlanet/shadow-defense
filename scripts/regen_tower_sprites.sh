#!/bin/bash
# Regenerate all 12 tower sprites using character portraits as reference
# Each sprite should match the portrait art style — detailed cartoon illustration, NOT chibi/pixel art

export GEMINI_API_KEY="AIzaSyBr_MLM8yTB7bntayesxQ0LTZi7CuiibA0"

PORTRAITS_DIR="C:/Users/johnh/shadow-defense/assets/portraits"
OUTPUT_DIR="C:/Users/johnh/shadow-defense/assets/tower_sprites"
STYLE="detailed cartoon game character illustration, full body standing pose facing slightly right, holding their signature weapon ready for battle, semi-realistic proportions (NOT chibi, NOT pixel art), rich saturated colors, clean digital painting style matching mobile RPG character art, transparent PNG background, single character, no text, no watermark, high quality game asset, 512x512"

declare -A CHARACTERS
CHARACTERS[alice]="Alice from Alice in Wonderland, young girl in blue dress with white apron, blonde hair with black headband, holding a vorpal blade sword, curious determined expression, Wonderland fantasy theme"
CHARACTERS[dracula]="Count Dracula, pale aristocratic vampire lord in elegant black and red cape with high collar, slicked dark hair, intense red eyes, fangs, holding dark magic, gothic horror noble, menacing charisma"
CHARACTERS[frankenstein]="Frankenstein's Monster as a heroic character, large green-skinned figure with flat-top head, neck bolts, stitches, wearing torn dark coat, electrical energy crackling around fists, sympathetic but powerful"
CHARACTERS[merlin]="Merlin the wizard, elderly wise mage with long white beard, flowing blue robes with star patterns, pointed wizard hat, holding a glowing magical staff with crystal orb, mystical powerful aura"
CHARACTERS[peter_pan]="Peter Pan, youthful boy in green tunic and pointed green hat with red feather, brown tights, pointed ears, wielding a small sword, flying pose with pixie dust, confident smirk, adventurous"
CHARACTERS[phantom]="The Phantom of the Opera, mysterious figure in elegant black tuxedo and flowing black cape, iconic white half-mask covering right side of face, red rose, dark romantic, theatrical, music of the night"
CHARACTERS[robin_hood]="Robin Hood, dashing outlaw archer in green hooded tunic with brown leather belt and quiver of arrows on back, brown hair, holding a longbow ready to fire, confident smirk, forest hero"
CHARACTERS[scrooge]="Ebenezer Scrooge reformed, elderly Victorian gentleman in dark coat with top hat, pocket watch chain, holding a glowing lantern with ghostly energy, wise stern expression, Christmas Carol theme"
CHARACTERS[shadow_author]="The Shadow Author, mysterious dark cloaked figure with a glowing quill pen, ink-dark robes with pages and text floating around them, glowing green eyes under hood, original dark fantasy character, creator of shadow creatures"
CHARACTERS[sherlock]="Sherlock Holmes, tall lean detective in iconic deerstalker hat and Inverness cape coat, holding a magnifying glass, pipe, sharp intelligent eyes, Victorian London detective, analytical gaze"
CHARACTERS[tarzan]="Tarzan, muscular wild man of the jungle with tanned skin, long brown hair, wearing only a leopard-skin loincloth, holding a hunting knife, vines nearby, fierce primal warrior, noble savage"
CHARACTERS[wicked_witch]="The Wicked Witch of the West, green-skinned witch in black pointed hat and flowing black robes, holding a broomstick, crystal ball nearby, cackling expression, dark magic swirling, menacing"

success=0
total=0
failed=""

for char in alice dracula frankenstein merlin peter_pan phantom robin_hood scrooge shadow_author sherlock tarzan wicked_witch; do
    total=$((total + 1))
    portrait="$PORTRAITS_DIR/${char}.png"
    output="$OUTPUT_DIR/${char}_idle.png"
    desc="${CHARACTERS[$char]}"

    echo ""
    echo "============================================================"
    echo "[$total/12] Generating: ${char}_idle.png"
    echo "Using portrait reference: $portrait"
    echo "============================================================"

    # Use portrait as reference image for style consistency
    if [ -f "$portrait" ]; then
        nano-banana "${desc}. ${STYLE}" \
            --file "$portrait" \
            --output "$output" 2>&1
    else
        nano-banana "${desc}. ${STYLE}" \
            --output "$output" 2>&1
    fi

    if [ $? -eq 0 ] && [ -f "$output" ]; then
        echo "  ✅ SUCCESS: $output"
        success=$((success + 1))
    else
        echo "  ❌ FAILED: $char"
        failed="$failed $char"
    fi

    # Rate limit
    sleep 3
done

echo ""
echo "============================================================"
echo "TOWER SPRITES: $success/$total generated"
if [ -n "$failed" ]; then
    echo "FAILED:$failed"
fi
echo "============================================================"
