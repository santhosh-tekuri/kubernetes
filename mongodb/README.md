# mongodb:4.2.6

creates replicaset of 3 nodes with internal/membership authentication

- enusre env `REPLICAS` matches with replicas in statesfulset
- replSet name is specified in env `REPLSET`
- `keyfile` stores the shared secret mongodb uses to authenticate to each other
- creates `root` user with password `secret`, role `root`
  - password is specifed in `ROOT_PASSWORD` in secret
- `initContainer` creates `/etc/mongoauth/keyfile`
- `postStart` lifecycle is used to initiate respliaset and add user
  - this is done by `mongdb-0` pod
  - if replicaset is already initated, it does nothing
- to disable authentication:
  - remove the secret resource
  - remove `--keyfile` container argument
- to connect use:
  - `mongodb://mongodb`
  - `mongodb+srv://mongodb.default.svc.cluster.local/?ssl=false`
