// ==========================================================================
// VANGUARD SPIRIT — a new Companion type
// --------------------------------------------------------------------------
// A universal, fixed-build bruiser companion. It extends the BASE
// /obj/Skills/Companion (not the Squad or arcane_follower subtypes), so it
// inherits the working base mob/Player/AI brain and the functional control
// verbs — Companion Summon / Attack / Stop / Follow / Stay / Mode / Def /
// Focus Target / Customize (category "Companion").
//
// Design (per spec):
//  - Role: attacker / bruiser (melee auto-hits + a low-HP enrage).
//  - Control: HYBRID. Default mode is "Auto", so it auto-engages and protects
//    the owner; the inherited Attack/Stop verbs still work as manual overrides
//    (they drive the base AI's Chase/SetTarget, which plain Player/AI honors —
//    this is exactly what the Nymph's custom state machine failed to do).
//  - Stats: FIXED SHEET. The stat mods (the build) are hard-coded below rather
//    than inherited from the owner. Power scales as a fixed fraction of the
//    owner (Squad-style) via companion_potential/companion_bpm = -1; see note.
//  - Acquisition: universal (granted to every player in addMissingSkills).
//
// All numbers here are tunable placeholders.
// ==========================================================================

/obj/Skills/Companion/Vanguard
	name = "Vanguard Spirit"
	desc = "Summon a Vanguard Spirit: a fixed-build bruiser that auto-fights at your side and can be ordered directly (Companion verbs)."
	Mastery = 1
	cooldown = 100          // world.realtime is deciseconds -> ~10s resummon gate
	ai_count = 1

	companion_name = "Vanguard Spirit"
	companion_icon = 'Icons/Characters/Androids/Android11.dmi' // placeholder art; players can reskin via Customize: Companion
	companion_mode = "Auto" // hybrid: auto-fights + protects; Attack/Stop still override

	// --- FIXED STAT SHEET (the build; NOT inherited from the owner) ---
	// Tanky melee bruiser: high Strength/Endurance/Defense/Offense, low Force/Speed.
	companion_strmod = 3
	companion_endmod = 3
	companion_defmod = 3
	companion_offmod = 2.5
	companion_formod = 1
	companion_spdmod = 1.5
	companion_recovmod = 2
	companion_intimidation = 1.5
	companion_skill_aggression = 1 // ai_spammer: how eagerly it throws skills

	// Power level: -1 keeps the Squad-style fraction-of-owner scaling
	// (0.5 x (1 + Mastery/4) of the owner). The BUILD stays fixed; only the raw
	// power tracks the owner, so the companion is neither useless for veterans
	// nor oppressive for newbies. Set these to fixed numbers for truly
	// owner-independent absolute power instead.
	companion_potential = -1
	companion_bpm = -1

	// --- Bruiser kit + a signature low-HP enrage ---
	// Turns_Red is an autonomous buff: the base AI (scrollSlotless in aiGain.dm)
	// auto-triggers it at its NeedsHealth threshold, so the Vanguard rages when
	// it drops low.
	companion_techniques = list(\
		"/obj/Skills/AutoHit/Flying_Kick",\
		"/obj/Skills/AutoHit/Force_Palm",\
		"/obj/Skills/AutoHit/Lariat",\
		"/obj/Skills/AutoHit/Massacre",\
		"/obj/Skills/Buffs/SlotlessBuffs/Autonomous/Turns_Red")
