/proc/get_sierra_social_data()
	var/static/list/data
	if(isnull(data))
		data = json_decode(file2text('modular_bandastation/sierra_background/data/social.json'))
	return data

/proc/get_sierra_social_kind(datum/species/species_type)
	var/list/data = get_sierra_social_data()
	var/list/species_kinds = data["species"]
	return species_kinds[get_sierra_background_species(species_type)]

/proc/get_sierra_social_catalog()
	var/list/data = get_sierra_social_data()
	var/list/source_entries = data["entries"]
	var/list/entries = source_entries.Copy()
	var/list/castes = get_skrell_castes()
	for(var/id in castes)
		var/list/entry = castes[id]
		var/list/social_entry = entry.Copy()
		social_entry["allowed_species"] = list("skrell")
		entries[id] = social_entry
	return entries

/datum/preference/choiced/sierra_background/social/is_accessible(datum/preferences/preferences)
	if(!preferences || !..())
		return FALSE
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/list/kind = get_sierra_social_kind(species_type)
	return kind?["preference"] == savefile_key

/datum/preference/choiced/sierra_background/social/is_valid(value, datum/preferences/preferences)
	// The native loader visits this dormant preference for species using another key or no social field.
	if(value == "none")
		return TRUE
	return ..()
