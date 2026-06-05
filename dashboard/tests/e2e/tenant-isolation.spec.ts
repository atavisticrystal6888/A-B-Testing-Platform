import { test, expect } from '@playwright/test';

test.describe('Tenant Isolation E2E', () => {
  const tenants = [
    { id: 'tenant-1', name: 'Tenant Alpha', apiKey: 'key-tenant-1' },
    { id: 'tenant-2', name: 'Tenant Beta', apiKey: 'key-tenant-2' },
  ];

  test('experiments are isolated between tenants', async ({ request }) => {
    // Create experiment in tenant-1
    const createRes = await request.post('/api/v1/experiments', {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${tenants[0].apiKey}`,
        'X-Tenant-ID': tenants[0].id,
      },
      data: {
        experiment: {
          name: 'Tenant-1 Only Experiment',
          hypothesis: 'This should not be visible to tenant-2',
          variants: [
            { name: 'control', weight: 50 },
            { name: 'treatment', weight: 50 },
          ],
        },
      },
    });

    expect(createRes.status()).toBe(201);
    const created = await createRes.json();
    const experimentId = created.data.id;

    // Try to access from tenant-2 - should fail
    const accessRes = await request.get(`/api/v1/experiments/${experimentId}`, {
      headers: {
        'Authorization': `Bearer ${tenants[1].apiKey}`,
        'X-Tenant-ID': tenants[1].id,
      },
    });

    expect(accessRes.status()).toBe(404);
  });

  test('assignments respect tenant boundaries', async ({ request }) => {
    // Create experiment in tenant-1
    const createRes = await request.post('/api/v1/experiments', {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${tenants[0].apiKey}`,
        'X-Tenant-ID': tenants[0].id,
      },
      data: {
        experiment: {
          name: 'Tenant Assignment Test',
          hypothesis: 'Test tenant isolation in assignments',
          variants: [
            { name: 'control', weight: 50 },
            { name: 'treatment', weight: 50 },
          ],
        },
      },
    });

    const created = await createRes.json();
    const experimentId = created.data.id;

    // Assign in tenant-1 (should work)
    const assign1 = await request.post('/api/v1/assignments', {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${tenants[0].apiKey}`,
        'X-Tenant-ID': tenants[0].id,
      },
      data: {
        experiment_id: experimentId,
        user_id: 'user-1',
      },
    });

    expect(assign1.status()).toBe(200);

    // Assign in tenant-2 (should fail - experiment doesn't exist in tenant-2)
    const assign2 = await request.post('/api/v1/assignments', {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${tenants[1].apiKey}`,
        'X-Tenant-ID': tenants[1].id,
      },
      data: {
        experiment_id: experimentId,
        user_id: 'user-1',
      },
    });

    expect(assign2.status()).toBe(404);
  });

  test('listing experiments only returns own tenant data', async ({ request }) => {
    // List experiments for tenant-1
    const list1 = await request.get('/api/v1/experiments', {
      headers: {
        'Authorization': `Bearer ${tenants[0].apiKey}`,
        'X-Tenant-ID': tenants[0].id,
      },
    });

    const data1 = await list1.json();

    // List experiments for tenant-2
    const list2 = await request.get('/api/v1/experiments', {
      headers: {
        'Authorization': `Bearer ${tenants[1].apiKey}`,
        'X-Tenant-ID': tenants[1].id,
      },
    });

    const data2 = await list2.json();

    // Ensure no overlap in experiment IDs
    const ids1 = new Set((data1.data || []).map((e: { id: string }) => e.id));
    const ids2 = new Set((data2.data || []).map((e: { id: string }) => e.id));

    for (const id of ids1) {
      expect(ids2.has(id)).toBe(false);
    }
  });
});
