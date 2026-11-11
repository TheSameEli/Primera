/// Reapplying preferences replaces only cultural knowledge, preserving species, training and other grants.
/mob/living/carbon/human/proc/apply_sierra_background_languages(culture_id)
	var/list/profile = get_sierra_background_culture_profile(culture_id)
	var/list/languages = profile["languages"]
	remove_all_languages(source = LANGUAGE_BACKGROUND)
	grant_language(/datum/language/common, ALL, LANGUAGE_BACKGROUND)
	for(var/language in languages)
		grant_language(language, ALL, LANGUAGE_BACKGROUND)
	var/datum/quirk/csl/common_second_language = get_quirk(/datum/quirk/csl)
	common_second_language?.reremove_common()
	get_selected_language()
