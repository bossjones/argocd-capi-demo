#!/usr/bin/env bash
# set -euxo pipefail
# shellcheck disable=SC3036

echo ""

echo "# path to me --------------->  ${0}     "
echo "# parent path -------------->  ${0%/*}  "
echo "# my name ------------------>  ${0##*/} "
echo ""

export GIT_URI=$(git config --get remote.origin.url | sed -e 's/:/\//g' | sed -e 's/ssh\/\/\///g' | sed -e 's/git@/https:\/\//g' | sed 's/.git$//')

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
    name: sops-age
    namespace: argocd
type: Opaque
stringData:
    key.txt: |
        $(cat "$HOME"/.sops/key.txt | base64)
EOF



# # set -euxo pipefail
# kubectl apply -f - <<EOF
# apiVersion: v1
# kind: Secret
# metadata:
#   name: main-repository
#   namespace: argocd
#   labels:
#     argocd.argoproj.io/secret-type: repository
# stringData:
#   type: git
#   url: ${GIT_URI}
#   password: ${GH_PASS}
#   username: ${GH_USER}
# EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-creds
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: ${GIT_URI}
  password: ${GH_PASS}
  username: ${GH_USER}
EOF
