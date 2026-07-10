import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import get_datetime, now_datetime


class LMSUserInvite(Document):
	def validate(self):
		if self.status == "Pending" and self.expires_at and get_datetime(self.expires_at) <= now_datetime():
			self.status = "Expired"

	def validate_acceptance(self):
		self.reload()
		if self.status != "Pending":
			frappe.throw(_("This invite is no longer active."), frappe.PermissionError)
		if self.used_at:
			frappe.throw(_("This invite has already been used."), frappe.PermissionError)
		if self.expires_at and get_datetime(self.expires_at) <= now_datetime():
			self.status = "Expired"
			self.save(ignore_permissions=True)
			frappe.throw(_("This invite has expired."), frappe.PermissionError)

