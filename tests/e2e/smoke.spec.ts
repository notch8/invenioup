import { test, expect } from "@playwright/test";

test.describe("Smoke tests", () => {
  test("frontpage loads and shows branding", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveTitle(/InvenioRDM/);
    await expect(page.locator("body")).toContainText("InvenioRDM");
  });

  test("search page loads", async ({ page }) => {
    await page.goto("/search");
    await expect(page.locator(".search-bar, input[type='text']").first()).toBeVisible();
  });

  test("login page loads", async ({ page }) => {
    await page.goto("/login/");
    await expect(page.locator("#email")).toBeVisible();
    await expect(page.locator("#password")).toBeVisible();
  });

  test("API records endpoint responds", async ({ request }) => {
    const response = await request.get("/api/records");
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty("hits");
  });

  test("API vocabularies endpoint responds", async ({ request }) => {
    const response = await request.get("/api/vocabularies/resourcetypes");
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty("hits");
  });
});
