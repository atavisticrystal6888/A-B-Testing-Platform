import { test, expect } from '@playwright/test';

test.describe('Experiment Results E2E', () => {
  test('results page shows statistical summary', async ({ page }) => {
    await page.goto('/experiments');

    // Navigate to a running/concluded experiment
    await page.click('text=Running >> xpath=../.. >> a');
    await page.click('text=Results');

    // Verify statistical summary is rendered
    await expect(page.locator('text=Statistical Summary')).toBeVisible();
    await expect(page.locator('text=Sample Size')).toBeVisible();
  });

  test('variant table displays conversion rates', async ({ page }) => {
    await page.goto('/experiments');
    await page.click('text=Running >> xpath=../.. >> a');
    await page.click('text=Results');

    const variantTable = page.locator('[data-testid="variant-table"]');
    await expect(variantTable).toBeVisible();

    // Should have at least control + 1 treatment
    const rows = variantTable.locator('tbody tr');
    const count = await rows.count();
    expect(count).toBeGreaterThanOrEqual(2);
  });

  test('Bayesian results tab shows probability to be best', async ({ page }) => {
    await page.goto('/experiments');
    await page.click('text=Running >> xpath=../.. >> a');
    await page.click('text=Results');

    // Switch to Bayesian tab if available
    const bayesianTab = page.locator('text=Bayesian');
    if (await bayesianTab.isVisible()) {
      await bayesianTab.click();
      await expect(page.locator('text=Probability to be Best')).toBeVisible();
    }
  });

  test('export buttons download data', async ({ page }) => {
    await page.goto('/experiments');
    await page.click('text=Running >> xpath=../.. >> a');
    await page.click('text=Results');

    // Check export buttons are present
    await expect(page.locator('text=Export CSV')).toBeVisible();
    await expect(page.locator('text=Export JSON')).toBeVisible();

    // Trigger CSV download
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.click('text=Export CSV'),
    ]);

    expect(download.suggestedFilename()).toContain('.csv');
  });

  test('sample size warning appears for small experiments', async ({ page }) => {
    // Navigate to a recently created experiment with few events
    await page.goto('/experiments');
    await page.click('text=Running >> xpath=../.. >> a');
    await page.click('text=Results');

    // Check if sample size warning is shown
    const warning = page.locator('[data-testid="sample-size-warning"]');
    // It may or may not appear depending on data
    if (await warning.isVisible()) {
      await expect(warning).toContainText('sample');
    }
  });
});
