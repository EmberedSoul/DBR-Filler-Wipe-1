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

// Per-species Potential a Pokemon was captured at (species -> Potential). Only set
// when a Pokemon is caught while stronger than its trainer; on summon it becomes the
// Pokemon's caught_potential floor so it keeps that strength until the trainer's own
// Potential catches up. Saved with the character so re-summons remember it.
mob/var/list/pokemon_caught_potential = list()

// Custom text color for this trainer's Pokemon Say/Emote output (null = default).
mob/var/pokemon_text_color = null

// Species that have fainted this session. A fainted Pokemon can't be sent out
// again until the trainer meditates (which clears this list in Meditation()).
// tmp, so relogging also lets them recover.
mob/var/tmp/list/fainted_pokemon = list()

// --- Admin: place a wild Pokemon spawner -----------------------------------
// Level 3+ admins (cumulative, so level-4 admins have it) get this in the Admin
// tab. Sits next to the base "MakeAISpawner" but builds a Pokemon spawner.
/mob/Admin3/verb/Make_Pokemon_Spawner()
	set name = "Make Pokemon Spawner"
	set category = "Admin"
	if(!pokemon_database.len) BuildPokemonDatabase()
	// Partition the dex: Legendaries and starters are kept OUT of the normal pools
	// and offered on their own. "normal" = the regular catchable wild filler.
	var/list/normal_names = list()
	var/list/legendary_names = list()
	var/list/starter_names = list()
	for(var/k in pokemon_database)
		if(k in pokemon_legendaries)
			legendary_names += k
		else if(k in pokemon_starters)
			starter_names += k
		else
			normal_names += k
	var/list/wild_species = list()
	var/spawn_desc = "any species"
	var/mode = input(src, "Which species should this spot spawn?", "Pokemon Spawner") in list("Any (Non-Legendary, no starters)", "By Region", "By Type", "Legendary", "Starters", "Pick specific")
	switch(mode)
		if("Any (Non-Legendary, no starters)")
			wild_species = normal_names.Copy()
			spawn_desc = "any Non-Legendary (no starters)"
		if("By Region")
			var/region = input(src, "Which region should this spot draw from?", "Region") as null|anything in list("Kanto", "Johto", "Hoenn", "Sinnoh")
			if(region)
				for(var/k in normal_names)
					var/datum/pokemon_species/sp = pokemon_database[k]
					if(sp && sp.region == region)
						wild_species += k
				spawn_desc = "any [region] (no Legendaries/starters)"
		if("By Type")
			var/list/types = list()
			for(var/t in PokemonTypeSkills)
				types += t
			var/ptype = input(src, "Which type should this spot spawn?", "Type") as null|anything in types
			if(ptype)
				for(var/k in normal_names)
					var/datum/pokemon_species/sp = pokemon_database[k]
					if(sp && (sp.PokemonType == ptype || sp.PokemonType2 == ptype))
						wild_species += k
				spawn_desc = "any [ptype]-type (no Legendaries/starters)"
		if("Legendary")
			var/pick = input(src, "Which Legendary? (or Any)", "Legendary") as null|anything in (list("Any Legendary") + legendary_names)
			if(pick == "Any Legendary")
				wild_species = legendary_names.Copy()
				spawn_desc = "any Legendary"
			else if(pick)
				wild_species += pick
				spawn_desc = pick
		if("Starters")
			var/pick = input(src, "Which Starter? (or Any)", "Starter") as null|anything in (list("Any Starter") + starter_names)
			if(pick == "Any Starter")
				wild_species = starter_names.Copy()
				spawn_desc = "any Starter"
			else if(pick)
				wild_species += pick
				spawn_desc = pick
		if("Pick specific")
			// Browse a narrowed list (by region/type/pool) and add species one at a time.
			while(TRUE)
				var/pool = input(src, "Browse which list? (Done to finish) — Chosen: [wild_species.len ? jointext(wild_species, ", ") : "none"]", "Pick Species") in list("Kanto", "Johto", "Hoenn", "Sinnoh", "By Type", "Legendary", "Starters", "Done")
				if(pool == "Done") break
				var/list/src_list = list()
				switch(pool)
					if("Kanto", "Johto", "Hoenn", "Sinnoh")
						for(var/k in normal_names)
							var/datum/pokemon_species/sp = pokemon_database[k]
							if(sp && sp.region == pool) src_list += k
					if("By Type")
						var/list/types = list()
						for(var/t in PokemonTypeSkills)
							types += t
						var/ptype = input(src, "Which type?", "Type") as null|anything in types
						if(!ptype) continue
						for(var/k in normal_names)
							var/datum/pokemon_species/sp = pokemon_database[k]
							if(sp && (sp.PokemonType == ptype || sp.PokemonType2 == ptype)) src_list += k
					if("Legendary")
						src_list = legendary_names
					if("Starters")
						src_list = starter_names
				var/chosen = input(src, "Add a species (Cancel = back).", "Add Species") as null|anything in (src_list + "Back")
				if(!chosen || chosen == "Back") continue
				wild_species |= chosen
			spawn_desc = wild_species.len ? jointext(wild_species, ", ") : "any species"
	// Never leave the pool empty (which would spawn everything) — fall back to the
	// normal non-legendary, non-starter pool.
	if(!wild_species.len)
		wild_species = normal_names.Copy()
		spawn_desc = "any Non-Legendary (no starters)"
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
	Log("Admin", "[ExtractInfo(src)] created a Pokemon spawner ([spawn_desc]).")
	src << "<b>Created a Pokemon spawner at your location.</b> Spawns: [spawn_desc] | level [max(0,level)] | limit [max(1,limit)] | range [max(1,range)] | respawn [max(1,timer)]."

// --- Admin: wipe every Pokemon spawner off the map -------------------------
// Level 4 admins only. Removes all Pokemon spawners and despawns the wild Pokemon
// they produced. Never touches trainer-owned/summoned Pokemon (those carry ai_owner).
/mob/Admin4/verb/Delete_All_Pokemon_Spawners()
	set name = "Delete All Pokemon Spawners"
	set category = "Admin"
	if(alert(src, "Delete EVERY Pokemon spawner on the map (and the wild Pokemon they spawned)?", "Delete All Pokemon Spawners", "No", "Yes") != "Yes")
		return
	// Snapshot first so we're not deleting out of the list we're iterating.
	var/list/spots = list()
	for(var/obj/AI_Spot/Pokemon/spot in world)
		spots += spot
	var/count = 0
	var/mons = 0
	for(var/obj/AI_Spot/Pokemon/spot in spots)
		for(var/mob/Player/AI/Pokemon/p in spot.ai_active)
			if(!p.ai_owner)   // only wild spawns, never a trainer's Pokemon
				mons++
				del p
		count++
		del spot
	Log("Admin", "[ExtractInfo(src)] deleted all Pokemon spawners ([count] spot(s), [mons] wild Pokemon).")
	src << "<b>Cleared [count] Pokemon spawner\s and [mons] wild Pokemon from the map.</b>"

// --- Wild Pokemon spawner --------------------------------------------------
// Inherits the AI_Spot timer/limit/tracker machinery; only the actual spawn is
// overridden to produce a Pokemon AI instead of a monster_info monster.
/obj/AI_Spot/Pokemon
	name = "Pokemon Spawner"
	var/list/wild_species = list() // names to spawn; empty = any regular species (no Legendaries/starters)
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
			// Empty pool = fall back to any regular species, but never Legendaries or
			// starters (those are only placed via an explicit spawner choice).
			for(var/k in pokemon_database)
				if((k in pokemon_legendaries) || (k in pokemon_starters)) continue
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
		// Manabit loot, so killing a wild Pokemon rewards Mana Bits like other AI.
		// The kill-reward path (BattleSystem.dm) collects any minerals held by the
		// dead AI; captured Pokemon are del'd instead, so only KILLING one drops it.
		// Same scaling monster spawners use (see _AISpot.dm), plus a Legendary bonus.
		var/obj/Items/mineral/loot = new()
		var/potExtra = p.Potential < 11 ? 0 : rand(35, 50) * round(p.Potential / 10, 1)
		loot.value = rand(8, 21) + p.Potential + potExtra
		loot.value *= 1 + (powerModifier / 2)
		loot.value *= mineralModifier
		if(s.legendary)
			loot.value *= 120          // Legendaries are worth far more
		loot.value = round(loot.value)
		loot.name = "[Commas(loot.value)] Mana Bits"
		p.contents += loot
		ai_active.Add(p)

	// Example placeable zone (uses the sample species). Add more zones as the dex grows.
	Kanto_Route
		wild_species = list("Pidgey","Rattata","Caterpie","Weedle","Ekans","Spearow","Nidoran M","Nidoran F")
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
		// Requires the Trainer's Pledge (a T1 signature choice) to throw a Pokeball.
		if(!usr.passive_handler || !usr.passive_handler.Get("Trainers Pledge"))
			usr << "Your finger rest over the Pokeballs button, but your lack of resolve to be a trainer holds you back from throwing it..."
			return
		if(!istype(wild)) return
		// Legendary Pokemon can only be captured by a Primordial Tamer (a T2 signature
		// that itself requires the Trainer's Pledge).
		if((wild.pkmn_species in pokemon_legendaries) && (!usr.passive_handler || !usr.passive_handler.Get("Primordial Tamer")))
			usr << "This is a Legendary Pokemon. Without the resolve of a Primordial Tamer, your Pokeball holds no power over a being of myth..."
			return
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
		// If the wild was stronger than the trainer, remember the Potential it was
		// caught at so it keeps that strength until the trainer's own Potential catches
		// up (PokemonEffectiveLevel). Keep the highest if they already own this species.
		if(wild.Potential > usr.Potential)
			var/prev = usr.pokemon_caught_potential[caught]
			if(!prev || wild.Potential > prev)
				usr.pokemon_caught_potential[caught] = wild.Potential
		usr.GivePokemonCommandVerbs() // grants the Pokemon command tab (Summon/Recall/...)
		// Deoxys grants its Forme-shifting verb in the Pokemon tab.
		if(caught == "Deoxys" && !locate(/obj/Skills/Utility/Deoxys_Form, usr))
			usr.AddSkill(new/obj/Skills/Utility/Deoxys_Form)
			usr << "<b>Deoxys' unstable DNA answers to you — \"Deoxys: Choose Form\" has been added to your Pokemon tab.</b>"
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
	a.ko_death = 0             // on KO, our Unconscious() recalls it — it never "dies"
	a.ai_alliances = list("[src.ckey]")
	// Restore any caught-high floor so it scales/evolves off max(owner, caught).
	if(pokemon_caught_potential && (s.species in pokemon_caught_potential))
		a.caught_potential = pokemon_caught_potential[s.species]
	a.ApplyPokemonSpecies(s) // ai_owner set -> scales to the trainer
	a.HealHealth(99999)       // a re-summoned Pokemon always comes out fully healed
	a.HealEnergy(99999)
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
	// A fainted Pokemon can't be sent out again until you meditate.
	var/list/available = owned_pokemon - fainted_pokemon
	if(!available.len)
		src << "All of your Pokemon have fainted. Meditate to let them recover before sending one out."
		return
	var/sp = input(src, "Which Pokemon do you want to send out?", "Summon Pokemon") as null|anything in available
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

// --- Deoxys: Choose Form ---------------------------------------------------
// Granted to the trainer when they capture Deoxys (see Capture_Pokemon). Shifts a
// summoned Deoxys between its four Formes (stats + colour tint; Deoxys has no separate
// form sprites in the sheet).
/obj/Skills/Utility/Deoxys_Form
	name = "Deoxys: Choose Form"
	desc = "Shift your summoned Deoxys between its Normal, Attack, Defense and Speed Formes."
	verb/Deoxys_Choose_Form()
		set category = "Pokemon"
		set name = "Deoxys: Choose Form"
		var/mob/Player/AI/Pokemon/deo = null
		for(var/mob/Player/AI/Pokemon/p in usr.ai_followers)
			if(p.pkmn_species == "Deoxys" && p.ai_owner == usr)
				deo = p
				break
		if(!deo)
			usr << "You need Deoxys summoned to change its Forme."
			return
		var/form = input(usr, "Which Forme should Deoxys take?", "Deoxys Forme") as null|anything in list("Normal", "Attack", "Defense", "Speed")
		if(!form) return
		deo.ApplyDeoxysForm(form)
		OMsg(usr, "[usr]'s Deoxys reshapes into its [form] Forme!")

// --- Pokemon Enchantment: stone/item evolutions ----------------------------
// Granted by learning the "Pokemon Enchantment" enchanting knowledge (see
// UnlockTech in knowledgeUnlock.dm). Spends 99 Mana Capacity to evolve the
// trainer's summoned Pokemon into one of its stone/item/trade evolutions that the
// level-based system can't reach (pokemon_stone_evolutions).
/obj/Skills/Utility/Enchant_Pokemon
	name = "Enchant Pokemon"
	desc = "Spend 99 Mana Capacity to evolve your summoned Pokemon into a form that would normally need a stone or item (e.g. Eevee's evolutions)."
	verb/Enchant_Pokemon()
		set category = "Utility"
		set name = "Enchant Pokemon"
		// Operate on the trainer's currently-summoned Pokemon.
		var/mob/Player/AI/Pokemon/a = null
		for(var/mob/Player/AI/Pokemon/p in usr.ai_followers)
			if(p.ai_owner == usr)
				a = p
				break
		if(!a)
			usr << "You need one of your own Pokemon out to enchant. Summon one first!"
			return
		var/list/options = pokemon_stone_evolutions[a.pkmn_species]
		if(!options || !options.len)
			usr << "[a.name] has no enchantment-driven evolution."
			return
		var/choice = input(usr, "Evolve [a.name] into which form? (costs 99 Mana Capacity)", "Enchant Pokemon") as null|anything in options
		if(!choice) return
		if(!usr.HasManaCapacity(99))
			usr << "You don't have enough stored Mana Capacity to enchant [a.name]. (Requires 99.)"
			return
		if(!pokemon_database.len) BuildPokemonDatabase()
		var/datum/pokemon_species/ns = pokemon_database[choice]
		if(!ns)
			usr << "No data found for [choice]."
			return
		usr.TakeManaCapacity(99)
		var/oldname = a.pkmn_species
		a.ApplySpeciesCore(ns)   // sprite, stats and type moves all update to the new form
		// Persist it in the party so a recall/re-summon keeps the evolved form.
		var/idx = usr.owned_pokemon.Find(oldname)
		if(idx)
			usr.owned_pokemon[idx] = choice
		OMsg(usr, "[usr] channels enchantment magic — [oldname] evolves into [choice]!")

// --- Pokemon Emote ---------------------------------------------------------
// Let a trainer roleplay their summoned Pokemon. Any "quoted speech" the trainer
// types is swapped for the Pokemon's name + "!", since Pokemon only ever say
// their own name (a Pikachu emoting `perks up, "hi there!"` broadcasts as
// `*Pikachu perks up, "Pikachu!"*`).

// Replace every "quoted" span in T with "[name]!". Unbalanced trailing quotes
// are left untouched. Done by hand (no regex) for a couple of short scans.
/proc/PokemonSpeak(T, name)
	var/out = ""
	var/pos = 1
	while(TRUE)
		var/open = findtext(T, "\"", pos)
		if(!open)
			out += copytext(T, pos)          // no more quotes: keep the rest
			break
		var/close = findtext(T, "\"", open + 1)
		if(!close)
			out += copytext(T, pos)          // dangling quote: leave as typed
			break
		out += copytext(T, pos, open)        // text before the opening quote
		out += "\"[name]!\""                 // the Pokemon "says" its own name
		pos = close + 1
	return out

/mob/PokemonOwner/verb/Pokemon_Emote()
	set category = "Pokemon"
	set name = "Pokemon: Emote"
	// Emote is performed by the trainer's currently-summoned Pokemon.
	var/mob/Player/AI/Pokemon/a = null
	for(var/mob/Player/AI/Pokemon/p in usr.ai_followers)
		if(p.ai_owner == usr)
			a = p
			break
	if(!a)
		usr << "You don't have a Pokemon out to emote. Summon one first!"
		return
	var/T = input(usr, "What does [a.name] do? (Anything in \"quotes\" becomes [a.name]!)", "Pokemon Emote") as message|null
	if(isnull(T)) return
	T = html_decode(T)
	if(!length(T)) return
	T = PokemonSpeak(T, a.name)
	// Bubble over the Pokemon while it acts, then broadcast the emote to everyone
	// who can hear the Pokemon or its trainer (same reach as the game's emotes).
	var/image/em = new('Emoting.dmi')
	em.appearance_flags = 66
	em.layer = EFFECTS_LAYER
	a.overlays += em
	var/emcolor = usr.pokemon_text_color ? usr.pokemon_text_color : "yellow"
	for(var/mob/Players/E in (hearers(15, a) | hearers(15, usr)))
		E << output("<font color=[emcolor]>*[a.name] [T]*</font>", "output")
		E << output("<font color=[emcolor]>*[a.name] [T]*</font>", "icchat")
	spawn(15)
		a.overlays -= em

// The trainer's Pokemon "speaks" — but whatever the trainer types comes out as
// just the Pokemon's name + "!". Routes through AISay so it uses the game's full
// speech pipeline (hearers, observers, wiretaps, chat logs).
/mob/PokemonOwner/verb/Pokemon_Say(msg as text)
	set category = "Pokemon"
	set name = "Pokemon: Say"
	var/mob/Player/AI/Pokemon/a = null
	for(var/mob/Player/AI/Pokemon/p in usr.ai_followers)
		if(p.ai_owner == usr)
			a = p
			break
	if(!a)
		usr << "You don't have a Pokemon out to speak. Summon one first!"
		return
	if(!msg) return
	// AISay renders in the speaker's Text_Color; apply the trainer's chosen color
	// (if any) so it matches their emotes. Read live so recoloring takes effect at once.
	if(usr.pokemon_text_color)
		a.Text_Color = usr.pokemon_text_color
	a.AISay("[a.name]!")

// Let a trainer pick the text color their Pokemon's Say and Emote use. Stored on
// the trainer (persists across relogs); applied to both verbs above.
/mob/PokemonOwner/verb/Pokemon_Text_Color()
	set category = "Pokemon"
	set name = "Pokemon: Text Color"
	var/newcolor = input(usr, "Pick the text color for your Pokemon's Say and Emote. (Cancel to reset to default.)", "Pokemon Text Color") as color|null
	usr.pokemon_text_color = newcolor
	if(newcolor)
		usr << "<font color=[newcolor]>Your Pokemon will now speak and emote in this color.</font>"
	else
		usr << "Your Pokemon's text color has been reset to the default."

// --- Fainting: a downed owned Pokemon is recalled and faint-locked ----------
// A KO'd owned Pokemon is NOT linked to its trainer's fate (they no longer share
// KOs). Instead it returns to the trainer and can't be sent out again until the
// trainer meditates (see fainted_pokemon / Meditation()). The trainer may still
// summon their other Pokemon in the meantime.
// (Only ALLY Pokemon carry an ai_owner; wild Pokemon are unaffected — they lie
// KO'd on the field so they can be captured.)
/mob/Player/AI/Pokemon/Unconscious(mob/P, text)
	..()
	if(src.KO && ai_owner)
		var/mob/owner = ai_owner
		var/downed = src.pkmn_species
		if(!(downed in owner.fainted_pokemon))
			owner.fainted_pokemon += downed
		owner << "<b>[downed] fainted!</b> It returns to you, and can't be sent out again until you meditate."
		owner.ai_followers -= src
		ai_owner = null            // sever the link before the mob is cleaned up
		spawn(2)
			if(src) del src
