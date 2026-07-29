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

	// Samurai: the ultimate glass cannon. Sky-high Strength/Speed/Offense with
	// almost no Endurance or Defense. Conjures a Legendary light blade (a katana)
	// with a Chaos edge, and its passives push raw DPS and attack rate.
	Samurai
		BuffName = "Samurai Attunement"
		JobLabel = "Samurai"
		ActiveMessage = "attunes to a Samurai Job Stone, drawing a gleaming blade in a single flash of steel!"
		OffMessage = "sheathes the Samurai blade, the attunement fading with a soft click..."
		JobStats = list("Strength" = 10, "Endurance" = 1, "Force" = 1, "Speed" = 9, "Offense" = 10, "Defense" = 0.75, \
			"Power" = 1.75, "Anger" = 1.5, "Learning" = 1, "Intellect" = 1, "Imagination" = 1)
		passives = list("AttackSpeed" = 3, "SwordDamage" = 3, "PureReduction" =-5)
		BuffTechniques = list("/obj/Skills/AutoHit/Moonlight_Dash", "/obj/Skills/AutoHit/Heavenly_Quake")
		// Conjured Legendary light blade with a Chaos edge. SwordAscension +
		// SwordUnbreakable make it ascended and shatterproof (Legendary-tier); the
		// stone's Customize verb can override the icon/name (see Job_Stone/Samurai).
		MakesSword = 1
		SwordClass = "Light"
		SwordElement = "Chaos"
		SwordAscension = 5
		SwordUnbreakable = 1
		KillSword = 1
		SwordName = "Samurai Blade"
		SwordIcon = 'SwordKatana.dmi'
		SwordX = 0
		SwordY = 0

	// Dark Knight: a void-clad tank. Heavy, slow, punishing hits and a wall of
	// Endurance/Defense. Conjures a Legendary heavy blade with a Void edge, drinks
	// life from every blow (50 LifeSteal) and turns aside pain (CallousedHands).
	Dark_Knight
		BuffName = "Dark Knight Attunement"
		JobLabel = "Dark Knight"
		ActiveMessage = "attunes to a Dark Knight Job Stone, summoning a heavy blade wreathed in devouring void!"
		OffMessage = "lets the Dark Knight attunement fade, the blade receding from their soul..."
		JobStats = list("Strength" = 8, "Endurance" = 8, "Force" = 1, "Speed" = 1, "Offense" = 2, "Defense" = 8, \
			"Power" = 1.5, "Anger" = 1.5, "Learning" = 1, "Intellect" = 1, "Imagination" = 1)
		passives = list("LifeSteal" = 50, "CallousedHands" = 1,"PureReduction" = 2)
		BuffTechniques = list("/obj/Skills/AutoHit/Abyssal_Cleave", "/obj/Skills/AutoHit/Dread_Harbinger")
		// Conjured Legendary heavy blade with a Void edge (shatterproof, ascended).
		MakesSword = 1
		SwordClass = "Heavy"
		SwordElement = "Void"
		SwordAscension = 5
		SwordUnbreakable = 1
		KillSword = 1
		SwordName = "Death Knight Sword"
		SwordIcon = 'BlackShard.dmi'
		SwordX = -32
		SwordY = -32

// --- the item -------------------------------------------------------------
// Base is abstract (Unobtainable so it never lists in the craft menu). Each
// concrete stone points JobBuffType at its Job Attunement buff.
//
// Craftable from Access Enchantment -> Tool Enchantment. Requires only the
// ToolEnchantment knowledge (EnchType gates the section; SubType="Any" adds no
// second requirement). Job Stones are paid for in MANABITS (Mineral), not Mana
// Capacity like other enchantments -- see the Job_Stone special case in the
// Enchantment purchase handler (Items.dm). The menu shows Cost * (EconomyMana /
// 100); EconomyMana defaults to 100, so Cost = 100000 is 100,000 Manabits a
// piece by default (and scales with the economy).
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
	// Per-stone visual customization for jobs that conjure a sword (Samurai,
	// Dark Knight). Saved with the stone (Savable=1) and pushed onto the job buff
	// on attune, so the conjured blade wears the player's chosen look. Null =
	// use the buff's default sword icon/name.
	var/icon/CustomSwordIcon = null
	var/CustomSwordX = 0
	var/CustomSwordY = 0
	var/CustomSwordName = null

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
		// Push any saved blade customization onto the buff before it conjures, so
		// the summoned sword uses the player's chosen icon/name. Harmless for jobs
		// that don't make a sword (their buff simply ignores unused sword vars).
		if(CustomSwordIcon)
			J.SwordIcon = CustomSwordIcon
			J.SwordX = CustomSwordX
			J.SwordY = CustomSwordY
		if(CustomSwordName)
			J.SwordName = CustomSwordName
		// Trigger routes through the Special Buff slot dispatcher: activates if
		// the slot is free, deactivates if this buff already holds it, or is
		// refused if a different special buff is active.
		J.Trigger(usr)

	// Shared blade-customization flow used by the sword jobs' Utility verbs. Stores
	// the chosen look on the (saved) stone, mirrors it onto the job buff, and — if
	// the job is active right now — refreshes the conjured blade in hand live.
	proc/CustomizeConjuredBlade(mob/user)
		if(!user) return
		var/icon/newIcon = input(user, "Choose a new icon for your blade (Cancel to keep the current one):", "Customize Blade") as icon|null
		if(newIcon)
			var/nx = input(user, "Pixel X offset for the blade?", "Customize Blade") as num|null
			var/ny = input(user, "Pixel Y offset for the blade?", "Customize Blade") as num|null
			CustomSwordIcon = newIcon
			CustomSwordX = isnull(nx) ? 0 : nx
			CustomSwordY = isnull(ny) ? 0 : ny
		var/newName = input(user, "Rename the blade? (leave blank to keep the current name)", "Customize Blade") as text|null
		if(newName && length(newName))
			CustomSwordName = newName
		if(!newIcon && !(newName && length(newName)))
			return // nothing changed
		// Mirror onto the job buff so the next conjure uses the new look.
		var/obj/Skills/Buffs/SpecialBuffs/Job_Attunement/J = locate(JobBuffType) in user
		if(J)
			if(CustomSwordIcon)
				J.SwordIcon = CustomSwordIcon
				J.SwordX = CustomSwordX
				J.SwordY = CustomSwordY
			if(CustomSwordName)
				J.SwordName = CustomSwordName
			// If this job is the active special buff, update the blade in hand now.
			if(user.SpecialBuff == J)
				for(var/obj/Items/Sword/s in user)
					if(!s.Conjured) continue
					if(CustomSwordIcon)
						s.icon = CustomSwordIcon
						s.pixel_x = CustomSwordX
						s.pixel_y = CustomSwordY
					if(CustomSwordName)
						s.name = CustomSwordName
					s.AlignEquip(user)
		user << "Your blade's look has been updated. It will appear whenever you attune to this Job."

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

	Samurai
		name = "Samurai Job Stone"
		JobName = "Samurai"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/Samurai
		Unobtainable = 0
		desc = "A Job Stone imprinted with the Samurai job. Attune to conjure a Legendary Chaos-edged blade and trade your body for a peerless glass cannon's."
		verb/Customize_Samurai_Blade()
			set src in usr
			set name = "Customize Samurai Blade"
			set category = "Utility"
			CustomizeConjuredBlade(usr)

	Dark_Knight
		name = "Dark Knight Job Stone"
		JobName = "Dark Knight"
		JobBuffType = /obj/Skills/Buffs/SpecialBuffs/Job_Attunement/Dark_Knight
		Unobtainable = 0
		desc = "A Job Stone imprinted with the Dark Knight job. Attune to conjure a Legendary Void-edged greatsword and trade your body for an unrelenting tank's."
		verb/Customize_Death_Knight_Sword()
			set src in usr
			set name = "Customize Death Knight Sword"
			set category = "Utility"
			CustomizeConjuredBlade(usr)

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
	HitSparkIcon = 'Slash - Zan.dmi' // a lance-slash flash on the dive-in
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.5
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
	IconLock = 'Fireball.dmi' // flaming projectile art (matches the base Fire spell)
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
	Bolt = 2             // same lightning-strike visual Thunder uses
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
	Bolt = 2             // the airborne finisher flashes lightning too
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
	HitSparkIcon = 'IceBurst.dmi' // a shard of ice bursts on impact
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.5
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
		// A wash of restorative sparkles over whoever was mended.
		KenShockwave(Target, icon = 'DivineSparkles.dmi', Size = 2, Blend = 2, Time = 15)
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
		// A radiant pillar erupts from the caster...
		KenShockwave(usr, icon = 'SparkleGod.dmi', Size = 4, Blend = 2, Time = 15)
		for(var/mob/m in oview(5, usr))
			if(m.IsEvil())
				m.LoseHealth(30)
				KenShockwave(m, icon = 'Hit Effect Divine.dmi', Size = 2, Blend = 2, Time = 12) // ...searing the wicked
			else
				m.HealHealth(25)
				KenShockwave(m, icon = 'DivineSparkles.dmi', Size = 1.5, Blend = 2, Time = 12) // ...and blessing the rest
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
		// A cleansing shimmer washes the ailments away.
		KenShockwave(Target, icon = 'SparkleGreen.dmi', Size = 2, Blend = 2, Time = 12)
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
	// A bone-crunching impact: a gold shockwave rings out and a heavy hit-spark
	// bursts on contact.
	ShockIcon = 'KenShockwaveGold.dmi'
	Shockwave = 4
	Shockwaves = 1
	PostShockwave = 1
	HitSparkIcon = 'Hit Effect Wind.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
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
	// A blur of slashing blows — each of the rapid hits throws a spinning slash.
	HitSparkIcon = 'Slash.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.5
	HitSparkTurns = 1
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
	// A concussive shield slam: a shockwave and a heavy impact spark.
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 3
	Shockwaves = 1
	PostShockwave = 1
	HitSparkIcon = 'Hit Effect Wind.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
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
	// A wide arcing cleave — a big sweeping slash across everything in front.
	HitSparkIcon = 'Slash - Zan.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
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
	// A swift, precise cut — a quick spinning slash on the strike.
	HitSparkIcon = 'Slash.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.25
	HitSparkTurns = 1
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
	IconLock = 'BlastKiShuriken.dmi' // spinning thrown-blade art
	IconSize = 0.7
	EnergyCost = 5
	Cooldown = 35
	ActiveMessage = "flings a Fan of Knives!"
	verb/Fan_Of_Knives()
		set category = "Skills"
		usr.UseProjectile(src)

// --- Samurai --------------------------------------------------------------

// Moonlight Dash: a hold-to-charge strike (see _HeldSkill.dm). Hold the bound
// key to charge; on release the Samurai vanishes in a streak of moonlight,
// reappearing beside their target for a strike whose damage scales with how
// long the charge was held (with a sweet-spot bonus in the middle of the hold).
/obj/Skills/AutoHit/Moonlight_Dash
	name = "Moonlight Dash"
	Area = "Strike"
	Distance = 12
	DamageMult = 5
	NeedsSword = 1
	StrOffense = 1
	Stunner = 2
	HitSparkIcon = 'Slash - Future.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 1.75
	HitSparkTurns = 1
	Cooldown = 30
	// Hold-charge configuration.
	HeldSkill = TRUE
	ChargePeriod = 3          // up to 3 seconds of charge
	SweetSpot = 1.5           // a well-timed release ~1.5s in lands the bonus
	SweetSpotWindow = 0.4
	SweetSpotBenefit = 1.5    // sweet spot = max scaling
	ChargeWaveIcon = 'LunarWrathIcon.dmi'
	ChargeWaveBlend = 2
	ActiveMessage = "flickers across the field in a streak of moonlight!"

	// benefit is 0-1 from how far through ChargePeriod the release happened, or
	// SweetSpotBenefit if the sweet-spot window was hit.
	OnHeldRelease(mob/p, var/benefit, var/sweet_spot_hit = FALSE)
		if(p.Target && p.z == p.Target.z && get_dist(p, p.Target) > 1)
			var/turf/origin = get_turf(p)
			var/turf/dest = get_step(p.Target, get_dir(p.Target, p))
			if(dest && !dest.density)
				// Leave a fading moonlit afterimage at the launch point.
				if(origin)
					var/image/ghost = image(p.icon, origin, p.icon_state, MOB_LAYER)
					ghost.color = "#88aaff"
					world << ghost
					spawn()
						animate(ghost, alpha = 0, time = 6)
						sleep(6)
						del ghost
				p.loc = dest
				p.dir = get_dir(p, p.Target)
				KenShockwave(p, icon = 'LunarWrathIcon.dmi', Size = 2, Blend = 2, Time = 10)
		// Longer holds hit harder (base at a flick, up to 2.5x at the sweet spot).
		DamageMult = initial(DamageMult) * (1 + benefit)
		p.Activate(src)

	verb/Moonlight_Dash()
		set category = "Skills"
		usr.BeginHeldSkill(src)

// Heavenly Quake: the Samurai leaps forward in the direction they face and slams
// down, erupting a shockwave that shatters guards and slows everything nearby.
/obj/Skills/AutoHit/Heavenly_Quake
	name = "Heavenly Quake"
	Area = "Circle"
	Distance = 3
	DamageMult = 6
	NeedsSword = 1
	StrOffense = 1
	Jump = 2                  // airborne hop as it lands (see AutoHit Jump handling)
	Shattering = 12           // shatters
	Slow = 0.5                // and slows
	Launcher = 1
	Knockback = 6
	ShockIcon = 'KenShockwave.dmi'
	Shockwave = 4
	Shockwaves = 2
	PostShockwave = 1
	HitSparkIcon = 'Hit Effect Wind.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	Cooldown = 45
	ActiveMessage = "leaps skyward and crashes down with a Heavenly Quake!"

	verb/Heavenly_Quake()
		set category = "Skills"
		if(usr.KO || usr.Frozen) return
		// Leap forward in the direction the Samurai is facing...
		var/leaps = 3
		while(leaps > 0)
			var/turf/t = get_step(usr, usr.dir)
			if(!t || t.density) break
			step(usr, usr.dir)
			leaps--
			sleep(1)
		// ...then slam down for the quake.
		usr.Activate(src)

// --- Dark Knight ----------------------------------------------------------

// Abyssal Cleave: a slow, immense void greatsword swing. It winds up as the
// abyss opens behind the knight, then cleaves through everything in front with
// a crushing, guard-shattering blow.
/obj/Skills/AutoHit/Abyssal_Cleave
	name = "Abyssal Cleave"
	Area = "Wave"
	Distance = 8
	DamageMult = 14           // heavy, slow, punishing
	NeedsSword = 1
	StrOffense = 1
	GuardBreak = 1
	Launcher = 1
	Crushing = 40
	WindUp = 0.6              // deliberate, weighty windup
	Icon = 'Deathbringer VFX1.dmi'
	IconX = -32
	IconY = -32
	IconTime = 8
	HitSparkIcon = 'Slash - Black.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2.5
	ShockIcon = 'KenShockwavePurple.dmi'
	Shockwave = 5
	Shockwaves = 1
	PostShockwave = 1
	Cooldown = 55
	WindupMessage = "raises their blade as the abyss yawns open behind them..."
	ActiveMessage = "brings down an Abyssal Cleave, rending the void itself!"
	verb/Abyssal_Cleave()
		set category = "Skills"
		usr.Activate(src)

// Dread Harbinger: the Dark Knight drives their blade down and erupts a ring of
// violet, necrotic void — stunning, shattering, and dragging down the speed of
// every foe caught in the dread.
/obj/Skills/AutoHit/Dread_Harbinger
	name = "Dread Harbinger"
	Area = "Circle"
	Distance = 4
	DamageMult = 5
	NeedsSword = 1
	StrOffense = 1
	Slow = 0.4
	Shattering = 8
	Stunner = 2
	Icon = 'DoomAura1.dmi'
	IconX = -32
	IconY = -32
	IconTime = 10
	HitSparkIcon = 'Deathbringer VFX2.dmi'
	HitSparkX = -32
	HitSparkY = -32
	HitSparkSize = 2
	ShockIcon = 'KenShockwavePurple.dmi'
	Shockwave = 5
	Shockwaves = 3
	PostShockwave = 1
	Cooldown = 60
	ActiveMessage = "unleashes a wave of Dread, the abyss clawing at all who stand near!"
	verb/Dread_Harbinger()
		set category = "Skills"
		// A shroud of violet death erupts around the knight before the pulse lands.
		KenShockwave(usr, icon = 'SparkleViolet.dmi', Size = 4, Blend = 2, Time = 15)
		usr.Activate(src)
