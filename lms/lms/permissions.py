# Copyright (c) 2026, Frappe and Contributors
# For license information, please see license.txt

"""Shared access-control helpers for LMS lesson media.

Centralizes the cross-doctype permission logic that the Course Lesson controller,
the serve_resource endpoint, the SCORM renderer, and the File has_permission hook
all rely on — mirroring the dedicated permissions module pattern used by frappe
core (frappe/permissions.py), CRM (crm.permissions.*), and Raven (raven.permissions).
"""

import frappe

from lms.lms.utils import can_modify_course, get_membership, guest_access_allowed, is_private_lms

# File fields that hold instructor-only lesson media (never served to students).
INSTRUCTOR_FIELDS = {"instructor_content", "instructor_notes"}


def _is_lms_admin(user=None):
	roles = frappe.get_roles(user or frappe.session.user)
	return bool({"Moderator", "Course Creator", "Batch Evaluator", "System Manager"} & set(roles))


def can_access_course(course: str, user: str | None = None) -> bool:
	if not course:
		return False
	user = user or frappe.session.user
	if _is_lms_admin(user):
		return True
	if user == "Guest":
		return False
	return bool(frappe.db.exists("LMS Enrollment", {"course": course, "member": user}))


def course_query_conditions(user=None):
	user = user or frappe.session.user
	if _is_lms_admin(user):
		return ""
	if user == "Guest" or is_private_lms():
		return """`tabLMS Course`.`name` in (
			select `course` from `tabLMS Enrollment` where `member` = {user}
		)""".format(user=frappe.db.escape(user))
	return ""


def enrollment_query_conditions(user=None):
	user = user or frappe.session.user
	if _is_lms_admin(user):
		return ""
	if user == "Guest":
		return "1=0"
	return "`tabLMS Enrollment`.`member` = {user}".format(user=frappe.db.escape(user))


def course_lesson_query_conditions(user=None):
	user = user or frappe.session.user
	if _is_lms_admin(user):
		return ""
	if user == "Guest":
		return "1=0"
	return """`tabCourse Lesson`.`course` in (
		select `course` from `tabLMS Enrollment` where `member` = {user}
	)""".format(user=frappe.db.escape(user))


def course_chapter_query_conditions(user=None):
	user = user or frappe.session.user
	if _is_lms_admin(user):
		return ""
	if user == "Guest":
		return "1=0"
	return """`tabCourse Chapter`.`name` in (
		select `chapter` from `tabChapter Reference`
		where `parenttype` = 'LMS Course'
		and `parent` in (
			select `course` from `tabLMS Enrollment` where `member` = {user}
		)
	)""".format(user=frappe.db.escape(user))


def _course_membership_condition(table: str, course_field: str, user: str) -> str:
	return """`{table}`.`{course_field}` in (
		select `course` from `tabLMS Enrollment` where `member` = {user}
	)""".format(table=table, course_field=course_field, user=frappe.db.escape(user))


def _private_course_record_conditions(table: str, course_field: str = "course", member_field: str | None = None, user=None):
	user = user or frappe.session.user
	if _is_lms_admin(user):
		return ""
	if user == "Guest":
		return "1=0"
	if not is_private_lms():
		return ""

	conditions = [_course_membership_condition(table, course_field, user)]
	if member_field:
		conditions.append(
			"`{table}`.`{member_field}` = {user}".format(
				table=table,
				member_field=member_field,
				user=frappe.db.escape(user),
			)
		)
	return " and ".join(f"({condition})" for condition in conditions)


def quiz_query_conditions(user=None):
	return _private_course_record_conditions("tabLMS Quiz", user=user)


def assignment_query_conditions(user=None):
	return _private_course_record_conditions("tabLMS Assignment", user=user)


def course_review_query_conditions(user=None):
	return _private_course_record_conditions("tabLMS Course Review", user=user)


def course_progress_query_conditions(user=None):
	return _private_course_record_conditions("tabLMS Course Progress", member_field="member", user=user)


def quiz_submission_query_conditions(user=None):
	return _private_course_record_conditions("tabLMS Quiz Submission", member_field="member", user=user)


def assignment_submission_query_conditions(user=None):
	return _private_course_record_conditions("tabLMS Assignment Submission", member_field="member", user=user)


def certificate_request_query_conditions(user=None):
	return _private_course_record_conditions("tabLMS Certificate Request", member_field="member", user=user)


def certificate_evaluation_query_conditions(user=None):
	return _private_course_record_conditions("tabLMS Certificate Evaluation", member_field="member", user=user)


def course_has_permission(doc, ptype="read", user=None):
	if ptype != "read":
		return None
	return can_access_course(doc.name, user)


def related_course_has_permission(doc, ptype="read", user=None):
	if ptype not in ("read", "select", "print"):
		return None
	if not is_private_lms():
		return None

	user = user or frappe.session.user
	if _is_lms_admin(user):
		return True
	if user == "Guest":
		return False

	member = getattr(doc, "member", None)
	if member and member != user:
		return False

	course = getattr(doc, "course", None)
	if course:
		return can_access_course(course, user)

	return bool(member == user)


def can_access_lesson(lesson: str, *, instructor_only: bool = False, user: str | None = None) -> bool:
	"""Single source of truth for who may read a lesson's resources.

	- instructors / moderators (can_modify_course) → all media (incl. instructor files)
	- instructor_only=True → only the above; enrolled students denied
	- else (student media): enrolled member OR (published course AND include_in_preview
	  AND guest access allowed)
	"""
	if not isinstance(lesson, str) or not lesson:
		return False

	lesson_row = frappe.db.get_value("Course Lesson", lesson, ["course", "include_in_preview"], as_dict=True)
	if not lesson_row:
		return False

	original_user = frappe.session.user
	user = user or original_user
	try:
		# can_modify_course / get_membership / guest_access_allowed read session.user.
		frappe.session.user = user
		if can_modify_course(lesson_row.course):
			return True
		if instructor_only:
			return False
		if get_membership(lesson_row.course, user):
			return True
		# Preview is for prospective students of a LIVE course. Require the course to be
		# published so draft lessons don't leak via this gate (matches get_course_details,
		# which already hides unpublished courses from non-authors). Instructors/members
		# are handled above, so unpublishing never locks them out.
		if (
			lesson_row.include_in_preview
			and frappe.db.get_value("LMS Course", lesson_row.course, "published")
			and guest_access_allowed()
		):
			return True
		return False
	finally:
		frappe.session.user = original_user


def file_has_permission(doc, ptype="read", user=None):
	"""File has_permission hook: deny-only tightening for instructor-only lesson files.

	For private Files attached to a Course Lesson via instructor_content /
	instructor_notes, deny ALL access (read and authoring) to anyone who cannot
	author the course. For every other File, return True (no opinion) so the
	student/native serving path is unaffected.

	Instructor-only access == can author the course == can_access_lesson with
	instructor_only=True, so delegate to it (the single source of truth) rather
	than re-implementing the course lookup / session swap. This is fail-closed: a
	missing/deleted owning lesson makes can_access_lesson return False, denying the
	orphaned instructor file.
	"""
	user = user or frappe.session.user

	if doc.attached_to_doctype != "Course Lesson":
		return True
	if doc.attached_to_field not in INSTRUCTOR_FIELDS:
		return True

	if can_access_lesson(doc.attached_to_name, instructor_only=True, user=user):
		return True

	frappe.logger("lms.security").warning(
		"Lesson resource access denied: user=%s file=%s field=%s lesson=%s",
		user,
		doc.name,
		doc.attached_to_field,
		doc.attached_to_name,
	)
	return False
