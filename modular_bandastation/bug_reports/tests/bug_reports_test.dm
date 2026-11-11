/datum/unit_test/bug_report_validation/Run()
	var/datum/bug_report/report = allocate(/datum/bug_report)
	var/list/params = list(
		"title" = "Тестовый баг",
		"expected_behavior" = "Ожидаемое поведение",
		"description" = "if(a < b && c > d)\n\treturn TRUE",
		"consequences" = "Последствия",
		"steps" = "1. Сделать что-нибудь\n2. Проверить результат",
		"log" = "<test> & \"quoted\"",
		"approver_note" = "Forged staff note",
		"unexpected" = "ignored",
	)
	var/list/validated = report.validate_data(params)
	TEST_ASSERT_NOTNULL(validated, "A complete report must be accepted")
	TEST_ASSERT_EQUAL(validated["description"], params["description"], "Code must not be stripped from reports")
	TEST_ASSERT_EQUAL(validated["log"], params["log"], "Logs must retain markup and quotes")
	TEST_ASSERT_EQUAL(validated["approver_note"], "", "Authors cannot provide a staff note")
	TEST_ASSERT(!("unexpected" in validated), "Unknown fields must not enter the payload")
	for(var/field in list("title", "expected_behavior", "description", "consequences", "steps"))
		var/list/invalid = params.Copy()
		invalid[field] = " \n\t"
		TEST_ASSERT_NULL(report.validate_data(invalid), "Blank required field [field] must be rejected")
		invalid[field] = list("not text")
		TEST_ASSERT_NULL(report.validate_data(invalid), "Non-text field [field] must be rejected")
	for(var/field in list("title", "description", "log"))
		var/limit = field == "title" ? 256 : (field == "log" ? 8192 : 4096)
		var/list/bounded = params.Copy()
		bounded[field] = repeat_string(limit, "я")
		TEST_ASSERT_NOTNULL(report.validate_data(bounded), "The character limit must accept Cyrillic")
		bounded[field] += "x"
		TEST_ASSERT_NULL(report.validate_data(bounded), "Oversized [field] must be rejected")
	report.submitted = TRUE
	validated = report.validate_data(params)
	TEST_ASSERT_EQUAL(validated["approver_note"], params["approver_note"], "Reviewers can provide a note")

/datum/unit_test/bug_report_repository/Run()
	TEST_ASSERT_EQUAL(bug_report_repository("https://github.com/mo0niverse/PrimeDream-"), "mo0niverse/PrimeDream-", "Use the configured repository")
	TEST_ASSERT_EQUAL(bug_report_repository("https://www.github.com/owner/repo/"), "owner/repo", "Accept the existing GITHUBURL format")
	for(var/invalid in list("http://github.com/a/b", "https://github.com.evil.test/a/b", "https://evil.test/a/b", "https://github.com/a/b/issues", "https://github.com/a/b?token=secret", "https://github.com/a/b\n"))
		TEST_ASSERT_NULL(bug_report_repository(invalid), "Unsafe or malformed repository URL must be rejected: [invalid]")

/datum/unit_test/bug_report_cooldown/Run()
	var/test_ckey = "bugreporttest"
	GLOB.bug_report_next_submission[test_ckey] = world.time + 5 MINUTES
	var/remaining = bug_report_cooldown_remaining(test_ckey)
	GLOB.bug_report_next_submission[test_ckey] = world.time - 1
	var/expired = bug_report_cooldown_remaining(test_ckey)
	GLOB.bug_report_next_submission -= test_ckey
	TEST_ASSERT_EQUAL(remaining, 5 MINUTES, "Cooldown must be keyed by ckey")
	TEST_ASSERT_EQUAL(expired, 0, "Expired cooldown must allow another report")
	TEST_ASSERT_EQUAL(bug_report_cooldown_remaining(test_ckey), 0, "First report must not be rate limited")

/datum/unit_test/bug_report_lifecycle/Run()
	var/datum/bug_report/report = allocate(/datum/bug_report)
	report.author_ckey = "bugreporttest"
	report.author_key = "BugReportTest"
	report.report_data = list("title" = "Retain on HTTP error", "description" = "A saved report")
	report.submitted = TRUE
	report.sending = TRUE
	report.reviewer_ckey = "reviewertest"
	GLOB.bug_reports += report
	var/datum/http_response/response = allocate(/datum/http_response)
	response.status_code = 403
	TEST_ASSERT(!report.handle_response(response), "GitHub errors must not be reported as success")
	TEST_ASSERT(!QDELETED(report) && (report in GLOB.bug_reports), "Failed reports must remain available")
	TEST_ASSERT_EQUAL(report.report_data["description"], "A saved report", "HTTP errors must not lose the report")
	TEST_ASSERT(!report.sending && !report.reviewer_ckey, "HTTP errors must release the review lock")
	var/mob/unauthorized = allocate(/mob)
	TEST_ASSERT_EQUAL(report.ui_status(unauthorized), UI_CLOSE, "Reports must be inaccessible without a client")
	TEST_ASSERT(!report.assign_approver(null), "An unauthorized reviewer must not acquire a report")
	response.status_code = 201
	TEST_ASSERT(report.handle_response(response), "HTTP 201 must resolve the report")
	TEST_ASSERT(QDELETED(report) && !(report in GLOB.bug_reports), "Published reports must leave the queue")
	var/datum/bug_report/draft = allocate(/datum/bug_report)
	draft.author_ckey = "bugreporttest"
	GLOB.bug_report_drafts[draft.author_ckey] = draft
	draft.ui_close(unauthorized)
	TEST_ASSERT(QDELETED(draft), "Closing an unsubmitted draft must delete it")
	TEST_ASSERT_NULL(GLOB.bug_report_drafts["bugreporttest"], "Deleted drafts must leave no global references")

/// Simulate the permission result changing without requiring a connected BYOND client.
/datum/bug_report/permission_test
	var/can_review = TRUE

/datum/bug_report/permission_test/ui_status(mob/user, datum/ui_state/state)
	return can_review ? UI_INTERACTIVE : UI_CLOSE

/// Omit browser registration while retaining native UI close and window lock handling.
/datum/tgui_window/bug_report_unit_test/New()
	id = "bug-report-unit-test"

/datum/unit_test/bug_report_deadmin/Run()
	var/mob/reviewer = allocate(/mob)
	reviewer.key = "@bugreportreviewer" // Native fake keys avoid client checks and ghosting during cleanup.
	var/datum/bug_report/permission_test/report = allocate(/datum/bug_report/permission_test)
	report.submitted = TRUE
	report.reviewer_ckey = reviewer.ckey
	GLOB.bug_reports += report
	TEST_ASSERT(length(report.reviewer_ckey), "The fixture must hold a review lock before losing permission")
	TEST_ASSERT_EQUAL(report.ui_status(reviewer), UI_INTERACTIVE, "The fixture must initially allow review")
	var/datum/tgui/ui = allocate(/datum/tgui, reviewer, report, "BugReportForm")
	var/datum/tgui_window/window = allocate(/datum/tgui_window/bug_report_unit_test)
	ui.window = window
	ui.initialized = TRUE
	ui.opened_at = world.time
	window.acquire_lock(ui)
	SStgui.on_open(ui)
	TEST_ASSERT((ui in SStgui.all_uis) && (ui in reviewer.tgui_open_uis) && (ui in report.open_uis), "The fixture must register a real open review UI")

	report.can_review = FALSE
	ui.process(1)

	TEST_ASSERT(QDELETED(ui), "Losing review permission must close the existing UI during autoupdate")
	TEST_ASSERT_NULL(report.reviewer_ckey, "Closing an unauthorized review must release its reviewer lock")
	TEST_ASSERT(!(ui in SStgui.all_uis) && !(ui in reviewer.tgui_open_uis) && !(ui in report.open_uis), "The unauthorized review must leave every native UI registry")
	TEST_ASSERT(!window.locked && isnull(window.locked_by), "Closing an unauthorized review must release the window lock")
	TEST_ASSERT(!QDELETED(report) && (report in GLOB.bug_reports), "Losing review permission must retain the submitted report for another reviewer")
