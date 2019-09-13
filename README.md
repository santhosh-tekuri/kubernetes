# kubernetes-vagrant

kubernetes 1.15 multinode cluster using vagrant

the cluster includes:
- one master and 2 worker nodes
  - you can edit `workers` in `Vagrantfile` 
- each node is given 2048 memory and 2 cpu
  - you can edit `vb.memory` and `vb.cpu` in `Vagrantfile`
- `kubectl` is configured on all nodes with bash auto-completion
- dynamic nfs client provisioner
    - nfs server is run in master node
    - `/kubedata` folder on master node is the nfs share
- metallb loadbalancer
- local docker registry server at `registry.local` address
- nginx ingress at `ingress.local` address
- [metrics-server](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)




