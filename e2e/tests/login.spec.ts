import { test, expect } from '@playwright/test';

const EMAIL = process.env.TEST_EMAIL!;
const PASSWORD = process.env.TEST_PASSWORD!;

// Flutter web renders to canvas — widget text/roles only exist in the DOM
// once the accessibility tree is turned on. Flutter injects a placeholder
// button for this before any semantics nodes exist.
async function enableSemantics(page: import('@playwright/test').Page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 30_000 });
  await placeholder.click({ force: true });
}

test('user can log in with valid credentials', async ({ page }) => {
  await page.goto('/');
  await enableSemantics(page);

  await page.getByRole('button', { name: 'Log in', exact: true }).click();

  const email = page.getByRole('textbox').nth(0);
  const password = page.getByRole('textbox').nth(1);
  await email.click();
  await email.fill(EMAIL);
  await password.click();
  await password.fill(PASSWORD);

  await page.getByRole('button', { name: 'Log in', exact: true }).click();

  const dashboardCta = page.getByRole('button', { name: 'Go to dashboard' });
  const formError = page.getByText('Enter your password', { exact: false });
  await expect(formError).toHaveCount(0);

  // Either lands on the "welcome back" success screen (onboarded account) or
  // is routed straight into onboarding (account with pending onboarding) —
  // both count as a successful login, so accept either outcome.
  await expect(
    dashboardCta.or(page.getByText("Let's get to know you")),
  ).toBeVisible({ timeout: 20_000 });

  if (await dashboardCta.isVisible()) {
    await dashboardCta.click();
    await expect(page.getByText('Learn', { exact: true })).toBeVisible();
    await expect(page.getByText('Jobs', { exact: true })).toBeVisible();
  }
});
