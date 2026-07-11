describe("Production deployment smoke test", () => {
	it("serves the LMS app through the public proxy", () => {
		const lmsPath = Cypress.env("lmsPath") || "lms";
		const escapedPath = lmsPath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

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
});
