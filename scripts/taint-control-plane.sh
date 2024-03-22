#!/usr/bin/env bash
# set -euxo pipefail

set -x
for node in $(kind get nodes --name manager | grep control)
do

  # kubectl taint node"s --a"ll node-role.kubernetes.io/control-plane-
  kubectl taint nodes "$node" node-role.kubernetes.io/master=true:NoSchedule
  kubectl taint nodes "$node" node-role.kubernetes.io/control-plane=true:NoSchedule
  kubectl taint nodes $node CriticalAddonsOnly=true:NoExecute

done
