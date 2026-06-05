// k6 load test: Dashboard query performance
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const queryDuration = new Trend('query_duration', true);

export const options = {
  stages: [
    { duration: '30s', target: 50 },
    { duration: '2m', target: 200 },
    { duration: '3m', target: 500 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'],
    'errors': ['rate<0.05'],
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
  const scenarios = [
    () => http.get(`${BASE_URL}/api/v1/experiments`, { headers }),
    () => http.get(`${BASE_URL}/api/v1/experiments/exp-1`, { headers }),
    () => http.get(`${BASE_URL}/api/v1/experiments/exp-1/results`, { headers }),
    () => http.get(`${BASE_URL}/api/v1/analytics/timeline`, { headers }),
    () => http.get(`${BASE_URL}/api/v1/feature-flags`, { headers }),
  ];

  const scenario = scenarios[Math.floor(Math.random() * scenarios.length)];
  const res = scenario();

  queryDuration.add(res.timings.duration);

  check(res, {
    'status is 2xx': (r) => r.status >= 200 && r.status < 300,
  });

  errorRate.add(res.status >= 400);
  sleep(0.5);
}
