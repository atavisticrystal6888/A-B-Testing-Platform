// k6 load test: 100 concurrent experiments
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '1m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(99)<100'],
    'errors': ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY || 'test-api-key';

const headers = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${API_KEY}`,
  'X-Tenant-ID': 'tenant-1',
};

export default function () {
  // Each VU simulates a user being assigned to one of 100 concurrent experiments
  const experimentId = `exp-${__VU % 100}`;
  const userId = `user-${__VU}-${__ITER}`;

  // Assignment
  const assignRes = http.post(
    `${BASE_URL}/api/v1/assignments`,
    JSON.stringify({
      experiment_id: experimentId,
      user_id: userId,
      context: { platform: 'web' },
    }),
    { headers }
  );

  check(assignRes, {
    'assignment 200': (r) => r.status === 200,
  });

  // Send event for the assigned variant
  if (assignRes.status === 200) {
    const body = assignRes.json();
    const variantId = body.data && body.data.variant_id;

    if (variantId) {
      const eventRes = http.post(
        `${BASE_URL}/api/v1/events`,
        JSON.stringify({
          event_type: 'conversion',
          experiment_id: experimentId,
          variant_id: variantId,
          user_id: userId,
          timestamp: new Date().toISOString(),
        }),
        { headers }
      );

      check(eventRes, {
        'event accepted': (r) => r.status === 200 || r.status === 202,
      });

      errorRate.add(eventRes.status >= 400);
    }
  }

  errorRate.add(assignRes.status >= 400);
  sleep(0.1);
}
