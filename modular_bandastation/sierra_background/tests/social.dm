/// A species profile owns the heading, native save key and optionality together.
/datum/unit_test/sierra_background_social_catalog

/datum/unit_test/sierra_background_social_catalog/Run()
	var/list/data = get_sierra_social_data()
	var/list/kinds = data["species"]
	var/list/catalog = get_sierra_social_catalog()
	for(var/species_id in kinds)
		var/list/kind = kinds[species_id]
		var/species_type = GLOB.species_list[species_id]
		TEST_ASSERT(species_type, "Social profile [species_id] has no native species.")
		TEST_ASSERT(length(kind["label"]), "Social profile [species_id] has no heading.")
		var/datum/preference/preference = GLOB.preference_entries_by_key[kind["preference"]]
		TEST_ASSERT(preference, "Social profile [species_id] has no native save key.")
		TEST_ASSERT(preference.savefile_identifier == PREFERENCE_CHARACTER, "Social membership escaped character-slot storage.")
		var/list/choices = get_sierra_background_choices("social", species_type)
		TEST_ASSERT_EQUAL(("none" in choices), kind["can_omit"], "Social optionality disagrees with its species profile.")
		for(var/choice in choices)
			var/list/entry = catalog[choice]
			TEST_ASSERT(length(entry?["name"]), "Social choice [choice] has no readable name.")
			TEST_ASSERT(length(entry?["description"]), "Social choice [choice] has no description.")
			TEST_ASSERT(sierra_background_matches_species(entry, species_id), "Social choice [choice] belongs to another species.")
	var/list/vulp_choices = get_sierra_background_choices("social", /datum/species/vulpkanin)
	for(var/choice in list("vulp_ashtar", "vulp_rakh", "vulp_mzmanulin", "vulp_refugee", "none"))
		TEST_ASSERT(choice in vulp_choices, "Author-approved Vulpkanin membership [choice] is missing.")
	TEST_ASSERT_EQUAL(length(vulp_choices), 5, "Vulpkanin membership contains duplicate or unconfirmed options.")
	TEST_ASSERT_EQUAL(catalog["vulp_rakh"]["name"], "Рахт", "The clan name does not match the approved spelling.")
	TEST_ASSERT_EQUAL(length(get_sierra_background_choices("social", /datum/species/skrell)), 5, "Genetic Skrell castes changed during the social audit.")
	var/list/house_descriptions = list()
	for(var/house_id in list("tajaran_kaitam", "tajaran_hadii", "tajaran_sendai"))
		var/list/house = catalog[house_id]
		TEST_ASSERT(house, "The Tajaran house [house_id] lost its existing saved ID.")
		TEST_ASSERT(!(house["description"] in house_descriptions), "Tajaran house [house_id] repeats another house's description.")
		house_descriptions += house["description"]

/// Exercise the actual middleware after each native species change, including hidden fields.
/datum/unit_test/sierra_background_social_species_changes
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_social_species_changes/Run()
	var/datum/preferences/preferences = make_preferences()
	for(var/species_id in GLOB.species_list)
		var/species_type = GLOB.species_list[species_id]
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, species_id), "Could not switch to native species [species_id].")
		var/list/kind = get_sierra_social_kind(species_type)
		var/list/row = background_row(preferences, "social")
		if(!kind)
			TEST_ASSERT_NULL(row, "[species_id] inherited another species' social field.")
			continue
		TEST_ASSERT(row, "[species_id] lost its social field after a species change.")
		TEST_ASSERT_EQUAL(row["label"], kind["label"], "Social heading is stale after selecting [species_id].")
		TEST_ASSERT_EQUAL(row["preference"], kind["preference"], "Social membership uses a stale save key for [species_id].")
		var/datum/preference/preference = GLOB.preference_entries_by_key[row["preference"]]
		TEST_ASSERT(preference.is_accessible(preferences), "The displayed social field is inaccessible for [species_id].")
		var/list/choices = row["choices"]
		for(var/choice in choices)
			TEST_ASSERT(preference.is_valid(choice, preferences), "The server rejects a displayed social choice for [species_id].")
		for(var/choice in list("vulp_rakh", "vulp_mzmanulin", "vulp_refugee"))
			TEST_ASSERT_EQUAL((choice in choices), species_id == "vulpkanin", "Vulpkanin membership [choice] crossed species boundaries.")

/// The published clan list reaches the ordinary chooser and preserves the old Zessur slot key.
/datum/unit_test/sierra_background_unathi_clans
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_unathi_clans/Run()
	var/list/clans = list(
		"unathi_szaahi" = "Сзаахи",
		"unathi_usshulu" = "Усшулу",
		"unathi_kharsi" = "Кхарси",
		"unathi_zessur" = "Зессур",
		"unathi_shursi" = "Шурси",
		"unathi_uzo" = "Узо (внеклановые)",
	)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "lizard"), "Could not prepare an Unathi character.")
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	var/list/row = background_row(preferences, "social")
	var/list/choices = row["choices"]
	TEST_ASSERT_EQUAL(length(choices), 7, "The complete Unathi list must include five clans, Uzo and an unset answer.")
	TEST_ASSERT("none" in choices, "An unset answer was conflated with the Uzo social status.")
	var/list/ui_catalog = middleware.get_constant_data()
	var/list/ui_social = ui_catalog["social"]
	for(var/id in clans)
		TEST_ASSERT(id in choices, "The native UI is missing published Unathi choice [id].")
		var/list/entry = ui_social[id]
		TEST_ASSERT_EQUAL(entry["name"], clans[id], "The displayed Unathi name differs from the published list.")
		TEST_ASSERT(length(entry["description"]), "The Unathi chooser cannot display a clan description.")
		var/list/params = list("preference" = "sierra_social", "value" = id, "slot" = preferences.default_slot, "species" = "lizard")
		TEST_ASSERT(middleware.choose_background(params, null), "The native chooser rejects a listed Unathi clan.")
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/social), id, "The confirmed clan did not reach character preferences.")
		for(var/species_id in GLOB.species_list)
			if(species_id == "lizard")
				continue
			var/list/foreign_choices = get_sierra_background_choices("social", GLOB.species_list[species_id])
			TEST_ASSERT(!(id in foreign_choices), "Unathi social membership is offered to [species_id].")
	var/list/zessur = ui_social["unathi_zessur"]
	TEST_ASSERT(!findtext(zessur["description"], "спутник"), "Zessur still shows a moon description instead of clan information.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/social, "unathi_zessur"), "The established Zessur ID no longer works.")
	TEST_ASSERT(preferences.save_character(), "Could not save the existing Zessur character.")
	preferences.switch_to_slot(2)
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "lizard"), "Could not prepare the second Unathi slot.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/social, "unathi_uzo"), "Could not select the explicit clanless status.")
	TEST_ASSERT(preferences.save_character(), "Could not save the Uzo character.")
	TEST_ASSERT(preferences.save_preferences(), "Could not flush both native character slots.")
	var/datum/preferences/reloaded = make_preferences(mock_client)
	TEST_ASSERT_EQUAL(reloaded.default_slot, 2, "Reopening preferences lost the active Unathi slot.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/social), "unathi_uzo", "Uzo was replaced with an unset answer during loading.")
	reloaded.switch_to_slot(1)
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/social), "unathi_zessur", "The expanded clan list changed the old Zessur selection.")
