import { test, expect } from "@playwright/test";

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || "admin@notch8.com";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "changeme123";

async function loginAsAdmin(page: import("@playwright/test").Page) {
  await page.goto("/login/");
  await page.fill("#email", ADMIN_EMAIL);
  await page.fill("#password", ADMIN_PASSWORD);
  await page.click("button[type='submit']");
  await page.waitForURL((url) => !url.pathname.includes("/login"), {
    timeout: 30_000,
    waitUntil: "domcontentloaded",
  });
}

test.describe("Record lifecycle", () => {
  test("unauthenticated API record create is rejected", async ({ request }) => {
    const response = await request.post("/api/records", {
      headers: { "Content-Type": "application/json" },
      data: {
        metadata: {
          title: `Smoke Test Record ${Date.now()}`,
          resource_type: { id: "publication-article" },
          creators: [
            {
              person_or_org: {
                type: "personal",
                given_name: "Test",
                family_name: "User",
              },
            },
          ],
          publication_date: new Date().toISOString().split("T")[0],
          publisher: "InvenioRDM Smoke Test",
        },
        access: { record: "public", files: "public" },
        files: { enabled: false },
      },
    });

    expect([400, 401, 403]).toContain(response.status());
  });

  test("uploads dashboard loads after login", async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto("/me/uploads");

    await expect(page.locator("body")).toContainText("My dashboard", {
      timeout: 15_000,
    });
  });
});
