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
	"Moltres"  = "/obj/Skills/AutoHit/Meteor_Strike/Sky_Attack",
	"Zapdos"   = "/obj/Skills/AutoHit/Zap_Cannon",
	"Articuno" = "/obj/Skills/AutoHit/Sheer_Cold",
	// Johto legendaries
	"Raikou"   = "/obj/Skills/AutoHit/Thunderclap",
	"Entei"    = "/obj/Skills/AutoHit/Sacred_Fire",
	"Suicune"  = "/obj/Skills/AutoHit/Tidal_Crash",
	"Lugia"    = "/obj/Skills/AutoHit/Aeroblast",
	"Ho-Oh"    = "/obj/Skills/AutoHit/Meteor_Strike/Rainbow_Inferno",
	"Celebi"   = "/obj/Skills/AutoHit/Sacred_Grove",
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
	Duration = 5
	DamageMult = 1.5
	AccuracyMult = 1.2
	Combo = 2            // small, fast combo
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
	DamageMult = 3
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
	DamageMult = 8
	ChargeRate = 2
	Dodgeable = 0
	Homing = 1
	Distance = 40
	ForRate = 1
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
	Poisoning = 8
	Toxic = 4
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
	Shattering = 8
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
	DamageMult = 4
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
	DamageMult = 5
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
	Freezing = 8
	Chilling = 6
	Distance = 40
	ForRate = 1
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

// --- Moltres: Sky Attack — a blazing dive-bomb from on high (heavier Meteor).
/obj/Skills/AutoHit/Meteor_Strike/Sky_Attack
	name = "Sky Attack"
	DamageMult = 28
	Scorching = 12
	Launcher = 2
	Stunner = 2
	HitSparkIcon = 'fevExplosion - Hellfire.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 100
	ActiveMessage = "rockets skyward and plummets down in a blazing Sky Attack!"
	verb/Sky_Attack()
		set category = "Skills"
		MeteorStrike(usr, src)

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
	Icon = 'fevExplosion - Hellfire.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Slash - Hellfire.dmi'
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

// --- Ho-Oh: Rainbow Inferno — a blazing rainbow dive from the heavens.
/obj/Skills/AutoHit/Meteor_Strike/Rainbow_Inferno
	name = "Rainbow Inferno"
	DamageMult = 28
	Scorching = 14
	HolyMod = 4            // sacred rainbow flame — deals Holy damage as well
	Launcher = 2
	Stunner = 2
	HitSparkIcon = 'fevExplosion - Hellfire.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	Cooldown = 100
	ActiveMessage = "ascends on rainbow wings and plummets down in a Rainbow Inferno!"
	verb/Rainbow_Inferno()
		set category = "Skills"
		MeteorStrike(usr, src)
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
