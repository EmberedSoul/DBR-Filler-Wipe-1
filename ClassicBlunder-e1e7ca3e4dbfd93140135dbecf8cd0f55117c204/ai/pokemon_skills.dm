// ==========================================================================
// POKEMON COMPANION SKILLS
// --------------------------------------------------------------------------
// A `PokemonType` var for Companions plus one signature skill per type. The
// upcoming Pokemon AI can read a companion's PokemonType and grant it the
// matching skill from PokemonTypeSkills[] below.
//
// Effects use the game's declarative element/status skill vars where possible
// (Scorching=fire, Chilling=ice/water, Shattering=steel/rock, Shocking/
// Paralyzing=electric, Poisoning/Toxic=poison, Crippling, Launcher, Stunner).
// Stat debuffs (Fairy Wind off/def, Rock Smash endurance, Double Kick "ignores
// half endurance") are applied as on-hit debuff buffs via BuffAffected, since
// there is no direct "ignore/lower a target stat" skill var. Numbers are
// tunable placeholders.
// ==========================================================================

// New Companion var — set per companion; drives the Pokemon AI's kit.
/obj/Skills/Companion/var/PokemonType = null

// Set on a Legendary's granted signature move (see GrantLegendarySkill). Activate()
// reads it to add a slight screen shake when a Legendary unleashes its unique move.
/obj/Skills/var/pokemon_legendary_move = 0

// Custom on-activate flourish for a Legendary's signature move. Called from Activate()
// (so it fires for AI use, not just the player verb). Override per-skill; user is the
// Pokemon unleashing the move.
/obj/Skills/proc/OnLegendaryActivate(mob/user)
	return

// Type -> signature skill path. Values are text paths so the AI can text2path
// + `new` them when building a companion's kit.
var/global/list/PokemonTypeSkills = list(
	"Dark"     = "/obj/Skills/Projectile/Magic/DarkMagic/Shadow_Ball", // reuses the existing Shadow Ball
	"Fairy"    = "/obj/Skills/AutoHit/Fairy_Wind",
	"Fire"     = "/obj/Skills/AutoHit/Flame_Wheel",
	"Water"    = "/obj/Skills/AutoHit/Surf",
	"Steel"    = "/obj/Skills/Projectile/Flash_Cannon",
	"Dragon"   = "/obj/Skills/AutoHit/Meteor_Strike/Draco_Meteor",
	"Electric" = "/obj/Skills/Queue/Thunder_Shock",
	"Normal"   = "/obj/Skills/Queue/Quick_Attack",
	"Ghost"    = "/obj/Skills/AutoHit/Pkmn_Hex",
	"Psychic"  = "/obj/Skills/Projectile/Beams/Psybeam",
	"Poison"   = "/obj/Skills/Projectile/Sludge_Bomb",
	"Rock"     = "/obj/Skills/AutoHit/Rock_Smash",
	"Fighting" = "/obj/Skills/Queue/Double_Kick",
	// The 5 types Pokemon need that the base 13 lacked.
	"Grass"    = "/obj/Skills/Projectile/Razor_Leaf",
	"Bug"      = "/obj/Skills/Projectile/Pin_Missile",
	"Flying"   = "/obj/Skills/AutoHit/Aerial_Ace",
	"Ground"   = "/obj/Skills/AutoHit/Pkmn_Earthquake",
	"Ice"      = "/obj/Skills/Projectile/Beams/Ice_Beam")

// Legendary -> its exclusive, powerful signature move (granted on top of the
// type move by GrantLegendarySkill in pokemon_ai.dm). Only species flagged in
// pokemon_legendaries use this.
var/global/list/PokemonLegendarySkills = list(
	"Mewtwo"   = "/obj/Skills/AutoHit/Psystrike",
	"Mew"      = "/obj/Skills/AutoHit/Psychic_Overload",
	"Moltres"  = "/obj/Skills/AutoHit/Sky_Attack",
	"Zapdos"   = "/obj/Skills/AutoHit/Zap_Cannon",
	"Articuno" = "/obj/Skills/AutoHit/Sheer_Cold",
	// Johto legendaries
	"Raikou"   = "/obj/Skills/AutoHit/Thunderclap",
	"Entei"    = "/obj/Skills/AutoHit/Sacred_Fire",
	"Suicune"  = "/obj/Skills/AutoHit/Tidal_Crash",
	"Lugia"    = "/obj/Skills/AutoHit/Aeroblast",
	"Ho-Oh"    = "/obj/Skills/AutoHit/Rainbow_Inferno",
	"Celebi"   = "/obj/Skills/AutoHit/Sacred_Grove",
	// Hoenn legendaries
	"Regirock"  = "/obj/Skills/AutoHit/Stone_Edge",
	"Regice"    = "/obj/Skills/AutoHit/Ice_Age",
	"Registeel" = "/obj/Skills/AutoHit/Metal_Breaker",
	"Groudon"   = "/obj/Skills/AutoHit/Precipice_Blades",
	"Kyogre"    = "/obj/Skills/Projectile/Origin_Pulse",
	"Rayquaza"  = "/obj/Skills/AutoHit/Dragon_Ascent",
	"Deoxys"    = "/obj/Skills/AutoHit/Psycho_Boost",
	// Sinnoh legendaries
	"Regigigas" = "/obj/Skills/AutoHit/Crush_Grip",
	"Dialga"    = "/obj/Skills/AutoHit/Roar_Of_Time",
	"Palkia"    = "/obj/Skills/AutoHit/Spacial_Rend",
	"Giratina"  = "/obj/Skills/AutoHit/Shadow_Force",
	"Heatran"   = "/obj/Skills/AutoHit/Magma_Storm",
	"Darkrai"   = "/obj/Skills/AutoHit/Dark_Void",
	"Cresselia" = "/obj/Skills/AutoHit/Lunar_Blessing",
	"Arceus"    = "/obj/Skills/AutoHit/Divine_Judgment",
	// Mythical
	"Keldeo"   = "/obj/Skills/AutoHit/Secret_Sword")

// --- On-hit debuff buffs (applied to the target via BuffAffected) ----------
// Modeled on existing autonomous debuffs like "Shredded" (EndMult/DefMult<1).
/obj/Skills/Buffs/SlotlessBuffs/Autonomous/PkmnDebuff
	IconLock = 'Stun.dmi'
	IconApart = 1

	Fairy_Wind
		OffMult = 0.8
		DefMult = 0.8
		ActiveMessage = "is buffeted by a fairy wind, their strikes and guard weakened!"
		OffMessage = "shakes off the fairy wind."

	Rock_Smash
		EndMult = 0.8
		ActiveMessage = "is battered by the rock smash, their endurance cracked!"
		OffMessage = "recovers their footing."

	Double_Kick
		// Approximates "ignores half endurance" by halving the target's Endurance
		// for the hit window (no true per-hit endurance-ignore var exists).
		EndMult = 0.5
		ActiveMessage = "reels from the double kick, their guard split open!"
		OffMessage = "steadies themselves."

// --- Fairy: Fairy Wind (autohit, debuffs offense + defense) ----------------
/obj/Skills/AutoHit/Fairy_Wind
	name = "Fairy Wind"
	Area = "Wave"
	Distance = 10
	DamageMult = 3
	ForOffense = 1
	BuffAffected = "/obj/Skills/Buffs/SlotlessBuffs/Autonomous/PkmnDebuff/Fairy_Wind"
	// A swirling pink gust: a spinning wind spark and a rose-pink shockwave.
	HitSparkIcon = 'Hit Effect Wind.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.5
	HitSparkTurns = 1
	ShockIcon = 'KenShockwavePink.dmi'
	Shockwave = 2
	Shockwaves = 1
	PostShockwave = 1
	Cooldown = 40
	ActiveMessage = "uses Fairy Wind!"
	verb/Fairy_Wind()
		set category = "Skills"
		usr.Activate(src)

// --- Fire: Flame Wheel (fire autohit, multiple rounds) ---------------------
/obj/Skills/AutoHit/Flame_Wheel
	name = "Flame Wheel"
	Area = "Strike"
	Distance = 10
	DamageMult = 3.5
	Rounds = 3
	Scorching = 8
	StrOffense = 1
	// A spinning wheel of fire — a whirling hellfire slash on each rotation.
	HitSparkIcon = 'Slash - Hellfire.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.75
	HitSparkTurns = 1
	Cooldown = 45
	ActiveMessage = "uses Flame Wheel!"
	verb/Flame_Wheel()
		set category = "Skills"
		usr.Activate(src)

// --- Water: Surf (aoe water wave, Chilling) --------------------------------
/obj/Skills/AutoHit/Surf
	name = "Surf"
	Area = "Wave"
	Distance = 12
	DamageMult = 4
	Chilling = 8
	ForOffense = 1
	// A crashing wave: bursts of spray on impact and a rolling shockwave.
	HitSparkIcon = 'IceBurst.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 3
	Shockwaves = 1
	PostShockwave = 1
	Cooldown = 50
	ActiveMessage = "uses Surf!"
	verb/Surf()
		set category = "Skills"
		usr.Activate(src)

// --- Steel: Flash Cannon (earth projectile, shattering) --------------------
/obj/Skills/Projectile/Flash_Cannon
	name = "Flash Cannon"
	Distance = 100
	DamageMult = 4
	Blasts = 1
	Shattering = 8
	ForRate = 1
	Charge = 1
	IconLock = 'Blast - Charged.dmi' // charged metallic slug
	IconSize = 1
	Trail = 'LightImpulseTrail.dmi'  // streak of steel-bright light
	ManaCost = 12
	Cooldown = 40
	ActiveMessage = "uses Flash Cannon!"
	verb/Flash_Cannon()
		set category = "Skills"
		usr.UseProjectile(src)

// --- Dragon: Draco Meteor (meteor AoE, big damage) -------------------------
// Subclass of Meteor Strike: inherits the dive/AoE impact, hits much harder.
/obj/Skills/AutoHit/Meteor_Strike/Draco_Meteor
	name = "Draco Meteor"
	DamageMult = 35
	Launcher = 2
	// A blazing dragon-meteor impact.
	HitSparkIcon = 'fevExplosion - Hellfire.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 120
	ActiveMessage = "uses Draco Meteor!"
	verb/Draco_Meteor()
		set category = "Skills"
		// Draconic energy erupts skyward before the meteor falls.
		KenShockwave(usr, icon = 'KenShockwavePurple.dmi', Size = 4, Blend = 2, Time = 12)
		MeteorStrike(usr, src)

// --- Electric: Thunder Shock (thunder-like queue hitting in succession) ----
/obj/Skills/Queue/Thunder_Shock
	name = "Thunder Shock"
	Duration = 5
	DamageMult = 2
	AccuracyMult = 1.1
	Combo = 3            // strikes in quick succession
	Rapid = 1
	Shocking = 6
	Paralyzing = 6
	// Queue skills fire lightning via SpecialEffect, not Bolt (Bolt is an AutoHit-only
	// var). "Thunder" with range 2 = LightningStrike2, the same bolt Thunder/Thundaga use.
	SpecialEffect = "Thunder"
	SpecialEffectRange = 2
	HitSparkIcon = 'Hit Effect.dmi'
	HitSparkX = -32
	HitSparkY = -32
	Cooldown = 40
	ActiveMessage = "uses Thunder Shock!"
	verb/Thunder_Shock()
		set category = "Skills"
		usr.SetQueue(src)

// --- Normal: Quick Attack (small combo, based on Meteor Combination) --------
/obj/Skills/Queue/Quick_Attack
	name = "Quick Attack"
	Duration = 6
	DamageMult = 2
	AccuracyMult = 1.2
	Combo = 6            // small, fast combo
	Rapid = 1
	// A quick blur of a strike.
	HitSparkIcon = 'Slash.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1
	HitSparkTurns = 1
	Cooldown = 15
	ActiveMessage = "uses Quick Attack!"
	verb/Quick_Attack()
		set category = "Skills"
		usr.SetQueue(src)

// --- Ghost: Hex (autohit, poisons and cripples) ----------------------------
// Named Pkmn_Hex to avoid colliding with the Witch's existing /obj/Skills/AutoHit/Hex.
/obj/Skills/AutoHit/Pkmn_Hex
	name = "Hex"
	Area = "Strike"
	Distance = 10
	DamageMult = 5
	Poisoning = 6
	Crippling = 25
	ForOffense = 1
	// A wicked, spectral cut wrapped in violet malice.
	HitSparkIcon = 'Slash - Black.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.75
	ShockIcon = 'KenShockwavePurple.dmi'
	Shockwave = 2
	Shockwaves = 1
	PostShockwave = 1
	Cooldown = 40
	ActiveMessage = "uses Hex!"
	verb/Hex()
		set category = "Skills"
		// A ring of violet dread flares around the caster.
		KenShockwave(usr, icon = 'SparkleViolet.dmi', Size = 2, Blend = 2, Time = 12)
		usr.Activate(src)

// --- Psychic: Psybeam (powerful homing beam) -------------------------------
/obj/Skills/Projectile/Beams/Psybeam
	name = "Psybeam"
	DamageMult = 10
	ChargeRate = 2
	Dodgeable = 0
	Homing = 1
	Distance = 100
	ForRate = 2
	IconLock = 'BeamKHH.dmi' // placeholder beam art
	EnergyCost = 8
	Cooldown = 60
	ActiveMessage = "uses Psybeam!"
	verb/Psybeam()
		set category = "Skills"
		usr.UseProjectile(src)

// --- Poison: Sludge Bomb (explosive projectile, poisons + cripples) --------
/obj/Skills/Projectile/Sludge_Bomb
	name = "Sludge Bomb"
	Distance = 80
	DamageMult = 6
	Blasts = 1
	Explode = 3
	Poisoning = 30
	Toxic = 25
	Crippling = 25
	ForRate = 1
	Charge = 1
	IconLock = 'DarkChargesGreen.dmi' // roiling toxic-green payload
	IconSize = 1
	Trail = 'venomoustrail.dmi'       // dripping venom trail
	ManaCost = 15
	Cooldown = 50
	ActiveMessage = "uses Sludge Bomb!"
	verb/Sludge_Bomb()
		set category = "Skills"
		usr.UseProjectile(src)

// --- Rock: Rock Smash (heavy hit, launches, debuffs endurance, shatters) ---
/obj/Skills/AutoHit/Rock_Smash
	name = "Rock Smash"
	Area = "Strike"
	Distance = 8
	DamageMult = 6
	Launcher = 2
	Shattering = 16
	StrOffense = 1
	BuffAffected = "/obj/Skills/Buffs/SlotlessBuffs/Autonomous/PkmnDebuff/Rock_Smash"
	// A crushing blow: a heavy shockwave and a spray of shattered stone.
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 4
	Shockwaves = 1
	PostShockwave = 1
	HitSparkIcon = 'Hit Effect Wind.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	Cooldown = 60
	ActiveMessage = "uses Rock Smash!"
	verb/Rock_Smash()
		set category = "Skills"
		usr.Activate(src)

// --- Fighting: Double Kick (2-part combo, high damage, "ignores .5 end") ----
/obj/Skills/Queue/Double_Kick
	name = "Double Kick"
	Duration = 5
	DamageMult = 5
	AccuracyMult = 1.1
	Combo = 2            // two-part combo
	BuffAffected = "/obj/Skills/Buffs/SlotlessBuffs/Autonomous/PkmnDebuff/Double_Kick" // halves target End (approx ignore .5)
	// Two solid impacts land in quick succession.
	HitSparkIcon = 'Hit Effect.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.25
	Cooldown = 30
	ActiveMessage = "uses Double Kick!"
	verb/Double_Kick()
		set category = "Skills"
		usr.SetQueue(src)

// ==========================================================================
// THE 5 EXTRA TYPES (Grass / Bug / Flying / Ground / Ice)
// The game has no dedicated grass/bug/flying/ground element vars, so these use
// the closest declarative effects (Crippling for vines, Poisoning for stingers,
// Shattering for quakes, Freezing/Chilling for ice) plus fitting behavior.
// ==========================================================================

// --- Grass: Razor Leaf (homing volley of blades, entangles) ----------------
/obj/Skills/Projectile/Razor_Leaf
	name = "Razor Leaf"
	Distance = 60
	DamageMult = 3
	Blasts = 3
	StrRate = 1
	ForRate = 0
	Homing = 1
	Crippling = 20
	Charge = 1
	IconLock = 'Air Render.dmi' // whirling, slicing leaves
	IconSize = 1
	Trail = 'HeinreikeWindScarTrail.dmi' // a cutting wind-scar in its wake
	EnergyCost = 6
	Cooldown = 40
	ActiveMessage = "uses Razor Leaf!"
	verb/Razor_Leaf()
		set category = "Skills"
		usr.UseProjectile(src)

// --- Bug: Pin Missile (rapid multi-hit stingers, poisons) ------------------
/obj/Skills/Projectile/Pin_Missile
	name = "Pin Missile"
	Distance = 60
	DamageMult = 2
	Blasts = 5
	StrRate = 1
	ForRate = 0
	Homing = 1
	Poisoning = 5
	Charge = 1
	IconLock = 'CrossbowBolt.dmi' // volley of sharp stinger needles
	IconSize = 0.7
	Trail = 'shadowneedletrail.dmi'
	EnergyCost = 6
	Cooldown = 40
	ActiveMessage = "uses Pin Missile!"
	verb/Pin_Missile()
		set category = "Skills"
		usr.UseProjectile(src)

// --- Flying: Aerial Ace (fast dash-in strike that launches) ----------------
/obj/Skills/AutoHit/Aerial_Ace
	name = "Aerial Ace"
	Area = "Strike"
	Distance = 12
	DamageMult = 4
	Launcher = 2
	Rush = 15
	StrOffense = 1
	// A blink-fast slicing pass.
	HitSparkIcon = 'Slash - Zan.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.5
	HitSparkTurns = 1
	Cooldown = 30
	ActiveMessage = "uses Aerial Ace!"
	verb/Aerial_Ace()
		set category = "Skills"
		usr.Activate(src)

// --- Ground: Earthquake (AoE around self, shatters + cripples) -------------
// Typed Pkmn_Earthquake to avoid colliding with the existing atom/proc/Earthquake.
/obj/Skills/AutoHit/Pkmn_Earthquake
	name = "Earthquake"
	Area = "Circle"
	Distance = 1
	DamageMult = 8
	Shattering = 8
	Crippling = 20
	Launcher = 1
	StrOffense = 1
	// The ground ruptures: rolling shockwaves and flying debris in every direction.
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 5
	Shockwaves = 3
	PostShockwave = 1
	HitSparkIcon = 'Hit Effect Wind.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	Cooldown = 60
	ActiveMessage = "uses Earthquake!"
	verb/Pkmn_Earthquake()
		set category = "Skills"
		set name = "Earthquake"
		usr.Activate(src)

// --- Ice: Ice Beam (freezing beam) -----------------------------------------
/obj/Skills/Projectile/Beams/Ice_Beam
	name = "Ice Beam"
	DamageMult = 6
	ChargeRate = 2
	Dodgeable = 0
	Freezing = 30
	Chilling = 25
	Distance = 40
	ForRate = 1.5
	IconLock = 'Ice Beam.dmi' // a proper freezing beam
	EnergyCost = 8
	Cooldown = 50
	ActiveMessage = "uses Ice Beam!"
	verb/Ice_Beam()
		set category = "Skills"
		usr.UseProjectile(src)

// ==========================================================================
// LEGENDARY SIGNATURE MOVES
// Exclusive, powerful moves granted to the Legendaries on top of their normal
// type move (see GrantLegendarySkill in pokemon_ai.dm). Tuned well above the
// type moves so a Legendary fights like a boss.
// ==========================================================================

// --- Mewtwo: Psystrike — a lance of pure psychic force that tears through guard.
/obj/Skills/AutoHit/Psystrike
	name = "Psystrike"
	Area = "Strike"
	Distance = 14
	DamageMult = 18
	ForOffense = 1
	Crushing = 60          // punches through defense/guard
	Launcher = 2
	Stunner = 3
	Icon = 'PsychoFlame.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Slash - Future.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 70
	ActiveMessage = "unleashes Psystrike, a lance of raw psychic force!"
	verb/Psystrike()
		set category = "Skills"
		KenShockwave(usr, icon = 'KenShockwavePurple.dmi', Size = 4, Blend = 2, Time = 12)
		usr.Activate(src)

// --- Mew: Psychic Overload — a wide psychic detonation around the ancestor.
/obj/Skills/AutoHit/Psychic_Overload
	name = "Psychic Overload"
	Area = "Circle"
	Distance = 4
	DamageMult = 13
	ForOffense = 1
	Stunner = 3
	Launcher = 1
	Shattering = 6
	Icon = 'PsychoFlame.dmi'
	IconX = -32
	IconY = -32
	IconTime = 10
	HitSparkIcon = 'Slash - Future.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	ShockIcon = 'KenShockwavePurple.dmi'
	Shockwave = 4
	Shockwaves = 2
	PostShockwave = 1
	Cooldown = 80
	ActiveMessage = "detonates a Psychic Overload, warping the space around them!"
	verb/Psychic_Overload()
		set category = "Skills"
		KenShockwave(usr, icon = 'SparkleViolet.dmi', Size = 4, Blend = 2, Time = 15)
		usr.Activate(src)

// --- Moltres: Sky Attack — a blazing dive-bomb that erupts around the impact.
// A proper AutoHit (routed through Activate) so it works for the AI and fires the
// legendary screen-shake / OnLegendaryActivate FX — unlike the old Meteor Strike
// subclass, whose MeteorStrike() needs a client and bypasses those hooks.
/obj/Skills/AutoHit/Sky_Attack
	name = "Sky Attack"
	Area = "Around Target"
	Distance = 14
	DistanceAround = 4
	DamageMult = 20
	ForOffense = 1
	Scorching = 25
	Launcher = 2
	Stunner = 2
	Icon = 'Icons/Effects/Fire VFX9.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Icons/Effects/Fire VFX5.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 100
	ActiveMessage = "rockets skyward and plummets down in a blazing Sky Attack!"
	verb/Sky_Attack()
		set category = "Skills"
		usr.Activate(src)
		src.OnLegendaryActivate(usr)   // players (shake flag off) still get the flourish
	OnLegendaryActivate(mob/user)
		// A twin blaze-burst, then flames erupt and linger across the scorched ground.
		KenShockwave(user, icon = 'Icons/Effects/SparkleOrange.dmi', Size = 5, Blend = 2, Time = 12)
		KenShockwave(user, icon = 'Icons/Effects/SparkleGold.dmi', Size = 4, Blend = 2, Time = 14)
		var/list/turf/near = list()
		for(var/turf/t in orange(2, user))
			near += t
		for(var/n in 1 to min(4, near.len))
			var/turf/t = pick(near)
			near -= t
			var/obj/f = new /obj(t)
			f.icon = 'Icons/Effects/Fire VFX3.dmi'
			f.layer = MOB_LAYER + 1
			f.mouse_opacity = 0
			f.density = 0
			spawn(20)
				if(f) del f

// --- Zapdos: Zap Cannon — a screaming cannon of raw voltage.
/obj/Skills/AutoHit/Zap_Cannon
	name = "Zap Cannon"
	Area = "Strike"
	Distance = 14
	DamageMult = 16
	ForOffense = 1
	Bolt = 2               // LightningStrike2 — the same bolt Thunder/Thundaga use
	Paralyzing = 12
	Shocking = 12
	Stunner = 4
	Launcher = 1
	HitSparkIcon = 'Hit Effect.dmi'
	HitSparkX = -32
	HitSparkY = -32
	Cooldown = 90
	ActiveMessage = "fires a Zap Cannon, a screaming bolt of pure voltage!"
	verb/Zap_Cannon()
		set category = "Skills"
		usr.Activate(src)
		src.OnLegendaryActivate(usr)   // players (shake flag off) still get the flourish
	OnLegendaryActivate(mob/user)
		// A double burst of voltage, then crackling arcs dance across the nearby ground.
		KenShockwave(user, icon = 'Icons/Effects/SparkleYellow.dmi', Size = 5, Blend = 2, Time = 12)
		KenShockwave(user, icon = 'Icons/Effects/SparkleYellow.dmi', Size = 3, Blend = 2, Time = 16)
		var/list/turf/near = list()
		for(var/turf/t in orange(3, user))
			near += t
		for(var/n in 1 to min(4, near.len))
			var/turf/t = pick(near)
			near -= t
			var/obj/e = new /obj(t)
			e.icon = 'Icons/Effects/Rising Electricity.dmi'
			e.layer = MOB_LAYER + 1
			e.mouse_opacity = 0
			e.density = 0
			spawn(15)
				if(e) del e

// --- Articuno: Sheer Cold — a blast of absolute zero that freezes solid.
/obj/Skills/AutoHit/Sheer_Cold
	name = "Sheer Cold"
	Area = "Wave"
	Distance = 12
	DamageMult = 15
	ForOffense = 1
	Freezing = 18
	Chilling = 12
	Shattering = 8
	Launcher = 1
	HitSparkIcon = 'IceBurst.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 4
	Shockwaves = 1
	PostShockwave = 1
	Cooldown = 100
	ActiveMessage = "exhales Sheer Cold, a gale of absolute zero!"
	verb/Sheer_Cold()
		set category = "Skills"
		usr.Activate(src)
		src.OnLegendaryActivate(usr)   // players (shake flag off) still get the flourish
	OnLegendaryActivate(mob/user)
		// A frozen shockwave, then hoarfrost creeps across the surrounding ground and
		// lingers longer than most FX — a battlefield flash-frozen solid.
		KenShockwave(user, icon = 'Icons/Effects/SparkleBlue.dmi', Size = 5, Blend = 2, Time = 12)
		KenShockwave(user, icon = 'Icons/Effects/SnowRing.dmi', Size = 4, Blend = 2, Time = 16)
		var/list/turf/near = list()
		for(var/turf/t in orange(2, user))
			near += t
		for(var/n in 1 to min(5, near.len))
			var/turf/t = pick(near)
			near -= t
			var/obj/ice = new /obj(t)
			ice.icon = 'Icons/Effects/SnowRing.dmi'
			ice.layer = TURF_LAYER + 1
			ice.mouse_opacity = 0
			ice.density = 0
			spawn(40)
				if(ice) del ice

// ==========================================================================
// JOHTO LEGENDARY SIGNATURE MOVES  (Raikou/Entei/Suicune/Lugia/Ho-Oh/Celebi)
// ==========================================================================

// --- Raikou: Thunderclap — a deafening crash of raw lightning.
/obj/Skills/AutoHit/Thunderclap
	name = "Thunderclap"
	Area = "Strike"
	Distance = 14
	DamageMult = 16
	ForOffense = 1
	Bolt = 2               // LightningStrike2 — the same bolt Thunder/Thundaga use
	Paralyzing = 12
	Shocking = 12
	Stunner = 4
	Launcher = 1
	HitSparkIcon = 'Hit Effect.dmi'
	HitSparkX = -32
	HitSparkY = -32
	Cooldown = 90
	ActiveMessage = "looses a Thunderclap, a deafening crash of raw lightning!"
	verb/Thunderclap()
		set category = "Skills"
		usr.Activate(src)

// --- Entei: Sacred Fire — a holy flame that scorches to the bone.
/obj/Skills/AutoHit/Sacred_Fire
	name = "Sacred Fire"
	Area = "Strike"
	Distance = 12
	DamageMult = 18
	ForOffense = 1
	Scorching = 16
	HolyMod = 2
	Stunner = 3
	Launcher = 1
	Icon = 'Icons/Effects/Fire VFX6.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Icons/Effects/Fire VFX5.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 90
	ActiveMessage = "breathes Sacred Fire, a holy flame that scorches to the bone!"
	verb/Sacred_Fire()
		set category = "Skills"
		usr.Activate(src)

// --- Suicune: Tidal Crash — a crushing wall of frigid water.
/obj/Skills/AutoHit/Tidal_Crash
	name = "Tidal Crash"
	Area = "Wave"
	Distance = 12
	DamageMult = 15
	ForOffense = 1
	Chilling = 12
	Freezing = 8
	Launcher = 2
	HitSparkIcon = 'IceBurst.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 4
	Shockwaves = 2
	PostShockwave = 1
	Cooldown = 90
	ActiveMessage = "calls down a Tidal Crash, a crushing wall of frigid water!"
	verb/Tidal_Crash()
		set category = "Skills"
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// Leaves a curtain of rain hanging over the battlefield for a few seconds.
		var/image/rainimg = image(icon = 'rain.dmi', layer = MOB_LAYER + 3)
		var/list/turf/wet = list()
		for(var/turf/t in range(3, user))
			wet += t
			t.overlays += rainimg
		spawn(50)
			for(var/turf/t in wet)
				t.overlays -= rainimg

// --- Lugia: Aeroblast — a screaming lance of compressed wind.
/obj/Skills/AutoHit/Aeroblast
	name = "Aeroblast"
	Area = "Strike"
	Distance = 16
	DamageMult = 18
	ForOffense = 1
	Crushing = 50
	Launcher = 2
	Stunner = 3
	Icon = 'Air Render.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Slash - Zan.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 90
	ActiveMessage = "fires an Aeroblast, a screaming lance of compressed wind!"
	verb/Aeroblast()
		set category = "Skills"
		KenShockwave(usr, icon = 'KenShockwave.dmi', Size = 4, Blend = 2, Time = 12)
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// Leaves a few enlarged whirlpools spinning in Lugia's wake for a moment.
		var/turf/c = get_turf(user)
		if(!c) return
		var/list/spots = list(get_step(c, NORTH), get_step(c, EAST), get_step(c, WEST), \
			get_step(c, SOUTH), get_step(c, NORTHEAST), get_step(c, SOUTHWEST))
		for(var/n in 1 to 3)
			var/turf/t = pick(spots)
			if(!t) continue
			var/obj/w = new /obj(t)
			w.icon = 'WhirlSpin.dmi'
			w.layer = MOB_LAYER
			w.mouse_opacity = 0
			w.density = 0
			w.transform = matrix() * 1.6   // enlarged
			spawn(45)
				if(w) del w

// --- Ho-Oh: Rainbow Inferno — a blazing rainbow dive that erupts around the impact.
// A proper AutoHit (routed through Activate) so it works for the AI and fires the
// legendary screen-shake / OnLegendaryActivate FX — unlike the old Meteor Strike
// subclass, whose MeteorStrike() needs a client and bypasses those hooks.
/obj/Skills/AutoHit/Rainbow_Inferno
	name = "Rainbow Inferno"
	Area = "Around Target"
	Distance = 14
	DistanceAround = 4
	DamageMult = 22
	ForOffense = 1
	Scorching = 14
	HolyMod = 4            // sacred rainbow flame — deals Holy damage as well
	Launcher = 2
	Stunner = 2
	Icon = 'Icons/Effects/Fire VFX7.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Icons/Effects/SparkleGold.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 100
	ActiveMessage = "ascends on rainbow wings and plummets down in a Rainbow Inferno!"
	verb/Rainbow_Inferno()
		set category = "Skills"
		KenShockwave(usr, icon = 'SparkleRainbow.dmi', Size = 4, Blend = 2, Time = 15)
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// A rainbow sparkle burst, and a rainbow shimmer washed over Ho-Oh itself.
		KenShockwave(user, icon = 'SparkleRainbow.dmi', Size = 4, Blend = 2, Time = 15)
		if(istype(user, /mob/Player/AI/Pokemon))
			var/mob/Player/AI/Pokemon/p = user
			if(p.body_sprite)
				var/obj/pokemon_sprite/bs = p.body_sprite
				spawn()
					animate(bs, color = "#ff4040", time = 2, flags = ANIMATION_PARALLEL)
					animate(bs, color = "#ffa030", time = 2)
					animate(bs, color = "#ffff40", time = 2)
					animate(bs, color = "#40ff40", time = 2)
					animate(bs, color = "#4090ff", time = 2)
					animate(bs, color = "#a040ff", time = 2)
					animate(bs, color = null, time = 2)
			// The flames it leaves burn through the same shifting rainbow hues that
			// wash over Ho-Oh itself, rather than plain orange fire.
			var/list/turf/near = list()
			for(var/turf/t in orange(2, user))
				near += t
			for(var/n in 1 to min(4, near.len))
				var/turf/t = pick(near)
				near -= t
				var/obj/f = new /obj(t)
				f.icon = 'Icons/Effects/Fire VFX3.dmi'
				f.layer = MOB_LAYER + 1
				f.mouse_opacity = 0
				f.density = 0
				spawn()
					animate(f, color = "#ff4040", time = 3, flags = ANIMATION_PARALLEL)
					animate(f, color = "#ffa030", time = 3)
					animate(f, color = "#ffff40", time = 3)
					animate(f, color = "#40ff40", time = 3)
					animate(f, color = "#4090ff", time = 3)
					animate(f, color = "#a040ff", time = 3)
				spawn(30)
					if(f) del f

// --- Celebi: Sacred Grove — a burst of primeval forest life.
/obj/Skills/AutoHit/Sacred_Grove
	name = "Sacred Grove"
	Area = "Circle"
	Distance = 4
	DamageMult = 13
	ForOffense = 1
	Stunner = 3
	Launcher = 1
	Crippling = 20
	TurfShift = 'Grass.dmi'       // grass sprouts across the tiles it strikes
	TurfShiftState = "Grass12"     // Looks lush and alive, not just a single grass tile.
	Icon = 'RosePetals.dmi'
	IconX = -32
	IconY = -32
	IconTime = 10
	HitSparkIcon = 'Air Render.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 4
	Shockwaves = 2
	PostShockwave = 1
	Cooldown = 90
	ActiveMessage = "awakens a Sacred Grove, primeval life bursting from the earth!"
	verb/Sacred_Grove()
		set category = "Skills"
		KenShockwave(usr, icon = 'SparkleGreen.dmi', Size = 4, Blend = 2, Time = 15)
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		KenShockwave(user, icon = 'SparkleGreen.dmi', Size = 4, Blend = 2, Time = 15)
		// Celebi's life energy flows to its trainer, easing their fatigue.
		if(istype(user, /mob/Player/AI/Pokemon))
			var/mob/Player/AI/Pokemon/p = user
			if(p.ai_owner)
				p.ai_owner.HealFatigue(300)

// --- Keldeo (Mythical): Secret Sword — the water on its head hardens into a blade
// that cleaves through its foe's guard.
/obj/Skills/AutoHit/Secret_Sword
	name = "Secret Sword"
	Area = "Strike"
	Distance = 12
	DamageMult = 17
	ForOffense = 1
	Crushing = 40          // its water-blade cuts past defense
	Launcher = 2
	Stunner = 3
	HitSparkIcon = 'Slash - Zan.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 80
	ActiveMessage = "draws the water on its head into a blade and unleashes Secret Sword!"
	verb/Secret_Sword()
		set category = "Skills"
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// The water-blade is drawn in a flash of blue and silver.
		KenShockwave(user, icon = 'KenShockwave.dmi', Size = 3, Blend = 2, Time = 10)
		KenShockwave(user, icon = 'Icons/Effects/SparkleBlue.dmi', Size = 3, Blend = 2, Time = 12)
		KenShockwave(user, icon = 'Icons/Effects/SparkleFinal.dmi', Size = 2, Blend = 2, Time = 14)

// ==========================================================================
// HOENN & SINNOH LEGENDARY SIGNATURE MOVES
// ==========================================================================

// --- Groudon: Precipice Blades — molten spikes erupt in a ring, quaking the earth.
/obj/Skills/AutoHit/Precipice_Blades
	name = "Precipice Blades"
	Area = "Circle"
	Distance = 8
	DamageMult = 22
	StrOffense = 1
	Scorching = 16
	Shattering = 16
	Quaking = 12
	Launcher = 2
	Stunner = 3
	TurfShift = 'Icons/NSE/Map Stuff/DBR Revamp/Water and Special/LavaTile.dmi'
	TurfShiftLayer = TURF_LAYER + 1
	TurfShiftDuration = 0
	TurfShiftDurationSpawn = 2
	TurfShiftDurationDespawn = 8
	HitSparkIcon = 'HellSSJ4AnimationRock.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 110
	ActiveMessage = "roars as a ring of molten precipice blades erupts from the ground!"
	verb/Precipice_Blades()
		set category = "Skills"
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// Several ground-shaking quakes as the earth splits open.
		spawn()
			for(var/n in 1 to 4)
				user.Earthquake(6, -4, 4, -4, 4)
				sleep(3)
		KenShockwave(user, icon = 'HellSSJ4AnimationRock.dmi', Size = 5, Blend = 2, Time = 14)

// --- Kyogre: Origin Pulse — a barrage of homing primordial beams that chill to the bone.
// (A projectile, so it can't carry a stat-debuff buff; the massive speed loss comes from
// heavy Slow + Freezing instead.)
/obj/Skills/Projectile/Origin_Pulse
	name = "Origin Pulse"
	Distance = 100
	DamageMult = 8
	Blasts = 3
	Homing = 1
	LosesHoming = 10
	Chilling = 18
	Freezing = 14
	ForRate = 1
	Charge = 1
	IconLock = 'BeamKHH.dmi'
	IconSize = 1.5
	ManaCost = 20
	Cooldown = 120
	ActiveMessage = "unleashes Origin Pulse -- a barrage of homing primordial beams!"
	verb/Origin_Pulse()
		set category = "Skills"
		usr.UseProjectile(src)

// --- Rayquaza: Dragon Ascent — ascends and dives, shrouding the impact in darkness
// split by thunderstrikes. The highest raw damage of any Legendary move.
/obj/Skills/AutoHit/Dragon_Ascent
	name = "Dragon Ascent"
	Area = "Around Target"
	Distance = 14
	DistanceAround = 5
	DamageMult = 30
	ForOffense = 1
	Bolt = 2
	Shocking = 12
	Launcher = 3
	Stunner = 3
	MortalBlow = 1
	Icon = 'Icons/Effects/SuperDarkness.dmi'
	IconX = -32
	IconY = -32
	IconTime = 10
	HitSparkIcon = 'Hit Effect.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 130
	ActiveMessage = "ascends into the heavens and dives in a devastating Dragon Ascent!"
	verb/Dragon_Ascent()
		set category = "Skills"
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// A shroud of darkness falls over the impact, split by scattered thunderstrikes.
		var/image/dark = image(icon = 'Icons/Effects/SuperDarkness.dmi', layer = MOB_LAYER + 3)
		var/list/turf/shroud = list()
		for(var/turf/t in range(4, user))
			shroud += t
			t.overlays += dark
		spawn()
			for(var/n in 1 to 6)
				if(!shroud.len) break
				var/turf/t = pick(shroud)
				if(t)
					var/obj/b = new /obj(t)
					b.icon = 'Icons/Effects/LightningStrike.dmi'
					b.layer = MOB_LAYER + 2
					b.mouse_opacity = 0
					b.density = 0
					spawn(8)
						if(b) del b
				sleep(2)
		spawn(45)
			for(var/turf/t in shroud)
				t.overlays -= dark

// --- Deoxys: Psycho Boost — an all-out psychic overload.
/obj/Skills/AutoHit/Psycho_Boost
	name = "Psycho Boost"
	Area = "Strike"
	Distance = 14
	DamageMult = 26
	ForOffense = 1
	Launcher = 2
	Stunner = 3
	MortalBlow = 1
	Icon = 'SparkleViolet.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Hit Effect.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 110
	ActiveMessage = "overloads reality with a devastating Psycho Boost!"
	verb/Psycho_Boost()
		set category = "Skills"
		KenShockwave(usr, icon = 'SparkleViolet.dmi', Size = 4, Blend = 2, Time = 14)
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		KenShockwave(user, icon = 'SparkleViolet.dmi', Size = 4, Blend = 2, Time = 14)

// --- Regirock: Stone Edge — a high-damage stone AoE that shatters guard and armor.
/obj/Skills/AutoHit/Stone_Edge
	name = "Stone Edge"
	Area = "Circle"
	Distance = 7
	DamageMult = 18
	StrOffense = 1
	Shattering = 22
	Launcher = 2
	Stunner = 3
	HitSparkIcon = 'HellSSJ4AnimationRock.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 90
	ActiveMessage = "drives up a ring of jagged Stone Edges!"
	verb/Stone_Edge()
		set category = "Skills"
		usr.Activate(src)

// --- Regice: Ice Age — a freezing AoE that chills everything solid.
/obj/Skills/AutoHit/Ice_Age
	name = "Ice Age"
	Area = "Circle"
	Distance = 7
	DamageMult = 16
	ForOffense = 1
	Chilling = 20
	Freezing = 16
	Shattering = 6
	Launcher = 1
	HitSparkIcon = 'IceBurst.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 4
	Shockwaves = 2
	PostShockwave = 1
	Cooldown = 90
	ActiveMessage = "blankets the field in an Ice Age!"
	verb/Ice_Age()
		set category = "Skills"
		usr.Activate(src)

// --- Registeel: Metal Breaker — a steel AoE built to break guards and weapons.
/obj/Skills/AutoHit/Metal_Breaker
	name = "Metal Breaker"
	Area = "Circle"
	Distance = 7
	DamageMult = 17
	StrOffense = 1
	GuardBreak = 1
	Crushing = 45          // shears through weapons and blocks (weapon-breaker)
	Launcher = 2
	Stunner = 3
	HitSparkIcon = 'Slash - Zan.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 90
	ActiveMessage = "slams down a Metal Breaker, shattering guard and steel alike!"
	verb/Metal_Breaker()
		set category = "Skills"
		usr.Activate(src)

// --- Regigigas: Crush Grip — seizes the foe, crushes them repeatedly, then hurls them away.
/obj/Skills/AutoHit/Crush_Grip
	name = "Crush Grip"
	Area = "Strike"
	Distance = 3
	DamageMult = 8
	StrOffense = 1
	Grapple = 1
	GrabMaster = 1
	Rounds = 5             // crushes repeatedly while held
	Crushing = 35
	Stunner = 4
	Launcher = 4           // launches / tosses them at the end
	GrabTrigger = "/obj/Skills/Grapple/Toss"
	HitSparkIcon = 'Hit Effect.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	Cooldown = 140
	ActiveMessage = "seizes its foe in a Crush Grip and refuses to let go!"
	verb/Crush_Grip()
		set category = "Skills"
		usr.Activate(src)

// --- Dialga: Roar of Time — freezes time for everything nearby (Timestop-style).
/obj/Skills/AutoHit/Roar_Of_Time
	name = "Roar of Time"
	Area = "Circle"
	Distance = 8
	DamageMult = 10
	ForOffense = 1
	Stunner = 5
	Launcher = 1
	Icon = 'Icons/Effects/Star.dmi'
	IconX = -32
	IconY = -32
	IconTime = 10
	HitSparkIcon = 'Hit Effect.dmi'
	HitSparkX = -32
	HitSparkY = -32
	Cooldown = 200
	ActiveMessage = "bellows a Roar of Time, and the world grinds to a halt!"
	verb/Roar_Of_Time()
		set category = "Skills"
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// Freeze every non-ally nearby for a few seconds.
		var/mob/owner_ref = null
		if(istype(user, /mob/Player/AI/Pokemon))
			var/mob/Player/AI/Pokemon/pu = user
			owner_ref = pu.ai_owner
		var/list/frozen = list()
		for(var/mob/M in range(6, user))
			if(M == user || M == owner_ref) continue
			if(istype(M, /mob/Player/AI/Pokemon))
				var/mob/Player/AI/Pokemon/pm = M
				if(owner_ref && pm.ai_owner == owner_ref) continue
			M.Frozen = 1
			M.TimeFrozen = 1
			frozen += M
			if(M.client)
				spawn() animate(M.client, color = list(0.3,0,0, 0,0.3,0, 0,0,0.4, 0,0,0), time = 5)
		spawn(40)   // ~4 seconds
			for(var/mob/M in frozen)
				M.Frozen = 0
				M.TimeFrozen = 0
				if(M.client)
					spawn() animate(M.client, color = null, time = 5)

// --- Palkia: Spacial Rend — a stronger, more potent Graviga that scatters star-space.
/obj/Skills/AutoHit/Spacial_Rend
	name = "Spacial Rend"
	Area = "Circle"
	Distance = 9
	DamageMult = 22
	ForOffense = 1
	GuardBreak = 1
	Crippling = 6
	Launcher = 2
	Stunner = 3
	MortalBlow = 1
	TurfShift = 'Icons/Effects/Star.dmi'
	TurfShiftLayer = MOB_LAYER + 1
	TurfShiftDuration = 0
	TurfShiftDurationSpawn = 3
	TurfShiftDurationDespawn = 7
	Icon = 'Icons/Effects/Star.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Slash - Zan.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 130
	ActiveMessage = "tears open space itself with a Spacial Rend!"
	verb/Spacial_Rend()
		set category = "Skills"
		KenShockwave(usr, icon = 'Icons/Effects/Star.dmi', Size = 4, Blend = 2, Time = 14)
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		KenShockwave(user, icon = 'Icons/Effects/Star.dmi', Size = 4, Blend = 2, Time = 14)

// --- Giratina: Shadow Force — a swarm of black phantoms home into the foe, tearing away
// their defenses, evasion and reduction.
/obj/Skills/AutoHit/Shadow_Force
	name = "Shadow Force"
	Area = "Strike"
	Distance = 16
	DamageMult = 24
	ForOffense = 1
	Launcher = 3
	Stunner = 4
	MortalBlow = 1
	CanBeDodged = 0
	BuffAffected = "/obj/Skills/Buffs/SlotlessBuffs/Autonomous/PkmnDebuff/Shadow_Force"
	HitSparkIcon = 'Hit Effect Dark.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 140
	ActiveMessage = "vanishes into the shadows and strikes with Shadow Force!"
	verb/Shadow_Force()
		set category = "Skills"
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		if(!user.Target) return
		var/mob/tgt = user.Target
		var/phantom_icon = user.icon
		var/phantom_state = user.icon_state
		if(istype(user, /mob/Player/AI/Pokemon))
			var/mob/Player/AI/Pokemon/pu = user
			if(pu.body_sprite)
				phantom_icon = pu.body_sprite.icon
				phantom_state = pu.body_sprite.icon_state
		for(var/n in 1 to 5)
			var/turf/start = get_step(user, pick(NORTH,SOUTH,EAST,WEST,NORTHEAST,NORTHWEST,SOUTHEAST,SOUTHWEST))
			if(!start) start = get_turf(user)
			if(!start) continue
			var/obj/phantom = new /obj(start)
			phantom.icon = phantom_icon
			phantom.icon_state = phantom_state
			phantom.color = list(0.2,0,0, 0,0.2,0, 0,0,0.3, 0,0,0)   // black tint
			phantom.alpha = 180
			phantom.mouse_opacity = 0
			phantom.density = 0
			phantom.layer = MOB_LAYER + 1
			spawn()
				for(var/i in 1 to 14)
					if(!phantom || !tgt || !tgt.loc) break
					step_towards(phantom, tgt)
					if(get_dist(phantom, tgt) <= 0) break
					sleep(1)
				if(phantom) del phantom

/obj/Skills/Buffs/SlotlessBuffs/Autonomous/PkmnDebuff/Shadow_Force
	DefMult = 0.6
	EndMult = 0.6
	passives = list("PureReduction" = -3, "Deflection" = -2)
	ActiveMessage = "is wracked by spectral force -- their defense, reduction and evasion torn away!"
	OffMessage = "shakes off the spectral corruption."

// --- Heatran: Magma Storm — traps the foe in a searing vortex of molten steel that
// leaves the ground glowing lava and shakes the earth as it collapses.
/obj/Skills/AutoHit/Magma_Storm
	name = "Magma Storm"
	Area = "Circle"
	Distance = 6
	DamageMult = 22
	ForOffense = 1
	Scorching = 20
	Crushing = 30          // the vortex ensnares and crushes
	Stunner = 3
	Launcher = 1
	TurfShift = 'Icons/NSE/Map Stuff/DBR Revamp/Water and Special/LavaTile.dmi'
	TurfShiftLayer = TURF_LAYER + 1
	TurfShiftDuration = 0
	TurfShiftDurationSpawn = 2
	TurfShiftDurationDespawn = 10
	Icon = 'Icons/Effects/Fire VFX5.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Icons/Effects/Fire VFX9.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 120
	ActiveMessage = "traps its foe in a searing vortex of molten steel -- Magma Storm!"
	verb/Magma_Storm()
		set category = "Skills"
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// A swirling ring of fire, and a few collapsing tremors.
		KenShockwave(user, icon = 'Icons/Effects/SparkleOrange.dmi', Size = 5, Blend = 2, Time = 14)
		KenShockwave(user, icon = 'Icons/Effects/Fire VFX3.dmi', Size = 4, Blend = 2, Time = 16)
		spawn()
			for(var/n in 1 to 3)
				user.Earthquake(4, -3, 3, -3, 3)
				sleep(4)

// --- Darkrai: Dark Void — opens a nightmare of pooling darkness that drags the foe
// under, hobbling their speed, offense and reflexes.
/obj/Skills/AutoHit/Dark_Void
	name = "Dark Void"
	Area = "Circle"
	Distance = 7
	DamageMult = 18
	ForOffense = 1
	Stunner = 6            // dragged into a nightmare slumber
	Slow = 2
	Crippling = 20
	Launcher = 1
	BuffAffected = "/obj/Skills/Buffs/SlotlessBuffs/Autonomous/PkmnDebuff/Dark_Void"
	Icon = 'Icons/Effects/SuperDarkness.dmi'
	IconX = -32
	IconY = -32
	IconTime = 10
	HitSparkIcon = 'Hit Effect Dark.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 120
	ActiveMessage = "opens a void of nightmares that drags its foes into darkness -- Dark Void!"
	verb/Dark_Void()
		set category = "Skills"
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// A shroud of nightmare-darkness pools across the ground for a few seconds.
		KenShockwave(user, icon = 'Icons/Effects/SparkleIndigo.dmi', Size = 5, Blend = 2, Time = 14)
		var/image/dark = image(icon = 'Icons/Effects/SuperDarkness.dmi', layer = MOB_LAYER + 3)
		var/list/turf/shroud = list()
		for(var/turf/t in range(4, user))
			shroud += t
			t.overlays += dark
		spawn(50)
			for(var/turf/t in shroud)
				t.overlays -= dark

/obj/Skills/Buffs/SlotlessBuffs/Autonomous/PkmnDebuff/Dark_Void
	SpdMult = 0.5
	OffMult = 0.7
	passives = list("Instinct" = -2, "Flow" = -2)
	ActiveMessage = "is trapped in a waking nightmare -- sluggish and disoriented!"
	OffMessage = "shakes off the lingering nightmare."

// --- Cresselia: Lunar Blessing — a restorative wave of moonlight that harms foes while
// its lunar wing mends its trainer's body and spirit. The support Legendary.
/obj/Skills/AutoHit/Lunar_Blessing
	name = "Lunar Blessing"
	Area = "Circle"
	Distance = 5
	DamageMult = 15
	ForOffense = 1
	Stunner = 3
	Launcher = 1
	Icon = 'SparkleViolet.dmi'
	IconX = -32
	IconY = -32
	IconTime = 10
	HitSparkIcon = 'Air Render.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 4
	Shockwaves = 2
	Cooldown = 100
	ActiveMessage = "bathes the field in restorative moonlight -- Lunar Blessing!"
	verb/Lunar_Blessing()
		set category = "Skills"
		KenShockwave(usr, icon = 'Icons/Effects/SparkleBlue.dmi', Size = 4, Blend = 2, Time = 15)
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// Cresselia's lunar wing mends its trainer's body and spirit.
		KenShockwave(user, icon = 'Icons/Effects/SparkleBlue.dmi', Size = 4, Blend = 2, Time = 15)
		if(istype(user, /mob/Player/AI/Pokemon))
			var/mob/Player/AI/Pokemon/p = user
			if(p.ai_owner)
				p.ai_owner.HealHealth(25)
				p.ai_owner.HealEnergy(40)
				p.ai_owner.HealFatigue(150)

// --- Arceus (the Alpha Pokemon): Judgment — a pillar of creation's light falls from on
// high in holy judgment. The single highest-damage Legendary move, to match the strongest
// Pokemon (which also wields scaling, uncapped God Ki — see PokemonArceusDivinity).
/obj/Skills/AutoHit/Divine_Judgment
	name = "Judgment"
	Area = "Around Target"
	Distance = 16
	DistanceAround = 6
	DamageMult = 34
	ForOffense = 1
	HolyMod = 6
	Launcher = 3
	Stunner = 4
	MortalBlow = 1
	Icon = 'Icons/Effects/SparkleGod.dmi'
	IconX = -32
	IconY = -32
	IconTime = 10
	HitSparkIcon = 'Icons/Effects/DivineSparkles.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 140
	ActiveMessage = "passes divine Judgment -- a pillar of creation's light falls from on high!"
	verb/Judgment()
		set category = "Skills"
		KenShockwave(usr, icon = 'Icons/Effects/SparkleGod.dmi', Size = 5, Blend = 2, Time = 16)
		usr.Activate(src)
	OnLegendaryActivate(mob/user)
		// A radiant pillar of creation's light, a divine sparkle burst, and the earth quakes.
		KenShockwave(user, icon = 'Icons/Effects/AvalonLight.dmi', Size = 6, Blend = 2, Time = 16)
		KenShockwave(user, icon = 'Icons/Effects/DivineSparkles.dmi', Size = 4, Blend = 2, Time = 18)
		spawn()
			for(var/n in 1 to 3)
				user.Earthquake(5, -4, 4, -4, 4)
				sleep(3)
