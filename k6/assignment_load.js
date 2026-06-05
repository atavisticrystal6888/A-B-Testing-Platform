// k6 load test: Assignment endpoint (NFR-010: 10K rps @ p99 < 50ms)
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const assignmentDuration = new Trend('assignment_duration', true);

export const options = {
  stages: [
    { duration: '30s', target: 100 },   // ramp up
    { duration: '2m', target: 1000 },   // sustain 1K
    { duration: '2m', target: 5000 },   // ramp to 5K
    { duration: '3m', target: 10000 },  // sustain 10K rps target
    { duration: '30s', target: 0 },     // ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(99)<50'],  // 99th percentile under 50ms
    'errors': ['rate<0.01'],            // error rate under 1%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY || 'test-api-key';

export default function () {
  const experimentId = `exp-${Math.floor(Math.random() * 100)}`;
  const userId = `user-${__VU}-${__ITER}`;

  const res = http.post(
    `${BASE_URL}/api/v1/assignments`,
    JSON.stringify({
      experiment_id: experimentId,
      user_id: userId,
      context: { platform: 'web', country: 'US' },
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
        'X-Tenant-ID': 'tenant-1',
      },
    }
  );

  assignmentDuration.add(res.timings.duration);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'has variant_id': (r) => {
      const body = r.json();
      return body && body.data && body.data.variant_id;
    },
  });

  errorRate.add(res.status !== 200);
  sleep(0.01);
}
