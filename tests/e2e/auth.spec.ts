import { test, expect } from "@playwright/test";

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || "admin@notch8.com";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "changeme123";

test.describe("Authentication", () => {
  test("admin can log in and reaches dashboard", async ({ page }) => {
    await page.goto("/login/");

    await page.fill("#email", ADMIN_EMAIL);
    await page.fill("#password", ADMIN_PASSWORD);
    await page.click("button[type='submit']");

    await page.waitForURL((url) => !url.pathname.includes("/login"), {
      timeout: 30_000,
      waitUntil: "domcontentloaded",
    });

    const url = page.url();
    expect(url).not.toContain("/login");
  });

  test("invalid credentials show error", async ({ page }) => {
    await page.goto("/login/");

    await page.fill("#email", "bad@example.com");
    await page.fill("#password", "wrongpassword");
    await page.click("button[type='submit']");

    await page.waitForTimeout(3000);
    expect(page.url()).toContain("/login");
  });
});
