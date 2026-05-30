#!/usr/bin/env python3
"""
Generate all 265 gear item icons for Shadow Defense using nano-banana.
Processes in batches of 10. Converts JPEG-with-PNG-extension to real PNG.
"""

import subprocess
import os
import sys
import time

# Windows Python path
sys.path.insert(0, "C:/Users/johnh/AppData/Local/Programs/Python/Python312")
from PIL import Image

OUTPUT_DIR = "C:/Users/johnh/shadow-defense/assets/gear_icons/generated"
GEMINI_API_KEY = "AIzaSyB5jA9-K7A976fDnNS0yeWz8a1XTHmpsRM"
# Full path to nano-banana on Windows npm global
NANO_BANANA_CMD = "C:/Users/johnh/AppData/Roaming/npm/nano-banana.cmd"

# All 265 gear items: (id, name, prompt_description)
GEAR_ITEMS = [
    # === COMMON — Robin Hood ===
    ("rh_c1", "Sherwood Shortbow", "A short wooden bow with green leather grip and fletched arrows"),
    ("rh_c2", "Lincoln Green Cloak", "A forest green hooded cloak with leaf-shaped clasp"),
    ("rh_c3", "Outlaw's Quiver", "A leather quiver filled with arrows decorated with green feathers"),
    ("rh_c4", "Merry Men's Token", "A carved wooden medallion with a bow and arrow symbol"),

    # === COMMON — Alice ===
    ("al_c1", "Curious Teacup", "A white porcelain teacup with colorful flower patterns, steam rising"),
    ("al_c2", "Eat Me Cookie", "A golden cookie with 'EAT ME' iced in red letters, magical glow"),
    ("al_c3", "Rabbit's Pocket Watch", "An ornate brass pocket watch with rabbit ears engraving"),
    ("al_c4", "Card Soldier's Shield", "A small red shield with a painted heart card symbol"),

    # === COMMON — Wicked Witch ===
    ("ww_c1", "Emerald Shard", "A glowing emerald crystal shard with green magical energy"),
    ("ww_c2", "Poppy Pollen Vial", "A dark glass vial filled with glowing orange poppy pollen"),
    ("ww_c3", "Broomstick Splinter", "A jagged splinter of enchanted dark wood from a witch's broomstick"),
    ("ww_c4", "Monkey Wing Feather", "A dark purple wing feather from a flying monkey"),

    # === COMMON — Peter Pan ===
    ("pp_c1", "Fairy Dust Pinch", "A small pouch leaking golden fairy dust with sparkles"),
    ("pp_c2", "Lost Boy's Dagger", "A crude small dagger with a wrapped leather handle"),
    ("pp_c3", "Shadow Stitch Thread", "A spool of black magical thread that moves like a shadow"),
    ("pp_c4", "Neverland Acorn Cap", "A tiny acorn cap with a glowing heart etched inside"),

    # === COMMON — Phantom ===
    ("ph_c1", "Porcelain Mask Chip", "A white porcelain mask fragment with delicate cracks"),
    ("ph_c2", "Opera House Rose", "A single red rose with a long stem, theatrical"),
    ("ph_c3", "Gondola Oar Shard", "A dark wooden oar fragment with ornate carvings"),
    ("ph_c4", "Chandelier Crystal", "A teardrop crystal prism from a grand chandelier"),

    # === COMMON — Scrooge ===
    ("sc_c1", "Tarnished Penny", "An old corroded copper penny with Queen's profile"),
    ("sc_c2", "Counting House Ledger", "A small leather-bound ledger with money tallies inside"),
    ("sc_c3", "Ghost Chain Link", "A heavy iron chain link wrapped in spectral mist"),
    ("sc_c4", "Candle Stub", "A half-burned white candle with dripping wax"),

    # === COMMON — Sherlock ===
    ("sh_c1", "Worn Magnifying Lens", "A scratched brass magnifying glass with worn leather handle"),
    ("sh_c2", "Baker Street Pipe", "A curved meerschaum pipe with carved face on bowl"),
    ("sh_c3", "Deduction Notes", "A rolled parchment paper with detective case notes"),
    ("sh_c4", "Watson's Field Kit", "A small medical leather pouch with brass clasp"),

    # === COMMON — Tarzan ===
    ("tz_c1", "Jungle Vine Whip", "A coiled jungle vine with rough bark texture"),
    ("tz_c2", "Ape Fang Necklace", "A necklace of large white gorilla fangs on a leather cord"),
    ("tz_c3", "Primal Drum Skin", "A small hand drum made from stretched animal skin"),
    ("tz_c4", "Leopard Claw", "A single large leopard claw, sharp and curved"),

    # === COMMON — Dracula ===
    ("dr_c1", "Blood Drop Pendant", "A dark ruby pendant shaped like a blood drop on a silver chain"),
    ("dr_c2", "Bat Wing Cloak", "A miniature black bat wing brooch for a cloak"),
    ("dr_c3", "Coffin Nail", "A long iron nail stained with dark dried blood"),
    ("dr_c4", "Moonlit Fang", "A vampiric fang carved from pale moonstone"),

    # === COMMON — Merlin ===
    ("mr_c1", "Cracked Crystal Orb", "A cracked magical crystal ball with faint inner glow"),
    ("mr_c2", "Apprentice Rune Stone", "A flat stone carved with a simple glowing rune"),
    ("mr_c3", "Round Table Splinter", "A polished oak splinter from the legendary Round Table"),
    ("mr_c4", "Prophecy Scroll Scrap", "A torn scroll fragment with ancient prophecy text"),

    # === COMMON — Frankenstein ===
    ("fr_c1", "Copper Bolt", "A large copper bolt with green patina and electrical burns"),
    ("fr_c2", "Lab Flask Shard", "A broken laboratory flask fragment with colored residue"),
    ("fr_c3", "Galvanic Wire", "A coil of copper electrical wire with sparks"),
    ("fr_c4", "Stitched Leather Strap", "A leather strap with crude stitching from a monster's restraints"),

    # === COMMON — Shadow Author ===
    ("sa_c1", "Ink-Stained Quill Tip", "A raven feather quill tip dripping black ink"),
    ("sa_c2", "Torn Page Fragment", "A torn book page with fading mysterious text"),
    ("sa_c3", "Blotted Margin Note", "A paper scrap covered in ink blots and scrawled notes"),
    ("sa_c4", "Cheap Inkwell", "A small glass inkwell half-full of dark ink"),

    # === COMMON — Universal (52) ===
    ("uc_01", "Iron Arrowhead", "A sharp triangular iron arrowhead with blood groove"),
    ("uc_02", "Dented Buckler", "A small round metal shield with dents and scratches"),
    ("uc_03", "Worn Leather Boots", "A pair of old weathered brown leather boots"),
    ("uc_04", "Cracked Scope Lens", "A brass telescope lens with a cracked glass"),
    ("uc_05", "Oiled Bowstring", "A taut bowstring coated in oil on a small spool"),
    ("uc_06", "Lucky Coin", "A golden coin with a four-leaf clover and radiant glow"),
    ("uc_07", "Barbed Tip", "A wicked barbed metal projectile tip with hooked spines"),
    ("uc_08", "Frost Pebble", "A small glowing blue-white pebble covered in frost crystals"),
    ("uc_09", "Ember Coal", "A glowing orange ember coal radiating heat"),
    ("uc_10", "Sharpened Needle", "A long steel needle honed to a razor point"),
    ("uc_11", "Copper Ring", "A simple copper ring with engraved geometric patterns"),
    ("uc_12", "Tar Pouch", "A small leather pouch dripping black tar"),
    ("uc_13", "Wooden Shield Fragment", "A splintered wooden shield fragment with painted design"),
    ("uc_14", "Rough Whetstone", "A rectangular sharpening stone with grooves from use"),
    ("uc_15", "Scouts Spyglass", "A brass collapsible telescope for reconnaissance"),
    ("uc_16", "Flint Striker", "A flint rock and steel striker for making fire"),
    ("uc_17", "Feathered Charm", "A small charm made of colorful bird feathers on a cord"),
    ("uc_18", "Silver Thimble", "A silver thimble with small decorative holes"),
    ("uc_19", "Venom Sac", "A translucent sac filled with green venom"),
    ("uc_20", "Bronze Clasp", "A decorative bronze belt buckle clasp"),
    ("uc_21", "Traveler's Compass", "A worn brass compass with a spinning needle"),
    ("uc_22", "Weighted Gloves", "A pair of leather gloves with metal studs in the knuckles"),
    ("uc_23", "Tinker's Gear", "A small brass clockwork gear"),
    ("uc_24", "Smoke Pellet", "A small dark sphere that leaks wisps of grey smoke"),
    ("uc_25", "Alchemist's Salt", "A glass vial of sparkling alchemical salt"),
    ("uc_26", "Merchant's Abacus", "A small wooden abacus with colorful counting beads"),
    ("uc_27", "Sturdy Chain Link", "A heavy iron chain link with no rust"),
    ("uc_28", "Splinter Shot", "A bundle of wooden splinter projectiles tied together"),
    ("uc_29", "Crow Feather", "A jet black crow feather with iridescent sheen"),
    ("uc_30", "Rusty Nail", "A long bent iron nail covered in orange rust"),
    ("uc_31", "Polished Pebble", "A smooth river pebble polished to a perfect shine"),
    ("uc_32", "Thorn Bracelet", "A bracelet woven from thorny rose stems"),
    ("uc_33", "Old Compass Needle", "A magnetized compass needle floating on its own"),
    ("uc_34", "Chipped Gemstone", "A semi-precious gemstone with a chip in one corner"),
    ("uc_35", "Ironwood Bark", "A piece of dense iron-hard dark wood bark"),
    ("uc_36", "Resin Globe", "A small amber resin sphere with trapped ancient bubbles"),
    ("uc_37", "Sparrow Talon", "A small bird talon on a leather string"),
    ("uc_38", "Chalk Dust Pouch", "A cloth pouch leaving trails of white chalk dust"),
    ("uc_39", "Bee Sting Barb", "A magnified bee stinger with venom sac attached"),
    ("uc_40", "Tin Soldier's Sword", "A small tin toy sword sharp as a real blade"),
    ("uc_41", "Glass Bead", "A transparent glass bead with a spiral inside"),
    ("uc_42", "Hemp Rope Coil", "A coil of rough hemp rope"),
    ("uc_43", "Pine Pitch Ball", "A sticky black ball of pine pitch resin"),
    ("uc_44", "Parchment Scrap", "A rolled piece of old parchment with faded text"),
    ("uc_45", "Bone Dice", "A pair of carved bone dice with dark spots"),
    ("uc_46", "Wax Seal Stamp", "A brass seal stamp with a coat of arms"),
    ("uc_47", "Horseshoe Nail", "A heavy iron horseshoe nail"),
    ("uc_48", "Dried Herb Bundle", "A bundle of dried medicinal herbs tied with twine"),
    ("uc_49", "Cobalt Dust", "A small vial of glowing cobalt blue dust"),
    ("uc_50", "Leather Finger Guard", "A leather archer's finger guard tab"),
    ("uc_51", "Tallow Candle", "A thick tallow candle with a long wick"),
    ("uc_52", "Forged Washer", "A thick steel washer forged with hammer marks"),

    # === RARE — Robin Hood ===
    ("rh_r1", "Sherwood Longbow", "An elegant longbow of yew wood with silver string and carved leaf motifs"),
    ("rh_r2", "Hood's Silver Arrow", "A gleaming silver arrow with perfect fletching and rune-carved shaft"),
    ("rh_r3", "Marian's Favor", "A lady's silk handkerchief embroidered with a rose, tied in a knot"),

    # === RARE — Alice ===
    ("al_r1", "Cheshire Cat Grin", "A floating disembodied grinning cat mouth with glowing teeth"),
    ("al_r2", "Drink Me Potion", "A small ornate bottle with 'DRINK ME' tag, glowing blue liquid inside"),
    ("al_r3", "Looking Glass Shard", "A mirror shard that shows a reversed twisted reflection"),

    # === RARE — Wicked Witch ===
    ("ww_r1", "Crystal Ball of Oz", "A glowing green crystal ball swirling with storm clouds inside"),
    ("ww_r2", "Ruby Slipper Heel", "A single red ruby-studded high heel shoe ornament"),
    ("ww_r3", "Enchanted Broomstick", "A wickedly curved broomstick with bound twigs and glowing handle"),

    # === RARE — Peter Pan ===
    ("pp_r1", "Tinker Bell's Lantern", "A tiny brass lantern glowing with warm golden fairy light"),
    ("pp_r2", "Captain Hook's Compass", "An ornate nautical compass with a hook motif and golden filigree"),
    ("pp_r3", "Crocodile Tooth", "A massive curved crocodile tooth with a ticking clock embedded"),

    # === RARE — Phantom ===
    ("ph_r1", "Phantom's Score Sheet", "A black music sheet covered in notes that seem to move"),
    ("ph_r2", "Underground Lake Gem", "A dark aquamarine gemstone that glows from within"),
    ("ph_r3", "Opera Mask Half", "The classic white half-mask of the Phantom, ornate and cracked"),

    # === RARE — Scrooge ===
    ("sc_r1", "Ghost of Christmas Past", "A spectral hooded figure made of white mist holding a candle"),
    ("sc_r2", "Marley's Lockbox", "A heavy iron lockbox wrapped in ghostly chains"),
    ("sc_r3", "Ebenezer's Walking Stick", "A gnarled black cane with a gold coin-shaped handle"),

    # === RARE — Sherlock ===
    ("sh_r1", "Hound's Tooth", "A large canine tooth from a massive supernatural hound"),
    ("sh_r2", "Moriarty's Cipher", "A coded note with interlocking puzzle patterns"),
    ("sh_r3", "221B Fireplace Iron", "A cast iron poker from a fireplace with a chess piece motif"),

    # === RARE — Tarzan ===
    ("tz_r1", "Gorilla King's Pelt", "A patch of thick silver-grey gorilla fur"),
    ("tz_r2", "Jungle Spear", "A handmade wooden spear with a sharpened bone tip"),
    ("tz_r3", "War Drum Mallet", "A heavy wooden mallet for beating tribal war drums"),

    # === RARE — Dracula ===
    ("dr_r1", "Crimson Chalice", "An ornate silver goblet filled with dark crimson liquid"),
    ("dr_r2", "Castle Transylvania Key", "A large gothic iron key with bat wings and skull design"),
    ("dr_r3", "Moonstone Brooch", "A silver brooch with a glowing moonstone centerpiece"),

    # === RARE — Merlin ===
    ("mr_r1", "Staff of the Lake", "A gnarled wooden staff with a living water droplet crystal at the top"),
    ("mr_r2", "Enchanted Runestone", "A large flat stone carved with multiple glowing interlocked runes"),
    ("mr_r3", "Camelot Signet Ring", "A heavy gold ring with the Camelot dragon seal"),

    # === RARE — Frankenstein ===
    ("fr_r1", "Tesla Coil Shard", "A shard of metallic coil that constantly arcs with electricity"),
    ("fr_r2", "Bride's Headband", "A white headband with lightning bolt streaks and silver electrodes"),
    ("fr_r3", "Galvanic Battery", "A brass Leyden jar battery sparking with contained energy"),

    # === RARE — Shadow Author ===
    ("sa_r1", "Fountain Pen of Revision", "An elegant dark fountain pen with golden nib dripping shadow ink"),
    ("sa_r2", "Bookmarked Chapter", "A thick book opened to a glowing chapter with a ribbon bookmark"),
    ("sa_r3", "Plot Twist Scroll", "A scroll that unravels to reveal contradicting text"),

    # === RARE — Universal (44) ===
    ("ur_01", "Steel Broadhead", "A heavy steel broadhead arrowhead with three sharp blades"),
    ("ur_02", "Reinforced Breastplate", "A steel chest armor plate with reinforced ribbing"),
    ("ur_03", "Hawk Eye Amulet", "A bronze amulet with a hawk eye carved into the center"),
    ("ur_04", "Quicksilver Bracelet", "A liquid mercury bracelet that constantly shifts shape"),
    ("ur_05", "Ruby Brooch", "A large ornate ruby brooch with gold filigree setting"),
    ("ur_06", "Frostbound Quartz", "A quartz crystal completely encased in dark ice"),
    ("ur_07", "Treasure Hunter's Pouch", "A bulging leather coin pouch overflowing with gold coins"),
    ("ur_08", "Vampire's Kiss Ring", "A dark silver ring with two small fang marks on the band"),
    ("ur_09", "Infernal Resin", "A vial of glowing red-orange volcanic resin"),
    ("ur_10", "Acrobat's Sash", "A long colorful silk sash worn by acrobats"),
    ("ur_11", "Armor-Piercing Bolt", "A reinforced crossbow bolt with a tungsten hardened tip"),
    ("ur_12", "Spiked Chain Whip", "A length of chain with sharp metal spikes every few links"),
    ("ur_13", "Explosive Pouch", "A leather pouch filled with black powder and a fuse"),
    ("ur_14", "Giant Slayer Charm", "A charm shaped like a giant's fist broken in half"),
    ("ur_15", "Medic's Bandage Roll", "A clean white bandage roll with a red cross symbol"),
    ("ur_16", "Executioner's Gauntlet", "A heavy black metal gauntlet with bladed knuckles"),
    ("ur_17", "Weakening Powder", "A pouch of purple shimmering debilitating powder"),
    ("ur_18", "Battle Standard", "A small flag on a pole with a warrior's crest"),
    ("ur_19", "Clockwork Spring", "A tightly wound metal spring mechanism"),
    ("ur_20", "Thunder Stone", "A dark storm cloud trapped inside a grey-blue stone"),
    ("ur_21", "Serpent Fang", "A long curved serpent fang with venom still on the tip"),
    ("ur_22", "Twin Shot Brace", "A double-barreled mechanical arm brace for twin shots"),
    ("ur_23", "War Horn", "A carved animal horn with bronze fittings for battle calls"),
    ("ur_24", "Mithril Chainmail", "A fine mesh of glowing silver mithril chainmail rings"),
    ("ur_25", "Sapphire Sightstone", "A deep blue sapphire gemstone with telescopic facets"),
    ("ur_26", "Razorwind Fan", "An ornamental fan with bladed edges that catch the wind"),
    ("ur_27", "Gilded Scales", "A set of golden merchant scales balanced perfectly"),
    ("ur_28", "Crimson Thorn", "A blood-red thorn from a cursed rosebush"),
    ("ur_29", "Glacial Hammer", "A hammer head made from solid dark blue glacial ice"),
    ("ur_30", "Wildfire Oil", "A vial of bright orange oil that ignites on contact"),
    ("ur_31", "Piercing Javelin", "A sleek metal javelin with a diamond tip"),
    ("ur_32", "Soul Siphon Pendant", "A dark gem pendant that absorbs a faint red mist"),
    ("ur_33", "Titan's Knuckle", "A giant's knuckle bone worn as a weapon"),
    ("ur_34", "Shadow Cloak", "A flowing black cloak that seems to absorb light"),
    ("ur_35", "Tempest Feather", "A large storm eagle feather crackling with static"),
    ("ur_36", "Bounty Tracker", "A wanted poster folded into a tracker's tool"),
    ("ur_37", "Dragonfire Canister", "A metal canister filled with compressed dragon fire"),
    ("ur_38", "Plague Doctor Mask", "A classic beaked plague doctor mask with dark lenses"),
    ("ur_39", "Fortune Cookie", "A golden fortune cookie radiating mystical light"),
    ("ur_40", "Rally Pennant", "A battle pennant flag with a rallying cry symbol"),
    ("ur_41", "Concussive Round", "A blunt metal explosive projectile round"),
    ("ur_42", "Barbed Net", "A weighted net with barbed wire edges"),
    ("ur_43", "Sniper's Bipod", "A folding metal bipod for precision shooting"),
    ("ur_44", "Berserker's Wristband", "A spiked black leather wristband with blood stains"),

    # === EPIC — Robin Hood ===
    ("rh_e1", "Bow of the Green Knight", "An ancient enchanted bow carved from living wood with glowing green runes and split arrow notches"),
    ("rh_e2", "Sherwood Heart Oak", "A glowing acorn heart of the oldest oak in Sherwood Forest with vine tendrils"),

    # === EPIC — Alice ===
    ("al_e1", "Vorpal Blade", "The legendary Vorpal Blade from Wonderland, brilliantly sharp with snicker-snack rune etching"),
    ("al_e2", "Queen's Croquet Mallet", "A flamingo-headed croquet mallet with hedgehog ball, dripping with royal power"),

    # === EPIC — Wicked Witch ===
    ("ww_e1", "Emerald City Crown", "A jagged green crown of pure emerald with dark magic spikes and swirling enchantment"),
    ("ww_e2", "Flying Monkey Scepter", "A dark scepter topped with a flying monkey skull and chain lightning arcing between wings"),

    # === EPIC — Peter Pan ===
    ("pp_e1", "Neverland Star Map", "A magical star chart that glows with second star location and floating islands"),
    ("pp_e2", "Hook's Enchanted Cutlass", "A wickedly curved pirate cutlass with enchanted blade and Captain Hook's hook guard"),

    # === EPIC — Phantom ===
    ("ph_e1", "Organ of Despair", "A miniature pipe organ with dark pipes and keys that play themselves with shadowy hands"),
    ("ph_e2", "Christine's Locket", "An ornate gold locket with Christine's portrait inside, glowing with bittersweet power"),

    # === EPIC — Scrooge ===
    ("sc_e1", "Ghost of Christmas Future", "A dark hooded specter silhouette pointing a skeletal finger, wreathed in ominous black mist"),
    ("sc_e2", "Tiny Tim's Crutch", "A small wooden crutch radiating warm golden healing light, tied with a red ribbon"),

    # === EPIC — Sherlock ===
    ("sh_e1", "Reichenbach Deduction", "A leather-bound deduction dossier with complex mind-palace diagrams and magnifying glass"),
    ("sh_e2", "Irene's Photograph", "A Victorian photograph in a silver frame with coded secrets hidden in the image"),

    # === EPIC — Tarzan ===
    ("tz_e1", "Lord of the Apes Crown", "A crown of twisted jungle vines, animal bones, and tribal feathers with primal power"),
    ("tz_e2", "Mangani War Paint", "A gourd of sacred red and black war paint with tribal power symbols"),

    # === EPIC — Dracula ===
    ("dr_e1", "Vlad's Impaler Stake", "A massive wooden stake darkened with ancient blood, radiating vampiric energy"),
    ("dr_e2", "Nocturne Cloak", "A sweeping midnight black cloak that transforms into bat wings at the edges"),

    # === EPIC — Merlin ===
    ("mr_e1", "Crystal Cave Focus", "A massive faceted crystal from Merlin's cave glowing with concentrated magical energy"),
    ("mr_e2", "Nimue's Blessing", "A water lily bloom from the Lake of Avalon glowing with divine healing light"),

    # === EPIC — Frankenstein ===
    ("fr_e1", "Lightning Rod Array", "A complex array of lightning rods connected by cables, constantly arcing electricity"),
    ("fr_e2", "Reanimation Serum", "A large syringe filled with glowing green reanimation fluid"),

    # === EPIC — Shadow Author ===
    ("sa_e1", "Inkwell of Rewriting", "A massive ornate inkwell overflowing with living shadow ink that rewrites reality"),
    ("sa_e2", "Chapter of Foreshadowing", "An open book page with glowing text that changes to predict the future"),

    # === EPIC — Universal (26) ===
    ("ue_01", "Dragonbone Warbow", "A massive bow crafted from dragon ribs with dragon fire runes and split projectile tip"),
    ("ue_02", "Frostfire Orb", "A crystal orb split between blue ice and orange fire swirling together"),
    ("ue_03", "Titan's Girdle", "A giant's belt with enormous iron buckle and strength runes"),
    ("ue_04", "Phantom Dancer Boots", "Ghostly translucent dancing slippers that leave shadow footprints"),
    ("ue_05", "Midas Gloves", "Golden gloves that turn everything they touch to gold"),
    ("ue_06", "Nightshade Extract", "A dark purple vial of nightshade poison with skull and crossbones"),
    ("ue_07", "Eagle Eye Scope", "A master sniper's scope with magical lens that sees through walls"),
    ("ue_08", "Berserker's Blood Paint", "A skull-shaped bowl of red war paint with battle runes"),
    ("ue_09", "Templar Shield", "A white crusader shield with red cross and holy light radiating"),
    ("ue_10", "Chain Lightning Coil", "A metal coil continuously crackling with three arcs of lightning"),
    ("ue_11", "Sniper's Focus Crystal", "A perfectly clear crystal lens with target reticle etched inside"),
    ("ue_12", "Soul Harvest Scythe", "A reaper's scythe blade glowing with soul energy"),
    ("ue_13", "War Cry Totem", "A carved tribal totem pole radiating war energy and aura"),
    ("ue_14", "Demolisher's Payload", "A large bomb casing covered in blast radius calculation markings"),
    ("ue_15", "Sentinel's Watch Helm", "A dark iron helm with a third glowing eye in the visor"),
    ("ue_16", "Spider Silk Garrote", "A garrote wire made from spider silk with poison barbs"),
    ("ue_17", "Chrono Gear", "An elaborate clockwork mechanism of interlocking gears frozen in time"),
    ("ue_18", "Boss Hunter's Trophy", "A massive monster skull mounted on a trophy plaque"),
    ("ue_19", "Leech King's Fang", "An oversized leech fang dripping with both venom and stolen life force"),
    ("ue_20", "Multi-Bolt Crossbow", "A mechanical crossbow loaded with three bolts simultaneously"),
    ("ue_21", "Guardian's Oath Ring", "A massive signet ring with a protective ward rune glowing gold"),
    ("ue_22", "Firestorm Catalyst", "A cracked orb with wildfire trapped inside swirling explosively"),
    ("ue_23", "Windwalker Cloak", "A cloak of compressed wind that leaves afterimages when moved"),
    ("ue_24", "Executioner's Verdict", "A judge's gavel wrapped in executioner's black cloth"),
    ("ue_25", "Magnetic Rail", "A pair of electromagnetic rails crackling with propulsion energy"),
    ("ue_26", "Thunder Drum", "A war drum etched with lightning bolts that rumbles on its own"),

    # === LEGENDARY — Character-specific ===
    ("rh_l1", "The Silver Arrow of Sherwood", "The legendary silver arrow of Robin Hood, pure silver shaft with hawk feathers, glowing with infinite piercing rune"),
    ("al_l1", "The Jabberwock's Eye", "A massive yellow eye from the Jabberwocky dripping with eldritch power"),
    ("ww_l1", "The Grimmerie", "An ancient tome of forbidden spells with living green flames on the cover"),
    ("pp_l1", "The Second Star", "A captured star from Neverland sky radiating direction-giving light in a glass bottle"),
    ("ph_l1", "The Music of the Night", "A sheet of music that plays itself, notes floating off the page in darkness"),
    ("sc_l1", "Scrooge's Redemption Ledger", "A golden ledger book radiating warm redemptive light with every entry glowing"),
    ("sh_l1", "The Art of Deduction", "A leather-bound master detective's notebook with complex deduction webs glowing"),
    ("tz_l1", "Heart of the Jungle", "A pulsing jungle heart made of vines, leaves, and ancient animal bones"),
    ("dr_l1", "Nosferatu's Crimson Throne", "A miniature ornate throne carved from dark stone with blood-red cushions"),
    ("mr_l1", "The Siege Perilous", "An empty glowing throne seat that chooses its worthy champion"),
    ("fr_l1", "The Promethean Spark", "The original spark of life in a crystal vial crackling with creation energy"),
    ("sa_l1", "The Unwritten Ending", "A blank final page of a book radiating void energy and infinite possibility"),

    # === LEGENDARY — Universal (13) ===
    ("ul_01", "Crown of the Conqueror", "A dark iron crown with enormous gems at each point radiating conquest power"),
    ("ul_02", "Aegis of the Fallen", "A legendary shield covered in names of the fallen heroes, glowing gold"),
    ("ul_03", "Stormcaller's Gauntlet", "A massive gauntlet crackling with storm lightning and summoning clouds"),
    ("ul_04", "The Gilded Compass", "A gold compass that points not north but toward treasure"),
    ("ul_05", "Hellfire Crucible", "A cauldron of hellfire with black flames and demonic runes"),
    ("ul_06", "Wraithbane", "A ghostly silver blade that exists between worlds, semi-transparent"),
    ("ul_07", "Timekeeper's Hourglass", "An ornate hourglass where the sand flows in all directions at once"),
    ("ul_08", "Bloodmoon Talisman", "A large amulet with a crimson moon trapped inside glowing red"),
    ("ul_09", "Oblivion's Edge", "A sword edge so sharp it cuts through the air leaving a black void trail"),
    ("ul_10", "Winter's Embrace", "A gauntlet of pure ice with frozen souls visible inside"),
    ("ul_11", "The Commander's Banner", "A war banner that never falls, glowing with commanding presence"),
    ("ul_12", "Viperstrike Gauntlet", "A scaled reptilian gauntlet with retractable fang blades"),
    ("ul_13", "Bulwark of Ages", "A massive tower shield older than civilization with age-worn divine marks"),

    # === ANCIENT (10) ===
    ("anc_01", "Shard of Excalibur", "A glowing broken sword fragment radiating golden holy light from Excalibur, ancient mythological artifact"),
    ("anc_02", "Phoenix Plume", "A brilliant iridescent phoenix feather that regenerates and heals, radiating golden fire"),
    ("anc_03", "Mjolnir Fragment", "A chunk of Thor's hammer Mjolnir crackling with divine Norse lightning"),
    ("anc_04", "Eye of Ra", "The divine eye of the Egyptian sun god Ra, a golden eye radiating solar power"),
    ("anc_05", "Dragon Scale", "A massive iridescent dragon scale harder than steel with protective runes"),
    ("anc_06", "Philosopher's Stone", "The legendary Philosopher's Stone glowing red with alchemical power to transmute all"),
    ("anc_07", "Pandora's Shard", "A shard of Pandora's Box leaking all of the world's evils as colored mist"),
    ("anc_08", "Yggdrasil Bark", "A sacred piece of bark from the Norse World Tree Yggdrasil with runes of life"),
    ("anc_09", "Leviathan Tooth", "An enormous sea monster tooth from the biblical Leviathan dripping dark ocean depths"),
    ("anc_10", "Void Ink", "A vial of void-black ink that unravels reality around it, shadow tendrils escaping"),
]

def generate_icon(item_id, item_name, prompt_description):
    """Generate a single gear icon using nano-banana."""
    output_path = os.path.join(OUTPUT_DIR, f"{item_id}.png")

    # Skip if already generated
    if os.path.exists(output_path):
        print(f"  [SKIP] {item_id} already exists")
        return True

    full_prompt = f"{prompt_description}, dark fantasy RPG game item icon, single item centered on dark background, no text, high detail, square icon format, digital game art style"

    env = os.environ.copy()
    env["GEMINI_API_KEY"] = GEMINI_API_KEY

    try:
        result = subprocess.run(
            [NANO_BANANA_CMD, full_prompt,
             "--output", output_path],
            capture_output=True, text=True, env=env, timeout=120,
            shell=False
        )

        if result.returncode == 0 and os.path.exists(output_path):
            return True
        else:
            print(f"  [ERROR] nano-banana failed for {item_id}: {result.stderr[:200]}")
            return False
    except subprocess.TimeoutExpired:
        print(f"  [TIMEOUT] {item_id} timed out")
        return False
    except Exception as e:
        print(f"  [EXCEPTION] {item_id}: {e}")
        return False

def convert_to_real_png(item_id):
    """Convert JPEG-with-PNG-extension to real PNG using Pillow."""
    path = os.path.join(OUTPUT_DIR, f"{item_id}.png")
    if not os.path.exists(path):
        return False
    try:
        img = Image.open(path)
        img.save(path, 'PNG')
        return True
    except Exception as e:
        print(f"  [PNG CONVERT ERROR] {item_id}: {e}")
        return False

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    total = len(GEAR_ITEMS)
    print(f"Starting generation of {total} gear icons...")
    print(f"Output: {OUTPUT_DIR}\n")

    success_count = 0
    fail_count = 0
    batch_size = 10

    for batch_start in range(0, total, batch_size):
        batch = GEAR_ITEMS[batch_start:batch_start + batch_size]
        batch_num = batch_start // batch_size + 1
        total_batches = (total + batch_size - 1) // batch_size

        print(f"=== Batch {batch_num}/{total_batches} (items {batch_start+1}-{min(batch_start+batch_size, total)}) ===")

        batch_success = 0
        generated_ids = []

        for item_id, item_name, prompt_desc in batch:
            print(f"  Generating: {item_id} — {item_name}")
            success = generate_icon(item_id, item_name, prompt_desc)
            if success:
                generated_ids.append(item_id)
                batch_success += 1
            else:
                fail_count += 1

        # Convert batch to real PNG
        print(f"  Converting {len(generated_ids)} images to real PNG...")
        for item_id in generated_ids:
            convert_to_real_png(item_id)

        success_count += batch_success
        print(f"  Batch {batch_num} complete: {batch_success}/{len(batch)} succeeded")
        print(f"  Progress: {success_count}/{total} total ({fail_count} failed)\n")

    print(f"=== GENERATION COMPLETE ===")
    print(f"Success: {success_count}/{total}")
    print(f"Failed:  {fail_count}/{total}")
    print(f"Output:  {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
