# Copyright (c) 2021, Frappe and contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import cint


class LMSCourseReview(Document):
	def validate(self):
		self.validate_enrollment()
		self.validate_if_already_reviewed()

	def validate_enrollment(self):
		enrollment = frappe.db.exists("LMS Enrollment", {"course": self.course, "member": self.owner})
		if not enrollment:
			frappe.throw(_("You must be enrolled in the course to submit a review"))

	def validate_if_already_reviewed(self):
		if frappe.db.exists("LMS Course Review", {"course": self.course, "owner": self.owner}):
			frappe.throw(_("You have already reviewed this course"))


@frappe.whitelist()
def submit_review(course: str, rating: float, review: str | None = None):
	"""Create a review for the signed-in, enrolled student.

	Course enrollment is the authority for submitting a review. Some enrolled
	portal users can lack the LMS Student role (for example, older/imported users),
	so the generic ``frappe.client.insert`` permission check is too restrictive for
	this workflow. Document validation below still enforces enrollment and prevents
	duplicate reviews.
	"""
	review_doc = frappe.get_doc(
		{
			"doctype": "LMS Course Review",
			"course": course,
			"rating": rating,
			"review": review,
		}
	)
	review_doc.insert(ignore_permissions=True)
	return review_doc.name
