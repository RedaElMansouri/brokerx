# k6 terminal batch

## direct microservices
```zsh
redaelmansouri@Redas-Laptop brokerx % k6 run load/k6/direct_microservices_smoke.js 
-e PORTFOLIOS_URL=http://localhost:3103 -e ORDERS_URL=http://localhost:3101 -e TOKE
N=eyJhbGciOiJIUzI1NiJ9.eyJjbGllbnRfaWQiOjEsImlzcyI6ImJyb2tlcngiLCJhdWQiOiJicm9rZXJ4
LndlYiIsImlhdCI6MTc2MTY3MDg5NywiZXhwIjoxNzYxNzU3Mjk3fQ.uveb09gOKLwwEwB29PY7hNN5hBDG
rQbKLE8qZDWKvqo -e VUS=5 -e DURATION=45s

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: load/k6/direct_microservices_smoke.js
        output: -

     scenarios: (100.00%) 1 scenario, 5 max VUs, 1m15s max duration (incl. graceful stop):
              * default: 5 looping VUs for 45s (gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✓ 'p(95)<600' p(95)=36.4ms

    http_req_failed
    ✓ 'rate<0.05' rate=0.00%


  █ TOTAL RESULTS 

    checks_total.......: 845     18.743991/s
    checks_succeeded...: 100.00% 845 out of 845
    checks_failed......: 0.00%   0 out of 845

    ✓ portfolio 200/401
    ✓ deposit 200/201
    ✓ order ok

    HTTP
    http_req_duration..............: avg=17.47ms  min=3.07ms   med=13.64ms  max=138.6ms  p(90)=29.46ms p(95)=36.4ms  
      { expected_response:true }...: avg=17.47ms  min=3.07ms   med=13.64ms  max=138.6ms  p(90)=29.46ms p(95)=36.4ms  
    http_req_failed................: 0.00%  0 out of 845
    http_reqs......................: 845    18.743991/s

    EXECUTION
    iteration_duration.............: avg=536.51ms min=508.45ms med=533.41ms max=805.58ms p(90)=545.4ms p(95)=551.26ms
    iterations.....................: 420    9.31654/s
    vus............................: 5      min=5        max=5
    vus_max........................: 5      min=5        max=5

    NETWORK
    data_received..................: 465 kB 10 kB/s
    data_sent......................: 330 kB 7.3 kB/s




running (0m45.1s), 0/5 VUs, 420 complete and 0 interrupted iterations
default ✓ [======================================] 5 VUs  45s
```


## Gateway
```zsh
 redaelmansouri@Redas-Laptop brokerx % k6 run load/k6/gateway_smoke.js -e BASE_URL=h
ttp://localhost:8080 -e APIKEY=brokerx-key-123 -e TOKEN=eyJhbGciOiJIUzI1NiJ9.eyJjbG
llbnRfaWQiOjEsImlzcyI6ImJyb2tlcngiLCJhdWQiOiJicm9rZXJ4LndlYiIsImlhdCI6MTc2MTY3MDg5N
ywiZXhwIjoxNzYxNzU3Mjk3fQ.uveb09gOKLwwEwB29PY7hNN5hBDGrQbKLE8qZDWKvqo -e VUS=5 -e D
URATION=45s

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: load/k6/gateway_smoke.js
        output: -

     scenarios: (100.00%) 1 scenario, 5 max VUs, 1m15s max duration (incl. graceful stop):
              * default: 5 looping VUs for 45s (gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✓ 'p(95)<600' p(95)=37.21ms

    http_req_failed
    ✓ 'rate<0.05' rate=0.00%


  █ TOTAL RESULTS 

    checks_total.......: 1265    28.04732/s
    checks_succeeded...: 100.00% 1265 out of 1265
    checks_failed......: 0.00%   0 out of 1265

    ✓ portfolio 200/401
    ✓ deposit 200/201
    ✓ order ok
    ✓ has X-Instance

    HTTP
    http_req_duration..............: avg=17.79ms min=3.58ms   med=13.54ms  max=142.47ms p(90)=30.38ms  p(95)=37.21ms
      { expected_response:true }...: avg=17.79ms min=3.58ms   med=13.54ms  max=142.47ms p(90)=30.38ms  p(95)=37.21ms
    http_req_failed................: 0.00%  0 out of 845
    http_reqs......................: 845    18.735167/s

    EXECUTION
    iteration_duration.............: avg=536.8ms min=510.07ms med=532.79ms max=739.56ms p(90)=549.88ms p(95)=582.4ms
    iterations.....................: 420    9.312154/s
    vus............................: 5      min=5        max=5
    vus_max........................: 5      min=5        max=5

    NETWORK
    data_received..................: 617 kB 14 kB/s
    data_sent......................: 351 kB 7.8 kB/s




running (0m45.1s), 0/5 VUs, 420 complete and 0 interrupted iterations
default ✓ [======================================] 5 VUs  45s
```

```zsh
redaelmansouri@Redas-Laptop brokerx % k6 run load/k6/cable_connect.js -e WS_URL=ws:
//host.docker.internal:3103/cable -e TOKEN=eyJhbGciOiJIUzI1NiJ9.eyJjbGllbnRfaWQiOjE
sImlzcyI6ImJyb2tlcngiLCJhdWQiOiJicm9rZXJ4LndlYiIsImlhdCI6MTc2MTY3MDg5NywiZXhwIjoxNz
YxNzU3Mjk3fQ.uveb09gOKLwwEwB29PY7hNN5hBDGrQbKLE8qZDWKvqo -e VUS=5 -e DURATION=2m -e
 WS_HOLD_MS=110000

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: load/k6/cable_connect.js
        output: -

     scenarios: (100.00%) 1 scenario, 5 max VUs, 2m30s max duration (incl. graceful stop):
              * default: 5 looping VUs for 2m0s (gracefulStop: 30s)



  █ TOTAL RESULTS 

    checks_total.......: 600     4.984794/s
    checks_succeeded...: 0.00%   0 out of 600
    checks_failed......: 100.00% 600 out of 600

    ✗ ws status is 101
      ↳  0% — ✓ 0 / ✗ 600

    EXECUTION
    iteration_duration....: avg=1s     min=1s       med=1s     max=1.01s   p(90)=1s     p(95)=1s    
    iterations............: 600 4.984794/s
    vus...................: 5   min=5      max=5
    vus_max...............: 5   min=5      max=5

    NETWORK
    data_received.........: 0 B 0 B/s
    data_sent.............: 0 B 0 B/s

    WEBSOCKET
    ws_connecting.........: avg=1.81ms min=427.7µs  med=1.75ms max=16.46ms p(90)=2.46ms p(95)=2.72ms
    ws_session_duration...: avg=1.83ms min=451.62µs med=1.76ms max=16.46ms p(90)=2.47ms p(95)=2.74ms
    ws_sessions...........: 600 4.984794/s




running (2m00.4s), 0/5 VUs, 600 complete and 0 interrupted iterations
default ✓ [======================================] 5 VUs  2m0s
```