#!/usr/bin/env bash
# set -euxo pipefail
# shellcheck disable=SC3036

echo ""

echo "# path to me --------------->  ${0}     "
echo "# parent path -------------->  ${0%/*}  "
echo "# my name ------------------>  ${0##*/} "
echo ""


set -x
until kubectl rollout status -n argo-events $(kubectl get deployment -n argo-events -l eventsource-name=webhook -o name); do sleep 30; done
until kubectl rollout status -n argo-events $(kubectl get deployment -n argo-events -l sensor-name=webhook -o name); do sleep 30; done
until kubectl rollout status sts/argocd-application-controller -n argocd; do sleep 30; done

set +x
echo "END ------------------>  ${0##*/} "
echo ""
