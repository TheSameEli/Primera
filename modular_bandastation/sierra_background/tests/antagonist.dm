/// The optional block uses native slots and never applies secrets to the body or shared UI assets.
/datum/unit_test/sierra_background_antagonist_preferences
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_antagonist_preferences/Run()
	var/datum/preferences/preferences = make_preferences()
	var/datum/preference/faction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/faction]
	var/datum/preference/subfaction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/subfaction]
	var/datum/preference/text/notes = GLOB.preference_entries[/datum/preference/text/sierra_antagonist_notes]
	var/datum/preference_middleware/sierra_antagonist/middleware
	for(var/datum/preference_middleware/sierra_antagonist/entry in preferences.middleware)
		middleware = entry
		break
	TEST_ASSERT_NOTNULL(middleware, "The private background middleware was not registered.")
	TEST_ASSERT_EQUAL(preferences.read_preference(faction.type), "none", "A new character was assigned an antagonist organization.")
	TEST_ASSERT_EQUAL(preferences.read_preference(subfaction.type), "none", "A new character was assigned an antagonist subgroup.")
	TEST_ASSERT_EQUAL(preferences.read_preference(notes.type), "", "A new character inherited a private biography.")
	var/list/catalog = get_sierra_antagonist_catalog()
	var/list/organizations = catalog["organizations"]
	TEST_ASSERT("Cybersun" in organizations, "The confirmed organization is absent.")
	TEST_ASSERT(!("Gorlex" in organizations), "The confirmed Cybersun subsidiary was duplicated as a separate parent.")
	TEST_ASSERT("SnakeStrike" in organizations, "The independent former Gorlex group was incorrectly nested.")
	for(var/id in organizations)
		var/list/organization = organizations[id]
		for(var/employer in organization["native_employers"])
			TEST_ASSERT((employer in GLOB.syndicate_employers) || (employer in GLOB.hijack_employers), "A biography compatibility rule names an unknown native Syndicate employer.")
			TEST_ASSERT(!(employer in GLOB.nanotrasen_employers), "A Syndicate biography is being applied to a Nanotrasen role.")
	TEST_ASSERT(!subfaction.is_valid("Gorlex", preferences), "A subgroup was accepted without its parent.")
	TEST_ASSERT(preferences.update_preference(faction, "Cybersun"), "Could not set an optional organization.")
	TEST_ASSERT(preferences.update_preference(subfaction, "Gorlex"), "Could not set the confirmed matching subgroup.")
	TEST_ASSERT(preferences.update_preference(notes, "PRIVATE_SENTINEL\n<b>Личный текст</b>"), "Could not set the private biography.")
	TEST_ASSERT_EQUAL(preferences.read_preference(notes.type), "PRIVATE_SENTINEL\nЛичный текст", "Private notes retained markup or lost line breaks.")
	TEST_ASSERT(middleware.pre_set_preference(null, faction.savefile_key, "forged"), "A forged organization was not intercepted.")
	TEST_ASSERT(middleware.pre_set_preference(null, subfaction.savefile_key, "forged"), "A forged subgroup was not intercepted.")
	TEST_ASSERT_EQUAL(preferences.read_preference(faction.type), "Cybersun", "A forged choice changed the saved organization.")
	TEST_ASSERT(preferences.update_preference(faction, "Donk"), "Could not change the optional organization.")
	middleware.post_set_preference(null, faction.savefile_key, "Donk")
	TEST_ASSERT_EQUAL(preferences.read_preference(subfaction.type), "none", "Changing parent retained an incompatible subgroup.")
	TEST_ASSERT_EQUAL(preferences.read_preference(notes.type), "PRIVATE_SENTINEL\nЛичный текст", "Changing organization erased the player's text.")
	var/full_text = repeat_string(1000, "Я")
	TEST_ASSERT(notes.is_valid(full_text), "A thousand Cyrillic characters were rejected by byte length.")
	TEST_ASSERT_EQUAL(notes.deserialize("[full_text]Лишнее", preferences), full_text, "Private notes were not truncated at the character limit.")
	TEST_ASSERT_EQUAL(notes.deserialize(list("forged"), preferences), "", "Malformed private notes did not recover safely.")
	TEST_ASSERT_EQUAL(notes.deserialize("Строка[ascii2text(13)]\n[ascii2text(7)][ascii2text(27)]Текст\t[ascii2text(127)]", preferences), "Строка\nТекст\t", "Private notes retained control characters or lost supported whitespace.")
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	var/old_features = json_encode(body.dna.features)
	for(var/datum/preference/preference as anything in list(faction, subfaction, notes))
		TEST_ASSERT_EQUAL(preference.savefile_identifier, PREFERENCE_CHARACTER, "Private biography must be saved per character.")
		TEST_ASSERT(!preference.can_randomize, "Appearance randomization can change private background.")
		preference.apply_to_human(body, preferences.read_preference(preference.type), preferences)
		TEST_ASSERT_NULL(preference.compile_ui_data(body, preferences.read_preference(preference.type)), "Private preference leaked into generic character data.")
	TEST_ASSERT_EQUAL(json_encode(body.dna.features), old_features, "Private biography was written into DNA.")
	TEST_ASSERT_NULL(middleware.get_constant_data(), "Private selections or personal text were exported to a shared preferences asset.")
	TEST_ASSERT_EQUAL(length(middleware.get_ui_data(body)), 0, "Another client could retrieve private preferences.")
	var/list/ui_data = preferences.get_sierra_antagonist_ui_data()
	var/list/ui_organization = ui_data["organization"]
	var/list/ui_notes = ui_data["notes"]
	TEST_ASSERT_EQUAL(ui_organization["value"], "Donk", "The owner panel does not reflect the saved organization.")
	TEST_ASSERT_EQUAL(ui_notes["value"], preferences.read_preference(notes.type), "The owner panel lost the private text.")

/// Capture once from the actual spawned character slot, before any possible midround role.
/datum/unit_test/sierra_background_antagonist_slots
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_antagonist_slots/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	var/datum/preference/faction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/faction]
	var/datum/preference/subfaction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/subfaction]
	var/datum/preference/notes = GLOB.preference_entries[/datum/preference/text/sierra_antagonist_notes]
	TEST_ASSERT(preferences.update_preference(faction, "Cybersun"), "Could not prepare slot one's organization.")
	TEST_ASSERT(preferences.update_preference(subfaction, "Gorlex"), "Could not prepare slot one's subgroup.")
	TEST_ASSERT(preferences.update_preference(notes, "Первый слот: прежняя связь с Горлексом."), "Could not prepare slot one's notes.")
	TEST_ASSERT(preferences.save_character(), "Could not save the first private biography.")
	var/datum/mind/first_character = allocate(/datum/mind)
	first_character.capture_sierra_antagonist_background(preferences)
	TEST_ASSERT(!length(first_character.antag_datums), "Filling a private biography assigned an antagonist role.")
	preferences.switch_to_slot(2)
	TEST_ASSERT_EQUAL(preferences.read_preference(faction.type), "none", "A fresh slot inherited an antagonist organization.")
	TEST_ASSERT_EQUAL(preferences.read_preference(subfaction.type), "none", "A fresh slot inherited an antagonist subgroup.")
	TEST_ASSERT_EQUAL(preferences.read_preference(notes.type), "", "A fresh slot inherited private notes.")
	TEST_ASSERT(preferences.update_preference(faction, "Donk"), "Could not prepare slot two's organization.")
	TEST_ASSERT(preferences.update_preference(notes, "Второй слот: другая биография."), "Could not prepare slot two's notes.")
	TEST_ASSERT(preferences.save_character(), "Could not save the second private biography.")
	TEST_ASSERT(preferences.save_preferences(), "Could not flush private biographies through native JSON storage.")
	var/datum/preferences/reloaded = make_preferences(mock_client)
	TEST_ASSERT_EQUAL(reloaded.default_slot, 2, "Reload lost the active slot.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(faction.type), "Donk", "Reload lost slot two's organization.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(notes.type), "Второй слот: другая биография.", "Reload lost slot two's notes.")
	first_character.capture_sierra_antagonist_background(reloaded)
	TEST_ASSERT_EQUAL(first_character.sierra_antagonist_background["organization"], "Cybersun", "Switching profiles changed the in-round character's organization.")
	TEST_ASSERT_EQUAL(first_character.sierra_antagonist_background["subgroup"], "Gorlex", "Switching profiles changed the in-round character's subgroup.")
	TEST_ASSERT_EQUAL(first_character.sierra_antagonist_background["notes"], "Первый слот: прежняя связь с Горлексом.", "A late role would use another profile's notes.")
	reloaded.switch_to_slot(1)
	TEST_ASSERT_EQUAL(reloaded.read_preference(faction.type), "Cybersun", "Reload lost slot one's organization.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(subfaction.type), "Gorlex", "Reload lost slot one's subgroup.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(notes.type), "Первый слот: прежняя связь с Горлексом.", "Reload lost slot one's notes.")

/// A job-specific profile can replace the active slot during apply_prefs_job, before capture.
/datum/unit_test/sierra_background_antagonist_job_slot
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_antagonist_job_slot/Run()
	var/datum/preferences/preferences = make_preferences()
	var/datum/preference/faction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/faction]
	var/datum/preference/subfaction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/subfaction]
	var/datum/preference/notes = GLOB.preference_entries[/datum/preference/text/sierra_antagonist_notes]
	TEST_ASSERT(preferences.update_preference(faction, "Cybersun"), "Could not prepare the initially active organization.")
	TEST_ASSERT(preferences.update_preference(subfaction, "Gorlex"), "Could not prepare the initially active subgroup.")
	TEST_ASSERT(preferences.update_preference(notes, "Биография активного слота."), "Could not prepare the initially active notes.")
	TEST_ASSERT(preferences.save_character(), "Could not save the initially active profile.")
	preferences.switch_to_slot(2)
	TEST_ASSERT(preferences.update_preference(faction, "Donk"), "Could not prepare the job-specific organization.")
	TEST_ASSERT(preferences.update_preference(notes, "Биография профиля для профессии."), "Could not prepare the job-specific notes.")
	TEST_ASSERT(preferences.save_character(), "Could not save the job-specific profile.")
	preferences.switch_to_slot(1)
	TEST_ASSERT_EQUAL(preferences.default_slot, 1, "The regression did not start with slot one active.")
	var/datum/preference/current_slot = GLOB.preference_entries[/datum/preference/toggle/round_start_always_join_current_slot]
	TEST_ASSERT(preferences.write_preference(current_slot, FALSE), "Could not enable job-specific profile selection.")
	var/datum/job/job = SSjob.get_job_type(/datum/job/assistant)
	preferences.pref_job_slots[job.title] = 2
	// This native operation runs inside apply_prefs_job, called by get_spawn_mob.
	preferences.set_assigned_slot(job.title, is_late_join = FALSE)
	TEST_ASSERT_EQUAL(preferences.default_slot, 2, "Native job-specific profile selection did not load slot two.")
	var/datum/mind/character = allocate(/datum/mind)
	character.capture_sierra_antagonist_background(preferences)
	TEST_ASSERT_EQUAL(character.sierra_antagonist_background["organization"], "Donk", "Capture used the former active profile instead of the job-specific profile.")
	TEST_ASSERT_EQUAL(character.sierra_antagonist_background["subgroup"], "none", "Capture inherited the former active profile's subgroup.")
	TEST_ASSERT_EQUAL(character.sierra_antagonist_background["notes"], "Биография профиля для профессии.", "Capture used the former active profile's notes.")
	preferences.switch_to_slot(1)
	character.capture_sierra_antagonist_background(preferences)
	TEST_ASSERT_EQUAL(character.sierra_antagonist_background["organization"], "Donk", "Later profile selection changed the spawned character's snapshot.")
	TEST_ASSERT_EQUAL(character.sierra_antagonist_background["notes"], "Биография профиля для профессии.", "Later profile selection replaced the spawned character's private notes.")

/// The owner's late or repeated role shows the saved biography separately from the real assignment.
/datum/unit_test/sierra_background_antagonist_display
	parent_type = /datum/unit_test/sierra_background_fixture
	var/datum/mind/display_character
	var/datum/antagonist/traitor/display_traitor

/datum/unit_test/sierra_background_antagonist_display/Destroy()
	// Both objects belong to allocate(), not to each other's native teardown path.
	if(display_traitor)
		display_traitor.owner = null
	if(display_character)
		display_character.antag_datums = list()
	display_traitor = null
	display_character = null
	return ..()

/datum/unit_test/sierra_background_antagonist_display/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	var/datum/preference/faction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/faction]
	var/datum/preference/subfaction = GLOB.preference_entries[/datum/preference/choiced/sierra_antagonist/subfaction]
	var/datum/preference/notes = GLOB.preference_entries[/datum/preference/text/sierra_antagonist_notes]
	TEST_ASSERT(preferences.update_preference(faction, "Cybersun"), "Could not prepare the biography organization.")
	TEST_ASSERT(preferences.update_preference(subfaction, "Gorlex"), "Could not prepare the biography subgroup.")
	TEST_ASSERT(preferences.update_preference(notes, "PRIVATE_SENTINEL: прежняя служба."), "Could not prepare private text.")
	TEST_ASSERT(preferences.save_character(), "Could not save the biography before a new login.")
	TEST_ASSERT(preferences.save_preferences(), "Could not flush the biography before a new login.")
	var/datum/preferences/reloaded = make_preferences(mock_client)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other_player = allocate(/mob/living/carbon/human/consistent)
	var/mob/dead/observer/observer = allocate(/mob/dead/observer)
	var/datum/mind/character = allocate(/datum/mind)
	character.set_current(body)
	display_character = character
	body.mind = character
	character.capture_sierra_antagonist_background(reloaded)
	// The role is added after capture, as with an activated sleeper agent.
	var/datum/antagonist/traitor/traitor = allocate(/datum/antagonist/traitor)
	display_traitor = traitor
	traitor.owner = character
	TEST_ASSERT_NULL(traitor.get_sierra_antagonist_background(body), "A character without the role received its private antagonist biography.")
	character.antag_datums = list(traitor)
	traitor.employer = "Gorlex Marauders"
	traitor.pick_employer()
	var/standard_intro = traitor.traitor_flavor["introduction"]
	var/original_flavor = json_encode(traitor.traitor_flavor)
	var/list/original_objectives = traitor.objectives.Copy()
	var/list/private_data = traitor.ui_static_data(body)
	var/list/biography = private_data["personal_background"]
	TEST_ASSERT_EQUAL(biography?["notes"], "PRIVATE_SENTINEL: прежняя служба.", "A saved and reloaded late role did not show its owner's exact biography.")
	TEST_ASSERT_EQUAL(biography?["organization"], "Cybersun Industries", "The biography lost its saved organization label.")
	TEST_ASSERT_EQUAL(biography?["subgroup"], "Gorlex Marauders", "The biography lost its saved subgroup label.")
	TEST_ASSERT_EQUAL(private_data["intro"], standard_intro, "The biography changed the authoritative employer statement.")
	var/list/reopened_data = traitor.ui_static_data(body)
	TEST_ASSERT_EQUAL(json_encode(reopened_data["personal_background"]), json_encode(biography), "Reopening the role window lost the biography.")
	TEST_ASSERT_NULL(traitor.get_sierra_antagonist_background(other_player), "Another player received private text.")
	TEST_ASSERT_NULL(traitor.get_sierra_antagonist_background(observer), "An observer received private text.")
	TEST_ASSERT_NULL(traitor.get_sierra_antagonist_background(null), "An unauthenticated request received private text.")
	var/list/foreign_data = traitor.ui_static_data(other_player)
	TEST_ASSERT_NULL(foreign_data["personal_background"], "The real role UI exported private notes to another player.")
	TEST_ASSERT_EQUAL(traitor.employer, "Gorlex Marauders", "The biography changed the assigned employer.")
	TEST_ASSERT_EQUAL(json_encode(traitor.traitor_flavor), original_flavor, "The display changed shared employer flavor.")
	TEST_ASSERT_EQUAL(json_encode(traitor.objectives), json_encode(original_objectives), "The display changed objectives.")
	TEST_ASSERT(!findtext(json_encode(body.dna.features), "PRIVATE_SENTINEL"), "Private text leaked into DNA.")
	var/list/serialized_mind = character.serialize_list(list(), list())
	TEST_ASSERT(!("sierra_antagonist_background" in serialized_mind), "The private snapshot entered ordinary mind serialization.")
	TEST_ASSERT(preferences.update_preference(notes, "LATE_EDIT_SENTINEL"), "Could not edit the other active preferences.")
	character.capture_sierra_antagonist_background(preferences)
	biography = traitor.get_sierra_antagonist_background(body)
	TEST_ASSERT(!findtext(biography?["notes"], "LATE_EDIT_SENTINEL"), "A late role reread mutable preferences instead of its character snapshot.")
	for(var/assigned_employer in list("Donk Corporation", "Cybersun Industries", "Corporate Climber"))
		traitor.employer = assigned_employer
		traitor.pick_employer()
		standard_intro = traitor.traitor_flavor["introduction"]
		var/list/conflicting_data = traitor.ui_static_data(body)
		biography = conflicting_data["personal_background"]
		TEST_ASSERT_EQUAL(biography?["notes"], "PRIVATE_SENTINEL: прежняя служба.", "A different employer hid the separately labelled character biography.")
		TEST_ASSERT_EQUAL(conflicting_data["intro"], standard_intro, "The biography replaced a conflicting real assignment.")
		TEST_ASSERT_EQUAL(traitor.employer, assigned_employer, "Displaying a biography changed the assigned employer.")
	character.sierra_antagonist_background = list("organization" = "Interdyne", "subgroup" = "none", "notes" = "INTERDYNE_SENTINEL")
	biography = traitor.get_sierra_antagonist_background(body)
	TEST_ASSERT_EQUAL(biography?["notes"], "INTERDYNE_SENTINEL", "An organization without a native employer can never display its biography.")
	character.sierra_antagonist_background = list("organization" = "none", "subgroup" = "none", "notes" = "PRIVATE_SENTINEL")
	biography = traitor.get_sierra_antagonist_background(body)
	TEST_ASSERT_EQUAL(biography?["notes"], "PRIVATE_SENTINEL", "A text-only biography was hidden without an organization.")
	TEST_ASSERT_NULL(biography?["organization"], "An unset organization was displayed as a real affiliation.")
	TEST_ASSERT_NULL(biography?["subgroup"], "An unset subgroup was displayed as a real affiliation.")
	character.sierra_antagonist_background = list("organization" = "Cybersun", "subgroup" = "none", "notes" = "")
	TEST_ASSERT_NULL(traitor.get_sierra_antagonist_background(body), "Empty notes created a private biography panel.")
	character.sierra_antagonist_background["notes"] = " \t\n"
	TEST_ASSERT_NULL(traitor.get_sierra_antagonist_background(body), "Whitespace-only notes created a private biography panel.")
	character.sierra_antagonist_background = null
	TEST_ASSERT_NULL(traitor.get_sierra_antagonist_background(body), "A character without a snapshot received a biography.")
