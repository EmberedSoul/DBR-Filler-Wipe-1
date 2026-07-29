mob/proc/Meditation()
	set waitfor=0
	var/obj/Skills/Meditate/med
	for(var/obj/Skills/Meditate/m in src)
		med = m
		break
	if(med.delay)
		sleep(5)
		return

	// Meditating rouses any fainted Pokemon so they can be sent out again.
	if(fainted_pokemon && fainted_pokemon.len)
		fainted_pokemon.Cut()
		src << "<font color='#88ff88'>Your fainted Pokemon have recovered and can be summoned again.</font>"

	spawn()
		if(src.VaizardHealth>0)
			src.VaizardHealth=0
		if(passive_handler.Get("AbsorbingDamage"))
			AbsorbingDamage = 0
		WarmingUpBonus = 0
		if(passive_handler["Shellshocked"])
			passive_handler.Set("Shellshocked", 0)
		if(isRace(BEASTKIN) && race?:Racial == "Heart of The Beastkin")
			if(passive_handler["Grit"] == 0)
				passive_handler.Set("Grit", 1)
		/*if(length(magatamaBeads))
			loseMagatama()*/
		med.delayTimer()


