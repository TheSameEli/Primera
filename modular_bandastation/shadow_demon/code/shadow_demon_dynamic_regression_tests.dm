#ifdef UNIT_TESTS

/// A server's older dynamic.toml must not make the new ruleset unusable or uneditable.
/datum/unit_test/shadow_demon_dynamic_configuration/Run()
	var/datum/dynamic_ruleset/midround/from_ghosts/shadow_demon/ruleset_type = /datum/dynamic_ruleset/midround/from_ghosts/shadow_demon
	var/list/legacy_config = list("Slaughter Demon" = list("weight" = 0))
	var/datum/dynamic_ruleset/midround/from_ghosts/shadow_demon/legacy = allocate(ruleset_type, legacy_config)
	TEST_ASSERT_EQUAL(legacy.weight, initial(ruleset_type.weight), "An older Dynamic config lost the shadow demon's code-defined weight.")
	TEST_ASSERT_EQUAL(legacy.min_pop, initial(ruleset_type.min_pop), "An older Dynamic config lost the shadow demon's code-defined population threshold.")
	TEST_ASSERT_EQUAL(legacy.min_antag_cap, 1, "An older Dynamic config changed the minimum volunteer count.")
	TEST_ASSERT_EQUAL(legacy.max_antag_cap, 1, "An older Dynamic config changed the maximum volunteer count.")
	TEST_ASSERT(!legacy.repeatable, "An older Dynamic config made the shadow demon repeatable.")
	TEST_ASSERT(legacy.can_vv_get("weight") && legacy.can_vv_get("min_pop"), "The real ruleset hides its weight or population setting from VV.")
	TEST_ASSERT(legacy.vv_edit_var("weight", 3), "The real ruleset rejected a native VV weight edit.")
	TEST_ASSERT_EQUAL(legacy.weight, 3, "The native VV weight edit did not affect the real ruleset.")
	TEST_ASSERT(!legacy.vv_edit_var("config_tag", "Different Demon"), "VV could desynchronize the panel's ruleset identifier.")
	var/list/role_settings = list("weight" = 0, "min_pop" = 25, "min_antag_cap" = 1, "max_antag_cap" = 2, "minimum_required_age" = 7)
	var/datum/dynamic_ruleset/midround/from_ghosts/shadow_demon/configured = allocate(ruleset_type, list("Shadow Demon" = role_settings))
	TEST_ASSERT_EQUAL(configured.weight, 0, "An explicit zero weight was replaced by the code default.")
	TEST_ASSERT_EQUAL(configured.min_pop, 25, "A configured population threshold was ignored.")
	TEST_ASSERT_EQUAL(configured.max_antag_cap, 2, "A configured maximum volunteer count was ignored.")
	TEST_ASSERT_EQUAL(configured.minimum_required_age, 7, "A configured account-age threshold was ignored.")
	var/datum/dynamic_panel/panel = allocate(/datum/dynamic_panel)
	var/list/panel_entry = panel.ruleset_to_data(ruleset_type)
	TEST_ASSERT_EQUAL(panel_entry["id"], configured.config_tag, "The admin panel and constructor use different configuration identifiers.")
	TEST_ASSERT_EQUAL(panel_entry["typepath"], ruleset_type, "The admin panel's execution button refers to another ruleset type.")

/// Forced preparation must still require an opted-in, connected, unbanned dead volunteer.
/datum/unit_test/shadow_demon_dynamic/forced_requirements/Run()
	set_up_spawn()
	var/datum/dynamic_ruleset/midround/from_ghosts/shadow_demon/ruleset = allocate(/datum/dynamic_ruleset/midround/from_ghosts/shadow_demon, list("Slaughter Demon" = list("weight" = 0)))
	TEST_ASSERT(ruleset.can_be_selected(), "The forced-preparation fixture has no valid dark maintenance spawn.")
	TEST_ASSERT(!ruleset.prepare_execution(1, list()), "Forced preparation succeeded without any volunteers.")
	TEST_ASSERT(findtext(ruleset.log_data, "Not enough eligible candidates"), "The empty forced attempt failed for a reason other than candidate availability.")
	var/datum/client_interface/shadow_demon_candidate/mock_client = allocate(/datum/client_interface/shadow_demon_candidate)
	mock_client.ban_cache = list()
	var/datum/preferences/preferences = allocate(/datum/preferences, mock_client)
	mock_client.prefs = preferences
	var/mob/dead/observer/candidate = allocate(/mob/dead/observer)
	candidate.key = mock_client.key
	candidate.mock_client = mock_client
	mock_client.mob = candidate
	preferences.be_special = list(ROLE_SENTIENCE)
	TEST_ASSERT(!ruleset.prepare_execution(1, list(candidate)), "A forced attempt bypassed the separate shadow demon preference.")
	preferences.be_special = list(ruleset.pref_flag)
	TEST_ASSERT(candidate in ruleset.trim_candidates(list(candidate)), "The same observer remained ineligible after separately opting in.")
	mock_client.ban_cache = list(ruleset.pref_flag)
	TEST_ASSERT(!ruleset.prepare_execution(1, list(candidate)), "A forced attempt bypassed a shadow demon role ban.")
	mock_client.ban_cache = list()
	candidate.mock_client = null
	TEST_ASSERT(!ruleset.prepare_execution(1, list(candidate)), "A forced attempt selected a disconnected observer.")
	TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 0, "A rejected forced attempt created or retained a selected mind.")

#endif
