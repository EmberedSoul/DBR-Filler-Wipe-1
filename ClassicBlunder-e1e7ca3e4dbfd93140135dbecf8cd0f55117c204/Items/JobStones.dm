// ==========================================================================
// JOB STONES
// --------------------------------------------------------------------------
// A Job Stone is a craftable Enchantment item behind the ToolEnchantment magic
// knowledge. EnchType places it in the Tool Enchantment section of the Access
// Enchantment menu (which requires ToolEnchantment); SubType="Any" adds no
// further requirement.
//
// Holding a Job Stone grants the "Attune to Job" verb. Attuning activates a
// Special Buff that OVERWRITES the character's base stats with the Job baked
// into that stone. Deactivating it (same verb again) reverts every stat to
// its stored original value and frees the Special Buff slot.
//
// Adding a new Job = one buff subtype (its stat block) + one stone subtype
// pointing at it. The example jobs below (Warrior / Mage / Rogue) use
// placeholder numbers meant to be tuned.
// ==========================================================================

// --- stat overwrite / restore plumbing -----------------------------------
// The "stats" a player allocates at creation live in modifier vars, mapped by
// SetStat(). GetJobStatValue() is the read-side mirror of that mapping so we
// can snapshot the originals before overwriting them.
mob
	var
		// Snapshot of the pre-attunement base stats, keyed by stat name.
		// Non-tmp so it survives a mid-attunement save; the Logout/Login
		// safeguards below guarantee we never leave a player stranded on
		// Job stats across a relog regardless.
		list/JobAttuneSaved = null
		JobAttuneName = null

	proc
		GetJobStatValue(stat)
			switch(stat)
				if("Power")      return PotentialRate
				if("Speed")      return SpdMod
				if("Strength")   return StrMod
				if("Endurance")  return EndMod
				if("Force")      return ForMod
				if("Offense")    return OffMod
				if("Defense")    return DefMod
				if("Anger")      return AngerMax
				if("Learning")   return RPPMult
				if("Intellect")  return Intelligence
				if("Imagination") return Imagination
			return null

		// Snapshot current base stats, then overwrite them with the Job's.
		ApplyJobStats(list/stats, jobName)
			if(!islist(stats)) return
			if(JobAttuneSaved) return // already attuned; slot logic should prevent this
			JobAttuneSaved = list()
			for(var/s in stats)
				JobAttuneSaved[s] = GetJobStatValue(s)
				SetStat(s, stats[s])
			JobAttuneName = jobName

		// Restore whatever was snapshotted; safe/no-op if not attuned.
		RestoreJobStats()
			if(!JobAttuneSaved) return
			for(var/s in JobAttuneSaved)
				SetStat(s, JobAttuneSaved[s])
			JobAttuneSaved = null
			JobAttuneName = null

// --- the Special Buff -----------------------------------------------------
// No verb of its own: it is triggered exclusively through the Job Stone item.
// The actual stat overwrite/revert is driven from AddSpecialBuff() /
// RemoveSpecialBuff() in _BuffX.dm, which detect this buff type and call
// ApplyJobStats()/RestoreJobStats().
obj/Skills/Buffs/SpecialBuffs/Job_Attunement
	BuffName = "Job Attunement"
	Cooldown = 0
	Copyable = 0
	// Activation sparkle burst (same mechanism Valor/Wisdom Form use on activate:
	// a KenWave shockwave rendered with a Sparkle icon). Gold to distinguish Job
	// Stones from Valor Form (red) and Wisdom Form (blue). Inherited by every job.
	KenWave = 1
	KenWaveIcon = 'SparkleGold.dmi'
	KenWaveSize = 3
	KenWaveX = 105
	KenWaveY = 105
	var/list/JobStats = list()
	var/JobLabel = "Job"

	// BuffTechniques are granted on attune and stripped on deactivation by the
	// buff framework (see _BuffX.dm). Skills listed here are placeholder
	// examples chosen to fit each job; swap them for whatever you want a job to
	// hand out. Note: if a player already owns one of these skills by other
	// means, deactivating will remove it (standard BuffTechniques behavior), so
	// prefer job-exclusive skills here where possible.
	Warrior
		BuffName = "Warrior Attunement"
		JobLabel = "Warrior"
		ActiveMessage = "attunes to a Warrior Job Stone, their body reforging into a hardened frontline fighter!"
		OffMessage = "sheds the Warrior attunement, their body settling back to normal..."
		JobStats = list("Strength" = 11, "Endurance" = 4.5, "Force" = 1, "Speed" = 1.5, "Offense" = 2, "Defense" = 2, \
			"Power" = 1.25, "Anger" = 1.5, "Learning" = 1, "Intellect" = 1, "Imagination" = 1)
		passives = list("SwordDamage" = 2, "TechniqueMastery" = 2)	
		BuffTechniques = list("/obj/Skills/AutoHit/Bulwark_Bash", "/obj/Skills/AutoHit/Cleaving_Blow")

	Berserker
		BuffName = "Berserker Attunement"
		JobLabel = "Berserker"
		ActiveMessage = "attunes to a Berserker Job Stone, their rage building with each strike!"
		OffMessage = "lets the Berserker attunement fade, their rage subsiding..."
		JobStats = list("Strength" = 4, "Endurance" = 4, "Force" = 4, "Speed" = 2.5, "Offense" = 2, "Defense" = 1.5, \
			"Power" = 1.75, "Anger" = 3, "Learning" = 1.5, "Intellect" = 2, "Imagination" = 2)
		passives = list("EndlessAnger" = 1, "UnbridledFury" = 1)
		BuffTechniques = list("/obj/Skills/AutoHit/Reckless_Slam", "/obj/Skills/AutoHit/Berserk_Flurry")	
		

	Rogue
		BuffName = "Rogue Attunement"
		JobLabel = "Rogue"
		ActiveMessage = "attunes to a Rogue Job Stone, becoming a blur of speed and precision!"
		OffMessage = "drops the Rogue attunement, their movements settling back to normal..."
		JobStats = list("Strength" = 1.5, "Endurance" = 1.5, "Force" = 1.5, "Speed" = 6, "Offense" = 8, "Defense" = 12, \
			"Power" = 1.25, "Anger" = 1.25, "Learning" = 1.25, "Intellect" = 1.25, "Imagination" = 1.25)
		BuffTechniques = list("/obj/Skills/AutoHit/Backstab", "/obj/Skills/Projectile/Fan_Of_Knives")
		passives = list("CriticalChance" = 20, "CriticalStrike" = 0.5, "Flow" = 2, "Instinct" = 2)

	// Dragoon: high speed, rapid strikes, the Extend passive. Grants the two
	// Dragoon skills (defined at the bottom of this file).
	Dragoon
		BuffName = "Dragoon Attunement"
		JobLabel = "Dragoon"
		ActiveMessage = "attunes to a Dragoon Job Stone, poised to strike like a plummeting lance!"
		OffMessage = "releases the Dragoon attunement, their footing settling back to normal..."
		JobStats = list("Strength" = 2.75, "Endurance" = 2.5, "Force" = 1, "Speed" = 7.5, "Offense" = 2.5, "Defense" = 2.5, \
			"Power" = 1.5, "Anger" = 1.5, "Learning" = 1, "Intellect" = 1, "Imagination" = 1)
		passives = list("Extend" = 2, "AttackSpeed" = 2)
		BuffTechniques = list("/obj/Skills/Queue/Dragon_Step", "/obj/Skills/AutoHit/Dragoon_Dive")

	// Black Mage: high force, powerful casting passives. Grants Fire/Thunder/
	// Blizzard II (defined at the bottom of this file).
	Black_Mage
		BuffName = "Black Mage Attunement"
		JobLabel = "Black Mage"
		ActiveMessage = "attunes to a Black Mage Job Stone, destructive magic crackling at their fingertips!"
		OffMessage = "lets the Black Mage attunement fade, the crackling magic dispersing..."
		JobStats = list("Strength" = 1, "Endurance" = 1.5, "Force" = 7.5, "Speed" = 1.5, "Offense" = 4, "Defense" = 3.5, \
			"Power" = 1.5, "Anger" = 1, "Learning" = 1.5, "Intellect" = 2.5, "Imagination" = 2.5)
		passives = list("TechniqueMastery" = 3, "SpiritStrike" = 1, "ManaGeneration" = 1)
		BuffTechniques = list("/obj/Skills/Projectile/Fire_II", "/obj/Skills/AutoHit/Thunder_II", "/obj/Skills/Queue/Blizzard_II")

	// White Mage: high defense and force, sustain passives. Grants Aero, Cure II,
	// and Holy (defined at the bottom of this file).
	White_Mage
		BuffName = "White Mage Attunement"
		JobLabel = "White Mage"
		ActiveMessage = "attunes to a White Mage Job Stone, wrapped in a warm, protective radiance!"
		OffMessage = "lets the White Mage attunement fade, the radiance dimming..."
		JobStats = list("Strength" = 1, "Endurance" = 2, "Force" = 3, "Speed" = 1.5, "Offense" = 1.5, "Defense" = 3.5, \
			"Power" = 1.5, "Anger" = 1, "Learning" = 1.5, "Intellect" = 2, "Imagination" = 2)
		passives = list("Blubber" = 2, "LifeGeneration" = 2)
		BuffTechniques = list("/obj/Skills/Projectile/Aero", "/obj/Skills/Utility/Cure_II", "/obj/Skills/Utility/Holy")

	// Red Mage: hybrid bruiser-caster, high Force and Strength, aggressive
	// sustain passives. Grants Aero, Fire II, Thunder II, and Esuna.
	Red_Mage
		BuffName = "Red Mage Attunement"
		JobLabel = "Red Mage"
		ActiveMessage = "attunes to a Red Mage Job Stone, blade and spell flowing as one!"
		OffMessage = "lets the Red Mage attunement fade, blade and spell parting ways..."
		JobStats = list("Strength" = 3, "Endurance" = 2, "Force" = 3, "Speed" = 2, "Offense" = 2.5, "Defense" = 1.5, \
			"Power" = 1.5, "Anger" = 1.25, "Learning" = 1.25, "Intellect" = 1.75, "Imagination" = 1.75)
		passives = list("LifeSteal" = 1, "KillerInstinct" = 1)
		BuffTechniques = list("/obj/Skills/Projectile/Aero", "/obj/Skills/Projectile/Fire_II", "/obj/Skills/AutoHit/Thunder_II", "/obj/Skills/Utility/Esuna")

// --- the item -------------------------------------------------------------
// Base is abstract (Unobtainable so it never lists in the craft menu). Each
// concrete stone points JobBuffType at its Job Attunement buff.
//
// Craftable from Access Enchantment -> Tool Enchantment. Requires only the
// ToolEnchantment knowledge (EnchType gates the section; SubType="Any" adds no
// second requirement). Cost is the raw price at default economy: the menu
// charges Cost * (EconomyMana / 100), and EconomyMana defaults to 100, so
// Cost = 100000 is 100,000 a piece by default (and scales with the economy).
obj/Items/Enchantment/Job_Stone
	EnchType = "ToolEnchantment" // craft section (requires ToolEnchantment knowledge)
	SubType = "Any"              // no additional knowledge requirement
	Cost = 100000
	Savable = 1
	icon = 'enchantmenticons.dmi'
	icon_state = "ArcanOrb" // placeholder art; swap per-job as desired
	Unobtainable = 1
	desc = "A dormant stone with a job imprinted inside it."
	var/JobBuffType = null
	var/JobName = "Job"

	verb/Attune_to_Job()
		set src in usr
		set name = "Attune to Job"
		set category = "Skills"
		if(!JobBuffType)
			usr << "This Job Stone is inert."
			return
		var/obj/Skills/Buffs/SpecialBuffs/Job_Attunement/J = locate(JobBuffType) in usr
		if(!J)
			J = new JobBuffType
			usr.AddSkill(J)
		// Trigger routes through the Special Buff slot dispatcher: activates if
		// the slot is free, deactivates if this buff already holds it, or is
		// refused if a different special buff is active.
		J.Trigger(usr)

	Warrior
		name = "Warrior Job Stone"
		JobName = "Warrior"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/Warrior
		Unobtainable = 0
		desc = "A Job Stone imprinted with the Warrior job. Attune to trade your stats for a hardened fighter's."

	Rogue
		name = "Rogue Job Stone"
		JobName = "Rogue"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/Rogue
		Unobtainable = 0
		desc = "A Job Stone imprinted with the Rogue job. Attune to trade your stats for a swift skirmisher's."

	Dragoon
		name = "Dragoon Job Stone"
		JobName = "Dragoon"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/Dragoon
		Unobtainable = 0
		desc = "A Job Stone imprinted with the Dragoon job. Attune to trade your stats for a high-flying lancer's."

	Black_Mage
		name = "Black Mage Job Stone"
		JobName = "Black Mage"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/Black_Mage
		Unobtainable = 0
		desc = "A Job Stone imprinted with the Black Mage job. Attune to trade your stats for a destructive caster's."

	White_Mage
		name = "White Mage Job Stone"
		JobName = "White Mage"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/White_Mage
		Unobtainable = 0
		desc = "A Job Stone imprinted with the White Mage job. Attune to trade your stats for a protective healer's."

	Red_Mage
		name = "Red Mage Job Stone"
		JobName = "Red Mage"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/Red_Mage
		Unobtainable = 0
		desc = "A Job Stone imprinted with the Red Mage job. Attune to trade your stats for a spellblade's."

	Berserker
		name = "Berserker Job Stone"
		JobName = "Berserker"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/Berserker
		Unobtainable = 0
		desc = "A Job Stone imprinted with the Berserker job. Attune to trade your stats for a reckless ragemonger's."

// ==========================================================================
// JOB SKILLS
// Granted by the job buffs above via BuffTechniques (added on attune, stripped
// on deactivation). Each is modeled on an existing skill of the same category
// so it inherits the working combat pipeline; only the noted properties differ.
// ==========================================================================

// --- Dragoon --------------------------------------------------------------

// Dragon-Step: a Zanzo-charge gap-closer. Warp homes it onto the target
// ("digging in from an impossible angle"), SpeedStrike scales damage off Speed,
// and it cripples on hit. Consumes a movement (Zanzo) charge like Zanzoken.
/obj/Skills/Queue/Dragon_Step
	name = "Dragon-Step"
	Duration = 5
	DamageMult = 3.25
	AccuracyMult = 1.1
	SpeedStrike = 2      // full Speed-mod scaling
	Crippling = 30
	Warp = 1             // homes onto the target
	Cooldown = 20
	ActiveMessage = "dives at breakneck speed, digging into their target from an impossible angle!"
	verb/Dragon_Step()
		set category = "Skills"
		if(usr.MovementCharges < 1)
			usr << "You need a movement (Zanzo) charge to use Dragon-Step!"
			return
		usr.MovementCharges -= 1
		usr.SetQueue(src)

// Dragoon Dive: a heavier Meteor Strike. Inherits the full dive animation and
// impact from its parent; adds launch, stun, guard break, and more damage.
/obj/Skills/AutoHit/Meteor_Strike/Dragoon_Dive
	name = "Dragoon Dive"
	DamageMult = 30      // Meteor Strike is 20
	Launcher = 2
	Stunner = 3
	GuardBreak = 1
	Cooldown = 90
	verb/Dragoon_Dive()
		set category = "Skills"
		MeteorStrike(usr, src)

// --- Black Mage -----------------------------------------------------------

// Fire II: a homing, multi-round searing projectile.
// NOTE: "ignores 25% of endurance" has no direct engine var; see report. The
// scorching/force scaling below approximates the burst, but the endurance
// bypass is left as a TODO to wire into the damage step deliberately.
/obj/Skills/Projectile/Fire_II
	name = "Fire II"
	Distance = 100
	DamageMult = 3
	Blasts = 3           // multiple rounds
	Homing = 1
	HyperHoming = 1
	Scorching = 12       // massive scorching
	StrRate = 0
	ForRate = 1          // Force-based, fits Black Mage
	Radius = 1
	IconLock = 'Blast - Rapid.dmi' // placeholder art
	IconSize = 1
	Charge = 1
	ManaCost = 15
	Cooldown = 30
	ActiveMessage = "invokes: FIRE II!"
	verb/Fire_II()
		set category = "Skills"
		usr.UseProjectile(src)

// Thunder II: a two-round autohit that stuns hard and launches, then follows
// up with a heavy hit while the foe is airborne.
/obj/Skills/AutoHit/Thunder_II
	name = "Thunder II"
	Area = "Strike"
	Distance = 12
	DamageMult = 4
	Rounds = 2
	Stunner = 6
	Launcher = 2
	StrOffense = 0
	ForOffense = 1
	FollowUp = "/obj/Skills/AutoHit/Thunder_II_Followup"
	FollowUpDelay = 3
	Cooldown = 40
	ActiveMessage = "invokes: THUNDER II!"
	verb/Thunder_II()
		set category = "Skills"
		usr.Activate(src)

// Engine-triggered follow-up (via FollowUp above); no verb. High damage on the
// launched target. NOTE: the requested "Dunker" is a Queue-only property, so it
// can't sit on this AutoHit follow-up; the raw damage below stands in for it.
/obj/Skills/AutoHit/Thunder_II_Followup
	name = "Thunder II (Follow-up)"
	Area = "Strike"
	Distance = 12
	DamageMult = 10
	Launcher = 1
	ForOffense = 1
	Cooldown = 0

// Blizzard II: a queued strike that freezes the foe solid, in the vein of
// Freeze Ray / Yukinesa's ice skills.
/obj/Skills/Queue/Blizzard_II
	name = "Blizzard II"
	Duration = 5
	DamageMult = 3
	AccuracyMult = 1.1
	Freezing = 10        // the freeze
	Shattering = 1
	Chilling = 5
	Cooldown = 60
	ManaCost = 15
	ActiveMessage = "invokes: BLIZZARD II!"
	verb/Blizzard_II()
		set category = "Skills"
		usr.SetQueue(src)

// --- White / Red Mage -----------------------------------------------------

// Aero: a Spirit Ball-style homing projectile that leans on paralysis/shock and
// saps the target's stamina. OnMobHit runs JobSkill_AeroFatigue on each blast
// that connects (fatigue the enemy). Shared by White and Red Mage.
/obj/Skills/Projectile/Aero
	name = "Aero"
	Distance = 30
	DamageMult = 6
	Blasts = 3
	AccMult = 2
	Launcher = 2
	Piercing = 1
	Striking = 1
	Homing = 1
	HomingCharge = 1
	HomingDelay = 0.5
	EnergyCost = 8
	Delay = 3
	Speed = 1
	IconChargeOverhead = 1
	Explode = 1
	Cooldown = 60
	IconLock = 'Plasma2.dmi' // placeholder art (Spirit Ball's icon)
	Shocking = 8         // high shock chance
	Paralyzing = 8       // high shock application
	OnMobHit = "/proc/JobSkill_AeroFatigue"
	ActiveMessage = "invokes: AERO!"
	verb/Aero()
		set category = "Skills"
		usr.UseProjectile(src)

// Called by Aero's OnMobHit for each blast that lands: fatigues the target.
/proc/JobSkill_AeroFatigue(mob/m, obj/o)
	if(ismob(m))
		m.GainFatigue(12)

// Cure II: fully restores a nearby ally's (or your own) health. Implemented as a
// targeted cast rather than a literal traveling projectile (a healing projectile
// would need custom ally-vs-enemy hit handling); see report.
/obj/Skills/Utility/Cure_II
	name = "Cure II"
	desc = "Fully restore the health of yourself or a nearby ally."
	Cooldown = 60
	verb/Cure_II()
		set category = "Skills"
		if(src.Using) return
		src.Using = 1
		var/list/Options = list(usr)
		for(var/mob/Players/P in oview(6, usr))
			Options.Add(P)
		var/mob/Target = usr
		if(Options.len > 1)
			Target = input(usr, "Who do you want to heal?", "Cure II") as null|anything in Options
		if(!Target)
			src.Using = 0
			return
		if(Target != usr && get_dist(usr, Target) > 6)
			usr << "[Target] has moved too far away."
			src.Using = 0
			return
		Target.HealHealth(99999)
		Target.HealWounds(99999)
		OMsg(usr, "[usr] casts Cure II, fully mending [Target == usr ? "themselves" : "[Target]"]!")
		src.Using = 0
		Cooldown()

// Holy: an AoE burst that damages the wicked (IsEvil: Demons, evil races/secrets,
// anything HolyMod would target) and heals everyone else in range by 25.
/obj/Skills/Utility/Holy
	name = "Holy"
	desc = "Call down holy light: it burns the wicked and mends everyone else."
	Cooldown = 60
	verb/Holy()
		set category = "Skills"
		if(src.Using) return
		src.Using = 1
		usr.HealHealth(25) // the caster is mended too
		for(var/mob/m in oview(5, usr))
			if(m.IsEvil())
				m.LoseHealth(30)
			else
				m.HealHealth(25)
		OMsg(usr, "[usr] calls down a radiant pillar of Holy light!")
		src.Using = 0
		Cooldown()

// Esuna: cleanses status ailments (debuffs) from yourself or a nearby ally.
/obj/Skills/Utility/Esuna
	name = "Esuna"
	desc = "Cleanse status ailments from yourself or a nearby ally."
	Cooldown = 30
	verb/Esuna()
		set category = "Skills"
		if(src.Using) return
		src.Using = 1
		var/list/Options = list(usr)
		for(var/mob/Players/P in oview(6, usr))
			Options.Add(P)
		var/mob/Target = usr
		if(Options.len > 1)
			Target = input(usr, "Who do you want to cleanse?", "Esuna") as null|anything in Options
		if(!Target)
			src.Using = 0
			return
		if(Target != usr && get_dist(usr, Target) > 6)
			usr << "[Target] has moved too far away."
			src.Using = 0
			return
		Target.CleanseDebuff(100)
		OMsg(usr, "[usr] casts Esuna, purging the ailments from [Target == usr ? "themselves" : "[Target]"]!")
		src.Using = 0
		Cooldown()

// --- Berserker ------------------------------------------------------------

// Reckless Slam: a raging gap-closer that crashes into the target, launching and
// guard-breaking them.
/obj/Skills/AutoHit/Reckless_Slam
	name = "Reckless Slam"
	Area = "Strike"
	Distance = 10
	DamageMult = 6
	Rush = 20
	Launcher = 2
	GuardBreak = 1
	Stunner = 2
	StrOffense = 1
	Cooldown = 45
	ActiveMessage = "hurls themselves into a Reckless Slam!"
	verb/Reckless_Slam()
		set category = "Skills"
		usr.Activate(src)

// Berserk Flurry: a frenzy of rapid blows.
/obj/Skills/AutoHit/Berserk_Flurry
	name = "Berserk Flurry"
	Area = "Strike"
	Distance = 6
	DamageMult = 3
	Rounds = 4
	StrOffense = 1
	Cooldown = 40
	ActiveMessage = "erupts into a Berserk Flurry!"
	verb/Berserk_Flurry()
		set category = "Skills"
		usr.Activate(src)

// --- Warrior --------------------------------------------------------------

// Bulwark Bash: a shield bash that stuns and breaks guard. (Typed Bulwark_Bash
// to avoid the existing /obj/Skills/Queue/Finisher/Shield_Bash.)
/obj/Skills/AutoHit/Bulwark_Bash
	name = "Shield Bash"
	Area = "Strike"
	Distance = 8
	DamageMult = 4
	Rush = 15
	Stunner = 4
	GuardBreak = 1
	StrOffense = 1
	Cooldown = 40
	ActiveMessage = "slams forward with a brutal Shield Bash!"
	verb/Bulwark_Bash()
		set category = "Skills"
		set name = "Shield Bash"
		usr.Activate(src)

// Cleaving Blow: a wide sweeping cleave that launches everything in front.
/obj/Skills/AutoHit/Cleaving_Blow
	name = "Cleaving Blow"
	Area = "Wave"
	Distance = 10
	DamageMult = 4.5
	Launcher = 1
	StrOffense = 1
	Cooldown = 45
	ActiveMessage = "swings a wide Cleaving Blow!"
	verb/Cleaving_Blow()
		set category = "Skills"
		usr.Activate(src)

// --- Rogue ----------------------------------------------------------------

// Backstab: a swift dash-in strike that cripples the target's movement.
/obj/Skills/AutoHit/Backstab
	name = "Backstab"
	Area = "Strike"
	Distance = 10
	DamageMult = 5
	Rush = 20
	Crippling = 25
	StrOffense = 1
	Cooldown = 40
	ActiveMessage = "darts in for a vicious Backstab!"
	verb/Backstab()
		set category = "Skills"
		usr.Activate(src)

// Fan of Knives: a homing volley of thrown blades that hobble the target.
/obj/Skills/Projectile/Fan_Of_Knives
	name = "Fan of Knives"
	Distance = 40
	DamageMult = 2.5
	Blasts = 5
	StrRate = 1
	ForRate = 0
	Crippling = 15
	Homing = 1
	Charge = 1
	IconLock = 'Blast - Rapid.dmi' // placeholder art
	IconSize = 0.7
	EnergyCost = 5
	Cooldown = 35
	ActiveMessage = "flings a Fan of Knives!"
	verb/Fan_Of_Knives()
		set category = "Skills"
		usr.UseProjectile(src)
