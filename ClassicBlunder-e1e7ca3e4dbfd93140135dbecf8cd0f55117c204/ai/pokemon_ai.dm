// ==========================================================================
// POKEMON AI  (scaffold)
// --------------------------------------------------------------------------
// A companion-style AI (mob/Player/AI/Pokemon) driven by a species template.
// Each species = an icon_state in POKEMON.dmi + a PokemonType. Applying a
// species sets the sprite/name/type and grants that type's signature skill
// from PokemonTypeSkills (see pokemon_skills.dm), which the base AI then uses
// on its own in combat.
//
// This is the framework + a validation sample (one species per type). The full
// ~490-species dex from POKEMON.dmi gets batched into BuildPokemonDatabase()
// once this pipeline is confirmed working.
// ==========================================================================

#define POKEMON_ICON 'Icons/Characters/Special/POKEMON.dmi'

// --- Stat tuning knobs -----------------------------------------------------
// Canonical Pokemon base stats (~1-255) are converted into the game's stat
// mods by dividing by POKEMON_STAT_DIVISOR (so base 50 -> mod 1.0, 100 -> 2.0,
// 200 -> 4.0). Raw power is scaled to the owner: a Pokemon whose base-stat
// total equals POKEMON_REFERENCE_BST gets POKEMON_POWER_FRACTION of the owner's
// power; weaker/stronger species scale proportionally.
#define POKEMON_STAT_DIVISOR 50
#define POKEMON_POWER_FRACTION 0.5
#define POKEMON_REFERENCE_BST 500
// Default Potential (level) of a wild Pokemon spawned without a spawner level.
// Kept low so first-stage wild Pokemon don't instantly evolve; a spawner (or
// admin) sets a higher level for tougher areas. Evolution thresholds below are
// canonical Pokemon evolution levels compared directly against Potential.
#define POKEMON_WILD_BASE_POTENTIAL 5
// Legendaries (see pokemon_legendaries) multiply every derived combat stat by
// this, so a Legendary is a flat 40% stronger than its raw base stats imply.
#define POKEMON_LEGENDARY_POWER_MULT 1.4
// Single-type Pokemon get only one type move, so its cooldown is multiplied by
// this to compensate. Dual-type Pokemon (two moves) pay full cooldown on each.
#define POKEMON_SINGLE_TYPE_CD_MULT 0.6

// --- Species template (mirrors the Squad system's ai_sheet) ----------------
// Stores the canonical Pokemon base stats (HP / Attack / Defense / Sp.Atk /
// Sp.Def / Speed) and its evolution (which species it becomes, and at what
// Potential). ApplyPokemonSpecies() converts base stats into the game's mods.
/datum/pokemon_species
	var/species            // display name / database key
	var/icon_state         // state name inside POKEMON.dmi
	var/PokemonType        // one of the PokemonTypeSkills keys
	var/PokemonType2       // second type for dual-type species (null = single-type); set from pokemon_second_types
	var/hp
	var/atk
	var/def
	var/spatk
	var/spdef
	var/spe
	var/evolves_into       // species key of the next stage (null = final form)
	var/evolve_level       // Potential at/above which it evolves (0 = never)
	var/legendary = 0      // set from pokemon_legendaries after the dex is built
	var/custom_icon        // if set, this species lives in its OWN full mob sheet (e.g.
	                       // Keldeo.dmi) instead of POKEMON.dmi; used directly on the mob
	var/region             // "Kanto" / "Johto" / "Mythical"; set from dex order in BuildPokemonDatabase
	New(_species, _state, _type, _hp, _atk, _def, _spatk, _spdef, _spe, _evolves_into, _evolve_level, _custom_icon)
		species = _species
		icon_state = _state
		PokemonType = _type
		hp = _hp
		atk = _atk
		def = _def
		spatk = _spatk
		spdef = _spdef
		spe = _spe
		evolves_into = _evolves_into
		evolve_level = _evolve_level
		custom_icon = _custom_icon

// Registry the Pokemon AI draws from. Built lazily (see GetPokemonSpecies).
var/global/list/pokemon_database = list()

// Legendary species. Kept separate from the regular dex in the "Make Pokemon
// Spawner" admin UI so legendaries aren't handed out by accident. Extend this as
// the dex grows past Kanto.
var/global/list/pokemon_legendaries = list("Articuno", "Zapdos", "Moltres", "Mewtwo", "Mew", \
	"Raikou", "Entei", "Suicune", "Lugia", "Ho-Oh", "Celebi", "Keldeo")

// Starter lines. Kept OUT of the normal spawner pools and offered in their own
// "Starters" list in the Make Pokemon Spawner UI (so admins place them deliberately).
var/global/list/pokemon_starters = list(\
	"Bulbasaur", "Ivysaur", "Venusaur", \
	"Charmander", "Charmeleon", "Charizard", \
	"Squirtle", "Wartortle", "Blastoise", \
	"Chikorita", "Bayleef", "Meganium", \
	"Cyndaquil", "Quilava", "Typhlosion", \
	"Totodile", "Croconaw", "Feraligatr", \
	"Treecko", "Grovyle", "Sceptile", \
	"Torchic", "Combusken", "Blaziken", \
	"Mudkip", "Marshtomp", "Swampert")

// Evolutions that in the real games need a Stone / evolution item / trade / etc.,
// which the level-based CheckEvolution can't reach. The "Enchant Pokemon" verb (from
// the Pokemon Enchantment enchanting knowledge) evolves the summoned Pokemon into one
// of these for 99 Mana Capacity. Species not listed have no enchant-driven evolution.
var/global/list/pokemon_stone_evolutions = list(
	// Stone evolutions (Fire/Water/Thunder/Leaf/Moon/Sun Stone in the originals).
	"Pikachu"    = list("Raichu"),
	"Eevee"      = list("Vaporeon", "Jolteon", "Flareon", "Espeon", "Umbreon", "Leafeon", "Glaceon"),
	"Nidorina"   = list("Nidoqueen"),
	"Nidorino"   = list("Nidoking"),
	"Clefairy"   = list("Clefable"),
	"Jigglypuff" = list("Wigglytuff"),
	"Vulpix"     = list("Ninetales"),
	"Gloom"      = list("Vileplume", "Bellossom"),
	"Growlithe"  = list("Arcanine"),
	"Poliwhirl"  = list("Poliwrath", "Politoed"),
	"Weepinbell" = list("Victreebel"),
	"Exeggcute"  = list("Exeggutor"),
	"Shellder"   = list("Cloyster"),
	"Staryu"     = list("Starmie"),
	"Sunkern"    = list("Sunflora"),
	// Trade-with-item evolutions (Metal Coat / King's Rock / Dragon Scale / Up-Grade).
	"Slowpoke"   = list("Slowking"),
	"Onix"       = list("Steelix"),
	"Scyther"    = list("Scizor"),
	"Seadra"     = list("Kingdra"),
	"Porygon"    = list("Porygon2"),
	// Friendship / special evolutions (kept from the original Eevee-forms request).
	"Golbat"     = list("Crobat"),
	"Chansey"    = list("Blissey"),
	"Tyrogue"    = list("Hitmonlee", "Hitmonchan"),
	// --- Hoenn stone / trade-item evolutions ---
	"Lombre"     = list("Ludicolo"),   // Water Stone
	"Nuzleaf"    = list("Shiftry"),    // Leaf Stone
	"Skitty"     = list("Delcatty"),   // Moon Stone
	"Clamperl"   = list("Huntail", "Gorebyss"))  // Deep Sea Tooth / Scale trade

// Second type for dual-type species. The dex line holds the primary type; this
// adds the other half of the canonical pair, so a dual-type Pokemon is granted
// BOTH type moves. Species absent here are single-type (and get a cooldown
// discount on their one move). Applied in BuildPokemonDatabase.
var/global/list/pokemon_second_types = list(
	// --- Eeveelutions: given Normal as a second type (unfaithful, but a family perk)
	// so every Eevee evolution also gets Quick Attack alongside its elemental move. ---
	"Vaporeon"="Normal", "Jolteon"="Normal", "Flareon"="Normal",
	"Espeon"="Normal", "Umbreon"="Normal", "Leafeon"="Normal", "Glaceon"="Normal",
	// --- Kanto ---
	"Bulbasaur"="Poison", "Ivysaur"="Poison", "Venusaur"="Poison",
	"Charizard"="Flying",
	"Butterfree"="Flying",
	"Weedle"="Poison", "Kakuna"="Poison", "Beedrill"="Poison",
	"Pidgey"="Normal", "Pidgeotto"="Normal", "Pidgeot"="Normal",
	"Spearow"="Normal", "Fearow"="Normal",
	"Nidoqueen"="Poison", "Nidoking"="Poison",
	"Jigglypuff"="Normal", "Wigglytuff"="Normal",
	"Zubat"="Flying", "Golbat"="Flying",
	"Oddish"="Poison", "Gloom"="Poison", "Vileplume"="Poison",
	"Paras"="Grass", "Parasect"="Grass",
	"Venonat"="Poison", "Venomoth"="Poison",
	"Poliwrath"="Fighting",
	"Bellsprout"="Poison", "Weepinbell"="Poison", "Victreebel"="Poison",
	"Tentacool"="Poison", "Tentacruel"="Poison",
	"Geodude"="Ground", "Graveler"="Ground", "Golem"="Ground",
	"Slowpoke"="Psychic", "Slowbro"="Psychic",
	"Magnemite"="Steel", "Magneton"="Steel",
	"Farfetchd"="Normal",
	"Doduo"="Normal", "Dodrio"="Normal",
	"Dewgong"="Ice",
	"Cloyster"="Ice",
	"Gastly"="Poison", "Haunter"="Poison", "Gengar"="Poison",
	"Onix"="Ground",
	"Exeggcute"="Psychic", "Exeggutor"="Psychic",
	"Rhyhorn"="Rock", "Rhydon"="Rock",
	"Starmie"="Psychic",
	"Mr. Mime"="Fairy",
	"Scyther"="Flying",
	"Jynx"="Psychic",
	"Gyarados"="Flying",
	"Lapras"="Ice",
	"Omanyte"="Water", "Omastar"="Water",
	"Kabuto"="Water", "Kabutops"="Water",
	"Aerodactyl"="Flying",
	"Articuno"="Flying", "Zapdos"="Flying", "Moltres"="Flying",
	"Dragonite"="Flying",
	// --- Johto ---
	"Hoothoot"="Normal", "Noctowl"="Normal",
	"Ledyba"="Flying", "Ledian"="Flying",
	"Spinarak"="Poison", "Ariados"="Poison",
	"Crobat"="Flying",
	"Chinchou"="Electric", "Lanturn"="Electric",
	"Igglybuff"="Normal",
	"Togetic"="Flying",
	"Natu"="Flying", "Xatu"="Flying",
	"Marill"="Fairy", "Azumarill"="Fairy",
	"Hoppip"="Flying", "Skiploom"="Flying", "Jumpluff"="Flying",
	"Yanma"="Flying",
	"Wooper"="Ground", "Quagsire"="Ground",
	"Murkrow"="Flying",
	"Slowking"="Water",
	"Girafarig"="Normal",
	"Forretress"="Steel",
	"Gligar"="Flying",
	"Steelix"="Ground",
	"Qwilfish"="Poison",
	"Scizor"="Bug",
	"Shuckle"="Rock",
	"Heracross"="Fighting",
	"Sneasel"="Ice",
	"Magcargo"="Rock",
	"Swinub"="Ground", "Piloswine"="Ground",
	"Corsola"="Rock",
	"Delibird"="Flying",
	"Mantine"="Flying",
	"Skarmory"="Flying",
	"Houndour"="Fire", "Houndoom"="Fire",
	"Kingdra"="Water",
	"Smoochum"="Psychic",
	"Larvitar"="Ground", "Pupitar"="Ground",
	"Tyranitar"="Dark",
	"Lugia"="Flying",
	"Ho-Oh"="Flying",
	"Celebi"="Grass",
	"Keldeo"="Fighting",
	// --- Hoenn ---
	"Combusken"="Fighting", "Blaziken"="Fighting",
	"Marshtomp"="Ground", "Swampert"="Ground",
	"Beautifly"="Flying",
	"Dustox"="Poison",
	"Lotad"="Grass", "Lombre"="Grass", "Ludicolo"="Grass",
	"Nuzleaf"="Dark", "Shiftry"="Dark",
	"Taillow"="Normal", "Swellow"="Normal",
	"Wingull"="Flying", "Pelipper"="Flying",
	"Ralts"="Fairy", "Kirlia"="Fairy", "Gardevoir"="Fairy",
	"Surskit"="Water", "Masquerain"="Flying",
	"Breloom"="Fighting",
	"Nincada"="Ground", "Ninjask"="Flying", "Shedinja"="Ghost",
	"Azurill"="Fairy",
	"Sableye"="Ghost",
	"Mawile"="Fairy",
	"Aron"="Rock", "Lairon"="Rock", "Aggron"="Rock",
	"Meditite"="Psychic", "Medicham"="Psychic",
	"Roselia"="Poison",
	"Carvanha"="Dark", "Sharpedo"="Dark",
	"Numel"="Ground", "Camerupt"="Ground",
	"Vibrava"="Dragon", "Flygon"="Dragon",
	"Cacturne"="Dark",
	"Swablu"="Normal", "Altaria"="Flying",
	"Lunatone"="Psychic", "Solrock"="Psychic",
	"Barboach"="Ground", "Whiscash"="Ground",
	"Crawdaunt"="Dark",
	"Baltoy"="Psychic", "Claydol"="Psychic",
	"Lileep"="Grass", "Cradily"="Grass",
	"Anorith"="Bug", "Armaldo"="Bug",
	"Tropius"="Flying",
	"Spheal"="Water", "Sealeo"="Water", "Walrein"="Water",
	"Relicanth"="Rock",
	"Salamence"="Flying",
	"Beldum"="Psychic", "Metang"="Psychic", "Metagross"="Psychic")

// species, icon_state, type, the 6 base stats (HP,Atk,Def,SpA,SpD,Spe), then the
// evolution target species and the Potential level it evolves at (or null/0).
/proc/_pkmn(species, state, ptype, hp, atk, def, spatk, spdef, spe, evolves_into, evolve_level, custom_icon)
	pokemon_database[species] = new/datum/pokemon_species(species, state, ptype, hp, atk, def, spatk, spdef, spe, evolves_into, evolve_level, custom_icon)

/proc/BuildPokemonDatabase()
	pokemon_database = list()
	// --- KANTO REGION (Gen 1, #001-151) ---
	// species / POKEMON.dmi state / appropriate single type / HP Atk Def SpA SpD Spe / evolves-into / evolve Potential
	_pkmn("Bulbasaur",  "Bulbasaur",  "Grass",     45, 49, 49, 65, 65, 45, "Ivysaur",     16)
	_pkmn("Ivysaur",    "Ivysaur",    "Grass",     60, 62, 63, 80, 80, 60, "Venusaur",    32)
	_pkmn("Venusaur",   "Venusaur",   "Grass",     80, 82, 83,100,100, 80, null,           0)
	_pkmn("Charmander", "Charmander", "Fire",      39, 52, 43, 60, 50, 65, "Charmeleon",  16)
	_pkmn("Charmeleon", "Charmeleon", "Fire",      58, 64, 58, 80, 65, 80, "Charizard",   36)
	_pkmn("Charizard",  "Charizard",  "Fire",      78, 84, 78,109, 85,100, null,           0)
	_pkmn("Squirtle",   "Squirtle",   "Water",     44, 48, 65, 50, 64, 43, "Wartortle",   16)
	_pkmn("Wartortle",  "Wartortle",  "Water",     59, 63, 80, 65, 80, 58, "Blastoise",   36)
	_pkmn("Blastoise",  "Blastoise",  "Water",     79, 83,100, 85,105, 78, null,           0)
	_pkmn("Caterpie",   "Caterpie",   "Bug",       45, 30, 35, 20, 20, 45, "Metapod",      7)
	_pkmn("Metapod",    "Metapod",    "Bug",       50, 20, 55, 25, 25, 30, "Butterfree",  10)
	_pkmn("Butterfree", "Butterfree", "Bug",       60, 45, 50, 90, 80, 70, null,           0)
	_pkmn("Weedle",     "Weedle",     "Bug",       40, 35, 30, 20, 20, 50, "Kakuna",       7)
	_pkmn("Kakuna",     "Kakuna",     "Bug",       45, 25, 50, 25, 25, 35, "Beedrill",    10)
	_pkmn("Beedrill",   "Beedrill",   "Bug",       65, 90, 40, 45, 80, 75, null,           0)
	_pkmn("Pidgey",     "Pidgey",     "Flying",    40, 45, 40, 35, 35, 56, "Pidgeotto",   18)
	_pkmn("Pidgeotto",  "Pidgeotto",  "Flying",    63, 60, 55, 50, 50, 71, "Pidgeot",     36)
	_pkmn("Pidgeot",    "Pidgeot",    "Flying",    83, 80, 75, 70, 70,101, null,           0)
	_pkmn("Rattata",    "Rattata",    "Normal",    30, 56, 35, 25, 35, 72, "Raticate",    20)
	_pkmn("Raticate",   "Raticate",   "Normal",    55, 81, 60, 50, 70, 97, null,           0)
	_pkmn("Spearow",    "Spearow",    "Flying",    40, 60, 30, 31, 31, 70, "Fearow",      20)
	_pkmn("Fearow",     "Fearow",     "Flying",    65, 90, 65, 61, 61,100, null,           0)
	_pkmn("Ekans",      "Ekans",      "Poison",    35, 60, 44, 40, 54, 55, "Arbok",       22)
	_pkmn("Arbok",      "Arbok",      "Poison",    60, 95, 69, 65, 79, 80, null,           0)
	_pkmn("Pikachu",    "Pikachu",    "Electric",  35, 55, 40, 50, 50, 90, "Raichu",       0)  // Thunder Stone -> Enchant Pokemon verb
	_pkmn("Raichu",     "Raichu",     "Electric",  60, 90, 55, 90, 80,110, null,           0)
	_pkmn("Sandshrew",  "Sandshrew",  "Ground",    50, 75, 85, 20, 30, 40, "Sandslash",   22)
	_pkmn("Sandslash",  "Sandslash",  "Ground",    75,100,110, 45, 55, 65, null,           0)
	_pkmn("Nidoran F",  "Nidoran F",  "Poison",    55, 47, 52, 40, 40, 41, "Nidorina",    16)
	_pkmn("Nidorina",   "Nidorina",   "Poison",    70, 62, 67, 55, 55, 56, "Nidoqueen",    0)  // Moon Stone -> Enchant Pokemon verb
	_pkmn("Nidoqueen",  "Nidoqueen",  "Ground",    90, 92, 87, 75, 85, 76, null,           0)
	_pkmn("Nidoran M",  "Nidoran M",  "Poison",    46, 57, 40, 40, 40, 50, "Nidorino",    16)
	_pkmn("Nidorino",   "Nidorino",   "Poison",    61, 72, 57, 55, 55, 65, "Nidoking",     0)  // Moon Stone -> Enchant Pokemon verb
	_pkmn("Nidoking",   "Nidoking",   "Ground",    81,102, 77, 85, 75, 85, null,           0)
	_pkmn("Clefairy",   "Clefairy",   "Fairy",     70, 45, 48, 60, 65, 35, "Clefable",     0)  // Moon Stone -> Enchant Pokemon verb
	_pkmn("Clefable",   "Clefable",   "Fairy",     95, 70, 73, 95, 90, 60, null,           0)
	_pkmn("Vulpix",     "Vulpix",     "Fire",      38, 41, 40, 50, 65, 65, "Ninetales",    0)  // Fire Stone -> Enchant Pokemon verb
	_pkmn("Ninetales",  "Ninetails",  "Fire",      73, 76, 75, 81,100,100, null,           0)
	_pkmn("Jigglypuff", "Jigglypuff", "Fairy",    115, 45, 20, 45, 25, 20, "Wigglytuff",   0)  // Moon Stone -> Enchant Pokemon verb
	_pkmn("Wigglytuff", "Wigglytuff", "Fairy",    140, 70, 45, 85, 50, 45, null,           0)
	_pkmn("Zubat",      "Zubat",      "Poison",    40, 45, 35, 30, 40, 55, "Golbat",      22)
	_pkmn("Golbat",     "Golbat",     "Poison",    75, 80, 70, 65, 75, 90, null,           0)
	_pkmn("Oddish",     "Oddish",     "Grass",     45, 50, 55, 75, 65, 30, "Gloom",       21)
	_pkmn("Gloom",      "Gloom",      "Grass",     60, 65, 70, 85, 75, 40, "Vileplume",    0)  // Leaf/Sun Stone -> Enchant Pokemon verb
	_pkmn("Vileplume",  "Vileplume",  "Grass",     75, 80, 85,110, 90, 50, null,           0)
	_pkmn("Paras",      "Paras",      "Bug",       35, 70, 55, 45, 55, 25, "Parasect",    24)
	_pkmn("Parasect",   "Parasect",   "Bug",       60, 95, 80, 60, 80, 30, null,           0)
	_pkmn("Venonat",    "Venonat",    "Bug",       60, 55, 50, 40, 55, 45, "Venomoth",    31)
	_pkmn("Venomoth",   "Venomoth",   "Bug",       70, 65, 60, 90, 75, 90, null,           0)
	_pkmn("Diglett",    "Diglett",    "Ground",    10, 55, 25, 35, 45, 95, "Dugtrio",     26)
	_pkmn("Dugtrio",    "Dugtrio",    "Ground",    35,100, 50, 50, 70,120, null,           0)
	_pkmn("Meowth",     "Meowth",     "Normal",    40, 45, 35, 40, 40, 90, "Persian",     28)
	_pkmn("Persian",    "Persian",    "Normal",    65, 70, 60, 65, 65,115, null,           0)
	_pkmn("Psyduck",    "Psyduck",    "Water",     50, 52, 48, 65, 50, 55, "Golduck",     33)
	_pkmn("Golduck",    "Golduck",    "Water",     80, 82, 78, 95, 80, 85, null,           0)
	_pkmn("Mankey",     "Mankey",     "Fighting",  40, 80, 35, 35, 45, 70, "Primeape",    28)
	_pkmn("Primeape",   "Primeape",   "Fighting",  65,105, 60, 60, 70, 95, null,           0)
	_pkmn("Growlithe",  "Growlithe",  "Fire",      55, 70, 45, 70, 50, 60, "Arcanine",     0)  // Fire Stone -> Enchant Pokemon verb
	_pkmn("Arcanine",   "Arcanine",   "Fire",      90,110, 80,100, 80, 95, null,           0)
	_pkmn("Poliwag",    "Poliwag",    "Water",     40, 50, 40, 40, 40, 90, "Poliwhirl",   25)
	_pkmn("Poliwhirl",  "Poliwhirl",  "Water",     65, 65, 65, 50, 50, 90, "Poliwrath",    0)  // Water Stone / King's Rock -> Enchant Pokemon verb
	_pkmn("Poliwrath",  "Poliwrath",  "Water",     90, 95, 95, 70, 90, 70, null,           0)
	_pkmn("Abra",       "Abra",       "Psychic",   25, 20, 15,105, 55, 90, "Kadabra",     16)
	_pkmn("Kadabra",    "Kadabra",    "Psychic",   40, 35, 30,120, 70,105, "Alakazam",    36)
	_pkmn("Alakazam",   "Alakazam",   "Psychic",   55, 50, 45,135, 95,120, null,           0)
	_pkmn("Machop",     "Machop",     "Fighting",  70, 80, 50, 35, 35, 35, "Machoke",     28)
	_pkmn("Machoke",    "Machoke",    "Fighting",  80,100, 70, 50, 60, 45, "Machamp",     40)
	_pkmn("Machamp",    "Machamp",    "Fighting",  90,130, 80, 65, 85, 55, null,           0)
	_pkmn("Bellsprout", "Bellsprout", "Grass",     50, 75, 35, 70, 30, 40, "Weepinbell",  21)
	_pkmn("Weepinbell", "Weepinbell", "Grass",     65, 90, 50, 85, 45, 55, "Victreebel",   0)  // Leaf Stone -> Enchant Pokemon verb
	_pkmn("Victreebel", "Victreebel", "Grass",     80,105, 65,100, 70, 70, null,           0)
	_pkmn("Tentacool",  "Tentacool",  "Water",     40, 40, 35, 50,100, 70, "Tentacruel",  30)
	_pkmn("Tentacruel", "Tentacruel", "Water",     80, 70, 65, 80,120,100, null,           0)
	_pkmn("Geodude",    "Geodude",    "Rock",      40, 80,100, 30, 30, 20, "Graveler",    25)
	_pkmn("Graveler",   "Graveler",   "Rock",      55, 95,115, 45, 45, 35, "Golem",       35)
	_pkmn("Golem",      "Golem",      "Rock",      80,120,130, 55, 65, 45, null,           0)
	_pkmn("Ponyta",     "Ponyta",     "Fire",      50, 85, 55, 65, 65, 90, "Rapidash",    40)
	_pkmn("Rapidash",   "Rapidash",   "Fire",      65,100, 70, 80, 80,105, null,           0)
	_pkmn("Slowpoke",   "Slowpoke",   "Water",     90, 65, 65, 40, 40, 15, "Slowbro",     37)
	_pkmn("Slowbro",    "Slowbro",    "Water",     95, 75,110,100, 80, 30, null,           0)
	_pkmn("Magnemite",  "Magnemite",  "Electric",  25, 35, 70, 95, 55, 45, "Magneton",    30)
	_pkmn("Magneton",   "Magneton",   "Electric",  50, 60, 95,120, 70, 70, null,           0)
	_pkmn("Farfetchd",  "Farfetchd",  "Flying",    52, 90, 55, 58, 62, 60, null,           0)
	_pkmn("Doduo",      "Doduo",      "Flying",    35, 85, 45, 35, 35, 75, "Dodrio",      31)
	_pkmn("Dodrio",     "Dodrio",     "Flying",    60,110, 70, 60, 60,110, null,           0)
	_pkmn("Seel",       "Seel",       "Water",     65, 45, 55, 45, 70, 45, "Dewgong",     34)
	_pkmn("Dewgong",    "Dewgong",    "Water",     90, 70, 80, 70, 95, 70, null,           0)
	_pkmn("Grimer",     "Grimer",     "Poison",    80, 80, 50, 40, 50, 25, "Muk",         38)
	_pkmn("Muk",        "Muk",        "Poison",   105,105, 75, 65,100, 50, null,           0)
	_pkmn("Shellder",   "Shellder",   "Water",     30, 65,100, 45, 25, 40, "Cloyster",     0)  // Water Stone -> Enchant Pokemon verb
	_pkmn("Cloyster",   "Cloyster",   "Water",     50, 95,180, 85, 45, 70, null,           0)
	_pkmn("Gastly",     "Gastly",     "Ghost",     30, 35, 30,100, 35, 80, "Haunter",     25)
	_pkmn("Haunter",    "Haunter",    "Ghost",     45, 50, 45,115, 55, 95, "Gengar",      35)
	_pkmn("Gengar",     "Gengar",     "Ghost",     60, 65, 60,130, 75,110, null,           0)
	_pkmn("Onix",       "Onix",       "Rock",      35, 45,160, 30, 45, 70, null,           0)
	_pkmn("Drowzee",    "Drowzee",    "Psychic",   60, 48, 45, 43, 90, 42, "Hypno",       26)
	_pkmn("Hypno",      "Hypno",      "Psychic",   85, 73, 70, 73,115, 67, null,           0)
	_pkmn("Krabby",     "Krabby",     "Water",     30,105, 90, 25, 25, 50, "Kingler",     28)
	_pkmn("Kingler",    "Kingler",    "Water",     55,130,115, 50, 50, 75, null,           0)
	_pkmn("Voltorb",    "Voltorb",    "Electric",  40, 30, 50, 55, 55,100, "Electrode",   30)
	_pkmn("Electrode",  "Electrode",  "Electric",  60, 50, 70, 80, 80,150, null,           0)
	_pkmn("Exeggcute",  "Exeggcute",  "Grass",     60, 40, 80, 60, 45, 40, "Exeggutor",    0)  // Leaf Stone -> Enchant Pokemon verb
	_pkmn("Exeggutor",  "Exeggutor",  "Grass",     95, 95, 85,125, 75, 55, null,           0)
	_pkmn("Cubone",     "Cubone",     "Ground",    50, 50, 95, 40, 50, 35, "Marowak",     28)
	_pkmn("Marowak",    "Marowak",    "Ground",    60, 80,110, 50, 80, 45, null,           0)
	_pkmn("Hitmonlee",  "Hitmonlee",  "Fighting",  50,120, 53, 35,110, 87, null,           0)
	_pkmn("Hitmonchan", "Hitmonchan", "Fighting",  50,105, 79, 35,110, 76, null,           0)
	_pkmn("Lickitung",  "Lickitung",  "Normal",    90, 55, 75, 60, 75, 30, null,           0)
	_pkmn("Koffing",    "koffing",    "Poison",    40, 65, 95, 60, 45, 35, "Weezing",     35)
	_pkmn("Weezing",    "Weezing",    "Poison",    65, 90,120, 85, 70, 60, null,           0)
	_pkmn("Rhyhorn",    "Rhyhorn",    "Ground",    80, 85, 95, 30, 30, 25, "Rhydon",      42)
	_pkmn("Rhydon",     "Rhydon",     "Ground",   105,130,120, 45, 45, 40, null,           0)
	_pkmn("Chansey",    "Chansey",    "Normal",   250,  5,  5, 35,105, 50, null,           0)
	_pkmn("Tangela",    "Tangela",    "Grass",     65, 55,115,100, 40, 60, null,           0)
	_pkmn("Kangaskhan", "Kangaskhan", "Normal",   105, 95, 80, 40, 80, 90, null,           0)
	_pkmn("Horsea",     "Horsea",     "Water",     30, 40, 70, 70, 25, 60, "Seadra",      32)
	_pkmn("Seadra",     "Seadra",     "Water",     55, 65, 95, 95, 45, 85, null,           0)
	_pkmn("Goldeen",    "Goldeen",    "Water",     45, 67, 60, 35, 50, 63, "Seaking",     33)
	_pkmn("Seaking",    "Seaking",    "Water",     80, 92, 65, 65, 80, 68, null,           0)
	_pkmn("Staryu",     "Staryu",     "Water",     30, 45, 55, 70, 55, 85, "Starmie",      0)  // Water Stone -> Enchant Pokemon verb
	_pkmn("Starmie",    "Starmie",    "Water",     60, 75, 85,100, 85,115, null,           0)
	_pkmn("Mr. Mime",   "Mr. Mime",   "Psychic",   40, 45, 65,100,120, 90, null,           0)
	_pkmn("Scyther",    "Scyther",    "Bug",       70,110, 80, 55, 80,105, null,           0)
	_pkmn("Jynx",       "Jynx",       "Ice",       65, 50, 35,115, 95, 95, null,           0)
	_pkmn("Electabuzz", "Electabuzz", "Electric",  65, 83, 57, 95, 85,105, null,           0)
	_pkmn("Magmar",     "Magmar",     "Fire",      65, 95, 57,100, 85, 93, null,           0)
	_pkmn("Pinsir",     "Pinsir",     "Bug",       65,125,100, 55, 70, 85, null,           0)
	_pkmn("Tauros",     "Tauros",     "Normal",    75,100, 95, 40, 70,110, null,           0)
	_pkmn("Magikarp",   "Magikarp",   "Water",     20, 10, 55, 15, 20, 80, "Gyarados",    20)
	_pkmn("Gyarados",   "Gyarados",   "Water",     95,125, 79, 60,100, 81, null,           0)
	_pkmn("Lapras",     "Lapras",     "Water",    130, 85, 80, 85, 95, 60, null,           0)
	_pkmn("Ditto",      "Ditto",      "Normal",    48, 48, 48, 48, 48, 48, null,           0)
	_pkmn("Eevee",      "Eevee",      "Normal",    55, 55, 50, 45, 65, 55, "Vaporeon",     0)  // Water/Thunder/Fire Stone + friendship -> Enchant Pokemon verb
	_pkmn("Vaporeon",   "Vaporeon",   "Water",    130, 65, 60,110, 95, 65, null,           0)
	_pkmn("Jolteon",    "Jolteon",    "Electric",  65, 65, 60,110, 95,130, null,           0)
	_pkmn("Flareon",    "Flareon",    "Fire",      65,130, 60, 95,110, 65, null,           0)
	_pkmn("Porygon",    "Porygon",    "Normal",    65, 60, 70, 85, 75, 40, null,           0)
	_pkmn("Omanyte",    "Omanyte",    "Rock",      35, 40,100, 90, 55, 35, "Omastar",     40)
	_pkmn("Omastar",    "Omastar",    "Rock",      70, 60,125,115, 70, 55, null,           0)
	_pkmn("Kabuto",     "Kabuto",     "Rock",      30, 80, 90, 55, 45, 55, "Kabutops",    40)
	_pkmn("Kabutops",   "Kabutops",   "Rock",      60,115,105, 65, 70, 80, null,           0)
	_pkmn("Aerodactyl", "Aerodactyl", "Rock",      80,105, 65, 60, 75,130, null,           0)
	_pkmn("Snorlax",    "Snorlax",    "Normal",   160,110, 65, 65,110, 30, null,           0)
	_pkmn("Articuno",   "Articuno",   "Ice",       90, 85,100, 95,125, 85, null,           0)
	_pkmn("Zapdos",     "Zapdos",     "Electric",  90, 90, 85,125, 90,100, null,           0)
	_pkmn("Moltres",    "Moltres",    "Fire",      90,100, 90,125, 85, 90, null,           0)
	_pkmn("Dratini",    "Dratini",    "Dragon",    41, 64, 45, 50, 50, 50, "Dragonair",   30)
	_pkmn("Dragonair",  "Dragonair",  "Dragon",    61, 84, 65, 70, 70, 70, "Dragonite",   55)
	_pkmn("Dragonite",  "Dragonite",  "Dragon",    91,134, 95,100,100, 80, null,           0)
	_pkmn("Mewtwo",     "Mewtwo",     "Psychic",  106,110, 90,154, 90,130, null,           0)
	_pkmn("Mew",        "Mew",        "Psychic",  100,100,100,100,100,100, null,           0)
	// --- JOHTO REGION (Gen 2, #152-251) ---
	// Same format as Kanto. icon_state matches the exact POKEMON.dmi state (a few use
	// the sheet's spellings: Bayleaf, Typholsion, Unknown, lugiamiddle). Single most-
	// fitting type; non-level evolutions (stone/trade/happiness) get a sensible level.
	_pkmn("Chikorita",  "Chikorita",  "Grass",     45, 49, 65, 49, 65, 45, "Bayleef",     16)
	_pkmn("Bayleef",    "Bayleaf",    "Grass",     60, 62, 80, 63, 80, 60, "Meganium",    32)
	_pkmn("Meganium",   "Meganium",   "Grass",     80, 82,100, 83,100, 80, null,           0)
	_pkmn("Cyndaquil",  "Cyndaquil",  "Fire",      39, 52, 43, 60, 50, 65, "Quilava",     14)
	_pkmn("Quilava",    "Quilava",    "Fire",      58, 64, 58, 80, 65, 80, "Typhlosion",  36)
	_pkmn("Typhlosion", "Typholsion", "Fire",      78, 84, 78,109, 85,100, null,           0)
	_pkmn("Totodile",   "Totodile",   "Water",     50, 65, 64, 44, 48, 43, "Croconaw",    18)
	_pkmn("Croconaw",   "Croconaw",   "Water",     65, 80, 80, 59, 63, 58, "Feraligatr",  30)
	_pkmn("Feraligatr", "Feraligatr", "Water",     85,105,100, 79, 83, 78, null,           0)
	_pkmn("Sentret",    "Sentret",    "Normal",    35, 46, 34, 35, 45, 20, "Furret",      15)
	_pkmn("Furret",     "Furret",     "Normal",    85, 76, 64, 45, 55, 90, null,           0)
	_pkmn("Hoothoot",   "Hoothoot",   "Flying",    60, 30, 30, 36, 56, 50, "Noctowl",     20)
	_pkmn("Noctowl",    "Noctowl",    "Flying",   100, 50, 50, 86, 96, 70, null,           0)
	_pkmn("Ledyba",     "Ledyba",     "Bug",       40, 20, 30, 40, 80, 55, "Ledian",      18)
	_pkmn("Ledian",     "Ledian",     "Bug",       55, 35, 50, 55,110, 85, null,           0)
	_pkmn("Spinarak",   "Spinarak",   "Bug",       40, 60, 40, 40, 40, 30, "Ariados",     22)
	_pkmn("Ariados",    "Ariados",    "Bug",       70, 90, 70, 60, 70, 40, null,           0)
	_pkmn("Crobat",     "Crobat",     "Poison",    85, 90, 80, 70, 80,130, null,           0)
	_pkmn("Chinchou",   "Chinchou",   "Water",     75, 38, 38, 56, 56, 67, "Lanturn",     27)
	_pkmn("Lanturn",    "Lanturn",    "Water",    125, 58, 58, 76, 76, 67, null,           0)
	_pkmn("Pichu",      "Pichu",      "Electric",  20, 40, 15, 35, 35, 60, "Pikachu",     10)
	_pkmn("Cleffa",     "Cleffa",     "Fairy",     50, 25, 28, 45, 55, 15, "Clefairy",    10)
	_pkmn("Igglybuff",  "Igglybuff",  "Fairy",     90, 30, 15, 40, 20, 15, "Jigglypuff",  10)
	_pkmn("Togepi",     "Togepi",     "Fairy",     35, 20, 65, 40, 65, 20, "Togetic",     10)
	_pkmn("Togetic",    "Togetic",    "Fairy",     55, 40, 85, 80,105, 40, null,           0)
	_pkmn("Natu",       "Natu",       "Psychic",   40, 50, 45, 70, 45, 70, "Xatu",        25)
	_pkmn("Xatu",       "Xatu",       "Psychic",   65, 75, 70, 95, 70, 95, null,           0)
	_pkmn("Mareep",     "Mareep",     "Electric",  55, 40, 40, 65, 45, 35, "Flaaffy",     15)
	_pkmn("Flaaffy",    "Flaaffy",    "Electric",  70, 55, 55, 80, 60, 45, "Ampharos",    30)
	_pkmn("Ampharos",   "Ampharos",   "Electric",  90, 75, 85,115, 90, 55, null,           0)
	_pkmn("Bellossom",  "Bellossom",  "Grass",     75, 80, 95, 90,100, 50, null,           0)
	_pkmn("Marill",     "Marill",     "Water",     70, 20, 50, 20, 50, 40, "Azumarill",   18)
	_pkmn("Azumarill",  "Azumarill",  "Water",    100, 50, 80, 60, 80, 50, null,           0)
	_pkmn("Sudowoodo",  "Sudowoodo",  "Rock",      70,100,115, 30, 65, 30, null,           0)
	_pkmn("Politoed",   "Politoed",   "Water",     90, 75, 75, 90,100, 70, null,           0)
	_pkmn("Hoppip",     "Hoppip",     "Grass",     35, 35, 40, 35, 55, 50, "Skiploom",    18)
	_pkmn("Skiploom",   "Skiploom",   "Grass",     55, 45, 50, 45, 65, 80, "Jumpluff",    27)
	_pkmn("Jumpluff",   "Jumpluff",   "Grass",     75, 55, 70, 55, 95,110, null,           0)
	_pkmn("Aipom",      "Aipom",      "Normal",    55, 70, 55, 40, 55, 85, null,           0)
	_pkmn("Sunkern",    "Sunkern",    "Grass",     30, 30, 30, 30, 30, 30, "Sunflora",     0)  // Sun Stone -> Enchant Pokemon verb
	_pkmn("Sunflora",   "Sunflora",   "Grass",     75, 75, 55,105, 85, 30, null,           0)
	_pkmn("Yanma",      "Yanma",      "Bug",       65, 65, 45, 75, 45, 95, null,           0)
	_pkmn("Wooper",     "Wooper",     "Water",     55, 45, 45, 25, 25, 15, "Quagsire",    20)
	_pkmn("Quagsire",   "Quagsire",   "Water",     95, 85, 85, 65, 65, 35, null,           0)
	_pkmn("Espeon",     "Espeon",     "Psychic",   65, 65, 60,130, 95,110, null,           0)
	_pkmn("Umbreon",    "Umbreon",    "Dark",      95, 65,110, 60,130, 65, null,           0)
	_pkmn("Murkrow",    "Murkrow",    "Dark",      60, 85, 42, 85, 42, 91, null,           0)
	_pkmn("Slowking",   "Slowking",   "Psychic",   95, 75, 80,100,110, 30, null,           0)
	_pkmn("Misdreavus", "Misdreavus", "Ghost",     60, 60, 60, 85, 85, 85, null,           0)
	_pkmn("Unown",      "Unknown",    "Psychic",   48, 72, 48, 72, 48, 48, null,           0)
	_pkmn("Wobbuffet",  "Wobbuffet",  "Psychic",  190, 33, 58, 33, 58, 33, null,           0)
	_pkmn("Girafarig",  "Girafarig",  "Psychic",   70, 80, 65, 90, 65, 85, null,           0)
	_pkmn("Pineco",     "Pineco",     "Bug",       50, 65, 90, 35, 35, 15, "Forretress",  31)
	_pkmn("Forretress", "Forretress", "Bug",       75, 90,140, 60, 60, 40, null,           0)
	_pkmn("Dunsparce",  "Dunsparce",  "Normal",   100, 70, 70, 65, 65, 45, null,           0)
	_pkmn("Gligar",     "Gligar",     "Ground",    65, 75,105, 35, 65, 85, null,           0)
	_pkmn("Steelix",    "Steelix",    "Steel",     75, 85,200, 55, 65, 30, null,           0)
	_pkmn("Snubbull",   "Snubbull",   "Fairy",     60, 80, 50, 40, 40, 30, "Granbull",    23)
	_pkmn("Granbull",   "Granbull",   "Fairy",     90,120, 75, 60, 60, 45, null,           0)
	_pkmn("Qwilfish",   "Qwilfish",   "Water",     65, 95, 85, 55, 55, 85, null,           0)
	_pkmn("Scizor",     "Scizor",     "Steel",     70,130,100, 55, 80, 65, null,           0)
	_pkmn("Shuckle",    "Shuckle",    "Bug",       20, 10,230, 10,230,  5, null,           0)
	_pkmn("Heracross",  "Heracross",  "Bug",       80,125, 75, 40, 95, 85, null,           0)
	_pkmn("Sneasel",    "Sneasel",    "Dark",      55, 95, 55, 35, 75,115, null,           0)
	_pkmn("Teddiursa",  "Teddiursa",  "Normal",    60, 80, 50, 50, 50, 40, "Ursaring",    30)
	_pkmn("Ursaring",   "Ursaring",   "Normal",    90,130, 75, 75, 75, 55, null,           0)
	_pkmn("Slugma",     "Slugma",     "Fire",      40, 40, 40, 70, 40, 20, "Magcargo",    38)
	_pkmn("Magcargo",   "Magcargo",   "Fire",      50, 50,120, 80, 80, 30, null,           0)
	_pkmn("Swinub",     "Swinub",     "Ice",       50, 50, 40, 30, 30, 50, "Piloswine",   33)
	_pkmn("Piloswine",  "Piloswine",  "Ice",      100,100, 80, 60, 60, 50, null,           0)
	_pkmn("Corsola",    "Corsola",    "Water",     65, 55, 95, 65, 95, 35, null,           0)
	_pkmn("Remoraid",   "Remoraid",   "Water",     35, 65, 35, 65, 35, 65, "Octillery",   25)
	_pkmn("Octillery",  "Octillery",  "Water",     75,105, 75,105, 75, 45, null,           0)
	_pkmn("Delibird",   "Delibird",   "Ice",       45, 55, 45, 65, 45, 75, null,           0)
	_pkmn("Mantine",    "Mantine",    "Water",     85, 40, 70, 80,140, 70, null,           0)
	_pkmn("Skarmory",   "Skarmory",   "Steel",     65, 80,140, 40, 70, 70, null,           0)
	_pkmn("Houndour",   "Houndour",   "Dark",      45, 60, 30, 80, 50, 65, "Houndoom",    24)
	_pkmn("Houndoom",   "Houndoom",   "Dark",      75, 90, 50,110, 80, 95, null,           0)
	_pkmn("Kingdra",    "Kingdra",    "Dragon",    75, 95, 95, 95, 95, 85, null,           0)
	_pkmn("Phanpy",     "Phanpy",     "Ground",    90, 60, 60, 40, 40, 40, "Donphan",     25)
	_pkmn("Donphan",    "Donphan",    "Ground",    90,120,120, 60, 60, 50, null,           0)
	_pkmn("Porygon2",   "Porygon2",   "Normal",    85, 80, 90,105, 95, 60, null,           0)
	_pkmn("Stantler",   "Stantler",   "Normal",    73, 95, 62, 85, 65, 85, null,           0)
	_pkmn("Smeargle",   "Smeargle",   "Normal",    55, 20, 35, 20, 45, 75, null,           0)
	_pkmn("Tyrogue",    "Tyrogue",    "Fighting",  35, 35, 35, 35, 35, 35, "Hitmontop",   20)
	_pkmn("Hitmontop",  "Hitmontop",  "Fighting",  50, 95, 95, 35,110, 70, null,           0)
	_pkmn("Smoochum",   "Smoochum",   "Ice",       45, 30, 15, 85, 65, 65, "Jynx",        30)
	_pkmn("Elekid",     "Elekid",     "Electric",  45, 63, 37, 65, 55, 95, "Electabuzz",  30)
	_pkmn("Magby",      "Magby",      "Fire",      45, 75, 37, 70, 55, 83, "Magmar",      30)
	_pkmn("Miltank",    "Miltank",    "Normal",    95, 80,105, 40, 70,100, null,           0)
	_pkmn("Blissey",    "Blissey",    "Normal",   255, 10, 10, 75,135, 55, null,           0)
	_pkmn("Raikou",     "Raikou",     "Electric",  90, 85, 75,115,100,115, null,           0)
	_pkmn("Entei",      "Entei",      "Fire",     115,115, 85, 90, 75,100, null,           0)
	_pkmn("Suicune",    "Suicune",    "Water",    100, 75,115, 90,115, 85, null,           0)
	_pkmn("Larvitar",   "Larvitar",   "Rock",      50, 64, 50, 45, 50, 41, "Pupitar",     30)
	_pkmn("Pupitar",    "Pupitar",    "Rock",      70, 84, 70, 65, 70, 51, "Tyranitar",   55)
	_pkmn("Tyranitar",  "Tyranitar",  "Rock",     100,134,110, 95,100, 61, null,           0)
	_pkmn("Lugia",      "lugiamiddle","Psychic",  106, 90,130, 90,154,110, null,           0)
	_pkmn("Ho-Oh",      "Ho-Oh",      "Fire",     106,130, 90,110,154, 90, null,           0)
	_pkmn("Celebi",     "Celebi",     "Psychic",  100,100,100,100,100,100, null,           0)
	// --- HOENN REGION (Gen 3, #252-386, LEGENDARIES EXCLUDED so #252-376) ---
	// Same format/conventions as Kanto/Johto. Single most-fitting primary type; second
	// types added via pokemon_second_types; stone/item evolutions get evolve_level 0 and
	// live in pokemon_stone_evolutions (reached through the Enchant Pokemon verb).
	_pkmn("Treecko",    "Treecko",    "Grass",     40, 45, 35, 65, 55, 70, "Grovyle",     16)
	_pkmn("Grovyle",    "Grovyle",    "Grass",     50, 65, 45, 85, 65, 95, "Sceptile",    36)
	_pkmn("Sceptile",   "Sceptile",   "Grass",     70, 85, 65,105, 85,120, null,           0)
	_pkmn("Torchic",    "Torchic",    "Fire",      45, 60, 40, 70, 50, 45, "Combusken",   16)
	_pkmn("Combusken",  "Combusken",  "Fire",      60, 85, 60, 85, 60, 55, "Blaziken",    36)
	_pkmn("Blaziken",   "Blaziken",   "Fire",      80,120, 70,110, 70, 80, null,           0)
	_pkmn("Mudkip",     "Mudkip",     "Water",     50, 70, 50, 50, 50, 40, "Marshtomp",   16)
	_pkmn("Marshtomp",  "Marshtomp",  "Water",     70, 85, 70, 60, 70, 50, "Swampert",    36)
	_pkmn("Swampert",   "Swampert",   "Water",    100,110, 90, 85, 90, 60, null,           0)
	_pkmn("Poochyena",  "Poochyena",  "Dark",      35, 55, 35, 30, 30, 35, "Mightyena",   18)
	_pkmn("Mightyena",  "Mightyena",  "Dark",      70, 90, 70, 60, 60, 70, null,           0)
	_pkmn("Zigzagoon",  "Zigzagoon",  "Normal",    38, 30, 41, 30, 41, 60, "Linoone",     20)
	_pkmn("Linoone",    "Linoone",    "Normal",    78, 70, 61, 50, 61,100, null,           0)
	_pkmn("Wurmple",    "Wurmple",    "Bug",       45, 45, 35, 20, 30, 20, "Silcoon",      7)
	_pkmn("Silcoon",    "Silcoon",    "Bug",       50, 35, 55, 25, 25, 15, "Beautifly",   10)
	_pkmn("Beautifly",  "Beautifly",  "Bug",       60, 70, 50,100, 50, 65, null,           0)
	_pkmn("Cascoon",    "Cascoon",    "Bug",       50, 35, 55, 25, 25, 15, "Dustox",      10)
	_pkmn("Dustox",     "Dustox",     "Bug",       60, 50, 70, 50, 90, 65, null,           0)
	_pkmn("Lotad",      "Lotad",      "Water",     40, 30, 30, 40, 50, 30, "Lombre",      14)
	_pkmn("Lombre",     "Lombre",     "Water",     60, 50, 50, 60, 70, 50, "Ludicolo",     0)  // Water Stone -> Enchant Pokemon verb
	_pkmn("Ludicolo",   "Ludicolo",   "Water",     80, 70, 70, 90,100, 70, null,           0)
	_pkmn("Seedot",     "Seedot",     "Grass",     40, 40, 50, 30, 30, 30, "Nuzleaf",     14)
	_pkmn("Nuzleaf",    "Nuzleaf",    "Grass",     70, 70, 40, 60, 40, 60, "Shiftry",      0)  // Leaf Stone -> Enchant Pokemon verb
	_pkmn("Shiftry",    "Shiftry",    "Grass",     90,100, 60, 90, 60, 80, null,           0)
	_pkmn("Taillow",    "Taillow",    "Flying",    40, 55, 30, 30, 30, 85, "Swellow",     22)
	_pkmn("Swellow",    "Swellow",    "Flying",    60, 85, 60, 75, 50,125, null,           0)
	_pkmn("Wingull",    "Wingull",    "Water",     40, 30, 30, 55, 30, 85, "Pelipper",    25)
	_pkmn("Pelipper",   "pelipper",   "Water",     60, 50,100, 95, 70, 65, null,           0)
	_pkmn("Ralts",      "Ralts",      "Psychic",   28, 25, 25, 45, 35, 40, "Kirlia",      20)
	_pkmn("Kirlia",     "Kirlia",     "Psychic",   38, 35, 35, 65, 55, 50, "Gardevoir",   30)
	_pkmn("Gardevoir",  "Gardevoir",  "Psychic",   68, 65, 65,125,115, 80, null,           0)
	_pkmn("Surskit",    "Surskit",    "Bug",       40, 30, 32, 50, 52, 65, "Masquerain",  22)
	_pkmn("Masquerain", "Masquerain", "Bug",       70, 60, 62,100, 82, 80, null,           0)
	_pkmn("Shroomish",  "Shroomish",  "Grass",     60, 40, 60, 40, 60, 35, "Breloom",     23)
	_pkmn("Breloom",    "Breloom",    "Grass",     60,130, 80, 60, 60, 70, null,           0)
	_pkmn("Slakoth",    "Slakoth",    "Normal",    60, 60, 60, 35, 35, 30, "Vigoroth",    18)
	_pkmn("Vigoroth",   "Vigoroth",   "Normal",    80, 80, 80, 55, 55, 90, "Slaking",     36)
	_pkmn("Slaking",    "Slaking",    "Normal",   150,160,100, 95, 65,100, null,           0)
	_pkmn("Nincada",    "Nincada",    "Bug",       31, 45, 90, 30, 30, 40, "Ninjask",     20)
	_pkmn("Ninjask",    "Ninjask",    "Bug",       61, 90, 45, 50, 50,160, null,           0)
	_pkmn("Shedinja",   "Shedinja",   "Bug",        1, 90, 45, 30, 30, 40, null,           0)
	_pkmn("Whismur",    "Whismur",    "Normal",    64, 51, 23, 51, 23, 28, "Loudred",     20)
	_pkmn("Loudred",    "Loudred",    "Normal",    84, 71, 43, 71, 43, 48, "Exploud",     40)
	_pkmn("Exploud",    "Exploud",    "Normal",   104, 91, 63, 91, 73, 68, null,           0)
	_pkmn("Makuhita",   "Makuhita",   "Fighting",  72, 60, 30, 20, 30, 25, "Hariyama",    24)
	_pkmn("Hariyama",   "Hariyama",   "Fighting", 144,120, 60, 40, 60, 50, null,           0)
	_pkmn("Azurill",    "Azurill",    "Normal",    50, 20, 40, 20, 40, 20, "Marill",      10)
	_pkmn("Nosepass",   "Nosepass",   "Rock",      30, 45,135, 45, 90, 30, null,           0)
	_pkmn("Skitty",     "Skitty",     "Normal",    50, 45, 45, 35, 35, 50, "Delcatty",     0)  // Moon Stone -> Enchant Pokemon verb
	_pkmn("Delcatty",   "Delcatty",   "Normal",    70, 65, 65, 55, 55, 90, null,           0)
	_pkmn("Sableye",    "Sableye",    "Dark",      50, 75, 75, 65, 65, 50, null,           0)
	_pkmn("Mawile",     "Mawile",     "Steel",     50, 85, 85, 55, 55, 50, null,           0)
	_pkmn("Aron",       "Aron",       "Steel",     50, 70,100, 40, 40, 30, "Lairon",      32)
	_pkmn("Lairon",     "Lairon",     "Steel",     60, 90,140, 50, 50, 40, "Aggron",      42)
	_pkmn("Aggron",     "Aggron",     "Steel",     70,110,180, 60, 60, 50, null,           0)
	_pkmn("Meditite",   "Meditite",   "Fighting",  30, 40, 55, 40, 55, 60, "Medicham",    37)
	_pkmn("Medicham",   "Medicham",   "Fighting",  60, 60, 75, 60, 75, 80, null,           0)
	_pkmn("Electrike",  "Electrike",  "Electric",  40, 45, 40, 65, 40, 65, "Manectric",   26)
	_pkmn("Manectric",  "Manectric",  "Electric",  70, 75, 60,105, 60,105, null,           0)
	_pkmn("Plusle",     "Plusle",     "Electric",  60, 50, 40, 85, 75, 95, null,           0)
	_pkmn("Minun",      "Minun",      "Electric",  60, 40, 50, 75, 85, 95, null,           0)
	_pkmn("Volbeat",    "Volbeat",    "Bug",       65, 73, 75, 47, 85, 85, null,           0)
	_pkmn("Illumise",   "illumise",   "Bug",       65, 47, 75, 73, 85, 85, null,           0)
	_pkmn("Roselia",    "Roselia",    "Grass",     50, 60, 45,100, 80, 65, null,           0)
	_pkmn("Gulpin",     "Gulpin",     "Poison",    70, 43, 53, 43, 53, 40, "Swalot",      26)
	_pkmn("Swalot",     "Swalot",     "Poison",   100, 73, 83, 73, 83, 55, null,           0)
	_pkmn("Carvanha",   "Carvanha",   "Water",     45, 90, 20, 65, 20, 65, "Sharpedo",    30)
	_pkmn("Sharpedo",   "Sharpedo",   "Water",     70,120, 40, 95, 40, 95, null,           0)
	_pkmn("Wailmer",    "Wailmer",    "Water",    130, 70, 35, 70, 35, 60, "Wailord",     40)
	_pkmn("Wailord",    "Wailord",    "Water",    170, 90, 45, 90, 45, 60, null,           0)
	_pkmn("Numel",      "Numel",      "Fire",      60, 60, 40, 65, 45, 35, "Camerupt",    33)
	_pkmn("Camerupt",   "Camerupt",   "Fire",      70,100, 70,105, 75, 40, null,           0)
	_pkmn("Torkoal",    "Torkoal",    "Fire",      70, 85,140, 85, 70, 20, null,           0)
	_pkmn("Spoink",     "Spoink",     "Psychic",   60, 25, 35, 70, 80, 60, "Grumpig",     32)
	_pkmn("Grumpig",    "Grumpig",    "Psychic",   80, 45, 65, 90,110, 80, null,           0)
	_pkmn("Spinda",     "Spinda",     "Normal",    60, 60, 60, 60, 60, 60, null,           0)
	_pkmn("Trapinch",   "Trapinch",   "Ground",    45,100, 45, 45, 45, 10, "Vibrava",     35)
	_pkmn("Vibrava",    "Vibrava",    "Ground",    50, 70, 50, 50, 50, 70, "Flygon",      45)
	_pkmn("Flygon",     "Flygon",     "Ground",    80,100, 80, 80, 80,100, null,           0)
	_pkmn("Cacnea",     "Cacnea",     "Grass",     50, 85, 40, 85, 40, 35, "Cacturne",    32)
	_pkmn("Cacturne",   "Cacturne",   "Grass",     70,115, 60,115, 60, 55, null,           0)
	_pkmn("Swablu",     "Swablu",     "Flying",    45, 40, 60, 40, 75, 50, "Altaria",     35)
	_pkmn("Altaria",    "Altaria",    "Dragon",    75, 70, 90, 70,105, 80, null,           0)
	_pkmn("Zangoose",   "Zangoose",   "Normal",    73,115, 60, 60, 60, 90, null,           0)
	_pkmn("Seviper",    "Seviper",    "Poison",    73,100, 60,100, 60, 65, null,           0)
	_pkmn("Lunatone",   "Lunatone",   "Rock",      90, 55, 65, 95, 85, 70, null,           0)
	_pkmn("Solrock",    "Solrock",    "Rock",      90, 95, 85, 55, 65, 70, null,           0)
	_pkmn("Barboach",   "Barboach",   "Water",     50, 48, 43, 46, 41, 60, "Whiscash",    30)
	_pkmn("Whiscash",   "Whiscash",   "Water",    110, 78, 73, 76, 71, 60, null,           0)
	_pkmn("Corphish",   "Corphish",   "Water",     43, 80, 65, 50, 35, 35, "Crawdaunt",   30)
	_pkmn("Crawdaunt",  "Crawdaunt",  "Water",     63,120, 85, 90, 55, 55, null,           0)
	_pkmn("Baltoy",     "Baltoy",     "Ground",    40, 40, 55, 40, 70, 55, "Claydol",     36)
	_pkmn("Claydol",    "Claydol",    "Ground",    60, 70,105, 70,120, 75, null,           0)
	_pkmn("Lileep",     "Lileep",     "Rock",      66, 41, 77, 61, 87, 23, "Cradily",     40)
	_pkmn("Cradily",    "Cradily",    "Rock",      86, 81, 97, 81,107, 43, null,           0)
	_pkmn("Anorith",    "Anorith",    "Rock",      45, 95, 50, 40, 50, 75, "Armaldo",     40)
	_pkmn("Armaldo",    "Armaldo",    "Rock",      75,125,100, 70, 80, 45, null,           0)
	_pkmn("Feebas",     "Feebas",     "Water",     20, 15, 20, 10, 55, 80, "Milotic",     20)
	_pkmn("Milotic",    "Milotic",    "Water",     95, 60, 79,100,125, 81, null,           0)
	_pkmn("Castform",   "Castform",   "Normal",    70, 70, 70, 70, 70, 70, null,           0)
	_pkmn("Kecleon",    "Kecleon",    "Normal",    60, 90, 70, 60,120, 40, null,           0)
	_pkmn("Shuppet",    "Shuppet",    "Ghost",     44, 75, 35, 63, 33, 45, "Banette",     37)
	_pkmn("Banette",    "Banette",    "Ghost",     64,115, 65, 83, 63, 65, null,           0)
	_pkmn("Duskull",    "Duskull",    "Ghost",     20, 40, 90, 30, 90, 25, "Dusclops",    37)
	_pkmn("Dusclops",   "Dusclops",   "Ghost",     40, 70,130, 60,130, 25, null,           0)
	_pkmn("Tropius",    "Tropius",    "Grass",     99, 68, 83, 72, 87, 51, null,           0)
	_pkmn("Chimecho",   "Chimecho",   "Psychic",   65, 50, 70, 95, 80, 65, null,           0)
	_pkmn("Absol",      "Absol",      "Dark",      65,130, 60, 75, 60, 75, null,           0)
	_pkmn("Wynaut",     "Wynaut",     "Psychic",   95, 23, 48, 23, 48, 23, "Wobbuffet",   15)
	_pkmn("Snorunt",    "Snorunt",    "Ice",       50, 50, 50, 50, 50, 50, "Glalie",      42)
	_pkmn("Glalie",     "Glalie",     "Ice",       80, 80, 80, 80, 80, 80, null,           0)
	_pkmn("Spheal",     "Spheal",     "Ice",       70, 40, 50, 55, 50, 25, "Sealeo",      32)
	_pkmn("Sealeo",     "Sealeo",     "Ice",       90, 60, 70, 75, 70, 45, "Walrein",     44)
	_pkmn("Walrein",    "Walrein",    "Ice",      110, 80, 90, 95, 90, 65, null,           0)
	_pkmn("Clamperl",   "Clamperl",   "Water",     35, 64, 85, 74, 55, 32, "Huntail",      0)  // trade item -> Enchant Pokemon verb (Huntail/Gorebyss)
	_pkmn("Huntail",    "Huntail",    "Water",     55,104,105, 94, 75, 52, null,           0)
	_pkmn("Gorebyss",   "Gorebyss",   "Water",     55, 84,105,114, 75, 52, null,           0)
	_pkmn("Relicanth",  "Relicanth",  "Water",    100, 90,130, 45, 65, 55, null,           0)
	_pkmn("Luvdisc",    "Luvdisc",    "Water",     43, 30, 55, 40, 65, 97, null,           0)
	_pkmn("Bagon",      "Bagon",      "Dragon",    45, 75, 60, 40, 30, 50, "Shelgon",     30)
	_pkmn("Shelgon",    "Shelgon",    "Dragon",    65, 95,100, 60, 50, 50, "Salamence",   50)
	_pkmn("Salamence",  "Salamence",  "Dragon",    95,135, 80,110, 80,100, null,           0)
	_pkmn("Beldum",     "Beldum",     "Steel",     40, 55, 80, 35, 60, 30, "Metang",      20)
	_pkmn("Metang",     "Metang",     "Steel",     60, 75,100, 55, 80, 50, "Metagross",   45)
	_pkmn("Metagross",  "Metagross",  "Steel",     80,135,130, 95, 90, 70, null,           0)
	// --- MYTHICAL --- Keldeo lives in its OWN sheet (Keldeo.dmi), not POKEMON.dmi.
	// Water/Fighting (second type via pokemon_second_types); flagged legendary below.
	_pkmn("Keldeo",     "",           "Water",     91, 72, 90,129, 90,108, null, 0, 'Icons/Characters/Special/Keldeo.dmi')
	// Gen-4 Eeveelutions (Leaf Stone / Ice Stone). Appended here — NOT inserted into
	// the Kanto block — so they don't shift the #151/#251 region-position boundaries.
	// Evolution-only (evolve_level 0): reached from Eevee via the Enchant Pokemon verb.
	_pkmn("Leafeon",    "Leafeon",    "Grass",     65,110,130, 60, 65, 95, null,           0)
	_pkmn("Glaceon",    "Glaceon",    "Ice",       65, 60,110,130, 95, 65, null,           0)
	// Flag the Legendaries (single source of truth = pokemon_legendaries).
	for(var/legname in pokemon_legendaries)
		if(pokemon_database[legname])
			var/datum/pokemon_species/ls = pokemon_database[legname]
			ls.legendary = 1
	// Assign second types to the dual-type species (see pokemon_second_types).
	for(var/dtname in pokemon_second_types)
		if(pokemon_database[dtname])
			var/datum/pokemon_species/ds = pokemon_database[dtname]
			ds.PokemonType2 = pokemon_second_types[dtname]
	// Tag each species' region by its dex position (the dex is built in order:
	// Kanto #1-151, Johto #152-251, Hoenn #252-376 (legendaries excluded), then the
	// appended specials (Keldeo, Leafeon, Glaceon) which are re-tagged by name below.
	var/ridx = 0
	for(var/rspn in pokemon_database)
		ridx++
		var/datum/pokemon_species/rs = pokemon_database[rspn]
		if(ridx <= 151)
			rs.region = "Kanto"
		else if(ridx <= 251)
			rs.region = "Johto"
		else
			rs.region = "Hoenn"
	// Fix the appended-after-Hoenn specials the position loop just tagged "Hoenn":
	// Keldeo is a Mythical; Leafeon/Glaceon belong to Eevee's Kanto family.
	if(pokemon_database["Keldeo"])
		pokemon_database["Keldeo"].region = "Mythical"
	for(var/eon in list("Leafeon", "Glaceon"))
		if(pokemon_database[eon])
			var/datum/pokemon_species/es = pokemon_database[eon]
			es.region = "Kanto"

/proc/GetPokemonSpecies(sp)
	if(!pokemon_database.len) BuildPokemonDatabase()
	return pokemon_database[sp]

// TRUE when a and b are a trainer and one of their OWN summoned Pokemon, in either
// order. Used to hard-block every combat interaction between them (damage, move
// effects, targeting/aggro, grabs) regardless of alliance / team-fire settings.
/proc/PokemonOwnerPair(atom/a, atom/b)
	if(!a || !b || a == b) return 0
	if(istype(a, /mob/Player/AI/Pokemon))
		var/mob/Player/AI/Pokemon/pa = a
		if(pa.ai_owner == b) return 1
	if(istype(b, /mob/Player/AI/Pokemon))
		var/mob/Player/AI/Pokemon/pb = b
		if(pb.ai_owner == a) return 1
	return 0

// Stable sprite holder. Its icon_state is fixed to the species and is rendered
// through the mob's vis_contents, so it is immune to the base AI constantly
// rewriting the mob's own icon_state ("", "Meditate", "KO", attack frames) —
// which is why a POKEMON.dmi mob otherwise renders blank.
/obj/pokemon_sprite
	mouse_opacity = 0
	density = 0
	layer = MOB_LAYER
	vis_flags = VIS_INHERIT_DIR

// Multi-tile species (the legendary birds, Onix, Wailord, Ho-Oh, etc.) are drawn
// larger than a single tile: the DMI stores the creature as a grid of
// icon_states, with the base state as the centre tile and directional-suffix
// states (_n/_s/_e/_w plus the four diagonals) as the surrounding tiles. These
// offsets place each surrounding piece exactly one tile (32px) from centre so
// the whole creature reassembles correctly. pixel_y is +up / -down, pixel_x is
// +right / -left.
var/global/list/pokemon_piece_offsets = list(
	"n"  = list(0,   32), "s"  = list(0,  -32), "e"  = list( 32,  0), "w"  = list(-32,  0),
	"ne" = list(32,  32), "nw" = list(-32, 32), "se" = list( 32,-32), "sw" = list(-32,-32))

// Cached list of every icon_state in POKEMON.dmi (built once on first use), so we
// can detect which species have grid pieces without hardcoding a list of them.
var/global/list/pokemon_icon_state_cache = null
/proc/PokemonIconStates()
	if(!pokemon_icon_state_cache)
		pokemon_icon_state_cache = icon_states(POKEMON_ICON)
	return pokemon_icon_state_cache

// --- The Pokemon AI mob ----------------------------------------------------
/mob/Player/AI/Pokemon
	var/PokemonType = null
	var/PokemonType2 = null
	var/pkmn_species = null
	var/obj/pokemon_sprite/body_sprite = null
	var/list/body_pieces = null   // extra vis sprites assembled for multi-tile species
	// If this Pokemon was captured while stronger than its trainer, this holds the
	// Potential it was caught at. Scaling/evolution use max(owner.Potential, this)
	// as the effective level, so the Pokemon keeps its captured strength until the
	// trainer's own Potential catches up — then shared scaling takes over (0 = none).
	var/tmp/caught_potential = 0
	// "Pokemon: Stop" toggle. While set, this Pokemon refuses to acquire ANY target
	// (blocked in SetTarget), so it won't aggro until the trainer toggles Stop off.
	var/tmp/pokemon_hold = 0

	// Tear down any assembled multi-tile pieces. Called before (re-)applying a
	// species so evolutions don't leave the previous form's tiles hanging around.
	proc/ClearBodyPieces()
		if(body_pieces)
			for(var/obj/pokemon_sprite/p in body_pieces)
				vis_contents -= p
			body_pieces = null

	// Configure this Pokemon from a species entry, then evolve it as far as its
	// current Potential allows (so a high-level spawn/summon comes out already
	// evolved).
	proc/ApplyPokemonSpecies(datum/pokemon_species/s)
		if(!s) return
		ApplySpeciesCore(s)
		CheckEvolution()

	// The guts of becoming a species: sprite, type, stats, signature skill.
	// Does NOT check evolution (CheckEvolution drives that so it can chain).
	proc/ApplySpeciesCore(datum/pokemon_species/s)
		if(!s) return
		pkmn_species = s.species
		name = s.species
		PokemonType = s.PokemonType
		PokemonType2 = s.PokemonType2
		if(s.custom_icon)
			// Special-case species with their own full mob sheet (e.g. Keldeo.dmi):
			// use the icon directly on the mob and let the base AI animate it normally
			// (the sheet already has "", Meditate, Attack, KO, Blast states). No vis
			// object / multi-tile assembly needed.
			ClearBodyPieces()
			if(body_sprite)
				vis_contents -= body_sprite
				body_sprite = null
			icon = s.custom_icon
			icon_state = s.icon_state
		else
			// Blank the churning base body; show the Pokemon via the stable vis object.
			icon = null
			if(!body_sprite)
				body_sprite = new
				vis_contents += body_sprite
			body_sprite.icon = POKEMON_ICON
			body_sprite.icon_state = s.icon_state
			// Large, multi-tile species are split across a grid of icon_states; the
			// base state above is the centre tile. Assemble the rest of the creature
			// by adding an offset vis piece for each directional-suffix state that
			// exists for this species. Normal species have no suffixed states, so this
			// loop adds nothing and they render from the single centre sprite as before.
			ClearBodyPieces()
			var/list/all_states = PokemonIconStates()
			for(var/suffix in pokemon_piece_offsets)
				var/pstate = "[s.icon_state]_[suffix]"
				if(pstate in all_states)
					if(!body_pieces) body_pieces = list()
					var/obj/pokemon_sprite/piece = new
					piece.icon = POKEMON_ICON
					piece.icon_state = pstate
					var/list/off = pokemon_piece_offsets[suffix]
					piece.pixel_x = off[1]
					piece.pixel_y = off[2]
					body_pieces += piece
					vis_contents += piece
		alpha = 255
		density = 1
		ApplyPokemonStats(s)
		GrantTypeSkill()
		GrantLegendarySkill()

	// Convert the species' canonical base stats into the game's stat mods, and
	// scale raw power off the owner by the species' base-stat total.
	proc/ApplyPokemonStats(datum/pokemon_species/s)
		var/K = POKEMON_STAT_DIVISOR
		// Legendaries get a flat multiplier on every combat stat (1 = no change).
		var/L = s.legendary ? POKEMON_LEGENDARY_POWER_MULT : 1
		StrMod   = (s.atk / K) * L               // Attack   -> physical offense
		ForMod   = (s.spatk / K) * L             // Sp.Atk   -> ki / special offense
		DefMod   = (s.def / K) * L               // Defense
		EndMod   = (((s.hp + s.spdef) / 2) / K) * L // HP + Sp.Def -> bulk / endurance
		SpdMod   = (s.spe / K) * L               // Speed
		OffMod   = (((s.atk + s.spatk) / 2) / K) * L // general offensive pressure
		RecovMod = 1
		var/bst = s.hp + s.atk + s.def + s.spatk + s.spdef + s.spe
		if(ai_owner)
			// Combat power scales off the trainer's Potential (with the caught-high
			// floor); evolution uses the same effective level directly (see below).
			var/eff = PokemonEffectiveLevel()
			var/pf = POKEMON_POWER_FRACTION * (bst / POKEMON_REFERENCE_BST)
			Potential = max(1, eff * pf)
			potential_power_mult = max(1, ai_owner.potential_power_mult * pf)
		else
			// Wild (no owner): a flat level (spawner may override). The AI power
			// pipeline derives BP from Potential + mods, as monster AI do.
			Potential = max(1, POKEMON_WILD_BASE_POTENTIAL)

	// The level that drives this Pokemon's scaling and evolution. For an owned
	// Pokemon it tracks the TRAINER's Potential directly (so it evolves alongside
	// them) — but never drops below the Potential it was captured at, so a Pokemon
	// caught stronger than its trainer keeps that strength until the trainer's own
	// Potential catches up, at which point shared scaling resumes. Wild Pokemon use
	// their own Potential.
	proc/PokemonEffectiveLevel()
		if(!ai_owner) return Potential
		var/eff = ai_owner.Potential
		if(caught_potential > eff) eff = caught_potential
		return eff

	// Evolve up the chain while the effective (trainer-facing) level is high enough.
	// Chains multiple stages in one pass (e.g. Bulbasaur -> Ivysaur -> Venusaur).
	proc/CheckEvolution(effLevel)
		if(isnull(effLevel)) effLevel = PokemonEffectiveLevel()
		var/datum/pokemon_species/cur = pokemon_database[pkmn_species]
		var/guard = 0
		while(cur && cur.evolves_into && cur.evolve_level && effLevel >= cur.evolve_level && guard++ < 6)
			var/datum/pokemon_species/nxt = pokemon_database[cur.evolves_into]
			if(!nxt) break
			var/oldname = pkmn_species
			ApplySpeciesCore(nxt)
			if(loc)
				OMsg(src, "[oldname] evolved into [nxt.species]!")
			cur = nxt

	// Grant the signature skill for this Pokemon's type (from pokemon_skills.dm).
	proc/GrantTypeSkill()
		// A dual-type Pokemon gets BOTH of its type moves; a single-type Pokemon
		// gets its one move at a discounted cooldown to compensate.
		var/single = !PokemonType2
		GrantOneTypeSkill(PokemonType, single)
		GrantOneTypeSkill(PokemonType2, 0)

	// Grant the signature move for one type. If discount, shorten this instance's
	// cooldown (single-type compensation) — done on the instance so it doesn't
	// affect the same move on a dual-type Pokemon.
	proc/GrantOneTypeSkill(ptype, discount)
		if(!ptype) return
		var/txt = PokemonTypeSkills[ptype]
		if(!txt) return
		var/skpath = text2path(txt)
		if(!skpath) return
		var/obj/Skills/existing = locate(skpath, src)
		if(existing)
			// Already have this move (e.g. from a pre-evolution). Re-fit its cooldown
			// to the current form: full for dual-type, discounted for single-type — so
			// a mono -> dual evolution (Charmeleon -> Charizard) stops being discounted.
			existing.Cooldown = discount ? round(initial(existing.Cooldown) * POKEMON_SINGLE_TYPE_CD_MULT) : initial(existing.Cooldown)
			return
		var/obj/Skills/sk = new skpath
		if(discount)
			sk.Cooldown = round(sk.Cooldown * POKEMON_SINGLE_TYPE_CD_MULT)
		AddSkill(sk)

	// Grant a Legendary's unique signature move (from pokemon_skills.dm), on top of
	// its normal type move. No-op for non-Legendary species.
	proc/GrantLegendarySkill()
		var/datum/pokemon_species/s = pokemon_database[pkmn_species]
		if(!s || !s.legendary) return
		var/txt = PokemonLegendarySkills[pkmn_species]
		if(!txt) return
		var/skpath = text2path(txt)
		if(!skpath) return
		if(!locate(skpath, src))
			var/obj/Skills/leg = new skpath
			leg.pokemon_legendary_move = 1   // drives the screen-shake in Activate()
			AddSkill(leg)

	// Per-life tick: an owned Pokemon tracks its trainer's growth and evolves as
	// its Potential crosses thresholds.
	aiGain()
		..()
		if(ai_owner)
			// Recover Health/Energy at the trainer's pace — while the trainer is
			// meditating, their Pokemon recovers fast right alongside them. We never
			// touch the Pokemon's own icon_state (it shares POKEMON.dmi via the vis
			// object, so a "Meditate" state would glitch it).
			if(ai_owner.icon_state == "Meditate")
				HealHealth(5)
				HealEnergy(12)
			else
				HealHealth(1)
				HealEnergy(2)
		if(ai_owner && pkmn_species)
			var/datum/pokemon_species/cur = pokemon_database[pkmn_species]
			var/eff = PokemonEffectiveLevel()
			if(cur)
				var/bst = cur.hp + cur.atk + cur.def + cur.spatk + cur.spdef + cur.spe
				var/pf = POKEMON_POWER_FRACTION * (bst / POKEMON_REFERENCE_BST)
				Potential = max(1, eff * pf)
				potential_power_mult = max(1, ai_owner.potential_power_mult * pf)
			CheckEvolution(eff)

// --- Trainer command verbs -------------------------------------------------
// Granted to whoever owns a Pokemon (by Spawn_Pokemon here; by the real
// acquisition flow later). They operate on the owner's Pokemon followers,
// mirroring the proven Companion command logic (SetTarget + Chase / Idle).
/mob/proc/GivePokemonCommandVerbs()
	if(/mob/PokemonOwner/verb/Pokemon_Attack_Target in verbs) return
	verbs += typesof(/mob/PokemonOwner/verb)

/mob/PokemonOwner/verb/Pokemon_Attack_Target()
	set category = "Pokemon"
	set name = "Pokemon: Attack Target"
	if(!Target)
		src << "You need a target first (Target something)."
		return
	if(isAI(Target))
		src << "Pokemon can't be ordered onto another AI right now."
		return
	var/count = 0
	for(var/mob/Player/AI/Pokemon/p in ai_followers)
		p.pokemon_hold = 0        // ordering an attack ends "stand down"
		p.SetTarget(Target)
		p.Chase()
		count++
	src << (count ? "Your Pokemon move to attack [Target]!" : "You have no Pokemon out.")

/mob/PokemonOwner/verb/Pokemon_Stop()
	set category = "Pokemon"
	set name = "Pokemon: Stop"
	// Toggle: while "held", a Pokemon won't aggro anything until Stop is pressed again.
	var/newstate = null
	for(var/mob/Player/AI/Pokemon/p in ai_followers)
		p.pokemon_hold = !p.pokemon_hold
		newstate = p.pokemon_hold
		if(p.pokemon_hold)
			p.RemoveTarget()
			p.Idle()
	if(isnull(newstate))
		src << "You have no Pokemon out."
	else
		src << (newstate ? "Your Pokemon stand down — they won't engage until you press Stop again." : "Your Pokemon are ready to fight again.")

/mob/PokemonOwner/verb/Pokemon_Follow()
	set category = "Pokemon"
	set name = "Pokemon: Follow / Stay"
	var/newstate = null
	for(var/mob/Player/AI/Pokemon/p in ai_followers)
		p.ai_follow = !p.ai_follow
		p.RemoveTarget()
		p.Idle()
		newstate = p.ai_follow
	src << "Your Pokemon [newstate ? "follow you" : "hold position"]."

/mob/PokemonOwner/verb/Pokemon_Recall()
	set category = "Pokemon"
	set name = "Pokemon: Recall All"
	var/count = 0
	for(var/mob/Player/AI/Pokemon/p in ai_followers)
		ai_followers -= p
		count++
		del p
	src << (count ? "You recall your Pokemon." : "You have no Pokemon out.")

// --- Admin test-spawn (scaffold harness) -----------------------------------
// Mirrors the essential companion-summon registration so the spawned Pokemon
// actually lives, follows, and fights. Replace/extend with the real acquisition
// flow (capture, party, etc.) later.
/mob/Admin2/verb/Spawn_Pokemon()
	set category = "Admin"
	if(!pokemon_database.len) BuildPokemonDatabase()
	// Build a plain list of names to pick from (input() on an associative list
	// is unreliable and can silently return null).
	var/list/names = list()
	for(var/k in pokemon_database)
		names += k
	if(!names.len)
		usr << "<b>Pokemon database is empty.</b>"
		return
	var/sp = input(usr, "Which Pokemon do you want to spawn?", "Spawn Pokemon") as null|anything in names
	if(!sp) return
	var/datum/pokemon_species/s = pokemon_database[sp]
	if(!s)
		usr << "<b>No data found for [sp].</b>"
		return
	var/mob/Player/AI/Pokemon/a = new
	// Spawn one tile away so it isn't hidden under the summoner.
	var/turf/dest = get_step(usr, usr.dir) || get_turf(usr)
	a.loc = dest
	a.ai_owner = usr
	a.ai_follow = 1
	a.ai_wander = 0
	a.ai_hostility = 1
	a.ai_focus_owner_target = 1
	a.Timeless = 1
	a.ai_alliances = list("[usr.ckey]")
	// ApplyPokemonSpecies now derives all stats/power from the species (using
	// ai_owner, set above, for power scaling).
	a.ApplyPokemonSpecies(s)
	usr.ai_followers += a
	a.aiGain()
	usr.GivePokemonCommandVerbs()
	usr << "<b>Spawned [s.species] ([s.PokemonType]-type) next to you. See the \"Pokemon\" verb tab to command it.</b>"
