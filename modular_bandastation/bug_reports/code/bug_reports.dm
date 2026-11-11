// Adapted from https://github.com/ParadiseSS13/Paradise/pull/30376 (originally CM-SS13).
#define BUG_REPORT_COOLDOWN (5 MINUTES)
#define BUG_REPORT_RIGHTS (R_ADMIN|R_DEBUG)
#define BUG_REPORT_TITLE_LIMIT 256
#define BUG_REPORT_TEXT_LIMIT 4096
#define BUG_REPORT_LOG_LIMIT 8192
#define BUG_REPORT_CREATED 201

GLOBAL_LIST_EMPTY(bug_reports)
GLOBAL_LIST_EMPTY(bug_report_drafts)
GLOBAL_LIST_EMPTY(bug_report_next_submission)

/datum/config_entry/string/github_api_token
	protection = CONFIG_ENTRY_LOCKED | CONFIG_ENTRY_HIDDEN

/// Restrict authenticated requests to the public GitHub API, using the existing repository setting.
/proc/bug_report_repository(repo_url)
	if(!istext(repo_url))
		return null
	var/static/regex/repository = regex("^https://(www\\.)?github\\.com/(\[A-Za-z0-9_.-\]+/\[A-Za-z0-9_.-\]+)/?$")
	if(repository.Find(repo_url) && repository.match == repo_url)
		return repository.group[2]
	return null

/proc/bug_report_cooldown_remaining(author_ckey)
	return max(0, GLOB.bug_report_next_submission[author_ckey] - world.time)

/client/proc/open_bug_report()
	if(!mob || !bug_report_repository(CONFIG_GET(string/githuburl)))
		to_chat(src, span_warning("Багрепорты не настроены: требуется адрес репозитория GitHub в GITHUBURL."))
		return
	var/remaining = bug_report_cooldown_remaining(ckey)
	if(remaining)
		to_chat(src, span_warning("Следующий багрепорт можно отправить через [DisplayTimeText(remaining)]."))
		return
	var/datum/bug_report/report = GLOB.bug_report_drafts[ckey]
	if(QDELETED(report))
		report = new(mob)
		GLOB.bug_report_drafts[ckey] = report
	report.ui_interact(mob)

ADMIN_VERB(view_bug_reports, BUG_REPORT_RIGHTS, "View Bug Reports", "Проверить багрепорты игроков перед отправкой на GitHub.", ADMIN_CATEGORY_DEBUG)
	var/list/choices = list()
	for(var/datum/bug_report/report as anything in GLOB.bug_reports)
		choices["#[length(choices) + 1] [report.author_key]: [report.report_data["title"]]"] = report
	if(!length(choices))
		to_chat(user, span_notice("Багрепортов на проверку нет."))
		return
	var/selection = tgui_input_list(user, "Выберите багрепорт", "Багрепорты", choices)
	var/datum/bug_report/report = choices[selection]
	if(!QDELETED(report) && report.assign_approver(user))
		report.ui_interact(user.mob)

/datum/bug_report
	/// Only submitted reports are retained after their UI closes.
	var/submitted = FALSE
	/// Locks approval before the HTTP request yields.
	var/sending = FALSE
	var/author_ckey
	var/author_key
	/// Keys avoid retaining disconnected clients or deleted mobs.
	var/reviewer_ckey
	var/list/report_data = list()
	var/client_version
	var/server_commit
	var/origin_commit
	var/round_id
	var/test_merges

/datum/bug_report/New(mob/user)
	. = ..()
	author_ckey = user?.ckey
	author_key = user?.key
	if(user?.client)
		client_version = "[user.client.byond_version].[user.client.byond_build]"
	server_commit = GLOB.revdata.commit
	origin_commit = GLOB.revdata.originmastercommit
	round_id = GLOB.round_id
	var/list/merges = list()
	for(var/datum/tgs_revision_information/test_merge/merge as anything in GLOB.revdata.testmerge)
		merges += "#[merge.number] at [merge.head_commit]"
	test_merges = merges.Join("\n")

/datum/bug_report/Destroy()
	GLOB.bug_reports -= src
	if(author_ckey && GLOB.bug_report_drafts[author_ckey] == src)
		GLOB.bug_report_drafts -= author_ckey
	SStgui.close_uis(src)
	report_data = null
	return ..()

/datum/bug_report/ui_status(mob/user, datum/ui_state/state)
	if(!user?.client)
		return UI_CLOSE
	if(!submitted)
		return user.ckey == author_ckey ? UI_INTERACTIVE : UI_CLOSE
	return user.ckey == reviewer_ckey && check_rights_for(user.client, BUG_REPORT_RIGHTS) ? UI_INTERACTIVE : UI_CLOSE

/datum/bug_report/ui_interact(mob/user, datum/tgui/ui)
	if(ui_status(user) != UI_INTERACTIVE)
		ui?.close()
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BugReportForm")
		ui.open()

/datum/bug_report/ui_close(mob/user)
	. = ..()
	if(!submitted && !QDELETED(src))
		qdel(src)
	else if(!sending && reviewer_ckey == user?.ckey)
		reviewer_ckey = null

/datum/bug_report/ui_data(mob/user)
	return list(
		"report_details" = report_data,
		"awaiting_approval" = submitted,
		"sending" = sending,
		"author" = author_key,
		"title_limit" = BUG_REPORT_TITLE_LIMIT,
		"text_limit" = BUG_REPORT_TEXT_LIMIT,
		"log_limit" = BUG_REPORT_LOG_LIMIT,
	)

/datum/bug_report/proc/assign_approver(client/user)
	if(!submitted || sending || !(src in GLOB.bug_reports) || !user?.mob || !check_rights_for(user, BUG_REPORT_RIGHTS))
		return FALSE
	var/client/reviewer = GLOB.directory[reviewer_ckey]
	if(reviewer && SStgui.get_open_ui(reviewer.mob, src))
		to_chat(user, span_warning("Этот багрепорт уже открыт на проверку."))
		return FALSE
	reviewer_ckey = user.ckey
	return TRUE

/// Whitelist, type-check and bound fields on the server; keep code/log text intact.
/datum/bug_report/proc/validate_data(list/params)
	if(!islist(params))
		return null
	var/list/validated = list()
	for(var/field in list("title", "expected_behavior", "description", "consequences", "steps", "log", "approver_note"))
		var/optional = field == "log" || field == "approver_note"
		var/value = params[field]
		if(isnull(value) && optional)
			value = ""
		var/limit = field == "title" ? BUG_REPORT_TITLE_LIMIT : (field == "log" ? BUG_REPORT_LOG_LIMIT : BUG_REPORT_TEXT_LIMIT)
		if(!istext(value) || length_char(value) > limit || (!optional && !length(trim(value))))
			return null
		validated[field] = value
	if(!submitted)
		validated["approver_note"] = ""
	return validated

/datum/bug_report/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || sending || ui_status(ui?.user) != UI_INTERACTIVE)
		return
	var/mob/user = ui.user
	switch(action)
		if("confirm")
			var/list/validated = validate_data(params)
			if(!validated)
				to_chat(user, span_warning("Заполните все обязательные поля и соблюдайте ограничения длины."))
				return
			if(!submitted)
				if(bug_report_cooldown_remaining(author_ckey))
					to_chat(user, span_warning("Между отправками багрепортов должно пройти 5 минут."))
					return
				report_data = validated
				submitted = TRUE
				GLOB.bug_report_drafts -= author_ckey
				GLOB.bug_reports += src
				GLOB.bug_report_next_submission[author_ckey] = world.time + BUG_REPORT_COOLDOWN
				message_admins("[html_encode(author_key)] отправил багрепорт «[html_encode(report_data["title"])]». Проверка: View Bug Reports (Debug).")
				to_chat(user, span_notice("Багрепорт отправлен на проверку администрации. Спасибо!"))
				ui.close()
			else
				report_data = validated
				sending = TRUE
				ui.close()
				INVOKE_ASYNC(src, PROC_REF(send_request))
		if("cancel")
			if(submitted)
				log_admin("[reviewer_ckey] rejected a bug report from [author_ckey]: [report_data["title"]]")
				message_admins("[reviewer_ckey] отклонил багрепорт [html_encode(author_key)] «[html_encode(report_data["title"])]».")
				var/client/author = GLOB.directory[author_ckey]
				if(author)
					to_chat(author, span_warning("Администрация отклонила ваш багрепорт «[html_encode(report_data["title"])]»."))
			qdel(src)
	return TRUE

/datum/bug_report/proc/create_body()
	return {"## Ожидаемое поведение
[report_data["expected_behavior"]]

## Что произошло
[report_data["description"]]

## Последствия
[report_data["consequences"]]

## Шаги воспроизведения
[report_data["steps"]]

## Логи
```
[report_data["log"] || "Нет"]
```

## Дополнительные сведения
- Автор: [author_key]
- Проверил: [reviewer_ckey]
- Раунд: [round_id || "Не задан"]
- BYOND клиента: [client_version]
- BYOND сервера: [world.byond_version].[world.byond_build]
- Коммит сервера: [server_commit]
- Коммит origin/master: [origin_commit]
- Активные test merges:
[test_merges || "Нет"]
- Примечание проверяющего: [report_data["approver_note"] || "Нет"]
"}

/datum/bug_report/proc/send_request()
	if(IsAdminAdvancedProcCall() || !sending || !submitted)
		return
	var/repository = bug_report_repository(CONFIG_GET(string/githuburl))
	var/token = CONFIG_GET(string/github_api_token)
	if(!repository || !length(token) || !check_rights_for(GLOB.directory[reviewer_ckey], BUG_REPORT_RIGHTS))
		sending = FALSE
		reviewer_ckey = null
		message_admins("Багрепорт сохранён в очереди: проверьте настройки GitHub и права проверяющего.")
		return
	var/datum/http_request/request = new()
	request.prepare(RUSTG_HTTP_METHOD_POST, "https://api.github.com/repos/[repository]/issues", json_encode(list(
		"title" = report_data["title"],
		"body" = create_body(),
		"labels" = list("bug"),
	)), list(
		"Authorization" = "Bearer [token]",
		"Accept" = "application/vnd.github+json",
		"Content-Type" = "application/json; charset=utf-8",
		"User-Agent" = "PrimeDream-BugReports",
	), timeout_seconds = 15)
	var/datum/http_response/response
	try
		request.begin_async()
		UNTIL(request.is_complete())
		response = request.into_response()
	catch
		response = new()
		response.errored = TRUE
	request.headers = null
	qdel(request)
	handle_response(response)
	qdel(response)

/datum/bug_report/proc/handle_response(datum/http_response/response)
	if(response.errored || response.status_code != BUG_REPORT_CREATED)
		sending = FALSE
		reviewer_ckey = null
		message_admins("GitHub не подтвердил создание issue (HTTP [response.status_code || "нет ответа"]). Багрепорт «[html_encode(report_data["title"])]» сохранён в очереди. Проверьте Issues перед повторной отправкой.")
		return FALSE
	log_admin("[reviewer_ckey] approved a bug report from [author_ckey]: [report_data["title"]]")
	message_admins("[reviewer_ckey] отправил багрепорт [html_encode(author_key)] «[html_encode(report_data["title"])]» на GitHub.")
	var/client/author = GLOB.directory[author_ckey]
	if(author)
		to_chat(author, span_notice("Ваш багрепорт «[html_encode(report_data["title"])]» опубликован на GitHub. Спасибо!"))
	qdel(src)
	return TRUE

#undef BUG_REPORT_COOLDOWN
#undef BUG_REPORT_RIGHTS
#undef BUG_REPORT_TITLE_LIMIT
#undef BUG_REPORT_TEXT_LIMIT
#undef BUG_REPORT_LOG_LIMIT
#undef BUG_REPORT_CREATED
