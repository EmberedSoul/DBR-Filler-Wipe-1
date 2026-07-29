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

// --- Species template (mirrors the Squad system's ai_sheet) ----------------
// Stores the canonical Pokemon base stats (HP / Attack / Defense / Sp.Atk /
// Sp.Def / Speed) and its evolution (which species it becomes, and at what
// Potential). ApplyPokemonSpecies() converts base stats into the game's mods.
/datum/pokemon_species
	var/species            // display name / database key
	var/icon_state         // state name inside POKEMON.dmi
	var/PokemonType        // one of the PokemonTypeSkills keys
	var/hp
	var/atk
	var/def
	var/spatk
	var/spdef
	var/spe
	var/evolves_into       // species key of the next stage (null = final form)
	var/evolve_level       // Potential at/above which it evolves (0 = never)
	var/legendary = 0      // set from pokemon_legendaries after the dex is built
	New(_species, _state, _type, _hp, _atk, _def, _spatk, _spdef, _spe, _evolves_into, _evolve_level)
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

// Registry the Pokemon AI draws from. Built lazily (see GetPokemonSpecies).
var/global/list/pokemon_database = list()

// Legendary species. Kept separate from the regular dex in the "Make Pokemon
// Spawner" admin UI so legendaries aren't handed out by accident. Extend this as
// the dex grows past Kanto.
var/global/list/pokemon_legendaries = list("Articuno", "Zapdos", "Moltres", "Mewtwo", "Mew")

// species, icon_state, type, the 6 base stats (HP,Atk,Def,SpA,SpD,Spe), then the
// evolution target species and the Potential level it evolves at (or null/0).
/proc/_pkmn(species, state, ptype, hp, atk, def, spatk, spdef, spe, evolves_into, evolve_level)
	pokemon_database[species] = new/datum/pokemon_species(species, state, ptype, hp, atk, def, spatk, spdef, spe, evolves_into, evolve_level)

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
	_pkmn("Pikachu",    "Pikachu",    "Electric",  35, 55, 40, 50, 50, 90, "Raichu",      30)
	_pkmn("Raichu",     "Raichu",     "Electric",  60, 90, 55, 90, 80,110, null,           0)
	_pkmn("Sandshrew",  "Sandshrew",  "Ground",    50, 75, 85, 20, 30, 40, "Sandslash",   22)
	_pkmn("Sandslash",  "Sandslash",  "Ground",    75,100,110, 45, 55, 65, null,           0)
	_pkmn("Nidoran F",  "Nidoran F",  "Poison",    55, 47, 52, 40, 40, 41, "Nidorina",    16)
	_pkmn("Nidorina",   "Nidorina",   "Poison",    70, 62, 67, 55, 55, 56, "Nidoqueen",   30)
	_pkmn("Nidoqueen",  "Nidoqueen",  "Ground",    90, 92, 87, 75, 85, 76, null,           0)
	_pkmn("Nidoran M",  "Nidoran M",  "Poison",    46, 57, 40, 40, 40, 50, "Nidorino",    16)
	_pkmn("Nidorino",   "Nidorino",   "Poison",    61, 72, 57, 55, 55, 65, "Nidoking",    30)
	_pkmn("Nidoking",   "Nidoking",   "Ground",    81,102, 77, 85, 75, 85, null,           0)
	_pkmn("Clefairy",   "Clefairy",   "Fairy",     70, 45, 48, 60, 65, 35, "Clefable",    30)
	_pkmn("Clefable",   "Clefable",   "Fairy",     95, 70, 73, 95, 90, 60, null,           0)
	_pkmn("Vulpix",     "Vulpix",     "Fire",      38, 41, 40, 50, 65, 65, "Ninetales",   30)
	_pkmn("Ninetales",  "Ninetails",  "Fire",      73, 76, 75, 81,100,100, null,           0)
	_pkmn("Jigglypuff", "Jigglypuff", "Fairy",    115, 45, 20, 45, 25, 20, "Wigglytuff",  30)
	_pkmn("Wigglytuff", "Wigglytuff", "Fairy",    140, 70, 45, 85, 50, 45, null,           0)
	_pkmn("Zubat",      "Zubat",      "Poison",    40, 45, 35, 30, 40, 55, "Golbat",      22)
	_pkmn("Golbat",     "Golbat",     "Poison",    75, 80, 70, 65, 75, 90, null,           0)
	_pkmn("Oddish",     "Oddish",     "Grass",     45, 50, 55, 75, 65, 30, "Gloom",       21)
	_pkmn("Gloom",      "Gloom",      "Grass",     60, 65, 70, 85, 75, 40, "Vileplume",   30)
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
	_pkmn("Growlithe",  "Growlithe",  "Fire",      55, 70, 45, 70, 50, 60, "Arcanine",    30)
	_pkmn("Arcanine",   "Arcanine",   "Fire",      90,110, 80,100, 80, 95, null,           0)
	_pkmn("Poliwag",    "Poliwag",    "Water",     40, 50, 40, 40, 40, 90, "Poliwhirl",   25)
	_pkmn("Poliwhirl",  "Poliwhirl",  "Water",     65, 65, 65, 50, 50, 90, "Poliwrath",   35)
	_pkmn("Poliwrath",  "Poliwrath",  "Water",     90, 95, 95, 70, 90, 70, null,           0)
	_pkmn("Abra",       "Abra",       "Psychic",   25, 20, 15,105, 55, 90, "Kadabra",     16)
	_pkmn("Kadabra",    "Kadabra",    "Psychic",   40, 35, 30,120, 70,105, "Alakazam",    36)
	_pkmn("Alakazam",   "Alakazam",   "Psychic",   55, 50, 45,135, 95,120, null,           0)
	_pkmn("Machop",     "Machop",     "Fighting",  70, 80, 50, 35, 35, 35, "Machoke",     28)
	_pkmn("Machoke",    "Machoke",    "Fighting",  80,100, 70, 50, 60, 45, "Machamp",     40)
	_pkmn("Machamp",    "Machamp",    "Fighting",  90,130, 80, 65, 85, 55, null,           0)
	_pkmn("Bellsprout", "Bellsprout", "Grass",     50, 75, 35, 70, 30, 40, "Weepinbell",  21)
	_pkmn("Weepinbell", "Weepinbell", "Grass",     65, 90, 50, 85, 45, 55, "Victreebel",  30)
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
	_pkmn("Shellder",   "Shellder",   "Water",     30, 65,100, 45, 25, 40, "Cloyster",    30)
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
	_pkmn("Exeggcute",  "Exeggcute",  "Grass",     60, 40, 80, 60, 45, 40, "Exeggutor",   30)
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
	_pkmn("Staryu",     "Staryu",     "Water",     30, 45, 55, 70, 55, 85, "Starmie",     30)
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
	_pkmn("Eevee",      "Eevee",      "Normal",    55, 55, 50, 45, 65, 55, "Vaporeon",    25)
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
	// Flag the Legendaries (single source of truth = pokemon_legendaries).
	for(var/legname in pokemon_legendaries)
		if(pokemon_database[legname])
			var/datum/pokemon_species/ls = pokemon_database[legname]
			ls.legendary = 1

/proc/GetPokemonSpecies(sp)
	if(!pokemon_database.len) BuildPokemonDatabase()
	return pokemon_database[sp]

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
	var/pkmn_species = null
	var/obj/pokemon_sprite/body_sprite = null
	var/list/body_pieces = null   // extra vis sprites assembled for multi-tile species

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
			var/pf = POKEMON_POWER_FRACTION * (bst / POKEMON_REFERENCE_BST)
			Potential = max(1, ai_owner.Potential * pf)
			potential_power_mult = max(1, ai_owner.potential_power_mult * pf)
		else
			// Wild (no owner): a flat level (spawner may override). The AI power
			// pipeline derives BP from Potential + mods, as monster AI do.
			Potential = max(1, POKEMON_WILD_BASE_POTENTIAL)

	// Evolve up the chain while this Pokemon's Potential is high enough. Chains
	// multiple stages in one pass (e.g. Bulbasaur -> Ivysaur -> Venusaur).
	proc/CheckEvolution()
		var/datum/pokemon_species/cur = pokemon_database[pkmn_species]
		var/guard = 0
		while(cur && cur.evolves_into && cur.evolve_level && Potential >= cur.evolve_level && guard++ < 6)
			var/datum/pokemon_species/nxt = pokemon_database[cur.evolves_into]
			if(!nxt) break
			var/oldname = pkmn_species
			ApplySpeciesCore(nxt)
			if(loc)
				OMsg(src, "[oldname] evolved into [nxt.species]!")
			cur = nxt

	// Grant the signature skill for this Pokemon's type (from pokemon_skills.dm).
	proc/GrantTypeSkill()
		if(!PokemonType) return
		var/txt = PokemonTypeSkills[PokemonType]
		if(!txt) return
		var/skpath = text2path(txt)
		if(!skpath) return
		if(!locate(skpath, src))
			AddSkill(new skpath)

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
			AddSkill(new skpath)

	// Per-life tick: an owned Pokemon tracks its trainer's growth and evolves as
	// its Potential crosses thresholds.
	aiGain()
		..()
		if(ai_owner && pkmn_species)
			var/datum/pokemon_species/cur = pokemon_database[pkmn_species]
			if(cur)
				var/bst = cur.hp + cur.atk + cur.def + cur.spatk + cur.spdef + cur.spe
				var/pf = POKEMON_POWER_FRACTION * (bst / POKEMON_REFERENCE_BST)
				Potential = max(1, ai_owner.Potential * pf)
				potential_power_mult = max(1, ai_owner.potential_power_mult * pf)
			CheckEvolution()

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
		p.SetTarget(Target)
		p.Chase()
		count++
	src << (count ? "Your Pokemon move to attack [Target]!" : "You have no Pokemon out.")

/mob/PokemonOwner/verb/Pokemon_Stop()
	set category = "Pokemon"
	set name = "Pokemon: Stop"
	for(var/mob/Player/AI/Pokemon/p in ai_followers)
		p.RemoveTarget()
		p.Idle()
	src << "Your Pokemon stand down."

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
