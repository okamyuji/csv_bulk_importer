import { expect, test } from "@playwright/test";
import { rand, signUp } from "./helpers";

test("sign up, see empty imports list, sign out", async ({ page }) => {
  const email = `${rand("alice")}@example.com`;
  await signUp(page, email, "secret123", "Alice");

  await expect(page.getByText(/No imports yet/i)).toBeVisible();
  await expect(page.getByTestId("nav-user")).toContainText(email);

  await page.getByRole("button", { name: /sign out/i }).click();
  await expect(page).toHaveURL(/\/login/);
});

test("unauthenticated user is redirected to login", async ({ page }) => {
  await page.goto("/imports");
  await expect(page).toHaveURL(/\/login/);
});
