describe("Production deployment smoke test", () => {
	const lmsPath = Cypress.env("lmsPath") || "lms";
	const escapedPath = lmsPath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

	it("serves the LMS app through the public proxy", () => {
		cy.request("/api/method/ping")
			.its("body")
			.should("deep.include", { message: "pong" });

		cy.intercept("GET", "/assets/lms/frontend/**").as("frontendAsset");
		cy.visit(`/${lmsPath}`);
		// A fresh private LMS redirects anonymous visitors to Frappe's login page;
		// an already authenticated session remains in /lms. Both paths prove the
		// SPA loaded and completed its first navigation.
		cy.location("pathname").should("match", new RegExp(`^/(${escapedPath}|${escapedPath}/login|login)$`));
		cy.wait("@frontendAsset")
			.its("response.statusCode")
			.should("be.oneOf", [200, 304]);
		cy.get("body").should("not.be.empty");
	});

	it("authenticates through the rendered login form", () => {
		const loginPath = Cypress.env("loginPath") || "login";
		const user = Cypress.env("adminUser") || "Administrator";
		const password = Cypress.env("adminPassword");

		expect(password, "CYPRESS_adminPassword").to.be.a("string").and.not.be.empty;
		cy.visit(`/${loginPath}`);
		cy.get("#login_email").type(user);
		cy.get("#login_password").type(password);
		cy.get("button.btn-login").click();
		cy.location("pathname").should("not.match", new RegExp(`^/(${escapedPath}/)?login$`));
		cy.request("/api/method/frappe.auth.get_logged_user")
			.its("body")
			.should("deep.include", { message: user });
	});

	it("returns to and renders the prefixed persona page after login", () => {
		const user = Cypress.env("adminUser") || "Administrator";
		const password = Cypress.env("adminPassword");

		expect(password, "CYPRESS_adminPassword").to.be.a("string").and.not.be.empty;
		cy.clearAllCookies();
		cy.visit(`/login?redirect-to=/${lmsPath}/persona`);
		cy.get("#login_email").type(user);
		cy.get("#login_password").type(password);
		cy.get("button.btn-login").click();
		cy.location("pathname").should("eq", `/${lmsPath}/persona`);
		cy.contains(`Where will you be using Pa's Academy?`).should("be.visible");
	});
});
