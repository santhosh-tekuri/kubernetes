# elasticsearch:7.6.2

creates 2 node cluster, with each node as all possible types
- `initContainer` updates system configuration using `sysctl`
- node name is set to the pod name
- if you change #replicas:
  - update env `cluster.initial_master_nodes` accordingly
  - update `PodDisruptionBudget.minAvailable` accordingly
- use env `ES_JAVA_OPTS` to set jvm heap size
- node discovery is done using headless service
