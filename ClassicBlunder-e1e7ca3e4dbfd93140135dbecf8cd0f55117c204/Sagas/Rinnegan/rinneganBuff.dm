/*

shar, mange and rinnegan all stack atop of each other, keep that in mind!!!

*/

/obj/Skills/Buffs/var/DevaPull // for deva path, pull people in instead of warping to them

/mob/var/devaCounter = 0

/mob/proc/findRinne()
    if(Saga != "Sharingan") return
    return GetSlotless("Rinnegan")


/obj/Skills/Buffs/SlotlessBuffs/Rinnegan
    SBuffNeeded = "Sharingan"
    Cooldown = -1
    SeeInvisible = 20
    Void = 1
    BuffMastery = 3
    IconLock='RinneganEyes.dmi'
    BuffTechniques=list("/obj/Skills/Six_Paths_of_Pain")
    ActiveMessage="ascends into enlightment as their eyes perceive all six paths of Samsara!"
    OffMessage="closes their eyes to the truth of the world..."
    verb/Rinnegan()
        set category="Skills"
        resetToDefault(usr)
        adjust(usr)
        src.Trigger(usr)
    // idk wound drain was here
    var/activePath = "Deva"


    proc/resetToDefault()
        //asura
        Mechanized = 0
        HybridStrike = 0
        StrMult = 1
        EndMult = 1
        OffMult = 1
        DefMult = 1
        DoubleStrike = 0
        TripleStrike = 0
        // Human
        StealsStats = 0
        Erosion = 0
        LifeSteal = 0
        // Preta
        BulletKill = 0
        EnergySteal = 0
        ManaSteal = 0
        ElementalDefense = "None"
        // Deva
        DevaPull = 0
        NoWhiff = 0



    adjust(mob/p)
        // they r just sagalevel 8
        var/pot = p.Potential
        GodKi = p / 100
        switch(activePath)
            if("Asura")
                // mechanical
                Mechanized=1
                HybridStrike = pot / 20 // double dmg at 100 pot
                SpiritHand = pot / 25 // Str + For at 100 pot
                ForMult = 1.3
                OffMult = 1.2
                EndMult = 1.3
                DoubleStrike = 2
                TripleStrike = 1
            if("Human")
                StealsStats = pot / 20
                ElementalOffense = "Void"
                Erosion = pot / 50
                LifeSteal = pot

            if("Preta")
                BulletKill = 1
                EnergySteal = pot
                ManaSteal = pot
                ElementalDefense = "Void"
                EndMult = 1.4
            if("Deva")
                // should be main fighting vs asura tbh
                // maybe mechanic that pulls people in instead of warping to them (reverse iaido)
                DevaPull = 1
                StrMult = 1.4
                EndMult = 1.4
                OffMult = 1.1
                DefMult = 1.1
                NoWhiff = 1
                NoMiss = 1

    proc/swapPath(path, mob/p)
        activePath = path
        Trigger(p, Override = 1)
        adjust(p)
        sleep(1)
        Trigger(p, Override = 1)








/*

Sharingan
			OffMult=1.2
			DefMult=1.3
			Maki = 1
			CalmAnger = 1
			PUSpike=10
					if(usr.SagaLevel>=3)
						if(usr.SharinganEvolution=="Resolve")
							OffMult=1.4
							DefMult=1.4
							SureDodgeTimerLimit=15
							LikeWater=2
							Instinct=2
							Flow=2
							FluidForm=1
							PUSpike=25
						else
							src.OffMult=1.3
							src.DefMult=1.3
							src.SureDodgeTimerLimit=20
							src.Instinct=2
							src.Flow=2
							src.FluidForm=1
							src.FatigueDrain=0


Mangekyou_Sharingan
			TaxThreshold=0.2
			OffTaxDrain=0.0003
			DefTaxDrain=0.0003
			SBuffNeeded="Sharingan"
			BuffMastery=5
			Cooldown=-1
			Deflection=1
			Flow=1
			ActiveMessage="gives into hatred; their tomoe twist into a kaleidoscope pattern!"
			OffMessage="closes their eyes with a pained look..."
			verb/Mangekyou_Sharingan()
				set category="Skills"
							src.Instinct=1
						if("Resolve")
							src.LikeWater=usr.SagaLevel / 2
							src.Flow=2
							src.Instinct=2
							src.Deflection= 1 + usr.SagaLevel / 4
							src.Duelist=1
							Godspeed= usr.SagaLevel / 4
				src.Trigger(usr)
		Rinnegan
			SBuffNeeded="Sharingan"
			WoundDrain=0.05
			GodKi=0.5
			Cooldown=-1
			IconLock='RinneganEyes.dmi'
			BuffTechniques=list("/obj/Skills/Six_Paths_of_Pain")
			ActiveMessage="ascends into enlightment as their eyes perceive all six paths of Samsara!"
			OffMessage="closes their eyes to the truth of the world..."
			verb/Rinnegan()
				set category="Skills"
				src.Trigger(usr)

                */

// ==========================================================================
// SHARINGAN SIGNATURE COPY  (rework of the old Skill-Tree copy)
// --------------------------------------------------------------------------
// With the Sharingan active, "Copy Signature" opens a 30-second window; the next
// N distinct Signature-flagged techniques used in view are copied into your kit
// and kept until "Forget Signature". N = 2 normally, 4 on the Copy-Ninja path.
// The old per-tier Skill-Tree copy is gone: the AutoHit/Projectile/Queue/Style
// use-hooks now call TrySharinganCopy(), which ONLY ever copies Signatures.
// ==========================================================================

/mob/var/tmp/SharinganCopyWindow = 0        // world.time the window closes (0 = shut)
/mob/var/SharinganCopyMax = 2               // simultaneous copied-signature cap (4 = Copy-Ninja)

var/global/list/AllSignaturePaths = null    // flat index of every Signature skill type-path

// How many signatures the Sharingan is currently holding (counted live off the
// actual skills, so it can never desync from a save/relog).
/mob/proc/SharinganCopyCount()
	var/n = 0
	for(var/obj/Skills/s in src)
		if(s.copiedBy == "Sharingan")
			n++
	return n

/proc/BuildSignaturePathIndex()
	AllSignaturePaths = list()
	for(var/list/tier in list(Tier1, Tier2, Tier3, Tier4))
		for(var/k in tier)
			var/v = tier[k]
			if(istext(v))
				AllSignaturePaths[v] = 1
			else if(islist(v))
				for(var/p in v)
					AllSignaturePaths[p] = 1

/mob/proc/IsSignatureSkill(obj/Skills/Z)
	if(!Z) return 0
	if(Z.SignatureTechnique) return 1
	if(!AllSignaturePaths) BuildSignaturePathIndex()
	return AllSignaturePaths["[Z.type]"] ? 1 : 0

// Called from each skill-category use-hook for every Sharingan viewer. Copies Z
// only if the window is open, Z is a Signature we lack, and we have a free slot.
/mob/proc/TrySharinganCopy(obj/Skills/Z)
	if(!Z || Z.Copied) return
	if(world.time > SharinganCopyWindow) return
	if(!IsSignatureSkill(Z)) return
	if(locate(Z.type, src)) return                 // already know it (or already copied it)
	if(SharinganCopyCount() >= SharinganCopyMax) return
	var/obj/Skills/copiedSkill = new Z.type
	AddSkill(copiedSkill)
	copiedSkill.Copied = TRUE
	copiedSkill.copiedBy = "Sharingan"
	var/held = SharinganCopyCount()
	src << "<font color=red>Your Sharingan copies the signature technique <b>[Z]</b>! ([held]/[SharinganCopyMax])</font>"
	if(held >= SharinganCopyMax)
		SharinganCopyWindow = 0
		src << "<font color=red>Your Sharingan can hold no more copied signatures -- Forget Signature to release them.</font>"

/mob/proc/ForgetSharinganSignatures()
	var/found = 0
	for(var/obj/Skills/s in src)
		if(s.copiedBy == "Sharingan")
			src.DeleteSkill(s)
			found++
	SharinganCopyWindow = 0
	if(found)
		src << "<font color=red>You release the [found] signature\s your Sharingan had stored.</font>"
	else
		src << "You have no copied signatures to release."

// --- Crow-visions (Master of Illusions passive) ---------------------------
// While the eye is active in combat, periodically leaves a crow-illusion decoy
// (a HohoClone) that draws an enemy's aim and dies to a single hit.
/mob/var/tmp/CrowVisionsActive = 0

/mob/proc/StartCrowVisions()
	if(CrowVisionsActive) return
	CrowVisionsActive = 1
	spawn()
		while(src && CrowVisionsActive && Saga == "Sharingan")
			sleep(150)                               // ~15s between illusions
			if(!src || !CrowVisionsActive) break
			if(!CheckSpecial("Sharingan")) continue  // only while an eye is active
			if(!Target && (!BeingTargetted || !BeingTargetted.len)) continue   // combat only
			var/count = 0
			for(var/mob/Player/HohoClone/hc in view(6, src))
				if(hc.owner == src) count++
			if(count >= 2) continue
			var/turf/dest = get_step(src, pick(NORTH, SOUTH, EAST, WEST, NORTHEAST, SOUTHWEST))
			if(!dest || dest.density) dest = get_turf(src)
			if(!dest) continue
			var/mob/Player/HohoClone/c = new(dest)
			c.initClone(src)
			OMsg(src, "A flock of crows scatters, leaving a phantom of [src] behind!")
			for(var/mob/m in oview(6, src))
				if(m.Target == src && prob(60))
					m.Target = c
			spawn(90)
				if(c && c.loc) c.fadeAndDelete()

// --- The verbs (granted by the Sharingan saga at SagaLevel 2) --------------
/obj/Skills/Utility/Copy_Signature
	name = "Copy Signature"
	desc = "With your Sharingan active, open a 30-second window: the next signature techniques used in view are copied into your kit and kept until you Forget them."
	verb/Copy_Signature()
		set category = "Skills"
		set name = "Copy Signature"
		if(usr.Saga != "Sharingan" || !usr.CheckSpecial("Sharingan"))
			usr << "You must have your Sharingan active to read and copy signatures."
			return
		if(usr.SharinganCopyCount() >= usr.SharinganCopyMax)
			usr << "Your Sharingan already holds [usr.SharinganCopyMax] signature\s. Forget one first."
			return
		usr.SharinganCopyWindow = world.time + 300
		usr << "<font color=red>Your Sharingan spins -- for 30 seconds you will copy the next signature techniques you witness. ([usr.SharinganCopyCount()]/[usr.SharinganCopyMax] stored)</font>"
	verb/Forget_Signature()
		set category = "Skills"
		set name = "Forget Signature"
		usr.ForgetSharinganSignatures()