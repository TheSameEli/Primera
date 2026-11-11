// AI EDIT START - Verify internal affairs equipment and antagonist protection
// BANDASTATION ADDITION START - Internal affairs role regression tests
/// The actual job outfit must implant a functional mindshield, including the fork's formal outfit override.
/datum/unit_test/lawyer_mindshield

/datum/unit_test/lawyer_mindshield/Run()
	var/mob/living/carbon/human/agent = allocate(/mob/living/carbon/human/consistent)
	agent.mind_initialize()
	var/datum/job/lawyer/job = SSjob.get_job_type(/datum/job/lawyer)
	agent.mind.assigned_role = job
	agent.dress_up_as_job(job)

	var/obj/item/implant/mindshield/shield = locate() in agent.implants
	TEST_ASSERT_NOTNULL(shield, "The internal affairs agent's job outfit did not implant a mindshield.")
	TEST_ASSERT(HAS_TRAIT(agent, TRAIT_MINDSHIELD), "The internal affairs agent's mindshield is not functional.")
	var/datum/antagonist/rev/revolutionary = allocate(/datum/antagonist/rev)
	TEST_ASSERT(!revolutionary.can_be_converted(agent), "An equipped internal affairs agent can be converted to revolution.")

	shield.removed(agent, silent = TRUE)
	qdel(shield)
	TEST_ASSERT(revolutionary.can_be_converted(agent), "The conversion check did not become eligible after removing the mindshield.")

/// Dynamic must exclude internal affairs when protected jobs are enabled and preserve the config opt-out.
/datum/unit_test/lawyer_antag_protection

/datum/unit_test/lawyer_antag_protection/Run()
	var/datum/dynamic_ruleset/ruleset = allocate(/datum/dynamic_ruleset)
	var/original_protection = CONFIG_GET(flag/protect_roles_from_antagonist)
	CONFIG_SET(flag/protect_roles_from_antagonist, TRUE)
	var/list/protected_roles = ruleset.get_config_blacklisted_roles()
	CONFIG_SET(flag/protect_roles_from_antagonist, FALSE)
	var/list/unprotected_roles = ruleset.get_config_blacklisted_roles()
	CONFIG_SET(flag/protect_roles_from_antagonist, original_protection)

	TEST_ASSERT(JOB_LAWYER in protected_roles, "Dynamic can assign a protected internal affairs agent an antagonist role.")
	TEST_ASSERT(!(JOB_LAWYER in unprotected_roles), "Internal affairs ignores the protected-jobs config opt-out.")
// BANDASTATION ADDITION END
// AI EDIT END
