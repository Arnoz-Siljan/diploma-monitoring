import http from 'k6/http';
import { sleep, check } from 'k6';

// Stopenjski load test s 4 fazami za diplomsko nalogo
export const options = {
  stages: [
    { duration: '30s', target: 5 },    // Faza 1: smoke test (5 navideznih uporabnikov)
    { duration: '1m',  target: 20 },   // Faza 2: ramp-up (postopno do 20 VU)
    { duration: '2m',  target: 50 },   // Faza 3: sustained load (50 VU)
    { duration: '1m',  target: 100 },  // Faza 4: stress (100 VU)
    { duration: '30s', target: 0 },    // Cool-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% odstotkov zahtev pod 500ms
    http_req_failed:   ['rate<0.01'],  // Manj kot 1% napak
  },
};

// Tarča: Sonus Ventis na host-only mreži (laptop iz VM perspektive)
const BASE_URL = __ENV.TARGET || 'http://192.168.56.1:5230';

// Seznam strani, ki jih simuliramo
const pages = ['/', '/About', '/Concerts', '/Contact', '/Gallery'];

export default function () {
  const page = pages[Math.floor(Math.random() * pages.length)];
  const res = http.get(`${BASE_URL}${page}`);

  check(res, {
    'status je 200': (r) => r.status === 200,
    'response time < 1s': (r) => r.timings.duration < 1000,
  });

  sleep(Math.random() * 2 + 1); // 1-3s premor med zahtevami (simulacija uporabnika)
}
