/// The regional tree has independent roots and real three-level selections, without duplicates.
/datum/unit_test/sierra_background_correction_tree
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_correction_tree/Run()
	var/list/expected_roots = list("Imperium", "TSF", "Nanotrasen", "Elysium", "CUSP", "Free", "Unathi", "Drask", "Gray", "KidanRepublic", "Adomai", "Cybersun", "Interdyne", "Donk", "KanashiTech", "none")
	for(var/species_id in GLOB.species_list)
		var/datum/species/species_type = GLOB.species_list[species_id]
		var/list/roots = get_sierra_background_choices("faction", species_type)
		var/list/unique_roots = list()
		unique_roots |= roots
		TEST_ASSERT_EQUAL(length(roots), length(unique_roots), "[species_id] has duplicate root factions.")
		TEST_ASSERT_EQUAL(length(roots), length(expected_roots) - (initial(species_type.id) != "human"), "[species_id] has an unexpected root faction count.")
		for(var/root_id in expected_roots)
			TEST_ASSERT_EQUAL((root_id in roots), root_id != "Elysium" || initial(species_type.id) == "human", "[species_id] has incorrect access to independent root [root_id].")
	var/list/subdivisions = get_sierra_background_choices("subfaction", /datum/species/human, list("faction" = "Free"))
	TEST_ASSERT_EQUAL(length(subdivisions), 10, "The regional tree lost a Triarchy group, duplicated a leaf, or included an independent state.")
	for(var/id in list("Seekers", "SeekersWings", "SeekersClaws", "SeekersTails", "FreeCartel", "ExagonIchiwaka", "WitherVit", "HumanRealm", "OrdoLex", "none"))
		TEST_ASSERT(id in subdivisions, "The Free root cannot select descendant [id].")
	TEST_ASSERT_EQUAL(json_encode(get_sierra_faction_path("WitherVit")), json_encode(list("Free", "FreeCartel", "WitherVit")), "A company lost its full regional ancestry.")
	TEST_ASSERT_EQUAL(json_encode(get_sierra_faction_path("SeekersWings")), json_encode(list("Free", "Seekers", "SeekersWings")), "A Seeker group lost its full regional ancestry.")
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare tree UI preferences.")
	var/list/row = background_row(preferences, "faction")
	var/list/children = row["choice_children"]
	TEST_ASSERT_EQUAL(length(children["Free"]), 3, "The root tree should expose exactly the three Triarchy organizations.")
	TEST_ASSERT("FreeCartel" in children["Free"], "The UI cannot expand the Cartel from Free.")
	TEST_ASSERT("WitherVit" in children["FreeCartel"], "The UI cannot expand a company from the Cartel.")
	TEST_ASSERT(!("WitherVit" in children["Free"]), "The UI flattened a company beside its parent.")
	TEST_ASSERT("SeekersWings" in children["Seekers"], "The UI cannot expand Seeker groups.")
	TEST_ASSERT(!("SeekersWings" in children["FreeCartel"]), "The UI mixed two organizations' groups.")
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	var/list/params = list("preference" = "sierra_faction", "value" = "Free", "subfaction" = "WitherVit", "slot" = preferences.default_slot, "species" = "human")
	TEST_ASSERT(middleware.choose_background(params, null), "The chooser rejected a company at the third level.")
	params["subfaction"] = "SeekersWings"
	TEST_ASSERT(middleware.choose_background(params, null), "The chooser rejected a Seeker group at the third level.")
	params["value"] = "TSF"
	TEST_ASSERT(!middleware.choose_background(params, null), "A leaf can be confirmed under a foreign root.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/subfaction), "SeekersWings", "Rejecting a forged ancestry changed the saved leaf.")
	params["value"] = "Free"
	params["subfaction"] = "none"
	TEST_ASSERT(middleware.choose_background(params, null), "The regional context requires membership in an organization.")

/// Historical flat and former regional selections retain their exact membership through native slots.
/datum/unit_test/sierra_background_correction_migration
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_correction_migration/Run()
	var/list/fixtures = list(
		list("old_root" = "WitherVit", "root" = "Free", "child" = "WitherVit"),
		list("old_root" = "FreeCartel", "old_child" = "WitherVit", "root" = "Free", "child" = "WitherVit"),
		list("old_root" = "FreeCartel", "old_child" = "none", "root" = "Free", "child" = "FreeCartel"),
		list("old_root" = "Free", "old_child" = "Adomai", "root" = "Adomai", "child" = "none"),
		list("old_root" = "Free", "old_child" = "KidanRepublic", "root" = "KidanRepublic", "child" = "none"),
	)
	for(var/list/fixture as anything in fixtures)
		var/datum/client_interface/mock_client = allocate(/datum/client_interface)
		var/datum/preferences/preferences = make_preferences(mock_client)
		TEST_ASSERT(preferences.save_character(), "Could not create the old faction slot.")
		var/list/save_data = preferences.savefile.get_entry("character1")
		save_data["species"] = "human"
		save_data["sierra_faction"] = fixture["old_root"]
		if(isnull(fixture["old_child"]))
			save_data -= "sierra_subfaction"
		else
			save_data["sierra_subfaction"] = fixture["old_child"]
		save_data["sierra_faction_notes"] = "Первая анкета: сохранённая принадлежность."
		preferences.savefile.save()
		var/datum/preferences/reloaded = make_preferences(mock_client)
		TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/faction), fixture["root"], "The old faction was not migrated to its current root.")
		TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/subfaction), fixture["child"], "The old faction lost its actual membership during migration.")
		TEST_ASSERT(reloaded.save_character(), "Could not save the canonical tree pair.")
		TEST_ASSERT(reloaded.save_preferences(), "Could not flush the canonical tree pair.")
		var/datum/preferences/reopened = make_preferences(mock_client)
		TEST_ASSERT_EQUAL(reopened.read_preference(/datum/preference/choiced/sierra_background/faction), fixture["root"], "Repeated loading reapplied a different faction migration.")
		TEST_ASSERT_EQUAL(reopened.read_preference(/datum/preference/choiced/sierra_background/subfaction), fixture["child"], "Repeated loading changed the canonical leaf.")
		reopened.switch_to_slot(2)
		TEST_ASSERT(edit_background(reopened, /datum/preference/choiced/species, "human"), "Could not prepare the separate second character.")
		TEST_ASSERT(edit_background(reopened, /datum/preference/choiced/sierra_background/faction, "TSF"), "Could not set the second character's faction.")
		TEST_ASSERT(edit_background(reopened, /datum/preference/text/sierra_background_notes/faction, "Вторая анкета: другая принадлежность."), "Could not set the second character's notes.")
		TEST_ASSERT(reopened.save_character(), "Could not save the second character.")
		reopened.switch_to_slot(1)
		TEST_ASSERT_EQUAL(reopened.read_preference(/datum/preference/choiced/sierra_background/faction), fixture["root"], "Switching slots changed a migrated root.")
		TEST_ASSERT_EQUAL(reopened.read_preference(/datum/preference/choiced/sierra_background/subfaction), fixture["child"], "Switching slots changed a migrated leaf.")
		TEST_ASSERT_EQUAL(reopened.read_preference(/datum/preference/text/sierra_background_notes/faction), "Первая анкета: сохранённая принадлежность.", "Faction migration mixed two characters' personal text.")
	var/list/stale_fixtures = list(
		list("root" = "Free", "child" = "Adomai", "migrated_root" = "Adomai", "migrated_child" = "none"),
		list("root" = "FreeCartel", "child" = "none", "migrated_root" = "Free", "migrated_child" = "FreeCartel"),
	)
	for(var/list/fixture as anything in stale_fixtures)
		var/datum/client_interface/stale_client = allocate(/datum/client_interface)
		var/datum/preferences/stale_preferences = make_preferences(stale_client)
		TEST_ASSERT(stale_preferences.save_character(), "Could not create the stale on-disk tree.")
		var/list/stale_data = stale_preferences.savefile.get_entry("character1")
		stale_data["species"] = "human"
		stale_data["sierra_faction"] = fixture["root"]
		stale_data["sierra_subfaction"] = fixture["child"]
		stale_preferences.savefile.save()
		var/datum/preferences/migrated = make_preferences(stale_client)
		TEST_ASSERT_EQUAL(migrated.read_preference(/datum/preference/choiced/sierra_background/faction), fixture["migrated_root"], "The stale-data fixture did not perform the initial root migration.")
		TEST_ASSERT_EQUAL(migrated.read_preference(/datum/preference/choiced/sierra_background/subfaction), fixture["migrated_child"], "The stale-data fixture did not perform the initial leaf migration.")
		var/datum/preference_middleware/sierra_background/middleware = background_middleware(migrated)
		var/list/params = list("preference" = "sierra_faction", "value" = "Free", "subfaction" = "none", "slot" = migrated.default_slot, "species" = "human")
		TEST_ASSERT(middleware.choose_background(params, null), "An explicit regional choice was replaced by the still unmigrated on-disk membership.")
		TEST_ASSERT(migrated.save_character(), "Could not save an explicit choice before the migrated pair was flushed.")
		TEST_ASSERT(migrated.save_preferences(), "Could not flush the explicit regional choice.")
		var/datum/preferences/final_reload = make_preferences(stale_client)
		TEST_ASSERT_EQUAL(final_reload.read_preference(/datum/preference/choiced/sierra_background/faction), "Free", "Stale on-disk membership overrode the player's explicit Free selection.")
		TEST_ASSERT_EQUAL(final_reload.read_preference(/datum/preference/choiced/sierra_background/subfaction), "none", "Removed membership returned on the next login.")

/// The short lists follow the chosen branch and residence, while migrants retain the full legal pool.
/datum/unit_test/sierra_background_correction_context
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_correction_context/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare context choices.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "Free"), "Could not select the regional context.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "Seekers"), "Could not select the northern branch.")
	var/list/row = background_row(preferences, "homeworld")
	TEST_ASSERT("Altam" in row["context_choices"], "The Seeker branch did not offer its northern environment.")
	TEST_ASSERT("NewBrazil" in row["context_choices"], "The Seeker branch lost its Luman environment.")
	TEST_ASSERT(!("Avalon" in row["context_choices"]), "The northern short list was not filtered from the southern branch.")
	TEST_ASSERT("Magnitka" in row["choices"], "Context grouping turned into an unsupported ban on migrant residence.")
	TEST_ASSERT(!("Limneya" in row["context_choices"]), "The northern branch still treats Limneya as a shared world.")
	var/list/northern_choices = row["context_choices"]
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "SeekersWings"), "Could not select a third-level branch.")
	row = background_row(preferences, "homeworld")
	TEST_ASSERT_EQUAL(json_encode(row["context_choices"]), json_encode(northern_choices), "A deeper Seeker group did not inherit its parent's environment.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "OrdoLex"), "Could not select the southern branch.")
	row = background_row(preferences, "homeworld")
	TEST_ASSERT("Avalon" in row["context_choices"], "The Order did not offer its southern environment.")
	TEST_ASSERT(!("Altam" in row["context_choices"]), "Changing subdivision left the northern short list unchanged.")
	TEST_ASSERT(!("Limneya" in row["context_choices"]), "The southern branch still treats Limneya as a shared world.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Earth"), "An allowed migrant residence outside the short list was rejected.")
	row = background_row(preferences, "culture")
	TEST_ASSERT("earth_upbringing" in row["context_choices"], "Earth residence did not suggest Earth upbringing.")
	TEST_ASSERT(!("avalon_upbringing" in row["context_choices"]), "Earth's cultural short list still contains the unrelated southern default.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/culture, "earth_upbringing"), "Could not prepare a migrant's authored upbringing.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Avalon"), "Could not change the current residence.")
	row = background_row(preferences, "culture")
	TEST_ASSERT("avalon_upbringing" in row["context_choices"], "Current residence did not update the cultural short list.")
	TEST_ASSERT(!("earth_upbringing" in row["context_choices"]), "Changing residence left the old cultural short list unchanged.")
	TEST_ASSERT("earth_upbringing" in row["choices"], "A lawful migrant upbringing disappeared from the full list.")
	TEST_ASSERT_EQUAL(row["value"], "earth_upbringing", "Changing residence erased a compatible migrant's upbringing.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "skrell"), "Could not change the context fixture species.")
	var/list/context = list("faction" = "Free", "subfaction" = "OrdoLex", "homeworld" = "Earth")
	var/list/full_choices = get_sierra_background_choices("culture", /datum/species/skrell, context)
	var/list/primary_choices = get_sierra_background_context_choices("culture", /datum/species/skrell, context, full_choices)
	TEST_ASSERT(!("earth_upbringing" in full_choices) && !("earth_upbringing" in primary_choices), "The diaspora path bypassed the closed human upbringing rule.")
	TEST_ASSERT(!edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Earth"), "The full list bypassed the closed human residence rule.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Magnitka"), "A Skrell migrant lost access to mixed Soviet society.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/culture, "kssp"), "A Skrell migrant lost valid Soviet upbringing.")

/// Limneya follows the faction's normal residence context without invalidating a migrant's selection.
/datum/unit_test/sierra_background_limneya_context
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_limneya_context/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare Limneya context choices.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "other"), "Could not clear the selected residence.")
	var/list/contexts = list(
		list("faction" = "Imperium", "subfaction" = "none", "primary" = FALSE),
		list("faction" = "Nanotrasen", "subfaction" = "none", "primary" = FALSE),
		list("faction" = "Elysium", "subfaction" = "none", "primary" = FALSE),
		list("faction" = "TSF", "subfaction" = "none", "primary" = FALSE),
		list("faction" = "CUSP", "subfaction" = "none", "primary" = FALSE),
		list("faction" = "Free", "subfaction" = "Seekers", "primary" = FALSE),
		list("faction" = "Free", "subfaction" = "SeekersWings", "primary" = FALSE),
		list("faction" = "Free", "subfaction" = "OrdoLex", "primary" = FALSE),
		list("faction" = "Free", "subfaction" = "FreeCartel", "primary" = TRUE),
		list("faction" = "Free", "subfaction" = "WitherVit", "primary" = TRUE),
		list("faction" = "Free", "subfaction" = "none", "primary" = TRUE),
		list("faction" = "none", "subfaction" = "none", "primary" = TRUE),
	)
	for(var/list/context as anything in contexts)
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, context["faction"]), "Could not select the Limneya faction context.")
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, context["subfaction"]), "Could not select the Limneya subdivision context.")
		var/list/row = background_row(preferences, "homeworld")
		TEST_ASSERT("Limneya" in row["choices"], "Limneya disappeared from the allowed diaspora pool.")
		TEST_ASSERT_EQUAL(("Limneya" in row["context_choices"]), context["primary"], "Limneya has the wrong primary visibility for [context["faction"]]/[context["subfaction"]].")
		TEST_ASSERT("other" in row["context_choices"], "Filtering Limneya removed the neutral residence option.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Limneya"), "The diaspora residence cannot be selected.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "Nanotrasen"), "Could not change the migrant's employer.")
	var/list/row = background_row(preferences, "homeworld")
	TEST_ASSERT_EQUAL(row["value"], "Limneya", "Changing faction erased the migrant's compatible residence.")
	TEST_ASSERT(!("Limneya" in row["context_choices"]), "A saved diaspora residence leaked into the primary pool.")

/// Loading a known conflict clears only contradictory choices and provides an owner-visible notice.
/datum/unit_test/sierra_background_correction_load_conflicts
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_correction_load_conflicts/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	TEST_ASSERT(preferences.save_character(), "Could not create the conflicting old slot.")
	var/list/save_data = preferences.savefile.get_entry("character1")
	save_data["species"] = "skrell"
	save_data["real_name"] = "Known Conflict Tester"
	save_data["sierra_faction"] = "Elysium"
	save_data["sierra_subfaction"] = "ElysiumSmallLight"
	save_data["sierra_homeworld"] = "Earth"
	save_data["sierra_culture"] = "elysian"
	save_data["sierra_religion"] = "neochristianity"
	save_data["skrell_caste"] = "Talum-Katish"
	var/list/notes = notes_types()
	for(var/category in notes)
		save_data["sierra_[category]_notes"] = "Личная запись [category]\nНе удалять при исправлении."
	preferences.savefile.save()
	var/datum/preferences/reloaded = make_preferences(mock_client)
	for(var/category in list("faction", "subfaction", "homeworld", "culture"))
		var/list/row = background_row(reloaded, category)
		TEST_ASSERT_EQUAL(row["value"], get_sierra_background_neutral(category), "Loading kept a known contradictory [category] selected.")
		TEST_ASSERT(row["reset_reason"], "Loading cleared [category] without explaining the correction to its owner.")
		TEST_ASSERT(!row["invalid_reason"], "A corrected [category] still has a hidden invalid selection.")
	for(var/category in notes)
		TEST_ASSERT_EQUAL(reloaded.read_preference(notes[category]), "Личная запись [category]\nНе удалять при исправлении.", "Reconciling a known conflict erased personal [category] text.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/name/real_name), "Known Conflict Tester", "Loading background conflicts regenerated the character name.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/religion), "neochristianity", "Background reconciliation reset independent faith.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/skrell_caste), "Talum-Katish", "Background reconciliation replaced an independent genetic caste.")
	TEST_ASSERT(reloaded.save_character(), "Could not save the corrected character.")
	TEST_ASSERT(reloaded.save_preferences(), "Could not flush corrected native preferences.")
	var/datum/preferences/reopened = make_preferences(mock_client)
	TEST_ASSERT_EQUAL(reopened.read_preference(/datum/preference/choiced/sierra_background/homeworld), "other", "A known closed-world conflict returned on the next login.")
	reopened.switch_to_slot(2)
	TEST_ASSERT(!length(reopened.sierra_background_load_corrections), "The next character inherited another slot's load notices.")

/// Retired objects and unknown identifiers remain visible to their owner instead of losing authored history.
/datum/unit_test/sierra_background_correction_load_history
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_correction_load_history/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	TEST_ASSERT(preferences.save_character(), "Could not create the historical slot.")
	var/list/save_data = preferences.savefile.get_entry("character1")
	save_data["species"] = "human"
	var/list/history = list("faction" = "retired-faction", "subfaction" = "retired-subfaction", "homeworld" = "Athena", "culture" = "retired-culture", "religion" = "retired-faith")
	for(var/category in history)
		save_data["sierra_[category]"] = history[category]
	save_data["sierra_homeworld_notes"] = "Старая орбитальная биография."
	preferences.savefile.save()
	var/datum/preferences/reloaded = make_preferences(mock_client)
	for(var/category in history)
		var/list/row = background_row(reloaded, category)
		TEST_ASSERT_EQUAL(row["value"], history[category], "Loading destroyed historical [category] instead of exposing it for repair.")
		TEST_ASSERT(row["invalid_reason"], "Historical [category] remained selected without an owner warning.")
	TEST_ASSERT(!length(reloaded.sierra_background_load_corrections), "Historical unknown values were reported as silently cleared.")
	TEST_ASSERT(reloaded.save_character(), "Historical values prevented unrelated character saving.")
	TEST_ASSERT(reloaded.save_preferences(), "Could not flush the historical character.")
	var/datum/preferences/reopened = make_preferences(mock_client)
	for(var/category in history)
		var/list/row = background_row(reopened, category)
		TEST_ASSERT_EQUAL(row["value"], history[category], "A read-save-read cycle changed historical [category].")
	TEST_ASSERT_EQUAL(reopened.read_preference(/datum/preference/text/sierra_background_notes/homeworld), "Старая орбитальная биография.", "Retiring a world erased the player's orbital history.")

/// Explicit rule gates apply to deep ancestors and direct updates, and reconciliation cascades synchronously.
/datum/unit_test/sierra_background_correction_dependency_guards
	parent_type = /datum/unit_test/sierra_background_fixture
	var/list/original_world_rule
	var/list/original_faction_rule

/datum/unit_test/sierra_background_correction_dependency_guards/Destroy()
	var/list/dependencies = get_sierra_background_dependencies()
	var/list/world_rules = dependencies["worlds"]
	var/list/faction_rules = dependencies["factions"]
	if(original_world_rule)
		world_rules["Magnitka"] = original_world_rule
	if(original_faction_rule)
		faction_rules["FreeCartel"] = original_faction_rule
	original_world_rule = null
	original_faction_rule = null
	return ..()

/datum/unit_test/sierra_background_correction_dependency_guards/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, "human"), "Could not prepare explicit dependency checks.")
	var/list/dependencies = get_sierra_background_dependencies()
	var/list/world_rules = dependencies["worlds"]
	var/list/faction_rules = dependencies["factions"]
	original_world_rule = world_rules["Magnitka"]
	original_faction_rule = faction_rules["FreeCartel"]
	var/list/world_rule = original_world_rule.Copy()
	var/list/faction_rule = original_faction_rule.Copy()
	world_rules["Magnitka"] = world_rule
	faction_rules["FreeCartel"] = faction_rule
	faction_rule["allowed_species"] = list("human")
	var/list/alien_subdivisions = get_sierra_background_choices("subfaction", /datum/species/skrell, list("faction" = "Free"))
	TEST_ASSERT(!("WitherVit" in alien_subdivisions), "A deep leaf bypassed an intermediate ancestor's species restriction.")
	TEST_ASSERT("SeekersWings" in alien_subdivisions, "Restricting one ancestor incorrectly hid an unrelated branch.")
	faction_rule["private"] = TRUE
	var/list/public_subdivisions = get_sierra_background_choices("subfaction", /datum/species/human, list("faction" = "Free"))
	TEST_ASSERT(!("WitherVit" in public_subdivisions), "A public leaf bypassed a private ancestor.")
	faction_rule -= "private"
	faction_rule["parent"] = "WitherVit"
	TEST_ASSERT(!length(get_sierra_faction_path("WitherVit")), "A cyclic ancestry did not fail safely.")
	faction_rule["parent"] = "Free"
	world_rule["allowed_factions"] = list("Free")
	world_rule["allowed_subfactions"] = list("SeekersWings")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "Free"), "Could not set the permitted root.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "SeekersWings"), "Could not set the permitted leaf.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Magnitka"), "The explicit permitted combination was rejected.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/culture, "kssp"), "Could not set a compatible migrant culture.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/religion, "atheism"), "Could not set independent faith.")
	var/datum/preference/subfaction = GLOB.preference_entries[/datum/preference/choiced/sierra_background/subfaction]
	TEST_ASSERT(preferences.update_preference(subfaction, "FreeCartel"), "The direct native subdivision update was rejected.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/homeworld), "other", "A direct subdivision update left a forbidden residence selected.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/culture), "kssp", "Reconciliation discarded compatible migrant upbringing.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/religion), "atheism", "Reconciliation changed independent faith.")
	TEST_ASSERT(!edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Magnitka"), "An explicit subsection gate was bypassed when saving residence.")
	TEST_ASSERT(preferences.validate_sierra_background_for_save(), "The reconciled native values were left invalid for serialization.")
	world_rule["allowed_factions"] = list("TSF", "Free")
	world_rule["allowed_subfactions"] = list("TF_LibertyDemocracy", "FreeCartel")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/faction, "TSF"), "Could not prepare the previous root for atomic preview.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/subfaction, "TF_LibertyDemocracy"), "Could not prepare the previous compatible leaf.")
	TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/sierra_background/homeworld, "Magnitka"), "Could not prepare a residence compatible with both complete selections.")
	var/list/resets = preferences.sierra_background_resets("sierra_faction", "Free", "FreeCartel")
	TEST_ASSERT_NULL(resets[/datum/preference/choiced/sierra_background/homeworld], "Preview used an intermediate empty leaf and would clear a compatible residence.")
	var/list/faction_row = background_row(preferences, "faction")
	var/list/effects = faction_row["choice_effects"]
	TEST_ASSERT(!length(effects["FreeCartel"]), "The chooser falsely warns that the selected final leaf will clear a compatible residence.")
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	var/list/params = list("preference" = "sierra_faction", "value" = "Free", "subfaction" = "FreeCartel", "slot" = preferences.default_slot, "species" = "human")
	TEST_ASSERT(middleware.choose_background(params, null), "The complete compatible root and leaf were rejected.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/sierra_background/homeworld), "Magnitka", "Applying the complete pair cleared a residence between its two halves.")
	TEST_ASSERT(!length(get_sierra_background_choices("unknown-category", /datum/species/human)), "An unknown category returned unrelated options.")
	TEST_ASSERT(!length(get_sierra_faction_path("unknown-faction")), "An unknown faction acquired a valid ancestry.")
	var/list/empty_choices = get_sierra_background_context_choices("culture", /datum/species/human, list("homeworld" = "Earth"), list())
	TEST_ASSERT(!length(empty_choices), "Context grouping manufactured options when authoritative constraints left an empty pool.")
