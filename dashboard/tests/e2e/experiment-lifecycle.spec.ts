import { test, expect } from '@playwright/test';

test.describe('Experiment Lifecycle E2E', () => {
  test('create, launch, pause, resume, and conclude an experiment', async ({ page }) => {
    await page.goto('/');

    // Navigate to create experiment
    await page.click('text=Create Experiment');
    await expect(page).toHaveURL(/\/experiments\/create/);

    // Step 1: Hypothesis
    await page.fill('[name="name"]', 'E2E Test Experiment');
    await page.fill('[name="hypothesis"]', 'Testing the full lifecycle flow');
    await page.click('text=Next');

    // Step 2: Variants
    await page.fill('[name="variants.0.name"]', 'control');
    await page.fill('[name="variants.0.weight"]', '50');
    await page.fill('[name="variants.1.name"]', 'treatment');
    await page.fill('[name="variants.1.weight"]', '50');
    await page.click('text=Next');

    // Step 3: Traffic
    await page.fill('[name="traffic_percentage"]', '100');
    await page.click('text=Next');

    // Step 4: Settings & Submit
    await page.click('text=Create Experiment');
    await expect(page.locator('text=Draft')).toBeVisible();

    // Launch
    await page.click('text=Launch');
    await page.click('text=Confirm');
    await expect(page.locator('text=Running')).toBeVisible();

    // Pause
    await page.click('text=Pause');
    await expect(page.locator('text=Paused')).toBeVisible();

    // Resume
    await page.click('text=Resume');
    await expect(page.locator('text=Running')).toBeVisible();

    // Conclude
    await page.click('text=Conclude');
    await page.click('text=Ship Winning Variant');
    await page.click('text=Confirm');
    await expect(page.locator('text=Concluded')).toBeVisible();
  });

  test('experiment list shows correct status badges', async ({ page }) => {
    await page.goto('/experiments');
    await expect(page.locator('table')).toBeVisible();

    const statusBadges = page.locator('[data-testid="status-badge"]');
    const count = await statusBadges.count();
    expect(count).toBeGreaterThan(0);
  });

  test('draft experiment can be edited', async ({ page }) => {
    await page.goto('/experiments');

    // Click first draft experiment
    await page.click('text=Draft >> xpath=../.. >> a');
    await page.click('text=Edit');

    await page.fill('[name="hypothesis"]', 'Updated hypothesis via E2E');
    await page.click('text=Save');

    await expect(page.locator('text=Updated hypothesis via E2E')).toBeVisible();
  });
});
