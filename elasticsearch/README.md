# elasticsearch:7.6.2

creates 3 node cluster, with each node as all possible types

## usage

to enable authentication:
- `kubectl apply -k auth`
- username: elastic
- password: secret

to enable tls:
- `./tls/gen.sh`
- `kubectl apply -k tls`
- https is enabled to clients
- nodes interaction is encrypted

deploy elasticsearch
- `kubectl apply -k kustomize`

testing:
```
$ kubectl exec -it elasticsearch-0 -- bash
[elasticsearch@elasticsearch-0 ~]$ curl -k -u elastic:secret https://elasticsearch:9200/_cluster/health?pretty
{
  "cluster_name" : "elasticsearch",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3,
  "active_primary_shards" : 0,
  "active_shards" : 0,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}
[elasticsearch@elasticsearch-0 ~]$ exit
```

## notes

- `initContainer` updates system configuration using `sysctl`
- node name is set to the pod name
- if you change #replicas:
  - update env `cluster.initial_master_nodes` accordingly
  - update `PodDisruptionBudget.minAvailable` accordingly
- use env `ES_JAVA_OPTS` to set jvm heap size
- node discovery is done using headless service
- password for user `elastic` is specified in secret param `ELASTIC_PASSWORD`