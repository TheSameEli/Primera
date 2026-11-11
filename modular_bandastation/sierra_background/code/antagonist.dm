/// This catalogue supplies optional biographies, never antagonist assignment or equipment.
/proc/get_sierra_antagonist_catalog()
	var/static/list/catalog
	if(isnull(catalog))
		catalog = json_decode(file2text('modular_bandastation/sierra_background/data/antagonist.json'))
	return catalog

/proc/get_sierra_antagonist_choices(category, organization = "none")
	var/list/catalog = get_sierra_antagonist_catalog()
	var/list/entries = catalog[category]
	var/list/choices = list()
	for(var/id in entries)
		var/list/entry = entries[id]
		if(category == "subgroups" && id != "none" && entry["parent_faction"] != organization)
			continue
		choices += id
	return choices

/// Values remain in the native character slot and are deliberately not applied to the body.
/datum/preference/choiced/sierra_antagonist
	abstract_type = /datum/preference/choiced/sierra_antagonist
	savefile_identifier = PREFERENCE_CHARACTER
	category = "sierra_antagonist_private"
	priority = PREFERENCE_PRIORITY_NAMES
	can_randomize = FALSE
	should_update_preview = FALSE
	var/catalog_category

/datum/preference/choiced/sierra_antagonist/init_possible_values()
	var/list/catalog = get_sierra_antagonist_catalog()
	var/list/entries = catalog[catalog_category]
	return assoc_to_keys(entries)

/datum/preference/choiced/sierra_antagonist/create_default_value()
	return "none"

/datum/preference/choiced/sierra_antagonist/deserialize(input, datum/preferences/preferences)
	var/value = is_valid(input, preferences) ? input : create_default_value()
	if(preferences && !isnull(input) && input != value)
		preferences.recently_updated_keys |= type
	return value

/datum/preference/choiced/sierra_antagonist/is_valid(value, datum/preferences/preferences)
	if(!istext(value))
		return FALSE
	var/organization = "none"
	if(catalog_category == "subgroups" && preferences)
		organization = preferences.read_preference(/datum/preference/choiced/sierra_antagonist/faction)
	return value in get_sierra_antagonist_choices(catalog_category, organization)

/datum/preference/choiced/sierra_antagonist/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/choiced/sierra_antagonist/compile_ui_data(mob/user, value)
	// Only the dedicated owner preferences panel receives the actual values.
	return null

/datum/preference/choiced/sierra_antagonist/faction
	savefile_key = "sierra_antagonist_faction"
	catalog_category = "organizations"

/datum/preference/choiced/sierra_antagonist/subfaction
	savefile_key = "sierra_antagonist_subfaction"
	catalog_category = "subgroups"

/datum/preference/text/sierra_antagonist_notes
	savefile_key = "sierra_antagonist_notes"
	savefile_identifier = PREFERENCE_CHARACTER
	category = "sierra_antagonist_private"
	priority = PREFERENCE_PRIORITY_NAMES
	can_randomize = FALSE
	should_update_preview = FALSE
	maximum_value_length = 1001

/datum/preference/text/sierra_antagonist_notes/deserialize(input, datum/preferences/preferences)
	if(!istext(input))
		return ""
	var/static/regex/control_characters = regex(@"[\x00-\x08\x0B-\x1F\x7F]", "g")
	var/carriage_return = ascii2text(13)
	input = replacetext(replacetext(input, "[carriage_return]\n", "\n"), carriage_return, "\n")
	return STRIP_HTML_FULL(control_characters.Replace(input, ""), maximum_value_length)

/datum/preference/text/sierra_antagonist_notes/is_valid(value, datum/preferences/preferences)
	return istext(value) && length_char(value) < maximum_value_length

/datum/preference/text/sierra_antagonist_notes/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/text/sierra_antagonist_notes/compile_ui_data(mob/user, value)
	return null

/datum/preferences/proc/sanitize_sierra_antagonist()
	var/datum/preference/subfaction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/subfaction]
	var/current = read_preference(subfaction.type)
	if(!subfaction.is_valid(current, src))
		update_preference(subfaction, "none")

/// No selection or personal text is put into a static preferences asset.
/datum/preferences/proc/get_sierra_antagonist_ui_data()
	sanitize_sierra_antagonist()
	var/list/catalog = get_sierra_antagonist_catalog()
	var/organization = read_preference(/datum/preference/choiced/sierra_antagonist/faction)
	var/list/result = list()
	var/list/categories = list(
		"organization" = list("organizations", /datum/preference/choiced/sierra_antagonist/faction),
		"subgroup" = list("subgroups", /datum/preference/choiced/sierra_antagonist/subfaction),
	)
	for(var/key in categories)
		var/list/config = categories[key]
		var/list/entries = catalog[config[1]]
		var/datum/preference/preference = GLOB.preference_entries[config[2]]
		var/value = read_preference(preference.type)
		var/list/options = list()
		for(var/id in get_sierra_antagonist_choices(config[1], organization))
			var/list/entry = entries[id]
			options += list(list("id" = id, "name" = entry["name"], "description" = entry["description"]))
		var/list/selected = entries[value]
		result[key] = list(
			"preference" = preference.savefile_key,
			"value" = value,
			"choices" = options,
			"selected_name" = selected?["name"],
		)
	var/datum/preference/text/notes = GLOB.preference_entries[/datum/preference/text/sierra_antagonist_notes]
	result["notes"] = list(
		"preference" = notes.savefile_key,
		"value" = read_preference(notes.type),
		"max_length" = notes.maximum_value_length - 1,
		"prompt" = "Как персонаж связан с выбранной организацией? Заметка видна только вам в личном окне предателя после получения роли и не определяет назначенного нанимателя.",
	)
	return result

/datum/preference_middleware/sierra_antagonist

/datum/preference_middleware/sierra_antagonist/pre_set_preference(mob/user, preference, value)
	var/datum/preference/choiced/sierra_antagonist/entry = GLOB.preference_entries_by_key[preference]
	if(!istype(entry))
		return FALSE
	return !entry.is_valid(value, preferences)

/datum/preference_middleware/sierra_antagonist/post_set_preference(mob/user, preference, value)
	if(preference == "sierra_antagonist_faction")
		preferences.sanitize_sierra_antagonist()

/datum/preference_middleware/sierra_antagonist/on_new_character(mob/user)
	preferences.sanitize_sierra_antagonist()

/datum/preference_middleware/sierra_antagonist/get_ui_data(mob/user)
	if(user && user.client != preferences.parent)
		return list()
	return list("sierra_antagonist" = preferences.get_sierra_antagonist_ui_data())

/datum/mind
	/// Server-owned snapshot for this character, excluded from DNA, records and public serialization.
	var/list/sierra_antagonist_background

/datum/mind/proc/capture_sierra_antagonist_background(datum/preferences/preferences)
	if(!isnull(sierra_antagonist_background) || !preferences)
		return
	preferences.sanitize_sierra_antagonist()
	sierra_antagonist_background = list(
		"organization" = preferences.read_preference(/datum/preference/choiced/sierra_antagonist/faction),
		"subgroup" = preferences.read_preference(/datum/preference/choiced/sierra_antagonist/subfaction),
		"notes" = preferences.read_preference(/datum/preference/text/sierra_antagonist_notes),
	)

/// The biography stays separate from this round's employer, including a conflicting past affiliation.
/datum/antagonist/traitor/proc/get_sierra_antagonist_background(mob/user)
	if(!owner || user != owner.current || user?.mind != owner || !(src in owner.antag_datums))
		return null
	var/list/background = owner.sierra_antagonist_background
	var/notes = background?["notes"]
	if(!istext(notes) || !length(trimtext(notes)))
		return null
	var/list/catalog = get_sierra_antagonist_catalog()
	var/list/organizations = catalog["organizations"]
	var/organization_id = background["organization"]
	var/list/organization = organizations[organization_id]
	var/subgroup_id = background["subgroup"]
	var/list/subgroups = catalog["subgroups"]
	var/list/subgroup = subgroups[subgroup_id]
	return list(
		"organization" = organization_id != "none" ? organization?["name"] : null,
		"subgroup" = subgroup?["parent_faction"] == organization_id ? subgroup?["name"] : null,
		"notes" = notes,
	)
