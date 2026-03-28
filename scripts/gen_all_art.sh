#!/bin/bash
# Generate all enemy art assets using nano-banana
# Usage: bash scripts/gen_all_art.sh [portraits|sprites|deathfx|all]
export GEMINI_API_KEY="AIzaSyCdJsbVdEhsFc3bkKI7Xryju9zdydt353w"
BASE="C:/Users/johnh/shadow-defense/assets"
MODE="${1:-all}"
OK=0
FAIL=0
SKIP=0

gen() {
    local prompt="$1"
    local output="$2"
    if [ -f "$output" ]; then
        echo "  SKIP: $output (exists)"
        SKIP=$((SKIP+1))
        return 0
    fi
    echo -n "  GEN: $(basename $(dirname $output))/$(basename $output)..."
    local result
    result=$(nano-banana "$prompt" --output "$output" 2>&1)
    if echo "$result" | grep -q "Image saved"; then
        local size=$(wc -c < "$output" 2>/dev/null || echo "0")
        echo " OK (${size} bytes)"
        OK=$((OK+1))
    else
        echo " FAIL"
        echo "    $result" | head -3
        FAIL=$((FAIL+1))
    fi
    sleep 1
}

#--- PORTRAITS (52) ---
generate_portraits() {
echo "=== PORTRAITS ==="
# Boss villains (tier 3)
gen "Dark fantasy book illustration portrait of the Sheriff of Nottingham, richly dressed in dark furs and chain of office, cruel calculating eyes, from Robin Hood, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/sherwood/tier_3.png"
gen "Dark fantasy book illustration portrait of the Queen of Hearts in her red and black royal gown, crown, scepter, furious expression, from Alice in Wonderland, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/wonderland/tier_3.png"
gen "Dark fantasy book illustration portrait of a Dark Witch with pointed hat, green skin, flowing black robes, crackling magic in hands, from The Wizard of Oz, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/oz/tier_3.png"
gen "Dark fantasy book illustration portrait of Captain Hook with his iconic iron hook hand, red coat, feathered hat, mustache, menacing grin, from Peter Pan, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/neverland/tier_3.png"
gen "Dark fantasy book illustration portrait of the Dark Phantom in full regalia, skull-like mask, flowing cape, organ pipes echoing behind, terrifying presence, from Phantom of the Opera, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/opera/tier_3.png"
gen "Dark fantasy book illustration portrait of the Ghost of Christmas Yet to Come, a towering hooded specter in black robes, skeletal hand pointing, from A Christmas Carol, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/victorian/tier_3.png"
gen "Dark fantasy book illustration portrait of the Shadow Lord, a towering entity of pure darkness with a crown of shadow tendrils and burning violet eyes, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/shadow_entities/tier_3.png"
gen "Dark fantasy book illustration portrait of Professor Moriarty, the Napoleon of Crime, high forehead, cold mathematical eyes, dark suit, spider-like presence, from Sherlock Holmes, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/sherlock/tier_3.png"
gen "Dark fantasy book illustration portrait of Morgan le Fay, dark sorceress queen in regal black and purple robes, crown of thorns, magical energy swirling, from Arthurian Legend, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/merlin/tier_3.png"
gen "Dark fantasy book illustration portrait of Clayton the villain hunter, tall and muscular in torn safari outfit, rifle and machete, cruel aristocratic bearing, from Tarzan, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/tarzan/tier_3.png"
gen "Dark fantasy book illustration portrait of Count Dracula himself, tall pale nobleman in high-collared black cape, widows peak, piercing red eyes, commanding presence, from Dracula by Bram Stoker, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/dracula/tier_3.png"
gen "Dark fantasy book illustration portrait of Igor the hunchbacked assistant alongside Frankensteins Creature, massive stitched body with bolts, tragic and powerful, from Frankenstein, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/frankenstein/tier_3.png"
gen "Dark fantasy book illustration portrait of The Shadow Author, a godlike figure made of swirling manuscripts and dark ink, quill pen staff, rewriting reality itself, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, menacing pose, fearsome boss villain, bust portrait" "$BASE/enemy_portraits/shadow_author/tier_3.png"

# Tier 2 (Elites)
gen "Dark fantasy book illustration portrait of a Sheriff Knight, heavily armored dark knight with a plume helm and longsword, imposing, from Robin Hood, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/sherwood/tier_2.png"
gen "Dark fantasy book illustration portrait of the terrifying Jabberwock dragon with scales and burning eyes from Through the Looking Glass, from Alice in Wonderland, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/wonderland/tier_2.png"
gen "Dark fantasy book illustration portrait of a rock-armored Nome Soldier from underground, crystalline features, from The Wizard of Oz, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/oz/tier_2.png"
gen "Dark fantasy book illustration portrait of a heavy Pirate Gunner with a cannon fuse and bandolier of grenades, from Peter Pan, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/neverland/tier_2.png"
gen "Dark fantasy book illustration portrait of a stone Gargoyle come to life from the Opera rooftop, crouching and snarling, from Phantom of the Opera, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/opera/tier_2.png"
gen "Dark fantasy book illustration portrait of a translucent spectral Ghost wrapped in chains and lockboxes, from A Christmas Carol, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/victorian/tier_2.png"
gen "Dark fantasy book illustration portrait of a massive Ink Beast, amorphous and monstrous with tentacles of liquid darkness, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/shadow_entities/tier_2.png"
gen "Dark fantasy book illustration portrait of an elite Moriarty Agent in gentlemans disguise with hidden weapons, calculating, from Sherlock Holmes, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/sherlock/tier_2.png"
gen "Dark fantasy book illustration portrait of a powerful Warlock in dark robes with a gnarled staff, arcane sigils floating around, from Arthurian Legend, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/merlin/tier_2.png"
gen "Dark fantasy book illustration portrait of a hardened Mercenary in jungle camo with automatic weapons and tactical gear, from Tarzan, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/tarzan/tier_2.png"
gen "Dark fantasy book illustration portrait of a hauntingly beautiful Vampire Bride in flowing white gown, fangs bared, blood-red eyes, from Dracula, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/dracula/tier_2.png"
gen "Dark fantasy book illustration portrait of a terrifying Failed Experiment, a hulking body with mismatched limbs, sparking electrodes, screaming, from Frankenstein, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/frankenstein/tier_2.png"
gen "Dark fantasy book illustration portrait of a massive Shadow Beast made of torn pages and liquid darkness, multiple ink tendrils, tower defense game art, painterly style, dramatic lighting, dark atmospheric background, powerful elite enemy, bust portrait" "$BASE/enemy_portraits/shadow_author/tier_2.png"

# Tier 1 (Soldiers)
gen "Dark fantasy book illustration portrait of a Sheriff Soldier, armored soldier in the Sheriffs colors with a pike and chain mail, from Robin Hood, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/sherwood/tier_1.png"
gen "Dark fantasy book illustration portrait of a Face Card Guard with ornate royal suit markings, larger and more decorated, from Alice in Wonderland, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/wonderland/tier_1.png"
gen "Dark fantasy book illustration portrait of a sinister Flying Monkey with bat wings, red cap and vest, sharp teeth, from The Wizard of Oz, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/oz/tier_1.png"
gen "Dark fantasy book illustration portrait of a Pirate Officer in a faded naval coat with pistol and rapier, from Peter Pan, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/neverland/tier_1.png"
gen "Dark fantasy book illustration portrait of a masked Opera Phantom figure in black cape and white half-mask, lurking, from Phantom of the Opera, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/opera/tier_1.png"
gen "Dark fantasy book illustration portrait of a stern Victorian Debt Collector in top hat and dark coat, ledger in hand, from A Christmas Carol, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/victorian/tier_1.png"
gen "Dark fantasy book illustration portrait of a humanoid Shadow Soldier made of dark ink with glowing purple eyes, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/shadow_entities/tier_1.png"
gen "Dark fantasy book illustration portrait of a skilled Assassin in dark Victorian attire with concealed blades, from Sherlock Holmes, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/sherlock/tier_1.png"
gen "Dark fantasy book illustration portrait of a Cursed Knight in blackened plate armor with glowing runes, unholy aura, from Arthurian Legend, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/merlin/tier_1.png"
gen "Dark fantasy book illustration portrait of a Big Game Hunter in safari gear with a large-bore rifle and pith helmet, from Tarzan, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/tarzan/tier_1.png"
gen "Dark fantasy book illustration portrait of a massive Dire Wolf with red eyes and slavering jaws, dark fur, from Dracula, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/dracula/tier_1.png"
gen "Dark fantasy book illustration portrait of a small misshapen Homunculus with patchwork skin and jerky movements, from Frankenstein, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/frankenstein/tier_1.png"
gen "Dark fantasy book illustration portrait of a Corrupted storybook Character glitching between forms, half-dissolved in ink, tower defense game art, painterly style, dramatic lighting, trained soldier enemy, bust portrait" "$BASE/enemy_portraits/shadow_author/tier_1.png"

# Tier 0 (Grunts)
gen "Dark fantasy book illustration portrait of a scrawny medieval Tax Collector in drab robes clutching a coin purse, greedy eyes, from Robin Hood, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/sherwood/tier_0.png"
gen "Dark fantasy book illustration portrait of a playing Card Soldier with spade suit markings, flat body, small spear, from Alice in Wonderland, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/wonderland/tier_0.png"
gen "Dark fantasy book illustration portrait of a yellow-uniformed Winkie Guard with a spear, simple helmet, from The Wizard of Oz, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/oz/tier_0.png"
gen "Dark fantasy book illustration portrait of a scruffy young Pirate Deckhand with torn clothes and a rusty cutlass, from Peter Pan, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/neverland/tier_0.png"
gen "Dark fantasy book illustration portrait of a grimy Paris Opera Stagehand in work clothes among ropes and pulleys, from Phantom of the Opera, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/opera/tier_0.png"
gen "Dark fantasy book illustration portrait of a ragged Victorian Street Urchin in tattered clothes, thin and desperate, from A Christmas Carol, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/victorian/tier_0.png"
gen "Dark fantasy book illustration portrait of a small wispy Ink Wisp tendril of living ink and shadow, barely formed, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/shadow_entities/tier_0.png"
gen "Dark fantasy book illustration portrait of a Victorian London Street Thug with a cap, club, and menacing scowl, from Sherlock Holmes, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/sherlock/tier_0.png"
gen "Dark fantasy book illustration portrait of a young Dark Squire in corrupted armor with a tarnished shield, from Arthurian Legend, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/merlin/tier_0.png"
gen "Dark fantasy book illustration portrait of a scruffy African jungle Poacher with a rusty rifle and net, from Tarzan, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/tarzan/tier_0.png"
gen "Dark fantasy book illustration portrait of a pale mindless Thrall in peasant clothes, vacant eyes, bite marks on neck, from Dracula, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/dracula/tier_0.png"
gen "Dark fantasy book illustration portrait of a grotesque oversized Lab Rat with stitches and glowing eyes, escaped from the lab, from Frankenstein, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/frankenstein/tier_0.png"
gen "Dark fantasy book illustration portrait of a soldier formed from living ink, dripping black, carrying a quill-blade, Ink Soldier, tower defense game art, painterly style, dramatic lighting, weak grunt enemy, bust portrait" "$BASE/enemy_portraits/shadow_author/tier_0.png"
}

#--- SPRITES (52) ---
generate_sprites() {
echo "=== SPRITES ==="
# All 52 sprites — top-down game art, transparent bg
for faction in sherwood wonderland oz neverland opera victorian shadow_entities sherlock merlin tarzan dracula frankenstein shadow_author; do
for tier in 0 1 2 3; do

case "${faction}_${tier}" in
sherwood_0) NAME="Tax Collector"; DESC="scrawny medieval bureaucrat in drab robes"; NOVEL="Robin Hood";;
sherwood_1) NAME="Sheriff Soldier"; DESC="armored soldier with pike and chain mail"; NOVEL="Robin Hood";;
sherwood_2) NAME="Sheriff Knight"; DESC="heavily armored dark knight with plume helm"; NOVEL="Robin Hood";;
sherwood_3) NAME="Sheriff of Nottingham"; DESC="richly dressed in dark furs and chain of office"; NOVEL="Robin Hood";;
wonderland_0) NAME="Card Soldier"; DESC="playing card soldier with spade markings and spear"; NOVEL="Alice in Wonderland";;
wonderland_1) NAME="Face Card Guard"; DESC="ornate royal face card guard"; NOVEL="Alice in Wonderland";;
wonderland_2) NAME="Jabberwock"; DESC="terrifying dragon with scales and burning eyes"; NOVEL="Alice in Wonderland";;
wonderland_3) NAME="Queen of Hearts"; DESC="red and black royal gown, crown, furious"; NOVEL="Alice in Wonderland";;
oz_0) NAME="Winkie Guard"; DESC="yellow-uniformed guard with spear"; NOVEL="Wizard of Oz";;
oz_1) NAME="Flying Monkey"; DESC="sinister monkey with bat wings and red cap"; NOVEL="Wizard of Oz";;
oz_2) NAME="Nome Soldier"; DESC="rock-armored underground soldier, crystalline"; NOVEL="Wizard of Oz";;
oz_3) NAME="Dark Witch"; DESC="witch with pointed hat, green skin, black robes, magic"; NOVEL="Wizard of Oz";;
neverland_0) NAME="Pirate Deckhand"; DESC="scruffy pirate with torn clothes and rusty cutlass"; NOVEL="Peter Pan";;
neverland_1) NAME="Pirate Officer"; DESC="pirate officer in faded naval coat with pistol"; NOVEL="Peter Pan";;
neverland_2) NAME="Pirate Gunner"; DESC="heavy pirate with cannon fuse and grenades"; NOVEL="Peter Pan";;
neverland_3) NAME="Captain Hook"; DESC="iron hook hand, red coat, feathered hat"; NOVEL="Peter Pan";;
opera_0) NAME="Stagehand"; DESC="grimy opera stagehand in work clothes"; NOVEL="Phantom of the Opera";;
opera_1) NAME="Opera Phantom"; DESC="masked figure in black cape, white half-mask"; NOVEL="Phantom of the Opera";;
opera_2) NAME="Gargoyle"; DESC="stone gargoyle come to life, snarling"; NOVEL="Phantom of the Opera";;
opera_3) NAME="Dark Phantom"; DESC="skull-like mask, flowing cape, terrifying"; NOVEL="Phantom of the Opera";;
victorian_0) NAME="Street Urchin"; DESC="ragged Victorian child in tattered clothes"; NOVEL="A Christmas Carol";;
victorian_1) NAME="Debt Collector"; DESC="stern Victorian man in top hat and dark coat"; NOVEL="A Christmas Carol";;
victorian_2) NAME="Ghost"; DESC="translucent specter wrapped in chains"; NOVEL="A Christmas Carol";;
victorian_3) NAME="Ghost of Christmas"; DESC="towering hooded specter in black robes"; NOVEL="A Christmas Carol";;
shadow_entities_0) NAME="Ink Wisp"; DESC="small wispy tendril of living ink"; NOVEL="Shadow Defense";;
shadow_entities_1) NAME="Shadow Soldier"; DESC="humanoid shadow with glowing purple eyes"; NOVEL="Shadow Defense";;
shadow_entities_2) NAME="Ink Beast"; DESC="massive amorphous ink monster with tentacles"; NOVEL="Shadow Defense";;
shadow_entities_3) NAME="Shadow Lord"; DESC="towering entity of darkness, crown of shadow tendrils"; NOVEL="Shadow Defense";;
sherlock_0) NAME="Street Thug"; DESC="Victorian thug with cap and club"; NOVEL="Sherlock Holmes";;
sherlock_1) NAME="Assassin"; DESC="skilled assassin in dark Victorian attire"; NOVEL="Sherlock Holmes";;
sherlock_2) NAME="Moriarty Agent"; DESC="elite agent in gentleman disguise"; NOVEL="Sherlock Holmes";;
sherlock_3) NAME="Professor Moriarty"; DESC="Napoleon of Crime, cold mathematical eyes"; NOVEL="Sherlock Holmes";;
merlin_0) NAME="Dark Squire"; DESC="young squire in corrupted armor"; NOVEL="Arthurian Legend";;
merlin_1) NAME="Cursed Knight"; DESC="knight in blackened plate armor with glowing runes"; NOVEL="Arthurian Legend";;
merlin_2) NAME="Warlock"; DESC="warlock in dark robes with gnarled staff"; NOVEL="Arthurian Legend";;
merlin_3) NAME="Morgan le Fay"; DESC="dark sorceress in black and purple robes"; NOVEL="Arthurian Legend";;
tarzan_0) NAME="Poacher"; DESC="scruffy poacher with rusty rifle"; NOVEL="Tarzan";;
tarzan_1) NAME="Big Game Hunter"; DESC="hunter in safari gear with rifle and pith helmet"; NOVEL="Tarzan";;
tarzan_2) NAME="Mercenary"; DESC="hardened mercenary in jungle camo with weapons"; NOVEL="Tarzan";;
tarzan_3) NAME="Clayton"; DESC="tall muscular villain hunter in torn safari outfit"; NOVEL="Tarzan";;
dracula_0) NAME="Thrall"; DESC="pale mindless thrall with bite marks"; NOVEL="Dracula";;
dracula_1) NAME="Dire Wolf"; DESC="massive wolf with red eyes and dark fur"; NOVEL="Dracula";;
dracula_2) NAME="Vampire Bride"; DESC="beautiful vampire in flowing white gown, fangs"; NOVEL="Dracula";;
dracula_3) NAME="Count Dracula"; DESC="tall pale nobleman in high-collared black cape"; NOVEL="Dracula";;
frankenstein_0) NAME="Lab Rat"; DESC="grotesque oversized rat with stitches"; NOVEL="Frankenstein";;
frankenstein_1) NAME="Homunculus"; DESC="small misshapen creature with patchwork skin"; NOVEL="Frankenstein";;
frankenstein_2) NAME="Failed Experiment"; DESC="hulking body with mismatched limbs and electrodes"; NOVEL="Frankenstein";;
frankenstein_3) NAME="Igor and Creature"; DESC="hunchback assistant with massive stitched creature"; NOVEL="Frankenstein";;
shadow_author_0) NAME="Ink Soldier"; DESC="soldier formed from living ink with quill-blade"; NOVEL="Shadow Defense";;
shadow_author_1) NAME="Corrupted Character"; DESC="glitching storybook character half-dissolved in ink"; NOVEL="Shadow Defense";;
shadow_author_2) NAME="Shadow Beast"; DESC="massive beast of torn pages and liquid darkness"; NOVEL="Shadow Defense";;
shadow_author_3) NAME="Shadow Author"; DESC="godlike figure of swirling manuscripts and dark ink"; NOVEL="Shadow Defense";;
esac

PLEVEL="weak grunt"
[ "$tier" = "1" ] && PLEVEL="trained soldier"
[ "$tier" = "2" ] && PLEVEL="powerful elite"
[ "$tier" = "3" ] && PLEVEL="fearsome boss villain"

gen "Top-down game sprite of $NAME, $DESC, dark fantasy tower defense style, transparent background, 3/4 view facing right, $PLEVEL, pixel art influenced, clean silhouette, from $NOVEL, 128x128, isolated character" "$BASE/enemy_sprites/$faction/tier_${tier}.png"

done
done
}

#--- DEATH VFX (13) ---
generate_deathfx() {
echo "=== DEATH VFX ==="
gen "Arrow and green leaf burst explosion effect, medieval forest debris, green and brown tones, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/sherwood.png"
gen "Playing card explosion with hearts diamonds clubs spades flying outward, red and black, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/wonderland.png"
gen "Green smoke tornado explosion with emerald sparkles, green and gold tones, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/oz.png"
gen "Water splash with golden fairy dust burst, blue and gold tones, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/neverland.png"
gen "Chandelier crystal shatter explosion, glass shards and candle flame sparks, amber and crystal, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/opera.png"
gen "Ghostly wisp dissipation effect, pale blue-white ectoplasm dissolving, cold blue tones, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/victorian.png"
gen "Ink splash dissolve explosion, black liquid splattering outward, purple-black tones, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/shadow_entities.png"
gen "Fog and smoke bomb burst, grey-brown Victorian smog explosion, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/sherlock.png"
gen "Magical rune circle explosion with arcane symbols, blue-purple magical energy, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/merlin.png"
gen "Vine snap and tropical leaf burst, green brown natural debris explosion, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/tarzan.png"
gen "Bat swarm explosion with crimson dust cloud, black bats and red mist, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/dracula.png"
gen "Electric sparks and stitch unraveling explosion, yellow-blue electrical discharge, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/frankenstein.png"
gen "Torn book pages and ink splatter explosion, white pages and black ink flying outward, game VFX sprite, transparent background, particle burst, dramatic, 256x256, radial explosion frame" "$BASE/death_fx/shadow_author.png"
}

# Execute based on mode
case "$MODE" in
    portraits) generate_portraits;;
    sprites) generate_sprites;;
    deathfx) generate_deathfx;;
    all) generate_portraits; generate_sprites; generate_deathfx;;
esac

echo ""
echo "==============================="
echo "DONE: $OK OK, $FAIL FAIL, $SKIP SKIP"
echo "==============================="
