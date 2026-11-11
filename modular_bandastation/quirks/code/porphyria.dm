#define PORPHYRIA_NUTRITION_PER_BLOOD (NUTRITION_LEVEL_WELL_FED / 120)
#define PORPHYRIA_DRAIN_PER_SECOND (NUTRITION_LEVEL_WELL_FED / (40 * 60))
#define PORPHYRIA_STARVATION_SECONDS (3 * 60)
#define PORPHYRIA_BITE_PER_SECOND 15
#define PORPHYRIA_ALTERNATE_EFFICIENCY 0.5
#define PORPHYRIA_REVIVAL_BLOOD 50

/datum/quirk/porphyria
	name = "Порфирия"
	desc = "Вам необходима кровь: полного насыщения хватает на 40 минут, а три минуты без крови смертельны. Агрессивно удерживая живую жертву, ударьте пустой рукой в голову, чтобы пить кровь. Кровь обезьян и любая кровь, полученная иначе, насыщает вдвое слабее. После смерти от голода вас можно оживить 50 единицами крови в желудке."
	icon = FA_ICON_DROPLET
	value = -6
	quirk_flags = QUIRK_HUMAN_ONLY|QUIRK_PROCESSES
	mob_trait = TRAIT_BLOOD_DIET
	maximum_process_stat = null
	gain_text = span_warning("Вы ощущаете жажду крови.")
	lose_text = span_notice("Жажда крови покидает вас.")
	medical_record_text = "Пациент страдает порфирией и нуждается в регулярном употреблении крови."
	/// Seconds spent continuously at zero ordinary nutrition.
	var/starvation_time = 0
	/// Blood revival applies to death from this quirk, rather than unrelated injuries.
	var/died_from_starvation = FALSE
	/// Prevents concurrent bite actions.
	var/drinking = FALSE

/datum/quirk/porphyria/is_species_appropriate(datum/species/mob_species)
	return !ispath(mob_species, /datum/species/ipc) && ..()

/datum/quirk/porphyria/add(client/client_source)
	RegisterSignal(quirk_holder, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
	RegisterSignal(quirk_holder, COMSIG_CARBON_STOMACH_DIGEST, PROC_REF(on_stomach_digest))
	RegisterSignal(quirk_holder, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	RegisterSignals(quirk_holder, list(SIGNAL_ADDTRAIT(TRAIT_VAMPIRE), SIGNAL_REMOVETRAIT(TRAIT_VAMPIRE)), PROC_REF(on_vampire_changed))
	update_effects()

/datum/quirk/porphyria/add_unique(client/client_source)
	if(!is_active())
		return
	quirk_holder.set_nutrition(NUTRITION_LEVEL_WELL_FED, forced = TRUE)
	update_effects()

/datum/quirk/porphyria/remove()
	UnregisterSignal(quirk_holder, list(COMSIG_LIVING_EARLY_UNARMED_ATTACK, COMSIG_CARBON_STOMACH_DIGEST, COMSIG_ATOM_EXAMINE, SIGNAL_ADDTRAIT(TRAIT_VAMPIRE), SIGNAL_REMOVETRAIT(TRAIT_VAMPIRE)))
	clear_effects()
	starvation_time = 0
	died_from_starvation = FALSE

/// Synthetic bodies and vampires never receive any of the quirk's effects.
/datum/quirk/porphyria/proc/is_active()
	if(QDELETED(quirk_holder) || !ishuman(quirk_holder) || HAS_TRAIT(quirk_holder, TRAIT_VAMPIRE))
		return FALSE
	var/mob/living/carbon/human/holder = quirk_holder
	return holder.dna.species.id != SPECIES_IPC

/datum/quirk/porphyria/should_process()
	return ..() && !HAS_TRAIT(quirk_holder, TRAIT_VAMPIRE)

/datum/quirk/porphyria/proc/on_vampire_changed(datum/source)
	SIGNAL_HANDLER
	starvation_time = 0
	died_from_starvation = FALSE
	update_effects()
	update_process()

/datum/quirk/porphyria/process(seconds_per_tick)
	if(!is_active())
		clear_effects()
		starvation_time = 0
		return
	if(quirk_holder.stat == DEAD)
		try_blood_revival()
		return
	died_from_starvation = FALSE
	var/seconds_until_empty = quirk_holder.nutrition / PORPHYRIA_DRAIN_PER_SECOND
	quirk_holder.adjust_nutrition(-PORPHYRIA_DRAIN_PER_SECOND * seconds_per_tick, forced = TRUE)
	if(quirk_holder.nutrition > 0)
		starvation_time = 0
	else
		if(!starvation_time)
			to_chat(quirk_holder, span_userdanger("Жажда крови становится смертельной! Без крови вы умрёте через три минуты!"))
		starvation_time += max(0, seconds_per_tick - seconds_until_empty)
		if(starvation_time >= PORPHYRIA_STARVATION_SECONDS)
			quirk_holder.investigate_log("died of porphyria blood starvation.", INVESTIGATE_DEATHS)
			quirk_holder.death()
			died_from_starvation = quirk_holder.stat == DEAD
	update_effects()

/// Uses stomach blood for ordinary nutrition before it can enter the bloodstream.
/datum/quirk/porphyria/proc/on_stomach_digest(mob/living/carbon/source, obj/item/organ/stomach/stomach, seconds_per_tick)
	SIGNAL_HANDLER
	metabolize_blood()

/// All indirect sources share half efficiency; surplus is consumed without a reward.
/datum/quirk/porphyria/proc/metabolize_blood(efficiency = PORPHYRIA_ALTERNATE_EFFICIENCY)
	if(!is_active() || quirk_holder.stat == DEAD)
		return 0
	var/mob/living/carbon/human/holder = quirk_holder
	var/obj/item/organ/stomach/stomach = holder.get_organ_slot(ORGAN_SLOT_STOMACH)
	var/amount = stomach?.reagents.get_reagent_amount(/datum/reagent/blood)
	if(!amount)
		return 0
	stomach.reagents.remove_reagent(/datum/reagent/blood, amount)
	holder.set_nutrition(min(NUTRITION_LEVEL_WELL_FED, holder.nutrition + amount * efficiency * PORPHYRIA_NUTRITION_PER_BLOOD), forced = TRUE)
	starvation_time = 0
	update_effects()
	return amount

/// A failed revival never consumes the treatment, and a successful one preserves surplus.
/datum/quirk/porphyria/proc/try_blood_revival()
	if(!is_active() || !died_from_starvation || quirk_holder.stat != DEAD)
		return FALSE
	var/mob/living/carbon/human/holder = quirk_holder
	var/obj/item/organ/stomach/stomach = holder.get_organ_slot(ORGAN_SLOT_STOMACH)
	if(stomach?.reagents.get_reagent_amount(/datum/reagent/blood) < PORPHYRIA_REVIVAL_BLOOD)
		return FALSE
	if(!holder.revive())
		return FALSE
	stomach.reagents.remove_reagent(/datum/reagent/blood, PORPHYRIA_REVIVAL_BLOOD)
	holder.set_nutrition(NUTRITION_LEVEL_WELL_FED * 0.05, forced = TRUE)
	starvation_time = 0
	died_from_starvation = FALSE
	update_effects()
	to_chat(holder, span_notice("Кровь возвращает вас к жизни, но жажда всё ещё мучает вас."))
	return TRUE

/datum/quirk/porphyria/proc/on_unarmed_attack(mob/living/carbon/human/source, atom/target, proximity_flag, list/modifiers)
	SIGNAL_HANDLER
	if(!proximity_flag || LAZYACCESS(modifiers, RIGHT_CLICK) || !can_bite(target))
		return
	if(!drinking)
		INVOKE_ASYNC(src, PROC_REF(drink_blood), target)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/// Revalidated during the interruptible action and immediately before each blood transfer.
/datum/quirk/porphyria/proc/can_bite(mob/living/carbon/victim, mob/living/carbon/human/expected_holder = quirk_holder)
	if(!is_active() || quirk_holder != expected_holder || QDELETED(victim) || !ishuman(victim) || victim == quirk_holder)
		return FALSE
	var/mob/living/carbon/human/holder = quirk_holder
	if(holder.stat >= SOFT_CRIT || holder.incapacitated || !holder.can_unarmed_attack() || holder.is_mouth_covered())
		return FALSE
	if(!holder.combat_mode || holder.get_active_held_item() || holder.zone_selected != BODY_ZONE_HEAD)
		return FALSE
	if(holder.pulling != victim || holder.grab_state < GRAB_AGGRESSIVE || !holder.Adjacent(victim))
		return FALSE
	if(victim.stat == DEAD || victim.get_blood_volume() <= 0 || victim.get_blood_reagent() != /datum/reagent/blood)
		return FALSE
	return holder.nutrition < NUTRITION_LEVEL_WELL_FED && holder.get_organ_slot(ORGAN_SLOT_STOMACH)

/// Transfers real blood into the stomach and immediately metabolizes this fresh serving.
/datum/quirk/porphyria/proc/bite_tick(mob/living/carbon/victim, seconds_per_tick = 1)
	if(seconds_per_tick <= 0 || !can_bite(victim))
		return 0
	metabolize_blood()
	if(!can_bite(victim))
		return 0
	var/mob/living/carbon/human/holder = quirk_holder
	var/efficiency = HAS_TRAIT(victim, TRAIT_SIMIAN) ? PORPHYRIA_ALTERNATE_EFFICIENCY : 1
	var/amount = min(PORPHYRIA_BITE_PER_SECOND * seconds_per_tick, (NUTRITION_LEVEL_WELL_FED - holder.nutrition) / (efficiency * PORPHYRIA_NUTRITION_PER_BLOOD))
	var/obj/item/organ/stomach/stomach = holder.get_organ_slot(ORGAN_SLOT_STOMACH)
	var/drained = victim.transfer_blood_to(stomach, amount, ignore_low_blood = TRUE)
	if(!drained)
		return 0
	var/datum/reagent/blood/blood = stomach.reagents.has_reagent(/datum/reagent/blood)
	var/list/exposure = list()
	exposure[blood] = drained
	stomach.reagents.expose(holder, INGEST, r_to_expose = exposure)
	metabolize_blood(efficiency)
	holder.do_attack_animation(victim, ATTACK_EFFECT_BITE)
	if(efficiency == 1)
		holder.add_mood_event("porphyria_fresh_blood", /datum/mood_event/porphyria_fresh_blood)
	victim.add_mood_event("porphyria_bitten", /datum/mood_event/porphyria_bitten)
	return drained

/datum/quirk/porphyria/proc/drink_blood(mob/living/carbon/victim)
	if(drinking || !can_bite(victim))
		return
	drinking = TRUE
	var/mob/living/carbon/human/holder = quirk_holder
	log_combat(holder, victim, "started drinking blood (porphyria)")
	holder.visible_message(span_danger("[holder] вонзает зубы в [victim.declent_ru(ACCUSATIVE)] и начинает пить кровь!"), span_notice("Вы начинаете пить кровь."))
	var/datum/callback/checks = CALLBACK(src, PROC_REF(can_bite), victim, holder)
	while(can_bite(victim, holder) && do_after(holder, 1 SECONDS, victim, extra_checks = checks, cog_icon = null))
		if(!can_bite(victim, holder) || !bite_tick(victim))
			break
	if(!QDELETED(src))
		drinking = FALSE

#undef PORPHYRIA_NUTRITION_PER_BLOOD
#undef PORPHYRIA_DRAIN_PER_SECOND
#undef PORPHYRIA_STARVATION_SECONDS
#undef PORPHYRIA_BITE_PER_SECOND
#undef PORPHYRIA_ALTERNATE_EFFICIENCY
#undef PORPHYRIA_REVIVAL_BLOOD
