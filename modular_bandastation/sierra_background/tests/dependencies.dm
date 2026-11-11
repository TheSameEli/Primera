/// These helpers follow the ordinary preference update and owner-only UI middleware paths.
/datum/unit_test/sierra_background_fixture/proc/background_row(datum/preferences/preferences, category)
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	var/list/data = middleware.get_ui_data(null)
	for(var/list/row as anything in data["sierra_background"])
		if(row["category"] == category)
			return row
	return null

/datum/unit_test/sierra_background_fixture/proc/edit_background(datum/preferences/preferences, preference_type, value)
	var/datum/preference/preference = GLOB.preference_entries[preference_type]
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	if(middleware.pre_set_preference(null, preference.savefile_key, value))
		return FALSE
	if(!preferences.update_preference(preference, value))
		return FALSE
	middleware.post_set_preference(null, preference.savefile_key, value)
	return TRUE

/// Browsing the tree is read-only; confirming writes the parent and actual child together.
/datum/unit_test/sierra_background_chooser_atomic
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_chooser_atomic/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare chooser fixture.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "TSF"), "Could not set initial affiliation.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "TF_LibertyDemocracy"), "Could not set initial subdivision.")
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	var/list/row = background_row(preferences, "faction")
	var/list/children = row["choice_children"]
	TEST_ASSERT("NTSC" in children["Nanotrasen"], "The tree cannot preview another parent's valid subsidiary.")
	TEST_ASSERT(!("NTSC" in children["TSF"]), "The tree puts a subsidiary under an unrelated parent.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/faction), "TSF", "Previewing another parent changed the saved affiliation.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "TF_LibertyDemocracy", "Previewing removed the old political choice.")
	var/list/params = list("preference" = "sierra_faction", "value" = "Nanotrasen", "subfaction" = "NTSC", "slot" = preferences.default_slot, "species" = "human")
	TEST_ASSERT(middleware.choose_background(params, null), "A valid parent and child cannot be selected together.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/faction), "Nanotrasen", "The confirmed parent was not applied.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "NTSC", "The confirmed child was not applied.")
	params["value"] = "TSF"
	TEST_ASSERT(!middleware.choose_background(params, null), "A forged parent-child combination was accepted.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/faction), "Nanotrasen", "Rejecting an invalid child partially applied its parent.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "NTSC", "Rejecting an invalid child removed the previous selection.")
	params["value"] = "Nanotrasen"
	params["subfaction"] = "none"
	TEST_ASSERT(middleware.choose_background(params, null), "Choosing the parent without membership requires a child.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "none", "Parent-only confirmation retained hidden membership.")

/// The dedicated chooser accepts only an available background field in the same slot and species.
/datum/unit_test/sierra_background_chooser_validation
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_chooser_validation/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare validation fixture.")
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	var/list/params = list("preference" = "sierra_religion", "value" = "atheism", "slot" = preferences.default_slot, "species" = "human")
	TEST_ASSERT(middleware.choose_background(params, null), "The chooser rejected a valid independent faith.")
	params["value"] = "agnosticism"
	params["slot"] = preferences.default_slot + 1
	TEST_ASSERT(!middleware.choose_background(params, null), "A confirmation for another slot was accepted.")
	params["slot"] = preferences.default_slot
	params["species"] = "skrell"
	TEST_ASSERT(!middleware.choose_background(params, null), "A confirmation from an obsolete species view was accepted.")
	params["species"] = "human"
	params["subfaction"] = "none"
	TEST_ASSERT(!middleware.choose_background(params, null), "A non-faction selection accepted an extra subdivision.")
	params -= "subfaction"
	params["value"] = list("agnosticism")
	TEST_ASSERT(!middleware.choose_background(params, null), "The chooser accepted a list in place of a choice ID.")
	params["preference"] = "real_name"
	params["value"] = "Injected Name"
	TEST_ASSERT(!middleware.choose_background(params, null), "The chooser can edit unrelated preferences.")
	params["preference"] = "skrell_caste"
	params["value"] = "Qerr-Katish"
	TEST_ASSERT(!middleware.choose_background(params, null), "A human can edit a Skrell genetic feature through the chooser.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/religion), "atheism", "Rejected requests changed the last valid faith.")
	params["preference"] = "sierra_religion"
	params["value"] = "agnosticism"
	preferences.current_window = PREFERENCE_TAB_GAME_PREFERENCES
	TEST_ASSERT(!middleware.choose_background(params, null), "The chooser bypassed native character-page accessibility.")

/// Dependency warnings are calculated with the same reconciliation used by native edits.
/datum/unit_test/sierra_background_chooser_effects
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_chooser_effects/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare effects fixture.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "Nanotrasen"), "Could not set the starting parent.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "NTSC"), "Could not set the starting child.")
	var/list/resets = preferences.sierra_background_resets("sierra_faction", "TSF")
	TEST_ASSERT_EQUAL(resets[/datum/preference/choiced/sierra_background/subfaction], "none", "Preview omitted the incompatible subsidiary reset.")
	var/list/row = background_row(preferences, "faction")
	var/list/effects = row["choice_effects"]
	TEST_ASSERT(!length(effects["TSF"]), "The chooser warns about an intermediate child reset instead of the explicitly selected tree entry.")
	TEST_ASSERT(!length(effects["Nanotrasen"]), "Preview warns about a compatible unchanged parent.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "NTSC", "Calculating the warning changed the character.")
	preferences.value_cache[/datum/preference/choiced/sierra_background/culture] = "retired-culture"
	row = background_row(preferences, "faction")
	effects = row["choice_effects"]
	TEST_ASSERT(length(effects["TSF"]), "The chooser hides the reset of another incompatible background field.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/culture), "retired-culture", "Calculating a warning rewrote a historical upbringing.")
	resets = preferences.sierra_background_resets("sierra_faction", "TSF")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "TSF"), "Could not apply the previewed edit.")
	for(var/preference_type in resets)
		TEST_ASSERT_EQUAL(preferences.read_preference(preference_type), resets[preference_type], "Preview and native application disagree about a dependent value.")

/// Confirmed subsidiaries and political currents belong only to their actual parent.
/datum/unit_test/sierra_background_dependency_hierarchy
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_hierarchy/Run()
	var/list/parents = list(
		"TF_LibertyDemocracy" = "TSF", "TF_ProgressiveCitizens" = "TSF", "TF_EnterpriseTrade" = "TSF",
		"SK_Imperialists" = "Imperium", "SK_Reactionaries" = "Imperium", "SK_Reformers" = "Imperium",
		"CU_Siberists" = "CUSP", "CU_Zimovists" = "CUSP",
		"Seekers" = "Free", "FreeCartel" = "Free", "OrdoLex" = "Free",
		"SeekersWings" = "Seekers", "SeekersClaws" = "Seekers", "SeekersTails" = "Seekers",
		"ElysiumSmallLight" = "Elysium", "ElysiumGreenExpansion" = "Elysium",
		"GalAndSons" = "Nanotrasen", "NanoFax" = "Nanotrasen", "SecTech" = "Nanotrasen",
		"NTAmmunition" = "Nanotrasen", "NTSC" = "Nanotrasen", "NanoStream" = "Nanotrasen",
		"ExagonIchiwaka" = "FreeCartel", "WitherVit" = "FreeCartel", "HumanRealm" = "FreeCartel",
	)
	var/list/main_choices = get_sierra_background_choices("faction", /datum/species/human)
	for(var/id in list("TSF", "CUSP", "Nanotrasen", "Elysium", "Free", "Adomai", "KidanRepublic", "KanashiTech", "none"))
		TEST_ASSERT(id in main_choices, "Independent affiliation [id] disappeared from the main level.")
	for(var/id in parents)
		var/parent = parents[id]
		var/list/path = get_sierra_faction_path(id)
		TEST_ASSERT_EQUAL(path[length(path) - 1], parent, "[id] lost its documented immediate parent.")
		TEST_ASSERT(!(id in main_choices), "Subdivision [id] is still offered as a main affiliation.")
		var/list/own_choices = get_sierra_background_choices("subfaction", /datum/species/human, list("faction" = path[1]))
		TEST_ASSERT(id in own_choices, "[id] is missing under its documented parent [parent].")
		TEST_ASSERT("none" in own_choices, "Selecting [parent] requires membership of a subdivision.")
		var/other_parent = parent == "TSF" ? "Nanotrasen" : "TSF"
		var/list/foreign_choices = get_sierra_background_choices("subfaction", /datum/species/human, list("faction" = other_parent))
		TEST_ASSERT(!(id in foreign_choices), "[id] is exposed inside unrelated affiliation [other_parent].")
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare a human hierarchy fixture.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "Nanotrasen"), "Could not select Nanotrasen.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "none", "A corporation assigned a subsidiary without player choice.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "NTSC"), "A valid Nanotrasen subsidiary was rejected.")
	TEST_ASSERT(!edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "TF_LibertyDemocracy"), "A forged foreign party crossed the server trust boundary.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "NTSC", "Rejecting a forged subdivision replaced the previous legal choice.")

/// Political disagreement is not proof that an ordinary migrant cannot reside in another state.
/datum/unit_test/sierra_background_dependency_migrants
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_migrants/Run()
	for(var/species_type in list(/datum/species/human, /datum/species/skrell, /datum/species/lizard, /datum/species/tajaran, /datum/species/vulpkanin))
		for(var/faction_id in list("TSF", "CUSP", "Nanotrasen"))
			var/list/context = list("faction" = faction_id, "homeworld" = "Magnitka", "social" = "none")
			var/list/worlds = get_sierra_background_choices("homeworld", species_type, context)
			for(var/world_id in list("Magnitka", "Boron", "Agir", "Adomai"))
				TEST_ASSERT(world_id in worlds, "[species_type] with [faction_id] lost documented migrant residence [world_id].")
			var/list/cultures = get_sierra_background_choices("culture", species_type, context)
			TEST_ASSERT("nanotrasen" in cultures, "A corporate upbringing was tied to citizenship for [species_type]/[faction_id].")
			TEST_ASSERT("kssp" in cultures, "A Soviet migrant upbringing was tied to current affiliation for [species_type]/[faction_id].")
			if(species_type == /datum/species/skrell)
				TEST_ASSERT("skrell_imperial" in cultures, "A Skrell living outside the Empire lost imperial upbringing.")
				TEST_ASSERT(!("Earth" in worlds), "Skrell migrant handling bypassed the confirmed closed Solar residence restriction.")
	var/list/skrell_cultures = get_sierra_background_choices("culture", /datum/species/skrell)
	TEST_ASSERT(!("earth_upbringing" in skrell_cultures), "A Skrell can claim exclusive upbringing inside the confirmed closed human Solar society.")
	var/list/felinid_worlds = get_sierra_background_choices("homeworld", /datum/species/human/felinid)
	TEST_ASSERT(!("Earth" in felinid_worlds), "A human subtype inherited closed human-only residence by path inheritance.")

/// Retired places stay readable, but all seven gas giants and every uninhabited world are unselectable.
/datum/unit_test/sierra_background_dependency_world_audit
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_world_audit/Run()
	var/list/retired = list("BoronII", "Athena", "Vorat", "RouunLum", "Pioneer", "ViyaraII", "Morgana", "LasisArdaks", "Prometheus", "Pandora", "Khiram", "Ramaja", "Ree", "DeltaMazz", "Nemeina", "Miriam", "Gregor", "Anselm", "Violet", "Zaratus", "Idyllia")
	var/list/gas_giants = list("Athena", "Morgana", "Ramaja", "Ree", "Nemeina", "Gregor", "Violet")
	var/list/dependencies = get_sierra_background_dependencies()
	var/list/rules = dependencies["worlds"]
	var/list/catalog = get_sierra_background_catalog()
	var/list/world_entries = catalog["homeworld"]
	var/retired_count = 0
	var/gas_count = 0
	for(var/id in rules)
		var/list/rule = rules[id]
		if(!isnull(rule["selectable"]) && !rule["selectable"])
			retired_count++
			TEST_ASSERT(id in retired, "A newly retired world [id] is absent from the reviewed regression fixture.")
		if(rule["kind"] == "gas_giant")
			gas_count++
			TEST_ASSERT(id in gas_giants, "Gas giant [id] was not included in the complete exclusion audit.")
			TEST_ASSERT(!rule["selectable"], "Gas giant [id] was restored because of an orbital habitat.")
	TEST_ASSERT_EQUAL(retired_count, 21, "The approved world review must retire exactly 21 current catalogue entries.")
	TEST_ASSERT_EQUAL(gas_count, 7, "The source has seven gas giants, all of which must be excluded.")
	var/list/species_types = list(/datum/species/human, /datum/species/skrell, /datum/species/lizard, /datum/species/tajaran, /datum/species/vulpkanin, /datum/species/plasmaman, /datum/species/moth)
	for(var/species_id in GLOB.species_list)
		species_types |= GLOB.species_list[species_id]
	for(var/id in retired)
		var/list/entry = world_entries[id]
		TEST_ASSERT(islist(entry) && length(entry["description"]), "Retiring [id] deleted its full source lore.")
		for(var/species_type in species_types)
			for(var/faction_id in list("none", "TSF", "CUSP", "Nanotrasen", "Imperium"))
				var/list/choices = get_sierra_background_choices("homeworld", species_type, list("faction" = faction_id))
				TEST_ASSERT(!(id in choices), "[id] can still be selected by [species_type]/[faction_id].")
	var/list/human_choices = get_sierra_background_choices("homeworld", /datum/species/human)
	for(var/id in list("Citra", "Zuviyen", "Paradise", "Agir", "Iluk", "Ayrone"))
		TEST_ASSERT(id in human_choices, "A confirmed permanent settlement on solid world [id] was removed with the gas giants.")
	var/list/zuviyen = rules["Zuviyen"]
	var/list/lasis = rules["LasisArdaks"]
	TEST_ASSERT(zuviyen["selectable"] && zuviyen["kind"] == "settlement", "The author's permanent Zuviyen settlement override was ignored.")
	TEST_ASSERT(!lasis["selectable"] && lasis["kind"] == "uninhabited", "Temporary Lasis Ardaks work outposts were treated as permanent residents against the author decision.")
	TEST_ASSERT_EQUAL(length(dependencies["author_decisions"]), 2, "The two explicit world decisions lost their provenance.")
	var/list/plasmaman_choices = get_sierra_background_choices("homeworld", /datum/species/plasmaman)
	for(var/id in list("plasmaman_ledon", "plasmaman_rod", "plasmaman_zeitag", "plasmaman_kont", "plasmaman_hen"))
		TEST_ASSERT(id in plasmaman_choices, "Documented mobile Plasmaman society [id] was discarded as uninhabited.")

/// The conditional social row uses race-specific terms and never changes job permissions.
/datum/unit_test/sierra_background_dependency_social
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_social/Run()
	var/list/fixtures = list(
		list(/datum/species/skrell, "skrell", "Каста", "Qerr-Katish", /datum/preference/choiced/skrell_caste),
		list(/datum/species/vulpkanin, "vulpkanin", "Клан", "vulp_ashtar", /datum/preference/choiced/sierra_background/social),
		list(/datum/species/lizard, "lizard", "Клан", "unathi_zessur", /datum/preference/choiced/sierra_background/social),
		list(/datum/species/tajaran, "tajaran", "Дом", "tajaran_kaitam", /datum/preference/choiced/sierra_background/social),
	)
	var/datum/preferences/preferences = make_preferences()
	for(var/list/fixture as anything in fixtures)
		var/species_type = fixture[1]
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, fixture[2]), "Could not prepare social fixture [fixture[2]].")
		var/list/kind = get_sierra_social_kind(species_type)
		TEST_ASSERT_EQUAL(kind["label"], fixture[3], "[fixture[2]] has the wrong social terminology.")
		var/list/choices = get_sierra_background_choices("social", species_type, preferences.sierra_background_context("social"))
		TEST_ASSERT(fixture[4] in choices, "[fixture[2]] lost a documented social choice.")
		TEST_ASSERT_EQUAL(("none" in choices), species_type != /datum/species/skrell, "Optional clan/house membership and inherited Skrell caste were conflated.")
		for(var/list/other as anything in fixtures)
			if(other[1] != species_type)
				TEST_ASSERT(!(other[4] in choices), "[fixture[2]] can choose a foreign race's social structure.")
		preferences.job_preferences = list("Assistant" = JP_HIGH)
		preferences.job_assigned_profiles = list("Assistant" = 1)
		var/jobs_before = json_encode(preferences.job_preferences)
		var/slots_before = json_encode(preferences.job_assigned_profiles)
		TEST_ASSERT(edit_background(preferences, fixture[5], fixture[4]), "Could not select documented social membership.")
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "Nanotrasen"), "Could not prepare a migrant employer.")
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Magnitka"), "Could not prepare a residence outside traditional social territory.")
		TEST_ASSERT_EQUAL(preferences.read_preference(fixture[5]), fixture[4], "Living abroad silently removed the social membership.")
		var/list/row = background_row(preferences, "social")
		TEST_ASSERT_EQUAL(row["label"], fixture[3], "The live social row has the wrong race-specific heading.")
		var/datum/preference/preference = GLOB.preference_entries[fixture[5]]
		TEST_ASSERT_EQUAL(row["preference"], preference.savefile_key, "The social UI changed its native savefile key.")
		TEST_ASSERT(!("notes_preference" in row), "A social row invented an extra biography editor.")
		TEST_ASSERT_EQUAL(json_encode(preferences.job_preferences), jobs_before, "Social background changed job priorities.")
		TEST_ASSERT_EQUAL(json_encode(preferences.job_assigned_profiles), slots_before, "Social background changed profession or slot permissions.")
	for(var/species_id in list("human", "moth", "plasmaman", "ethereal"))
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, species_id), "Could not prepare a species without clans or castes.")
		TEST_ASSERT_NULL(background_row(preferences, "social"), "[species_id] was given an invented mandatory social block.")

/// The actual update hook must reconcile synchronously, retaining faith, text and legal migrant values.
/datum/unit_test/sierra_background_dependency_rapid_updates
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_rapid_updates/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], "human"), "Could not prepare the rapid-update fixture.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/faction], "Elysium"), "Could not prepare Elysium affiliation.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/subfaction], "ElysiumSmallLight"), "Could not prepare Elysium's own organization.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/homeworld], "Tellurus"), "Could not prepare confirmed human-only residence.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/culture], "elysian"), "Could not prepare human-only upbringing.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/religion], "neochristianity"), "Could not prepare independent faith.")
	var/list/notes = notes_types()
	for(var/category in notes)
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[notes[category]], "Ручная биография [category]\nНовая строка."), "Could not prepare personal biography text.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], "skrell"), "Could not change species through the real native update hook.")
	for(var/category in list("faction", "subfaction", "homeworld", "culture"))
		var/list/row = background_row(preferences, category)
		TEST_ASSERT_EQUAL(row["value"], get_sierra_background_neutral(category), "An incompatible descendant received an arbitrary alternative rather than a neutral choice.")
		TEST_ASSERT(!row["invalid_reason"], "An explicit edit left a stale contradictory descendant.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/religion), "neochristianity", "Changing species discarded an independently selected faith.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Magnitka"), "Could not choose a migrant residence.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/culture, "kssp"), "Could not choose migrant upbringing.")
	for(var/faction_id in list("Nanotrasen", "TSF", "CUSP", "Nanotrasen", "TSF"))
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/faction], faction_id), "A rapid parent change was rejected.")
		if(faction_id == "Nanotrasen")
			TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/subfaction], "NanoFax"), "A matching corporate subdivision was rejected during rapid edits.")
		else
			TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "none", "Changing parent retained a foreign corporate subsidiary.")
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/homeworld), "Magnitka", "Current affiliation erased a compatible foreign residence.")
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/culture), "kssp", "Current affiliation erased compatible migrant upbringing.")
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/religion), "neochristianity", "Current affiliation reset independent faith.")
		for(var/category in notes)
			TEST_ASSERT_EQUAL(preferences.read_preference(notes[category]), "Ручная биография [category]\nНовая строка.", "Rapid dependency changes erased personal [category] text.")
		var/list/row = background_row(preferences, "subfaction")
		TEST_ASSERT(row["value"] in row["choices"], "A stale subdivision escaped synchronous reconciliation.")
	TEST_ASSERT(!preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/subfaction], "NTSC"), "A direct forged update bypassed parent validation.")

/// Unknown and retired IDs stay visible for repair without deleting personal biography text.
/datum/unit_test/sierra_background_dependency_legacy_slots
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_legacy_slots/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	TEST_ASSERT(preferences.save_character(), "Could not create the legacy JSON slot.")
	var/list/save_data = preferences.savefile.get_entry("character1")
	save_data["species"] = "skrell"
	save_data["real_name"] = "Legacy Tester"
	save_data["age"] = 40
	var/list/legacy_values = list("faction" = "retired-affiliation", "subfaction" = "retired-subdivision", "homeworld" = "Athena", "culture" = "retired-upbringing", "religion" = "Christianity")
	for(var/category in legacy_values)
		save_data["sierra_[category]"] = legacy_values[category]
	var/list/notes = notes_types()
	for(var/category in notes)
		save_data["sierra_[category]_notes"] = "Старая биография [category]\nИстория станции и миграции."
	preferences.savefile.save()
	var/datum/preferences/reloaded = make_preferences(mock_client)
	for(var/category in legacy_values)
		var/list/row = background_row(reloaded, category)
		TEST_ASSERT_EQUAL(row["value"], legacy_values[category], "Opening an old invalid slot silently replaced [category].")
		TEST_ASSERT(row["invalid_reason"], "The owner was not warned about invalid historical [category].")
		if(category in notes)
			TEST_ASSERT_EQUAL(row["notes"], "Старая биография [category]\nИстория станции и миграции.", "Opening old [category] lost personal text.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/name/real_name), "Legacy Tester", "Reading old background regenerated the authored name.")
	TEST_ASSERT(reloaded.save_character(), "Could not save the unresolved historical character.")
	TEST_ASSERT(reloaded.save_preferences(), "Could not flush unresolved historical character JSON.")
	var/datum/preferences/reopened = make_preferences(mock_client)
	var/list/reopened_data = reopened.savefile.get_entry("character1")
	for(var/category in legacy_values)
		TEST_ASSERT_EQUAL(reopened_data["sierra_[category]"], legacy_values[category], "Read/save/read rewrote the historical [category] ID.")
		var/list/row = background_row(reopened, category)
		TEST_ASSERT_EQUAL(row["value"], legacy_values[category], "Reopening changed unresolved [category].")
		TEST_ASSERT(row["invalid_reason"], "Reopening hid the historical [category] warning.")
	reopened.switch_to_slot(2)
	TEST_ASSERT(edit_background(reopened, /datum/preference/choiced/species, "human"), "Could not prepare a separate modern slot.")
	TEST_ASSERT(edit_background(reopened, /datum/preference/choiced/sierra_background/faction, "TSF"), "Could not set modern affiliation.")
	TEST_ASSERT(edit_background(reopened, /datum/preference/choiced/sierra_background/homeworld, "Earth"), "Could not set modern residence.")
	TEST_ASSERT(edit_background(reopened, /datum/preference/choiced/sierra_background/culture, "tsf_solar"), "Could not set modern upbringing.")
	TEST_ASSERT(edit_background(reopened, /datum/preference/choiced/sierra_background/religion, "atheism"), "Could not set modern faith.")
	TEST_ASSERT(reopened.save_character(), "Could not save the modern second character.")
	reopened.switch_to_slot(1)
	for(var/category in legacy_values)
		var/list/row = background_row(reopened, category)
		TEST_ASSERT_EQUAL(row["value"], legacy_values[category], "Switching slots overwrote historical [category].")
		TEST_ASSERT(row["invalid_reason"], "Switching slots lost a historical validation warning.")
	TEST_ASSERT_EQUAL(reopened.read_preference(/datum/preference/numeric/age), 40, "Background slot handling changed the old character's age.")
	TEST_ASSERT(reopened.save_character(), "Could not resave the historical first slot.")
	TEST_ASSERT(reopened.save_preferences(), "Could not flush the two separate characters.")
	var/datum/preferences/final_reload = make_preferences(mock_client)
	for(var/category in legacy_values)
		var/list/row = background_row(final_reload, category)
		TEST_ASSERT_EQUAL(row["value"], legacy_values[category], "A fresh login rewrote historical [category] after using another slot.")
	for(var/category in notes)
		TEST_ASSERT_EQUAL(final_reload.read_preference(notes[category]), "Старая биография [category]\nИстория станции и миграции.", "Two-slot persistence lost old [category] notes.")
	final_reload.switch_to_slot(2)
	TEST_ASSERT_EQUAL(final_reload.read_preference(/datum/preference/choiced/sierra_background/homeworld), "Earth", "The second slot inherited the retired first-slot world.")
	TEST_ASSERT_EQUAL(final_reload.read_preference(/datum/preference/choiced/sierra_background/religion), "atheism", "The second slot inherited the first slot's unresolved faith ID.")

/// New fields in an existing character use valid defaults without changing authored ordinary preferences.
/datum/unit_test/sierra_background_dependency_missing_fields
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_missing_fields/Run()
	for(var/species_id in list("human", "skrell", "vulpkanin", "lizard", "tajaran", "moth"))
		var/datum/client_interface/mock_client = allocate(/datum/client_interface)
		var/datum/preferences/preferences = make_preferences(mock_client)
		TEST_ASSERT(preferences.save_character(), "Could not create the old character without background fields.")
		var/list/save_data = preferences.savefile.get_entry("character1")
		save_data["species"] = species_id
		save_data["real_name"] = "Existing Tester"
		for(var/category in list("faction", "subfaction", "homeworld", "social", "culture", "religion"))
			save_data -= "sierra_[category]"
			save_data -= "sierra_[category]_notes"
		save_data -= "skrell_caste"
		preferences.savefile.save()
		var/datum/preferences/reloaded = make_preferences(mock_client)
		var/species_type = reloaded.read_preference(/datum/preference/choiced/species)
		for(var/category in background_types())
			var/list/types = background_types()
			var/datum/preference/preference = GLOB.preference_entries[types[category]]
			var/value = reloaded.read_preference(preference.type)
			TEST_ASSERT_EQUAL(value, get_sierra_background_default(category, species_type), "An old [species_id] slot missing [category] inherited another character's values.")
			TEST_ASSERT(preference.is_valid(value, reloaded), "A missing [category] field received an invalid default.")
		TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/subfaction), "none", "A missing optional subdivision assigned political membership.")
		TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/name/real_name), "Existing Tester", "Adding background defaults changed an authored character name.")
		for(var/category in notes_types())
			var/list/types = notes_types()
			TEST_ASSERT_EQUAL(reloaded.read_preference(types[category]), "", "A missing optional personal field was filled with invented biography.")
		if(species_id == "skrell")
			var/list/social_row = background_row(reloaded, "social")
			TEST_ASSERT_EQUAL(social_row["preference"], "skrell_caste", "A missing old caste generated a new incompatible save key.")
			TEST_ASSERT_EQUAL(social_row["value"], "Qerr-Katish", "A missing Skrell caste lost the established genetic default.")
	var/list/empty = get_sierra_background_choices("unknown-category", /datum/species/human, list())
	TEST_ASSERT_EQUAL(length(empty), 0, "An unknown or empty category invented selectable options.")


/// Every religion is independent of the main tree, including when the race changes.
/datum/unit_test/sierra_background_dependency_faith
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_faith/Run()
	var/list/reference_choices = get_sierra_background_choices("religion", /datum/species/human)
	for(var/species_type in list(/datum/species/skrell, /datum/species/lizard, /datum/species/tajaran, /datum/species/vulpkanin, /datum/species/moth, /datum/species/ethereal))
		var/list/choices = get_sierra_background_choices("religion", species_type, list("faction" = "Nanotrasen", "homeworld" = "Magnitka", "social" = "none"))
		TEST_ASSERT_EQUAL(json_encode(choices), json_encode(reference_choices), "Faith choices were implicitly restricted by race or main-tree context.")
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare independent faith fixture.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/religion, "agnosticism"), "Agnosticism is missing from independent faith.")
	for(var/faction_id in list("TSF", "CUSP", "Nanotrasen"))
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, faction_id), "Could not change current affiliation.")
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Magnitka"), "Could not change residence.")
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/culture, "nanotrasen"), "Could not change upbringing.")
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/religion), "agnosticism", "An upstream edit reset personal beliefs.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "skrell"), "Could not change race for the faith regression.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/religion), "agnosticism", "Race selection reset independent personal beliefs.")

/// Native saving refuses an invalid dirty edit while preserving the previous on-disk value and text.
/datum/unit_test/sierra_background_dependency_save_validation
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_save_validation/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare save validation fixture.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "TSF"), "Could not select the real main affiliation.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "TF_LibertyDemocracy"), "Could not select the real party.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/text/sierra_background_notes/faction], "Моя история принадлежности."), "Could not prepare authored notes.")
	TEST_ASSERT(preferences.save_character(), "Could not save the legal starting character.")
	var/preference_type = /datum/preference/choiced/sierra_background/subfaction
	preferences.value_cache[preference_type] = "NTSC"
	preferences.recently_updated_keys |= preference_type
	TEST_ASSERT(!preferences.validate_sierra_background_for_save(), "Pre-save validation accepted a dirty foreign subsidiary.")
	TEST_ASSERT(!(preference_type in preferences.recently_updated_keys), "The invalid edit will still be serialized by the native writer.")
	TEST_ASSERT_EQUAL(preferences.read_preference(preference_type), "NTSC", "Pre-save validation silently assigned another biography instead of reporting the conflict.")
	var/list/row = background_row(preferences, "subfaction")
	TEST_ASSERT(row["invalid_reason"], "The unresolved dirty selection lost its owner warning.")
	TEST_ASSERT(preferences.save_character(), "Rejecting one invalid key prevented unrelated native character saving.")
	TEST_ASSERT(preferences.save_preferences(), "Could not flush the legal on-disk biography.")
	var/datum/preferences/reloaded = make_preferences(mock_client)
	TEST_ASSERT_EQUAL(reloaded.read_preference(preference_type), "TF_LibertyDemocracy", "The invalid dirty subsidiary replaced the actual saved political membership.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/text/sierra_background_notes/faction), "Моя история принадлежности.", "Pre-save validation deleted personal affiliation text.")

/// The former flat child selection migrates into its real parent plus optional subdivision.
/datum/unit_test/sierra_background_dependency_flat_faction_migration
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_dependency_flat_faction_migration/Run()
	var/list/fixtures = list("TF_LibertyDemocracy" = "TSF", "ElysiumSmallLight" = "Elysium", "NanoFax" = "Nanotrasen", "WitherVit" = "Free")
	for(var/child in fixtures)
		var/datum/client_interface/mock_client = allocate(/datum/client_interface)
		var/datum/preferences/preferences = make_preferences(mock_client)
		TEST_ASSERT(preferences.save_character(), "Could not create a legacy flat-faction slot.")
		var/list/save_data = preferences.savefile.get_entry("character1")
		save_data["species"] = "human"
		save_data["sierra_faction"] = child
		save_data["sierra_faction_notes"] = "Личная история принадлежности: [child]"
		save_data -= "sierra_subfaction"
		preferences.savefile.save()
		var/datum/preferences/reloaded = make_preferences(mock_client)
		TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/faction), fixtures[child], "Legacy child [child] was not promoted into its actual parent.")
		TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/subfaction), child, "Migrating the old flat faction lost its specific membership.")
		TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/text/sierra_background_notes/faction), "Личная история принадлежности: [child]", "Faction migration rewrote personal affiliation notes.")
		TEST_ASSERT(reloaded.save_character(), "Could not save the migrated faction hierarchy.")
		TEST_ASSERT(reloaded.save_preferences(), "Could not flush the migrated faction hierarchy.")
		var/datum/preferences/reopened = make_preferences(mock_client)
		var/list/persisted = reopened.savefile.get_entry("character1")
		TEST_ASSERT_EQUAL(persisted["sierra_faction"], fixtures[child], "The canonical parent did not persist to ordinary JSON.")
		TEST_ASSERT_EQUAL(persisted["sierra_subfaction"], child, "The old specific membership did not persist to ordinary JSON.")
