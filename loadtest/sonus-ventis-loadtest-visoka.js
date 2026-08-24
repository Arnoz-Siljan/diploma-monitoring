import http from 'k6/http';
import { sleep, check } from 'k6';
export const options = {
  stages: [
    { duration: '30s', target: 5 },
    { duration: '1m',  target: 20 },
    { duration: '2m',  target: 50 },
    { duration: '1m',  target: 100 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed:   ['rate<0.01'],
  },
};
const BASE_URL = __ENV.TARGET || 'http://192.168.56.1:5230';
const pages = ['/', '/About', '/Concerts', '/Contact', '/Gallery'];
export default function () {
  const page = pages[Math.floor(Math.random() * pages.length)];
  const res = http.get(`${BASE_URL}${page}`);
  check(res, {
    'status je 200': (r) => r.status === 200,
    'response time < 1s': (r) => r.timings.duration < 1000,
  });
  sleep(Math.random() * 0.2 + 0.1);
}
