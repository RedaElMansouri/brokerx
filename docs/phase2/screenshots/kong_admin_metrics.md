# Kong metrics (admin) (In Terminal)

```zsh
redaelmansouri@Redas-Laptop brokerx % curl -s http://localhost:8001/metrics | head 
-n 40
# HELP kong_datastore_reachable Datastore reachable from Kong, 0 is unreachable
# TYPE kong_datastore_reachable gauge
kong_datastore_reachable 1
# HELP kong_memory_lua_shared_dict_bytes Allocated slabs in bytes in a shared_dict
# TYPE kong_memory_lua_shared_dict_bytes gauge
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong",kong_subsystem="http"} 45056
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_cluster_events",kong_subsystem="http"} 40960
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_core_db_cache",kong_subsystem="http"} 802816
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_core_db_cache_miss",kong_subsystem="http"} 86016
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_db_cache",kong_subsystem="http"} 802816
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_db_cache_miss",kong_subsystem="http"} 86016
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_healthchecks",kong_subsystem="http"} 40960
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_locks",kong_subsystem="http"} 61440
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_rate_limiting_counters",kong_subsystem="http"} 86016
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_secrets",kong_subsystem="http"} 40960
kong_memory_lua_shared_dict_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="prometheus_metrics",kong_subsystem="http"} 40960
# HELP kong_memory_lua_shared_dict_total_bytes Total capacity in bytes of a shared_dict
# TYPE kong_memory_lua_shared_dict_total_bytes gauge
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong",kong_subsystem="http"} 5242880
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_cluster_events",kong_subsystem="http"} 5242880
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_core_db_cache",kong_subsystem="http"} 134217728
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_core_db_cache_miss",kong_subsystem="http"} 12582912
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_db_cache",kong_subsystem="http"} 134217728
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_db_cache_miss",kong_subsystem="http"} 12582912
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_healthchecks",kong_subsystem="http"} 5242880
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_locks",kong_subsystem="http"} 8388608
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_rate_limiting_counters",kong_subsystem="http"} 12582912
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="kong_secrets",kong_subsystem="http"} 5242880
kong_memory_lua_shared_dict_total_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",shared_dict="prometheus_metrics",kong_subsystem="http"} 5242880
# HELP kong_memory_workers_lua_vms_bytes Allocated bytes in worker Lua VM
# TYPE kong_memory_workers_lua_vms_bytes gauge
kong_memory_workers_lua_vms_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",pid="1331",kong_subsystem="http"} 77742284
kong_memory_workers_lua_vms_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",pid="1332",kong_subsystem="http"} 68701232
kong_memory_workers_lua_vms_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",pid="1333",kong_subsystem="http"} 83319171
kong_memory_workers_lua_vms_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",pid="1334",kong_subsystem="http"} 67751560
kong_memory_workers_lua_vms_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",pid="1335",kong_subsystem="http"} 54857695
kong_memory_workers_lua_vms_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",pid="1336",kong_subsystem="http"} 54857416
kong_memory_workers_lua_vms_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",pid="1337",kong_subsystem="http"} 54859371
kong_memory_workers_lua_vms_bytes{node_id="9d2a62e8-341a-4251-a4d9-2a0afb58d0ff",pid="1338",kong_subsystem="http"} 68104347
# HELP kong_nginx_connections_total Number of connections by subsystem
```