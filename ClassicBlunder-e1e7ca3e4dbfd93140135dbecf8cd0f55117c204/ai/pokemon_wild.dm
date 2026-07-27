// ==========================================================================
// WILD POKEMON, POKEBALLS & OWNERSHIP
// --------------------------------------------------------------------------
//  - AI_Spot/Pokemon: a monster spawner (like the game's other AI_Spots) that
//    spawns hostile WILD Pokemon which behave like normal AI.
//  - Pokeball: a tech item locked behind the Smelting knowledge. Used on a
//    knocked-out wild Pokemon, it captures it into the trainer's ownership list.
//  - Ownership: a trainer may hold up to 6 Pokemon and have 1 summoned at a time.
// ==========================================================================

#define MAX_OWNED_POKEMON 6

// Species names (keys into pokemon_database) this trainer has captured.
mob/var/list/owned_pokemon = list()

// --- Admin: place a wild Pokemon spawner -----------------------------------
// Level 3+ admins (cumulative, so level-4 admins have it) get this in the Admin
// tab. Sits next to the base "MakeAISpawner" but builds a Pokemon spawner.
/mob/Admin3/verb/Make_Pokemon_Spawner()
	set name = "Make Pokemon Spawner"
	set category = "Admin"
	if(!pokemon_database.len) BuildPokemonDatabase()
	var/list/all_names = list()
	for(var/k in pokemon_database)
		all_names += k
	var/list/wild_species = list()
	var/mode = input(src, "Which species should this spot spawn?", "Pokemon Spawner") in list("Any species", "Pick specific")
	if(mode == "Pick specific")
		while(TRUE)
			var/chosen = input(src, "Add a species (Cancel to finish). Chosen so far: [wild_species.len ? jointext(wild_species, ", ") : "none"]", "Add Species") as null|anything in (all_names + "Cancel")
			if(!chosen || chosen == "Cancel") break
			wild_species |= chosen
	var/limit = input(src, "How many can be active at once?", "Spawn Limit") as num|null
	var/range = input(src, "How far can they spawn from this spot? (tiles)", "Spawn Range") as num|null
	var/timer = input(src, "Respawn timer? (whole numbers, ~30s each)", "Respawn Timer") as num|null
	var/level = input(src, "Level? (Potential of spawns; higher = tougher and can spawn evolved forms)", "Spawn Level") as num|null
	var/obj/AI_Spot/Pokemon/spot = new()
	spot.wild_species = wild_species
	spot.ai_limit = max(1, limit)
	spot.spawn_range = max(1, range)
	spot.countdown_limit = max(1, timer)
	spot.wild_level = max(0, level)
	spot.loc = src.loc
	spot.generate_ai()
	Log("Admin", "[ExtractInfo(src)] created a Pokemon spawner ([wild_species.len ? jointext(wild_species, ", ") : "any"]).")
	src << "<b>Created a Pokemon spawner at your location.</b> Spawns: [wild_species.len ? jointext(wild_species, ", ") : "any species"] | level [max(0,level)] | limit [max(1,limit)] | range [max(1,range)] | respawn [max(1,timer)]."

// --- Wild Pokemon spawner --------------------------------------------------
// Inherits the AI_Spot timer/limit/tracker machinery; only the actual spawn is
// overridden to produce a Pokemon AI instead of a monster_info monster.
/obj/AI_Spot/Pokemon
	name = "Pokemon Spawner"
	var/list/wild_species = list() // names to spawn; empty = any species in the database
	var/wild_level = 0             // Potential level of spawns (0 = the default). Higher = tougher and more evolved.

	generate_ai()
		if(ai_active.len >= ai_limit) return
		// Find a free turf within spawn_range (same approach as the base spawner).
		var/turf/t
		var/tries = 0
		while((!t || t.density) && tries < 25)
			tries++
			var/neg = -spawn_range
			t = locate(x + rand(neg, spawn_range), y + rand(neg, spawn_range), z)
			sleep(1)
		if(!t || t.density) return

		if(!pokemon_database.len) BuildPokemonDatabase()
		var/list/pool = list()
		if(wild_species.len)
			pool = wild_species
		else
			for(var/k in pokemon_database)
				pool += k
		if(!pool.len) return
		var/datum/pokemon_species/s = pokemon_database[pick(pool)]
		if(!s) return

		var/mob/Player/AI/Pokemon/p = new
		p.loc = t
		p.senpai = src               // Del() auto-removes it from ai_active
		p.ApplyPokemonSpecies(s)     // no ai_owner -> wild power scaling
		if(wild_level > 0)
			p.Potential = wild_level
			p.CheckEvolution()       // higher-level areas can spawn evolved forms
		p.ai_state = "Idle"
		p.ai_wander = 1
		p.ai_hostility = 1
		p.prioritize_players = 1
		p.WoundIntent = 1
		p.ko_death = 0               // stay KO'd when defeated so they can be caught
		p.ai_alliances = list("AI Friends")
		ai_active.Add(p)

	// Example placeable zone (uses the sample species). Add more zones as the dex grows.
	Kanto_Route
		wild_species = list("Bulbasaur","Charmander","Squirtle","Pidgey","Rattata","Caterpie","Ekans","Machop")
		ai_limit = 3
		spawn_range = 6

// --- Pokeball (tech item, gated behind Smelting) ---------------------------
// TechType "Forge" lists it under Access Technology -> Forging; SubType
// "Smelting" hides it unless the player has learned the Smelting knowledge
// (Smelting requires Forge, so a Smelting-knower sees the Forging section).
// Consumed on a successful capture.
/obj/Items/Tech/Pokeball
	name = "Pokeball"
	desc = "A capture device. Use it on a knocked-out wild Pokemon to catch it (consumed on use). A trainer can hold up to 6."
	TechType = "Forge"
	SubType = "Smelting"
	Cost = 5
	Savable = 1
	icon = 'Icons/Technology/Gear/Pokeballs.dmi'
	icon_state = "Pokeball" 

	verb/Capture_Pokemon(mob/Player/AI/Pokemon/wild in oview(3, usr))
		set src in usr
		set name = "Capture Pokemon"
		set category = "Skills"
		if(!istype(wild)) return
		if(wild.ai_owner)
			usr << "That Pokemon already belongs to a trainer."
			return
		if(!wild.KO)
			usr << "You can only capture a Pokemon that has been knocked out."
			return
		if(usr.owned_pokemon.len >= MAX_OWNED_POKEMON)
			usr << "You can't carry more than [MAX_OWNED_POKEMON] Pokemon. Release one first."
			return
		var/caught = wild.pkmn_species
		usr.owned_pokemon += caught
		usr.GivePokemonCommandVerbs() // grants the Pokemon command tab (Summon/Recall/...)
		usr << "<b>Gotcha! [caught] was caught! ([usr.owned_pokemon.len]/[MAX_OWNED_POKEMON])</b>"
		OMsg(usr, "[usr] captures a wild [caught]!")
		del wild  // its Del() unregisters it from the spawner
		del src   // consume the Pokeball

// --- Summoning owned Pokemon (max 1 out at a time) -------------------------
// Shared spawn helper for an owned Pokemon summoned as an ally.
mob/proc/SpawnPokemonAlly(datum/pokemon_species/s)
	if(!s) return
	var/mob/Player/AI/Pokemon/a = new
	a.loc = get_step(src, src.dir) || get_turf(src)
	a.ai_owner = src
	a.ai_follow = 1
	a.ai_wander = 0
	a.ai_hostility = 1
	a.ai_focus_owner_target = 1
	a.Timeless = 1
	a.ai_alliances = list("[src.ckey]")
	a.ApplyPokemonSpecies(s) // ai_owner set -> scales to the trainer
	ai_followers += a
	a.aiGain()
	src << "<b>Go, [s.species]!</b>"

// Extra trainer verbs (granted alongside the command tab via GivePokemonCommandVerbs).
/mob/PokemonOwner/verb/Summon_Owned_Pokemon()
	set category = "Pokemon"
	set name = "Pokemon: Summon"
	if(!owned_pokemon.len)
		src << "You don't own any Pokemon yet — catch one first!"
		return
	for(var/mob/Player/AI/Pokemon/p in ai_followers)
		src << "You can only have one Pokemon out at a time. Recall it first."
		return
	var/sp = input(src, "Which Pokemon do you want to send out?", "Summon Pokemon") as null|anything in owned_pokemon
	if(!sp) return
	if(!pokemon_database.len) BuildPokemonDatabase()
	var/datum/pokemon_species/s = pokemon_database[sp]
	if(!s)
		src << "No data found for [sp]."
		return
	SpawnPokemonAlly(s)

/mob/PokemonOwner/verb/Release_Owned_Pokemon()
	set category = "Pokemon"
	set name = "Pokemon: Release (from party)"
	if(!owned_pokemon.len)
		src << "You don't own any Pokemon."
		return
	var/sp = input(src, "Permanently release which Pokemon from your party?", "Release Pokemon") as null|anything in owned_pokemon
	if(!sp) return
	owned_pokemon -= sp
	src << "You released [sp]. ([owned_pokemon.len]/[MAX_OWNED_POKEMON])"

// --- Linked fainting: an ally Pokemon and its trainer share their fate ------
// If a summoned Pokemon is KO'd, its trainer goes down with it, and vice versa.
// These override the shared Unconscious() proc; the base guards re-entry with
// `if(src.KO) return`, and we re-check KO after ..() (which accounts for any
// get-up/revive logic), so this can never loop.
// (Only ALLY Pokemon carry an ai_owner, so wild Pokemon are unaffected.)

// Pokemon faints -> its trainer faints, spirit crushed.
/mob/Player/AI/Pokemon/Unconscious(mob/P, text)
	..()
	if(src.KO && ai_owner && !ai_owner.KO)
		ai_owner.Unconscious(null, "their Pokemon falling, crushing their spirit")

// Trainer faints -> their summoned Pokemon faints too.
/mob/Players/Unconscious(mob/P, text)
	..()
	if(src.KO)
		for(var/mob/Player/AI/Pokemon/pk in ai_followers)
			if(pk.ai_owner == src && !pk.KO)
				pk.Unconscious(null, "their trainer falling")
