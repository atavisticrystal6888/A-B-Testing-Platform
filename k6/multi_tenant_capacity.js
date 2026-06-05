// k6 load test: Multi-tenant capacity (5 tenants × 20 experiments each)
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const totalAssignments = new Counter('total_assignments');

const NUM_TENANTS = 5;
const EXPERIMENTS_PER_TENANT = 20;

export const options = {
  stages: [
    { duration: '1m', target: 200 },
    { duration: '5m', target: 500 },
    { duration: '2m', target: 500 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<100'],
    'errors': ['rate<0.02'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY || 'test-api-key';

export default function () {
  const tenantId = `tenant-${(__VU % NUM_TENANTS) + 1}`;
  const experimentId = `exp-${tenantId}-${__VU % EXPERIMENTS_PER_TENANT}`;
  const userId = `user-${__VU}-${__ITER}`;

  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${API_KEY}`,
    'X-Tenant-ID': tenantId,
  };

  // Assignment request
  const assignRes = http.post(
    `${BASE_URL}/api/v1/assignments`,
    JSON.stringify({
      experiment_id: experimentId,
      user_id: userId,
      context: { platform: 'web', tenant: tenantId },
    }),
    { headers }
  );

  check(assignRes, {
    'assignment success': (r) => r.status === 200,
    'tenant isolation': (r) => {
      const body = r.json();
      return !body.data || !body.data.tenant_id || body.data.tenant_id === tenantId;
    },
  });

  totalAssignments.add(1);
  errorRate.add(assignRes.status >= 400);

  // Occasionally query results (10% of requests)
  if (Math.random() < 0.1) {
    const resultsRes = http.get(
      `${BASE_URL}/api/v1/experiments/${experimentId}/results`,
      { headers }
    );

    check(resultsRes, {
      'results 2xx': (r) => r.status >= 200 && r.status < 300,
    });
  }

  sleep(0.05);
}
