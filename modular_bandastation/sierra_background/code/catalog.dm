/// Catalog resources are compiled into the RSC and loaded once; retired entries remain readable.
/proc/get_sierra_background_catalog()
	var/static/list/catalog
	if(isnull(catalog))
		var/list/cultures = json_decode(file2text('modular_bandastation/sierra_background/data/cultures.json'))
		var/list/worlds = json_decode(file2text('modular_bandastation/sierra_background/data/worlds.json'))
		var/list/factions = json_decode(file2text('modular_bandastation/sierra_background/data/factions.json'))
		var/list/religions = json_decode(file2text('modular_bandastation/sierra_background/data/religions.json'))
		var/list/wiki = json_decode(file2text('modular_bandastation/sierra_background/data/wiki_species.json'))
		var/list/faction_entries = factions["entries"]
		var/list/subfactions = faction_entries.Copy()
		subfactions["none"] = list("name" = "Без подразделения", "description" = "Принадлежность к партии или подразделению не указана.")
		catalog = list(
			"culture" = cultures["entries"] + wiki["cultures"],
			"homeworld" = worlds["entries"] + wiki["worlds"],
			"faction" = factions["entries"],
			"subfaction" = subfactions,
			"social" = get_sierra_social_catalog(),
			"religion" = religions["entries"] + wiki["religions"],
		)
	return catalog

/proc/get_sierra_background_dependencies()
	var/static/list/data
	if(isnull(data))
		data = json_decode(file2text('modular_bandastation/sierra_background/data/dependencies.json'))
	return data

/// Felinids and ceruleans inherit /human but have distinct native IDs.
/proc/get_sierra_background_species(datum/species/species_type)
	return ispath(species_type, /datum/species) ? initial(species_type.id) : null

/// Neutral values do not assign a different biography when an earlier choice changes.
/proc/get_sierra_background_neutral(category)
	return (category in list("culture", "homeworld")) ? "other" : "none"

/proc/get_sierra_background_default(category, datum/species/species_type = /datum/species/human)
	var/static/list/culture_defaults = list(
		"human" = "tsf_solar", "felinid" = "felinid_community", "lizard" = "moges_upbringing",
		"skrell" = "skrell_imperial", "plasmaman" = "plasmaman_technocrat", "moth" = "nian_caravan",
		"ethereal" = "ethereal_sprout", "tajaran" = "adomai_upbringing", "vulpkanin" = "altam_upbringing",
	)
	var/static/list/world_defaults = list(
		"human" = "Earth", "lizard" = "Moges", "skrell" = "KverrBalakk", "plasmaman" = "Boron",
		"moth" = "Zuviyen", "ethereal" = "sprout", "tajaran" = "Adomai", "vulpkanin" = "Altam",
	)
	var/species_id = get_sierra_background_species(species_type)
	switch(category)
		if("culture")
			return culture_defaults[species_id] || "other"
		if("homeworld")
			return world_defaults[species_id] || "other"
		if("faction", "subfaction", "social", "religion")
			return "none"
	return null

/proc/sierra_background_matches_species(list/entry, species_id)
	var/list/allowed_species = entry?["allowed_species"]
	var/list/excluded_species = entry?["excluded_species"]
	return (!islist(allowed_species) || (species_id in allowed_species)) && !(species_id in excluded_species)

/// A stored subdivision is the selected leaf; its ancestors supply the whole UI path.
/proc/get_sierra_faction_path(id)
	var/list/dependencies = get_sierra_background_dependencies()
	var/list/rules = dependencies["factions"]
	var/list/catalog = get_sierra_background_catalog()
	var/list/entries = catalog["faction"]
	var/list/path = list()
	while(id)
		if(!(id in entries) || (id in path))
			return list()
		path.Insert(1, id)
		var/list/rule = rules[id]
		id = rule?["parent"]
	return path

/// Only explicit source-backed restrictions are gates; territory tags alone do not prohibit migrants.
/proc/get_sierra_background_choices(category, datum/species/species_type = /datum/species/human, list/context)
	var/list/catalog = get_sierra_background_catalog()
	var/list/entries = catalog[category]
	var/list/dependencies = get_sierra_background_dependencies()
	var/list/faction_rules = dependencies["factions"]
	var/list/world_rules = dependencies["worlds"]
	var/list/culture_rules = dependencies["cultures"]
	var/species_id = get_sierra_background_species(species_type)
	var/list/choices = list()
	for(var/id in entries)
		var/list/entry = entries[id]
		if(category == "social")
			var/list/social_kind = get_sierra_social_kind(species_type)
			if(id == "none" && social_kind && !social_kind["can_omit"])
				continue
		var/list/rule
		switch(category)
			if("faction", "subfaction")
				rule = faction_rules[id]
			if("homeworld")
				rule = world_rules[id]
			if("culture")
				rule = culture_rules[id]
		if(category != "religion" && (!sierra_background_matches_species(entry, species_id) || !sierra_background_matches_species(rule, species_id)))
			continue
		if(category == "faction" && (rule?["parent"] || rule?["private"]))
			continue
		if(category == "subfaction" && id != "none")
			var/list/path = get_sierra_faction_path(id)
			if(length(path) < 2 || path[1] != context?["faction"])
				continue
			var/ancestors_valid = TRUE
			for(var/ancestor in path)
				var/list/ancestor_rule = faction_rules[ancestor]
				var/list/faction_entries = catalog["faction"]
				if(ancestor_rule?["private"] || !sierra_background_matches_species(ancestor_rule, species_id) || !sierra_background_matches_species(faction_entries[ancestor], species_id))
					ancestors_valid = FALSE
					break
			if(!ancestors_valid)
				continue
		if(category == "homeworld")
			if(!isnull(rule?["selectable"]) && !rule["selectable"])
				continue
			var/list/current_faction = faction_rules[context?["faction"]]
			var/list/residence_factions = current_faction?["residence_factions"]
			if(current_faction?["residence_restricted"] && islist(residence_factions) && entry["faction"] && !(entry["faction"] in residence_factions))
				continue
		if(context && category != "religion")
			var/list/allowed_factions = rule?["allowed_factions"]
			var/list/allowed_subfactions = rule?["allowed_subfactions"]
			var/list/allowed_homeworlds = rule?["allowed_homeworlds"]
			var/list/allowed_social = rule?["allowed_social"]
			if(islist(allowed_factions) && !(context["faction"] in allowed_factions))
				continue
			if(islist(allowed_subfactions) && !(context["subfaction"] in allowed_subfactions))
				continue
			if(islist(allowed_homeworlds) && !(context["homeworld"] in allowed_homeworlds))
				continue
			if(islist(allowed_social) && !(context["social"] in allowed_social))
				continue
		choices += id
	var/default_value = get_sierra_background_default(category, species_type)
	if(default_value in choices)
		choices -= default_value
		choices.Insert(1, default_value)
	if(category == "homeworld" && context?["faction"] && context["faction"] != "none")
		var/list/current_faction = faction_rules[context["faction"]]
		var/list/territories = current_faction?["residence_factions"]
		var/list/context_choices = list()
		for(var/id in choices)
			var/list/entry = entries[id]
			if(entry["faction"] in territories)
				context_choices += id
		choices = context_choices + (choices - context_choices)
	return choices

/// Context narrows the first list, never the source-backed pool available to a migrant.
/proc/get_sierra_background_context_choices(category, datum/species/species_type, list/context, list/choices)
	if(isnull(choices))
		choices = get_sierra_background_choices(category, species_type, context)
	if(!(category in list("homeworld", "culture")))
		return choices.Copy()
	var/list/dependencies = get_sierra_background_dependencies()
	var/list/pools = dependencies["context_pools"]
	var/list/faction_rules = dependencies["factions"]
	var/list/catalog = get_sierra_background_catalog()
	var/list/worlds = catalog["homeworld"]
	var/list/entries = catalog[category]
	var/list/path = get_sierra_faction_path(context?["subfaction"])
	if(!length(path) || path[1] != context?["faction"])
		path = get_sierra_faction_path(context?["faction"])
	var/list/context_ids
	var/list/territories
	if(category == "culture" && context?["homeworld"] && context["homeworld"] != "other")
		var/list/world_cultures = pools?["world_cultures"]
		context_ids = world_cultures?[context["homeworld"]]
		var/list/world_entry = worlds[context["homeworld"]]
		if(world_entry?["faction"])
			territories = list(world_entry["faction"])
	else
		var/list/faction_pools = pools?[category == "homeworld" ? "faction_worlds" : "faction_cultures"]
		for(var/index = length(path); index >= 1; index--)
			context_ids = faction_pools?[path[index]]
			if(islist(context_ids))
				break
		var/list/root_rule = length(path) ? faction_rules[path[1]] : null
		territories = root_rule?["residence_factions"]
	if(!islist(context_ids) && !length(territories))
		return choices.Copy()
	var/list/context_choices = list()
	for(var/id in choices)
		var/list/entry = entries[id]
		if(id == get_sierra_background_neutral(category) || (id in context_ids) || (!islist(context_ids) && (entry["faction"] in territories)))
			context_choices += id
	return context_choices

/// Preserve historical text IDs on load; interactive writes still require a currently valid choice.
/proc/normalize_sierra_background_value(category, value, datum/species/species_type)
	var/static/list/aliases = list(
		"culture" = list("Earther" = "tsf_solar", "Other Culture" = "other", "OtherCulture" = "other"),
		"homeworld" = list("Other" = "other"),
		"faction" = list("Other Faction" = "none"),
		"religion" = list("Other Religion" = "other", "None" = "none", "Atheism" = "atheism", "Agnosticism" = "agnosticism"),
	)
	if(!istext(value) || length_char(value) > 128)
		return get_sierra_background_default(category, species_type)
	if(category == "faction" && value == ("Nano" + "Trasen"))
		return "Nanotrasen"
	var/list/category_aliases = aliases[category]
	return category_aliases?[value] || value
