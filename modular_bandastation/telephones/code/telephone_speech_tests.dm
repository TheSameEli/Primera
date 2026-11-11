/// Real speech and TTS220 receivers, without external synthesis or a network client.
/datum/unit_test/telephone/speech_relay
	var/list/observations = list()
	var/legacy_tts_enabled

/datum/unit_test/telephone/speech_relay/New()
	. = ..()
	legacy_tts_enabled = SStts.tts_enabled
	SStts.tts_enabled = FALSE
	calling_user = allocate(/mob/living/carbon/human/consistent/tts_listener)
	receiving_user = allocate(/mob/living/carbon/human/consistent/tts_listener)
	observe(calling_user)
	observe(receiving_user)
	var/turf/remote_turf = locate(calling_phone.x + 10, calling_phone.y, calling_phone.z)
	receiving_phone.forceMove(remote_turf)
	receiving_user.forceMove(remote_turf)
	calling_user.put_in_hands(calling_phone.handset)
	calling_phone.start_call(calling_user, receiving_phone.phone_id)
	receiving_user.put_in_hands(receiving_phone.handset)
	receiving_phone.answer_call()
	// TTS220's signal define is included after the core unit tests.
	RegisterSignal(calling_user, "atom_tts_cast", PROC_REF(on_tts))
	RegisterSignal(receiving_user, "atom_tts_cast", PROC_REF(on_tts))

/datum/unit_test/telephone/speech_relay/Destroy()
	if(!isnull(legacy_tts_enabled))
		SStts.tts_enabled = legacy_tts_enabled
	observations = null
	return ..()

/// Watches rendered telephone messages and synthesis input without replacing Hear or say.
/datum/unit_test/telephone/speech_relay/proc/observe(mob/living/carbon/human/listener)
	listener.voice = null
	listener.mock_client = allocate(/datum/client_interface)
	observations[listener] = list("count" = 0, "tts_count" = 0)
	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))

/datum/unit_test/telephone/speech_relay/proc/on_hear(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	if(!istype(hearing_args[HEARING_SPEAKER], /atom/movable/virtualspeaker))
		return
	var/list/result = observations[source]
	var/list/modifiers = hearing_args[HEARING_MESSAGE_MODE]
	var/list/filters = modifiers[MODE_TTS_FILTERS]
	result["count"]++
	result["message"] = hearing_args[HEARING_RAW_MESSAGE]
	result["relay"] = modifiers[MODE_RELAY]
	result["quiet"] = (/datum/singleton/sound_effect/telephone_leak in filters)
	result["verb"] = modifiers[SAY_MOD_VERB]
	result["italics"] = (SPAN_ITALICS in hearing_args[HEARING_SPANS])

/datum/unit_test/telephone/speech_relay/proc/on_tts(datum/source, listener, message, location, is_local, is_radio, list/effects)
	SIGNAL_HANDLER
	if(!(listener in observations) || !(/datum/singleton/sound_effect/radio in effects))
		return
	var/list/result = observations[listener]
	result["tts_count"]++
	result["tts_message"] = message
	result["tts_quiet"] = (/datum/singleton/sound_effect/telephone_leak in effects)
	result["tts_local"] = is_local

/datum/unit_test/telephone/speech_relay/Run()
	TEST_ASSERT_EQUAL(calling_phone.status, PHONE_CONNECTED, "The speech fixture must connect its real phones.")
	var/list/received = observations[receiving_user]
	calling_user.set_species(/datum/species/lizard)
	calling_user.set_active_language(/datum/language/common)
	calling_user.say("She is so sassy", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(received["count"], 1, "The remote listener must receive exactly one utterance.")
	TEST_ASSERT_EQUAL(received["message"], "SSShe isss ssso sssasssy", "The telephone must relay the processed accent rather than raw input.")
	TEST_ASSERT_EQUAL(received["tts_message"], received["message"], "TTS220 must receive the listener's processed message.")
	TEST_ASSERT(received["relay"], "Relayed speech must retain MODE_RELAY.")
	calling_user.set_active_language(/datum/language/draconic)
	calling_user.say("Hidden words", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(received["count"], 2, "A second-language utterance must be relayed once.")
	TEST_ASSERT_NOTEQUAL(received["message"], "Hidden words", "The telephone must not reveal an unknown language.")
	TEST_ASSERT_EQUAL(received["tts_message"], received["message"], "TTS220 must voice the same scrambled language as chat.")
	calling_user.set_active_language(/datum/language/common)
	calling_user.say("She is so sassy ,o Hidden word ,0 Again", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(received["count"], 3, "Mixed languages must arrive as one complete utterance.")
	TEST_ASSERT(findtext(received["message"], "SSShe isss ssso sssasssy"), "Mixed speech must retain the accent on its known-language fragment.")
	TEST_ASSERT(!findtext(received["message"], "Hidden word"), "Mixed speech must conceal its unknown-language fragment.")
	TEST_ASSERT(findtext(received["message"], "Again"), "Mixed speech must preserve text after the unknown fragment.")
	TEST_ASSERT_EQUAL(received["tts_message"], received["message"], "TTS220 must receive the whole mixed-language utterance after translation.")
	receiving_phone.handset.attack_self(receiving_user)
	calling_user.say("Lowered receiver", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(received["count"], 4, "A lowered receiver must still leak its incoming voice nearby.")
	TEST_ASSERT(received["quiet"] && received["tts_quiet"], "A lowered receiver must use the quiet chat and TTS route.")
	calling_phone.handset.attack_self(calling_user)
	calling_user.say("Lowered sender", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(received["count"], 4, "A lowered caller handset must not transmit.")

/// The holder hears once at normal volume; only adjacent bystanders hear quiet earpiece leakage.
/datum/unit_test/telephone/speech_audibility
	parent_type = /datum/unit_test/telephone/speech_relay

/datum/unit_test/telephone/speech_audibility/Run()
	TEST_ASSERT_EQUAL(calling_phone.status, PHONE_CONNECTED, "The audibility fixture must connect its real phones.")
	var/mob/living/carbon/human/consistent/tts_listener/nearby = allocate(/mob/living/carbon/human/consistent/tts_listener, get_step(receiving_user, NORTH))
	var/mob/living/carbon/human/consistent/tts_listener/distant = allocate(/mob/living/carbon/human/consistent/tts_listener, get_step(nearby, NORTH))
	observe(nearby)
	observe(distant)
	var/list/primary = observations[receiving_user]
	var/list/close = observations[nearby]
	var/list/far = observations[distant]
	var/list/reverse = observations[calling_user]
	calling_user.say("Audible once", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(primary["count"], 1, "The raised receiver's holder must receive one message without a quiet duplicate.")
	TEST_ASSERT_EQUAL(primary["tts_count"], 1, "The raised receiver's holder must receive one synthesis request.")
	TEST_ASSERT(!primary["quiet"] && !primary["tts_quiet"], "A raised receiver must retain normal telephone volume for its holder.")
	TEST_ASSERT_EQUAL(close["count"], 1, "A bystander one tile away must hear the incoming voice.")
	TEST_ASSERT(close["quiet"] && close["tts_quiet"] && close["italics"], "Nearby leakage must use quiet text and reduced-volume TTS.")
	TEST_ASSERT_EQUAL(close["verb"], "тихо говорит", "The nearby chat message must describe the quiet voice.")
	TEST_ASSERT(close["relay"] && !close["tts_local"], "Quiet delivery must remain relayed and private to its selected listener.")
	TEST_ASSERT_EQUAL(far["count"], 0, "A bystander two tiles away must not receive telephone chat.")
	TEST_ASSERT_EQUAL(far["tts_count"], 0, "A bystander two tiles away must not receive a TTS request.")
	receiving_user.dropItemToGround(receiving_phone.handset)
	calling_user.say("Receiver on floor", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(receiving_phone.handset.loc, get_turf(receiving_user), "The receiver must actually be on the floor.")
	TEST_ASSERT_EQUAL(primary["count"], 2, "The former holder must hear the floor receiver quietly.")
	TEST_ASSERT(primary["quiet"] && primary["tts_quiet"], "A floor receiver must not retain a private normal-volume listener.")
	TEST_ASSERT_EQUAL(close["count"], 2, "An adjacent bystander must still hear a receiver on the floor.")
	TEST_ASSERT_EQUAL(far["count"], 0, "Putting the receiver on the floor must not widen its chat audience.")
	TEST_ASSERT_EQUAL(far["tts_count"], 0, "Putting the receiver on the floor must not widen its synthesis audience.")
	receiving_user.say("Not a floor microphone", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(reverse["count"], 0, "A floor handset must not transmit nearby speech back to the caller.")

/// Covering takes a real second hand, mutes only transmission, and leaves raise/lower independent.
/datum/unit_test/telephone/microphone_cover
	parent_type = /datum/unit_test/telephone/speech_relay

/datum/unit_test/telephone/microphone_cover/Run()
	TEST_ASSERT_EQUAL(calling_phone.status, PHONE_CONNECTED, "The cover fixture must connect its real phones.")
	var/obj/item/telephone/phone = calling_phone.handset
	var/datum/component/two_handed/cover = phone.GetComponent(/datum/component/two_handed)
	TEST_ASSERT_NOTNULL(cover, "The phone must use the native two-handed component.")
	phone.attack_self(calling_user)
	TEST_ASSERT(!phone.raised && !HAS_TRAIT(phone, TRAIT_WIELDED), "Primary use must lower the phone without covering its microphone.")
	phone.attack_self(calling_user)
	TEST_ASSERT(phone.raised && !HAS_TRAIT(phone, TRAIT_WIELDED), "Primary use must raise the phone without occupying the second hand.")
	var/obj/item/pen/pen = allocate(/obj/item/pen)
	TEST_ASSERT(calling_user.put_in_inactive_hand(pen), "The other hand must be genuinely occupied before the rejected action.")
	phone.attack_self_secondary(calling_user)
	TEST_ASSERT(!HAS_TRAIT(phone, TRAIT_WIELDED) && !cover.offhand_item, "A busy second hand must prevent microphone covering.")
	TEST_ASSERT_EQUAL(calling_user.get_inactive_held_item(), pen, "A rejected cover action must preserve the held item.")
	calling_user.dropItemToGround(pen)
	phone.attack_self_secondary(calling_user)
	var/obj/item/offhand/covering_hand = cover.offhand_item
	TEST_ASSERT(HAS_TRAIT(phone, TRAIT_WIELDED) && istype(covering_hand), "Secondary use must cover through a native offhand and wielded trait.")
	TEST_ASSERT_EQUAL(calling_user.get_inactive_held_item(), covering_hand, "Covering must actually occupy the second hand.")
	var/list/received = observations[receiving_user]
	var/list/reverse = observations[calling_user]
	calling_user.say("Covered microphone", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(received["count"], 0, "A covered microphone must suppress outgoing speech.")
	receiving_user.say("Still receiving", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(reverse["count"], 1, "Covering the microphone must preserve incoming speech.")
	phone.attack_self(calling_user)
	TEST_ASSERT(!phone.raised && HAS_TRAIT(phone, TRAIT_WIELDED), "Lowering must preserve the separately covered microphone.")
	phone.attack_self(calling_user)
	TEST_ASSERT(phone.raised && HAS_TRAIT(phone, TRAIT_WIELDED), "Raising must preserve the separately covered microphone.")
	phone.attack_self_secondary(calling_user)
	TEST_ASSERT(!HAS_TRAIT(phone, TRAIT_WIELDED) && QDELETED(covering_hand), "Opening the microphone must release its native offhand.")
	TEST_ASSERT_NULL(calling_user.get_inactive_held_item(), "Opening must free the second hand.")
	calling_user.say("Open microphone", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(received["count"], 1, "Opening must restore transmission on the same call.")

/// Native give, drop, hand loss and item deletion must release the microphone's reserved hand.
/datum/unit_test/telephone/microphone_cleanup
	parent_type = /datum/unit_test/telephone/speech_relay

/datum/unit_test/telephone/microphone_cleanup/Run()
	TEST_ASSERT_EQUAL(calling_phone.status, PHONE_CONNECTED, "The cleanup fixture must connect its real phones.")
	var/obj/item/telephone/phone = calling_phone.handset
	var/datum/component/two_handed/cover = phone.GetComponent(/datum/component/two_handed)
	phone.attack_self_secondary(calling_user)
	var/obj/item/offhand/old_offhand = cover.offhand_item
	TEST_ASSERT_NOTNULL(old_offhand, "The giver must cover the microphone before handing it over.")
	var/mob/living/carbon/human/consistent/next_holder = allocate(/mob/living/carbon/human/consistent)
	next_holder.take(calling_user, phone)
	TEST_ASSERT_EQUAL(phone.holder, next_holder, "Native take must transfer the handset to its new holder.")
	TEST_ASSERT(QDELETED(old_offhand) && !HAS_TRAIT(phone, TRAIT_WIELDED), "Giving a covered phone must release the previous holder's offhand and cover state.")
	TEST_ASSERT_NULL(calling_user.get_inactive_held_item(), "Giving must leave the former holder's other hand free.")
	phone.attack_self_secondary(next_holder)
	old_offhand = cover.offhand_item
	TEST_ASSERT_NOTNULL(old_offhand, "The new holder must be able to cover the microphone independently.")
	next_holder.dropItemToGround(phone)
	TEST_ASSERT(QDELETED(old_offhand) && !HAS_TRAIT(phone, TRAIT_WIELDED), "Dropping must release the microphone's reserved hand.")
	TEST_ASSERT_EQUAL(receiving_phone.current_call, calling_phone, "Dropping the covered handset must keep its call connected.")
	TEST_ASSERT(next_holder.put_in_hands(phone), "The next holder must pick the handset up again.")
	phone.attack_self_secondary(next_holder)
	old_offhand = cover.offhand_item
	TEST_ASSERT_NOTNULL(old_offhand, "The microphone must be covered before losing the supporting hand.")
	var/obj/item/bodypart/supporting_arm = next_holder.hand_bodyparts[next_holder.get_inactive_hand_index()]
	supporting_arm.drop_limb()
	TEST_ASSERT(QDELETED(old_offhand) && !HAS_TRAIT(phone, TRAIT_WIELDED), "Losing the supporting hand must open the microphone and delete its offhand.")
	TEST_ASSERT(next_holder.is_holding(phone), "Losing the supporting hand must leave the handset in the surviving hand.")
	TEST_ASSERT(supporting_arm.try_attach_limb(next_holder), "The fixture must restore the supporting hand before the deletion scenario.")
	phone.attack_self_secondary(next_holder)
	old_offhand = cover.offhand_item
	TEST_ASSERT_NOTNULL(old_offhand, "The microphone must be covered before deleting its handset.")
	qdel(phone)
	TEST_ASSERT(QDELETED(old_offhand), "Deleting a covered handset must delete its reserved offhand.")
	TEST_ASSERT_NULL(next_holder.get_inactive_held_item(), "Deleting the handset must leave no offhand in the holder's inventory.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "Deleting a covered handset must disconnect the remote phone.")
