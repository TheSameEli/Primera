
/*
 * This test checks all heretic knowledge nodes and validates they are setup correctly.
 * We check that all knowledge is reachable by players (through the research tree)
 * and that all knowledge have a valid next_knowledge list.
 */
/datum/unit_test/heretic_knowledge

/datum/unit_test/heretic_knowledge/Run()
	GLOB.heretic_path_knowledges = generate_global_heretic_tree()


	var/list/start_knowledges = list()
	generate_heretic_starting_knowledge(start_knowledges)
	start_knowledges = flatten_list(start_knowledges)
	var/list/all_knowledges = start_knowledges

	// we need to generate a set of shop_knowledges and drafted knowledges as they're unique per path and slightly random in drafted knowledges
	for(var/path in GLOB.heretic_path_knowledges)
		var/list/tree = GLOB.heretic_path_knowledges[path]
		var/list/shop = list()
		var/list/draft = list()
		determine_drafted_knowledge(path, tree, shop, draft)
		all_knowledges += flatten_list(tree)
		all_knowledges += flatten_list(shop)
		all_knowledges += flatten_list(draft)


	var/list/all_possible_knowledge = valid_subtypesof(/datum/heretic_knowledge)

	var/list/list_to_check = get_knowledge_unlockables(start_knowledges, all_knowledges)

	// We now have a list that SHOULD contain all knowledges with a path set (list_to_check).
	// Let's compare it to our original list (all_possible_knowledge). If they're not identical,
	// then somewhere we missed a knowledge somewhere, and should throw a fail.
	var/list/unreachables = list()
	for(var/knowledge_path in all_possible_knowledge)
		var/found = FALSE
		for(var/list/knowledge_node as anything in list_to_check)
			var/type = knowledge_node["type"]
			if(type == knowledge_path)
				found = TRUE
				break
		if(!found)
			unreachables += knowledge_path
	// Unreachables is a list of typepaths - all paths that cannot be obtained.
	for(var/datum/heretic_knowledge/lost_knowledge as anything in unreachables)
		TEST_FAIL("Heretic Knowledge: [lost_knowledge] is unreachable by players! Add it to another knowledge's 'next_knowledge' list. If it is purposeful, set its route to 'null'.")

/// Expects a flat list of knowledge nodes. Returns a list of all HKT_ID entries
/datum/unit_test/heretic_knowledge/proc/get_knowledge_ids(list/knowledges)
	var/list/ids = list()
	for(var/list/knowledge_node as anything in knowledges)
		ids += knowledge_node[HKT_ID]
	return ids

/// Gets all unique HKT_NEXT entries from a list of knowledges. both lists must be flat lists of knowledge nodes
/datum/unit_test/heretic_knowledge/proc/get_knowledge_unlockables(list/starting_point, list/all_knowledges)
	// Now, let's build a list of all researchable knowledge
	// from the ground up. We start with all starting knowledge,
	// then add the next possible knowledges back into the list
	// repeatedly, until we run out of knowledges to add.
	var/list/list_to_check = starting_point.Copy()
	var/i = 0
	while(i < length(list_to_check))
		var/list/knowledge_node = list_to_check[++i]
		// Next knowledge is a list of id that consists of typepath_shopcategory
		// we basically need to go through the entire chain of HKT_NEXT's to validate the paths's starting from GLOB.heretic_start_knowledge
		for(var/next_id in knowledge_node[HKT_NEXT])
			var/list/next_knowledge_node = find_knowledge_node_by_id(all_knowledges, next_id)
			var/datum/knowledge_path = next_knowledge_node["type"]
			if(isnull(next_knowledge_node))
				TEST_FAIL("Heretic Knowledge: [next_id] in [knowledge_path] 's next_knowledge list does not point to a valid knowledge node!")
				continue
			if(!istext(next_id))
				TEST_FAIL("Heretic Knowledge: [next_id] has an invalid non-string next_knowledge entry (Got: [next_id])!")
			list_to_check += list(next_knowledge_node)
	return list_to_check

/datum/unit_test/heretic_knowledge/proc/find_knowledge_node_by_id(list/knowledges, id)
	for(var/list/knowledge_node as anything in knowledges)
		if(knowledge_node[HKT_ID] == id)
			return knowledge_node
	return null

/datum/unit_test/heretic_knowledge/proc/flatten_list(list/knowledge_nodes)
	var/list/flat_list = list()
	for(var/datum/heretic_knowledge/knowledge_path as anything in knowledge_nodes)
		var/list/knowledge_node = knowledge_nodes[knowledge_path]
		knowledge_node["type"] = knowledge_path
		flat_list += list(knowledge_node)
	return flat_list

/// Advanced spells require a worn focus or held open Codex, but no consumable charges.
/datum/unit_test/heretic_spell_focus
	var/mob/living/carbon/human/caster
	var/datum/antagonist/heretic/heretic
	var/list/original_influences

/datum/unit_test/heretic_spell_focus/Destroy()
	if(!QDELETED(heretic) && !QDELETED(caster))
		heretic.remove_innate_effects(caster)
	if(original_influences)
		for(var/obj/effect/heretic_influence/influence as anything in GLOB.reality_smash_track.smashes - original_influences)
			qdel(influence)
	original_influences = null
	QDEL_NULL(heretic)
	caster = null
	return ..()

/datum/unit_test/heretic_spell_focus/Run()
	caster = allocate(/mob/living/carbon/human/consistent)
	caster.mind_initialize()
	allocated += caster.mind
	heretic = allocate(/datum/antagonist/heretic)
	heretic.owner = caster.mind
	LAZYADD(caster.mind.antag_datums, heretic)
	// Innate effects install the real cast signals without generating objectives or starting knowledge.
	original_influences = GLOB.reality_smash_track.smashes.Copy()
	heretic.apply_innate_effects(caster)

	var/datum/heretic_knowledge/spell/realignment/knowledge = allocate(/datum/heretic_knowledge/spell/realignment)
	knowledge.on_gain(caster, heretic)
	var/datum/action/cooldown/spell/realignment/spell = knowledge.created_action_ref
	TEST_ASSERT(!spell.Trigger(), "An advanced heretic spell cast without a focus.")
	TEST_ASSERT(!caster.has_status_effect(/datum/status_effect/realignment), "A rejected spell still applied its effect.")

	var/obj/item/clothing/neck/heretic_focus/focus = allocate(/obj/item/clothing/neck/heretic_focus)
	TEST_ASSERT(caster.equip_to_slot_if_possible(focus, ITEM_SLOT_NECK), "Could not equip the focus.")
	// Realignment previously ran out after three casts; only its ordinary cooldown is reset here.
	for(var/cast_number in 1 to 4)
		spell.ResetCooldown()
		TEST_ASSERT(spell.Trigger(), "Realignment failed on cast [cast_number] while wearing a focus.")
		TEST_ASSERT(caster.has_status_effect(/datum/status_effect/realignment), "Realignment cast [cast_number] did not apply its effect.")
		caster.remove_status_effect(/datum/status_effect/realignment)

	TEST_ASSERT(caster.dropItemToGround(focus), "Could not remove the focus.")
	spell.ResetCooldown()
	TEST_ASSERT(!spell.Trigger(), "A dropped focus still allowed advanced spellcasting.")

	var/obj/item/codex_cicatrix/codex = allocate(/obj/item/codex_cicatrix)
	TEST_ASSERT(caster.put_in_hands(codex), "Could not hold the Codex.")
	TEST_ASSERT(!spell.Trigger(), "A closed Codex allowed advanced spellcasting.")
	codex.attack_self(caster)
	TEST_ASSERT(spell.Trigger(), "A held open Codex did not allow advanced spellcasting.")
	TEST_ASSERT(caster.has_status_effect(/datum/status_effect/realignment), "Casting with an open Codex did not apply the spell effect.")
	caster.remove_status_effect(/datum/status_effect/realignment)
	spell.ResetCooldown()
	codex.attack_self(caster)
	TEST_ASSERT(!spell.Trigger(), "Closing the Codex did not remove its focus effect.")
	codex.attack_self(caster)
	TEST_ASSERT(caster.dropItemToGround(codex), "Could not drop the open Codex.")
	TEST_ASSERT(!spell.Trigger(), "A dropped open Codex still allowed advanced spellcasting.")
	var/obj/item/clothing/suit/space/santa/storage_suit = allocate(/obj/item/clothing/suit/space/santa)
	TEST_ASSERT(caster.equip_to_slot_if_possible(storage_suit, ITEM_SLOT_OCLOTHING), "Could not equip a suit with unrestricted storage.")
	TEST_ASSERT(caster.equip_to_slot_if_possible(codex, ITEM_SLOT_SUITSTORE), "Could not store the open Codex.")
	TEST_ASSERT(!spell.Trigger(), "A stored open Codex allowed spellcasting without being held.")

	var/datum/heretic_knowledge/spell/basic/grasp_knowledge = allocate(/datum/heretic_knowledge/spell/basic)
	grasp_knowledge.on_gain(caster, heretic)
	var/datum/action/cooldown/spell/touch/mansus_grasp/grasp = grasp_knowledge.created_action_ref
	TEST_ASSERT(grasp.Trigger(), "Mansus Grasp could not be invoked without a focus.")
	TEST_ASSERT_NOTNULL(grasp.attached_hand, "Mansus Grasp did not create its touch hand.")
