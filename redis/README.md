# redis:6.0.3

creates redis cluster of 3 masters each with 1 replica

- the statefulset creates `6` redis servers
- redis does not yet support dns names, it needs stable-ips
  - for each redis server, there is a service defined for stable-ip
  - in `redis.conf`, `${SERVICE_IP}` is replaced during startup
- authentication is enabled
  - `REDIS_PASSWORD` specified in secret
  - in `redis.conf`, `${REDIS_PASSWORD}` are replaced during startup
  - `default` user is disabled in `redis.conf`
- startup generates `redis.conf` with the above placeholders replaced
- configuration `/data/conf/redis.conf` is stored in persistent volme
- cluster is created using job `create-cluster.yaml`
  - enusre env `STATEFULSET_REPLICAS` matches with replicas in statesfulset
  - env `CLUSTER_REPLICAS` used to configure `--cluster-replicas`
