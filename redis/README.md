# redis:6.0.3

creates redis cluster of 3 masters each with 1 replica

- the statefulset creates `6` replicas
- redis does not yet support dns names, it needs stable-ips
  - for each replica there is a service defined for stable-ip
  - in `redis.conf`, `${SERVICE_IP}` is replaced by initContainer
- authentication is enabled
  - `USER_NAME` and `PASSWORD` specified in secret
  - in `redis.conf`, `${USER_NAME}` and `${PASSWORD}` are replaced by initContainer
  - `default` user is disabled in `redis.conf`
- initContainer generates `redis.conf` which the above placeholders replaced
- configuration `/data/conf/redis.conf` is stored in persistent volme
- cluster is created using job `create-cluster.yaml`
  - enusre env `STATEFULSET_REPLICAS` matches with replicas in statesfulset
  - env `CLUSTER_REPLICAS` used to configure `--cluster-replicas`
