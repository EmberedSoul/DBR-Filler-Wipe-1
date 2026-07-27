race
	quarter_saiyan
		name = "Quarter_Saiyan"
		desc = "A human with a trace of Saiyan blood running through their veins. Though their heritage is largely hidden beneath a human exterior, that fraction of warrior lineage stirs in moments of desperation."
		visual = 'Humans.png'
		passives = list("Tenacity" = 1, "Adrenaline" = 0.5, "Innovation" = 1)
		statPoints = 12
		power = 1
		strength = 1
		endurance = 1
		force = 1
		offense = 1
		defense = 1
		speed = 1
		anger = 1.5
		learning = 1.25
		intellect = 2
		imagination = 1.5
		classes = list("Dormant", "Awakend")
		class_info = list("Quarter-Saiyans who lean into their human side, trading raw power for adaptability and intellect.", "Quarter-Saiyans who have coaxed out their Saiyan blood, channeling it into bursts of aggression and resilience.")
		stats_per_class = list("Dormant" = list(1, 1.3, 1, 1.5, 1, 1.25), "Awakened" = list(1.3, 1.5, 1.3, 1, 1, 1))

		onFinalization(mob/user)
			if(user.Class == "Dormant")
				user.AngerMax = 1.75
				user.RPPMult = 1.3
				user.Intelligence = 2
				passives += list("Motivation" = 0.5)
			if(user.Class == "Awakened")
				user.AngerMax = 1.5
				user.RPPMult = 1.2
				user.Intelligence = 2

			if(!islist(user.race.transformations))
				user.race.transformations = list()
			user.race.transformations += new /transformation/saiyan/super_saiyan()
			user.race.transformations += new /transformation/saiyan/super_saiyan_2()

			..()
