//Please use mob or src (not usr) in these procs. This way they can be called in the same fashion as procs.
GAME_VERB_HIDDEN(/client, wiki, "wiki")

	var/wikiurl = CONFIG_GET(string/wikiurl)
	if(!wikiurl)
		to_chat(src, span_danger("The wiki URL is not set in the server configuration."))
		return

	var/query = tgui_input_text(src,
		"Напишите что-то о чём вы хотите узнать. Это откроет вики в вашем браузере. Если ничего не введено, то откроется главная страница.",
		"Вики",
		max_length = MAX_MESSAGE_LEN,
	)
	if(isnull(query)) //cancelled out
		return
	var/output = wikiurl
	if(query != "")
		output += "?title=Special%3ASearch&profile=default&search=[query]"
	DIRECT_OUTPUT(src, link(output))

GAME_VERB_HIDDEN(/client, forum, "forum")

	var/forumurl = CONFIG_GET(string/forumurl)
	if(!forumurl)
		to_chat(src, span_danger("The forum URL is not set in the server configuration."))
		return
	DIRECT_OUTPUT(src, link(forumurl))

GAME_VERB_HIDDEN(/client, rules, "rules")

	var/rulesurl = CONFIG_GET(string/rulesurl)
	if(!rulesurl)
		to_chat(src, span_danger("The rules URL is not set in the server configuration."))
		return
	DIRECT_OUTPUT(src, link(rulesurl))

GAME_VERB_HIDDEN(/client, github, "github")

	var/githuburl = CONFIG_GET(string/githuburl)
	if(!githuburl)
		to_chat(src, span_danger("The Github URL is not set in the server configuration."))
		return

	if(tgui_alert(usr, "Хотите перейти на страницу нашего репозитория?", "GitHub", list("Да", "Нет")) != "Да")
		return

	DIRECT_OUTPUT(src, link(githuburl))

GAME_VERB_HIDDEN(/client, config, "config")

	var/configurl = CONFIG_GET(string/configurl)
	if(!configurl)
		to_chat(src, span_danger("The Config URL is not set in the server configuration."))
		return
	DIRECT_OUTPUT(src, link(configurl))

// BANDASTATION EDIT START - replace external issue form with in-game bug reports
GAME_VERB_DESC(/client, reportissue, "report-issue", "Report an issue", "OOC")
	open_bug_report()
// BANDASTATION EDIT END - in-game bug reports

GAME_VERB(/client, changelog, "Changelog", "OOC")

	if(!GLOB.changelog_tgui)
		GLOB.changelog_tgui = new /datum/changelog()

	GLOB.changelog_tgui.ui_interact(mob)
	if(prefs.lastchangelog != GLOB.changelog_hash)
		prefs.lastchangelog = GLOB.changelog_hash
		prefs.save_preferences()

GAME_VERB_HIDDEN(/client, hotkeys_help, "Hotkeys Help")

	if(!GLOB.hotkeys_tgui)
		GLOB.hotkeys_tgui = new /datum/hotkeys_help()

	GLOB.hotkeys_tgui.ui_interact(mob)

GAME_VERB_HIDDEN(/client, emote_panel, "Emote Panel")

	if(!isliving(mob))
		to_chat(mob, span_notice("You can only use this while you're alive!"))
		return

	if(!GLOB.emote_panel)
		GLOB.emote_panel = new /datum/emote_panel()
	GLOB.emote_panel.ui_interact(mob)
