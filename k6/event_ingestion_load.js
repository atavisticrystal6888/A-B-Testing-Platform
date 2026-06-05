// k6 load test: Event ingestion (NFR-020: 50K events/sec)
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const eventsIngested = new Counter('events_ingested');

export const options = {
  stages: [
    { duration: '30s', target: 500 },
    { duration: '2m', target: 5000 },
    { duration: '3m', target: 10000 },
    { duration: '2m', target: 10000 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<100'],
    'errors': ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY || 'test-api-key';

const eventTypes = ['page_view', 'click', 'conversion', 'purchase', 'signup'];

export default function () {
  const batchSize = 5;
  const events = [];

  for (let i = 0; i < batchSize; i++) {
    events.push({
      event_type: eventTypes[Math.floor(Math.random() * eventTypes.length)],
      experiment_id: `exp-${Math.floor(Math.random() * 50)}`,
      variant_id: `variant-${Math.floor(Math.random() * 4)}`,
      user_id: `user-${__VU}-${__ITER}-${i}`,
      timestamp: new Date().toISOString(),
      properties: {
        value: Math.random() * 100,
        page: `/page-${Math.floor(Math.random() * 20)}`,
      },
    });
  }

  const res = http.post(
    `${BASE_URL}/api/v1/events/batch`,
    JSON.stringify({ events }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
        'X-Tenant-ID': 'tenant-1',
      },
    }
  );

  check(res, {
    'status is 202': (r) => r.status === 202 || r.status === 200,
  });

  eventsIngested.add(batchSize);
  errorRate.add(res.status >= 400);
  sleep(0.01);
}
