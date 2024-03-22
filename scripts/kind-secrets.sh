#!/usr/bin/env bash
# set -euxo pipefail
# shellcheck disable=SC3036

echo ""

echo "# path to me --------------->  ${0}     "
echo "# parent path -------------->  ${0%/*}  "
echo "# my name ------------------>  ${0##*/} "
echo ""


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
    name: sops-age
    namespace: argocd
type: Opaque
stringData:
    key.txt: |
        $(cat $HOME/.sops/key.txt | base64)
EOF
