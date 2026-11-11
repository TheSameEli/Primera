/// All values use the native character savefile and slot lifecycle.
/datum/preference/choiced/sierra_background
	abstract_type = /datum/preference/choiced/sierra_background
	savefile_identifier = PREFERENCE_CHARACTER
	category = "sierra_background"
	priority = PREFERENCE_PRIORITY_NAMES
	can_randomize = FALSE
	should_update_preview = FALSE
	var/background_category
	var/background_label

/datum/preference/choiced/sierra_background/init_possible_values()
	var/list/catalog = get_sierra_background_catalog()
	var/list/entries = catalog[background_category]
	var/list/choices = list()
	for(var/entry in entries)
		choices += entry
	return choices

/datum/preference/choiced/sierra_background/create_default_value()
	return get_sierra_background_default(background_category)

/datum/preference/choiced/sierra_background/create_informed_default_value(datum/preferences/preferences)
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/value = get_sierra_background_default(background_category, species_type)
	var/list/choices = get_sierra_background_choices(background_category, species_type, preferences.sierra_background_context(background_category))
	return (value in choices) ? value : get_sierra_background_neutral(background_category)

/datum/preference/choiced/sierra_background/deserialize(input, datum/preferences/preferences)
	var/species_type = preferences?.read_preference(/datum/preference/choiced/species) || /datum/species/human
	var/value = normalize_sierra_background_value(background_category, input, species_type)
	if(preferences && !isnull(input) && value != input)
		preferences.recently_updated_keys |= type
	return value

/datum/preference/choiced/sierra_background/is_valid(value, datum/preferences/preferences)
	if(!istext(value))
		return FALSE
	var/species_type = preferences?.read_preference(/datum/preference/choiced/species) || /datum/species/human
	return value in get_sierra_background_choices(background_category, species_type, preferences?.sierra_background_context(background_category))

/datum/preference/choiced/sierra_background/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	// Unresolved historical choices remain in the slot, not as contradictory runtime facts.
	if(is_valid(value, preferences))
		target.dna.features[savefile_key] = value

/datum/preference/choiced/sierra_background/culture
	savefile_key = "sierra_culture"
	background_category = "culture"
	background_label = "Культура / воспитание"

/datum/preference/choiced/sierra_background/culture/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	..()
	target.apply_sierra_background_languages(target.dna.features[savefile_key] || "other")

/datum/preference/choiced/sierra_background/homeworld
	savefile_key = "sierra_homeworld"
	background_category = "homeworld"
	background_label = "Место жительства"

/datum/preference/choiced/sierra_background/faction
	savefile_key = "sierra_faction"
	background_category = "faction"
	background_label = "Фракция / текущая принадлежность"

/datum/preference/choiced/sierra_background/faction/deserialize(input, datum/preferences/preferences)
	var/list/dependencies = get_sierra_background_dependencies()
	var/list/rules = dependencies["factions"]
	var/list/rule = istext(input) ? rules[input] : null
	if(preferences && !(type in preferences.value_cache))
		var/list/save_data = preferences.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)
		var/old_child = save_data?["sierra_subfaction"]
		var/list/child_rule = istext(old_child) ? rules[old_child] : null
		if(child_rule?["previous_parent"] && child_rule["previous_parent"] == input && !child_rule["parent"])
			preferences.value_cache[/datum/preference/choiced/sierra_background/subfaction] = "none"
			preferences.recently_updated_keys |= /datum/preference/choiced/sierra_background/subfaction
			preferences.recently_updated_keys |= type
			return old_child
		if(!rule?["parent"] || rule["private"])
			return ..()
		var/list/path = get_sierra_faction_path(input)
		if(!length(path))
			return ..()
		if(isnull(old_child) || old_child == "none")
			preferences.value_cache[/datum/preference/choiced/sierra_background/subfaction] = input
			preferences.recently_updated_keys |= /datum/preference/choiced/sierra_background/subfaction
		preferences.recently_updated_keys |= type
		return path[1]
	return ..()

/datum/preference/choiced/sierra_background/subfaction
	savefile_key = "sierra_subfaction"
	background_category = "subfaction"
	background_label = "Подразделение / подфракция"

/datum/preference/choiced/sierra_background/religion
	savefile_key = "sierra_religion"
	background_category = "religion"
	background_label = "Вера"

/datum/preference/choiced/sierra_background/social
	savefile_key = "sierra_social"
	background_category = "social"
	background_label = "Социальная принадлежность"

/datum/preference/choiced/sierra_background/social/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	if(get_sierra_social_kind(target.dna.species.type) && !ispath(target.dna.species.type, /datum/species/skrell))
		return ..()

/// Only read earlier dependencies: faction -> residence -> social -> culture; faith has no parents.
/datum/preferences/proc/sierra_background_context(category)
	var/list/context = list()
	if(category in list("faction", "religion"))
		return context
	context["faction"] = read_preference(/datum/preference/choiced/sierra_background/faction)
	if(category == "subfaction")
		return context
	context["subfaction"] = read_preference(/datum/preference/choiced/sierra_background/subfaction)
	if(category == "homeworld")
		return context
	context["homeworld"] = read_preference(/datum/preference/choiced/sierra_background/homeworld)
	if(category == "culture")
		var/species_type = read_preference(/datum/preference/choiced/species)
		var/list/kind = get_sierra_social_kind(species_type)
		var/datum/preference/social_preference = GLOB.preference_entries_by_key[kind?["preference"]]
		context["social"] = social_preference ? read_preference(social_preference.type) : "none"
	return context

/// Preview and application share the same dependency reconciliation.
/datum/preferences/proc/sierra_background_resets(changed_preference, preview_value = null, preview_subfaction = null, preserve_historical = FALSE)
	var/list/dependent_categories = list()
	switch(changed_preference)
		if("species")
			dependent_categories = list("faction", "subfaction", "homeworld", "social", "culture")
		if("sierra_faction")
			dependent_categories = list("subfaction", "homeworld", "social", "culture")
		if("sierra_subfaction")
			dependent_categories = list("homeworld", "social", "culture")
		if("sierra_homeworld")
			dependent_categories = list("social", "culture")
		if("sierra_social", "skrell_caste")
			dependent_categories = list("culture")
	if(!length(dependent_categories))
		return list()
	var/list/preference_types = list(
		"faction" = /datum/preference/choiced/sierra_background/faction,
		"subfaction" = /datum/preference/choiced/sierra_background/subfaction,
		"homeworld" = /datum/preference/choiced/sierra_background/homeworld,
		"social" = /datum/preference/choiced/sierra_background/social,
		"culture" = /datum/preference/choiced/sierra_background/culture,
	)
	var/species_type = read_preference(/datum/preference/choiced/species)
	var/list/kind = get_sierra_social_kind(species_type)
	var/datum/preference/social_preference = GLOB.preference_entries_by_key[kind?["preference"]]
	var/list/values = list(
		"faction" = read_preference(/datum/preference/choiced/sierra_background/faction),
		"subfaction" = read_preference(/datum/preference/choiced/sierra_background/subfaction),
		"homeworld" = read_preference(/datum/preference/choiced/sierra_background/homeworld),
		"social" = social_preference ? read_preference(social_preference.type) : "none",
	)
	if(!isnull(preview_value))
		var/datum/preference/choiced/sierra_background/changed = GLOB.preference_entries_by_key[changed_preference]
		if(istype(changed))
			values[changed.background_category] = preview_value
		else if(changed_preference == "skrell_caste")
			values["social"] = preview_value
	if(!isnull(preview_subfaction))
		values["subfaction"] = preview_subfaction
	var/list/resets = list()
	for(var/category in dependent_categories)
		var/preference_type = preference_types[category]
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_type]
		var/value = (category == "subfaction" && !isnull(preview_subfaction)) ? preview_subfaction : read_preference(preference_type)
		var/list/context = list()
		if(category != "faction")
			context["faction"] = values["faction"]
		if(category in list("homeworld", "social", "culture"))
			context["subfaction"] = values["subfaction"]
		if(category in list("social", "culture"))
			context["homeworld"] = values["homeworld"]
		if(category == "culture")
			context["social"] = values["social"]
		var/list/choices = get_sierra_background_choices(category, species_type, context)
		if(!(value in choices))
			if(preserve_historical)
				var/list/catalog = get_sierra_background_catalog()
				var/list/entries = catalog[category]
				var/list/dependencies = get_sierra_background_dependencies()
				var/list/world_rules = dependencies["worlds"]
				var/list/world_rule = world_rules[value]
				if(!entries[value] || (category == "homeworld" && !isnull(world_rule?["selectable"]) && !world_rule["selectable"]))
					continue
			var/neutral_value = get_sierra_background_neutral(preference.background_category)
			if(neutral_value in choices)
				resets[preference_type] = neutral_value
				values[category] = neutral_value
	return resets

/datum/preferences
	/// Slot-local notices; no personal text or historical identifier is overwritten by them.
	var/list/sierra_background_load_corrections = list()

/// Known incompatible combinations are cleared; retired or unknown IDs remain visible for repair.
/datum/preferences/proc/reconcile_sierra_background_on_load()
	var/list/catalog = get_sierra_background_catalog()
	var/list/resets = sierra_background_resets("species", preserve_historical = TRUE)
	for(var/preference_type in resets)
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_type]
		var/list/entries = catalog[preference.background_category]
		var/list/old_entry = entries[read_preference(preference_type)]
		sierra_background_load_corrections[preference.background_category] = "Сохранённый вариант «[old_entry["name"]]» несовместим с текущей анкетой и очищен. Личные подробности сохранены."
		value_cache[preference_type] = resets[preference_type]
		recently_updated_keys |= preference_type

/// Explicit edits reset only incompatible descendants. Passive reads never rewrite old biographies.
/datum/preferences/proc/sanitize_sierra_background(changed_preference)
	var/datum/preference/choiced/sierra_background/changed = GLOB.preference_entries_by_key[changed_preference]
	if(istype(changed))
		sierra_background_load_corrections -= changed.background_category
	var/list/resets = sierra_background_resets(changed_preference)
	for(var/preference_type in resets)
		value_cache[preference_type] = resets[preference_type]
		recently_updated_keys |= preference_type

/// Revalidate before native serialization, including direct updates outside the UI action.
/datum/preferences/proc/validate_sierra_background_for_save()
	var/valid = TRUE
	for(var/preference_type in subtypesof(/datum/preference/choiced/sierra_background))
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_type]
		if(!preference.is_valid(read_preference(preference_type), src))
			// Do not serialize an invalid edit or overwrite a historical value still on disk.
			recently_updated_keys -= preference_type
			valid = FALSE
	return valid

/datum/preference_middleware/sierra_background
	action_delegations = list("sierra_background_choose" = PROC_REF(choose_background))

/// Validate a tree selection before either half is written, using native slot preferences.
/datum/preference_middleware/sierra_background/proc/choose_background(list/params, mob/user)
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	if(params["slot"] != preferences.default_slot || params["species"] != get_sierra_background_species(species_type))
		return FALSE
	var/preference_key = params["preference"]
	if(!istext(preference_key))
		return FALSE
	var/datum/preference/preference = GLOB.preference_entries_by_key[preference_key]
	if(!istype(preference, /datum/preference/choiced/sierra_background) && !istype(preference, /datum/preference/choiced/skrell_caste))
		return FALSE
	var/value = params["value"]
	if(!istext(value) || !preference.is_accessible(preferences) || !preference.is_valid(value, preferences))
		return FALSE
	if(preference_key != "sierra_faction")
		if(!isnull(params["subfaction"]))
			return FALSE
		return preferences.update_preference(preference, value)
	var/subfaction = params["subfaction"]
	if(isnull(subfaction))
		subfaction = "none"
	if(!istext(subfaction))
		return FALSE
	var/list/choices = get_sierra_background_choices("subfaction", species_type, list("faction" = value))
	var/datum/preference/choiced/sierra_background/subfaction/subdivision_preference = GLOB.preference_entries[/datum/preference/choiced/sierra_background/subfaction]
	if(!(subfaction in choices) || !subdivision_preference.is_accessible(preferences))
		return FALSE
	// Both native values are validated above; reconcile only once against the final pair.
	preferences.value_cache[preference.type] = value
	preferences.value_cache[subdivision_preference.type] = subfaction
	preferences.recently_updated_keys |= list(preference.type, subdivision_preference.type)
	preferences.sanitize_sierra_background("sierra_faction")
	return TRUE

/datum/preference_middleware/sierra_background/proc/choice_details(list/row, datum/species/species_type)
	var/list/children = list()
	var/list/effects = list()
	var/list/catalog = get_sierra_background_catalog()
	var/list/choices = row["choices"]
	var/list/preview_ids = choices.Copy()
	if(row["category"] == "faction")
		var/list/dependencies = get_sierra_background_dependencies()
		var/list/rules = dependencies["factions"]
		for(var/root_id in row["choices"])
			var/list/subdivisions = get_sierra_background_choices("subfaction", species_type, list("faction" = root_id))
			subdivisions -= "none"
			preview_ids |= subdivisions
			for(var/child_id in subdivisions)
				var/list/rule = rules[child_id]
				var/parent = rule["parent"]
				if(!children[parent])
					children[parent] = list()
				children[parent] += child_id
	for(var/id in preview_ids)
		var/list/resets
		if(row["category"] == "faction")
			var/list/path = get_sierra_faction_path(id)
			resets = preferences.sierra_background_resets(row["preference"], path[1], length(path) > 1 ? id : "none")
		else
			resets = preferences.sierra_background_resets(row["preference"], id)
		var/list/messages = list()
		for(var/preference_type in resets)
			var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_type]
			// The tree explicitly selects this child; warn only about other dependent fields.
			if(preference.background_category == "subfaction")
				continue
			var/list/entries = catalog[preference.background_category]
			var/list/old_entry = entries[preferences.read_preference(preference_type)]
			var/list/new_entry = entries[resets[preference_type]]
			messages += "[preference.background_label]: [old_entry?["name"] || "Прежний выбор"] → [new_entry?["name"]]."
		effects[id] = messages
	row["choice_effects"] = effects
	if(row["category"] == "faction")
		row["choice_children"] = children

/datum/preference_middleware/sierra_background/get_constant_data()
	var/list/catalog = get_sierra_background_catalog()
	var/list/ui_catalog = list()
	for(var/category in catalog)
		var/list/entries = catalog[category]
		var/list/ui_entries = list()
		for(var/id in entries)
			var/list/entry = entries[id]
			ui_entries[id] = list("name" = entry["name"], "description" = entry["description"], "extra" = entry["extra"])
		ui_catalog[category] = ui_entries
	return ui_catalog

/datum/preference_middleware/sierra_background/pre_set_preference(mob/user, preference, value)
	if(preference == "skrell_caste")
		var/datum/preference/choiced/caste = GLOB.preference_entries[/datum/preference/choiced/skrell_caste]
		return !caste.is_accessible(preferences) || !caste.is_valid(value, preferences)
	var/datum/preference/choiced/sierra_background/entry = GLOB.preference_entries_by_key[preference]
	if(!istype(entry))
		return FALSE
	return !entry.is_valid(value, preferences)

/datum/preference_middleware/sierra_background/post_set_preference(mob/user, preference, value)
	preferences.sanitize_sierra_background(preference)

/datum/preference_middleware/sierra_background/get_ui_data(mob/user)
	var/list/rows = list()
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/list/catalog = get_sierra_background_catalog()
	var/list/preference_types = list(
		/datum/preference/choiced/sierra_background/faction,
		/datum/preference/choiced/sierra_background/subfaction,
		/datum/preference/choiced/sierra_background/homeworld,
		/datum/preference/choiced/sierra_background/social,
		/datum/preference/choiced/sierra_background/culture,
		/datum/preference/choiced/sierra_background/religion,
	)
	for(var/preference_type in preference_types)
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_type]
		var/category = preference.background_category
		var/list/choices = get_sierra_background_choices(category, species_type, preferences.sierra_background_context(category))
		if(category == "social")
			var/list/social_kind = get_sierra_social_kind(species_type)
			if(!social_kind)
				continue
			if(social_kind["preference"] != preference.savefile_key)
				var/datum/preference/social_preference = GLOB.preference_entries_by_key[social_kind["preference"]]
				var/value = preferences.read_preference(social_preference.type)
				var/list/row = list("category" = "social", "preference" = social_kind["preference"], "label" = social_kind["label"], "value" = value, "choices" = choices, "selected_name" = catalog["social"][value]?["name"])
				choice_details(row, species_type)
				rows += list(row)
				continue
		var/value = preferences.read_preference(preference_type)
		var/list/entries = catalog[category]
		var/list/row = list("category" = category, "preference" = preference.savefile_key, "label" = preference.background_label, "value" = value, "choices" = choices, "selected_name" = entries[value]?["name"] || value)
		if(category in list("homeworld", "culture"))
			row["context_choices"] = get_sierra_background_context_choices(category, species_type, preferences.sierra_background_context(category), choices)
		row["reset_reason"] = preferences.sierra_background_load_corrections[category]
		if(category == "social")
			var/list/social_kind = get_sierra_social_kind(species_type)
			row["label"] = social_kind["label"]
		if(!(value in choices))
			row["invalid_reason"] = "Сохранённый вариант больше недоступен для этой анкеты. Он сохранён для справки; выберите допустимый вариант. Личные подробности остаются без изменений."
		var/datum/preference/text/sierra_background_notes/notes_preference = GLOB.preference_entries_by_key["[preference.savefile_key]_notes"]
		if(notes_preference)
			row["notes"] = preferences.read_preference(notes_preference.type)
			row["notes_preference"] = notes_preference.savefile_key
			row["notes_max_length"] = notes_preference.maximum_value_length - 1
			row["notes_prompt"] = notes_preference.notes_prompt
		if(category == "culture")
			row["language_names"] = (value in choices) ? get_sierra_background_language_names(value) : list()
			row["name_generation"] = get_sierra_background_name_generation_label(preferences)
		choice_details(row, species_type)
		rows += list(row)
	return list("sierra_background" = rows)
