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

// --- Species template (mirrors the Squad system's ai_sheet) ----------------
// Stores the canonical Pokemon base stats (HP / Attack / Defense / Sp.Atk /
// Sp.Def / Speed); ApplyPokemonSpecies() converts them into the game's mods.
/datum/pokemon_species
	var/species            // display name
	var/icon_state         // state name inside POKEMON.dmi
	var/PokemonType        // one of the PokemonTypeSkills keys
	var/hp
	var/atk
	var/def
	var/spatk
	var/spdef
	var/spe
	New(_species, _state, _type, _hp, _atk, _def, _spatk, _spdef, _spe)
		species = _species
		icon_state = _state
		PokemonType = _type
		hp = _hp
		atk = _atk
		def = _def
		spatk = _spatk
		spdef = _spdef
		spe = _spe

// Registry the Pokemon AI draws from. Built lazily (see GetPokemonSpecies).
var/global/list/pokemon_database = list()

// species, icon_state, type, then the 6 base stats: HP, Atk, Def, SpA, SpD, Spe.
/proc/_pkmn(species, state, ptype, hp, atk, def, spatk, spdef, spe)
	pokemon_database[species] = new/datum/pokemon_species(species, state, ptype, hp, atk, def, spatk, spdef, spe)

/proc/BuildPokemonDatabase()
	pokemon_database = list()
	// --- VALIDATION SAMPLE: one species per type. Full dex to follow. ---
	//     species       state         type         HP  Atk Def SpA SpD Spe
	_pkmn("Bulbasaur",  "Bulbasaur",  "Grass",     45, 49, 49, 65, 65, 45)
	_pkmn("Charmander", "Charmander", "Fire",      39, 52, 43, 60, 50, 65)
	_pkmn("Squirtle",   "Squirtle",   "Water",     44, 48, 65, 50, 64, 43)
	_pkmn("Pikachu",    "Pikachu",    "Electric",  35, 55, 40, 50, 50, 90)
	_pkmn("Caterpie",   "Caterpie",   "Bug",       45, 30, 35, 20, 20, 45)
	_pkmn("Pidgey",     "Pidgey",     "Flying",    40, 45, 40, 35, 35, 56)
	_pkmn("Sandshrew",  "Sandshrew",  "Ground",    50, 75, 85, 20, 30, 40)
	_pkmn("Geodude",    "Geodude",    "Rock",      40, 80,100, 30, 30, 20)
	_pkmn("Machop",     "Machop",     "Fighting",  70, 80, 50, 35, 35, 35)
	_pkmn("Gastly",     "Gastly",     "Ghost",     30, 35, 30,100, 35, 80)
	_pkmn("Abra",       "Abra",       "Psychic",   25, 20, 15,105, 55, 90)
	_pkmn("Ekans",      "Ekans",      "Poison",    35, 60, 44, 40, 54, 55)
	_pkmn("Dratini",    "Dratini",    "Dragon",    41, 64, 45, 50, 50, 50)
	_pkmn("Rattata",    "Rattata",    "Normal",    30, 56, 35, 25, 35, 72)
	_pkmn("Steelix",    "Steelix",    "Steel",     75, 85,200, 55, 65, 30)
	_pkmn("Murkrow",    "Murkrow",    "Dark",      60, 85, 42, 85, 42, 91)
	_pkmn("Clefairy",   "Clefairy",   "Fairy",     70, 45, 48, 60, 65, 35)
	_pkmn("Articuno",   "Articuno",   "Ice",       90, 85,100, 95,125, 85)

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

// --- The Pokemon AI mob ----------------------------------------------------
/mob/Player/AI/Pokemon
	var/PokemonType = null
	var/pkmn_species = null
	var/obj/pokemon_sprite/body_sprite = null

	// Configure this Pokemon from a species entry.
	proc/ApplyPokemonSpecies(datum/pokemon_species/s)
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
		alpha = 255
		density = 1
		ApplyPokemonStats(s)
		GrantTypeSkill()

	// Convert the species' canonical base stats into the game's stat mods, and
	// scale raw power off the owner by the species' base-stat total.
	proc/ApplyPokemonStats(datum/pokemon_species/s)
		var/K = POKEMON_STAT_DIVISOR
		StrMod   = s.atk / K                    // Attack   -> physical offense
		ForMod   = s.spatk / K                  // Sp.Atk   -> ki / special offense
		DefMod   = s.def / K                    // Defense
		EndMod   = ((s.hp + s.spdef) / 2) / K   // HP + Sp.Def -> bulk / endurance
		SpdMod   = s.spe / K                     // Speed
		OffMod   = ((s.atk + s.spatk) / 2) / K  // general offensive pressure
		RecovMod = 1
		var/bst = s.hp + s.atk + s.def + s.spatk + s.spdef + s.spe
		if(ai_owner)
			var/pf = POKEMON_POWER_FRACTION * (bst / POKEMON_REFERENCE_BST)
			Potential = max(1, ai_owner.Potential * pf)
			potential_power_mult = max(1, ai_owner.potential_power_mult * pf)
		else
			// No owner (e.g. future wild spawns): absolute fallback from BST.
			Potential = max(1, bst / 10)
			potential_power_mult = max(1, bst * 10)

	// Grant the signature skill for this Pokemon's type (from pokemon_skills.dm).
	proc/GrantTypeSkill()
		if(!PokemonType) return
		var/txt = PokemonTypeSkills[PokemonType]
		if(!txt) return
		var/skpath = text2path(txt)
		if(!skpath) return
		if(!locate(skpath, src))
			AddSkill(new skpath)

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
