#!/usr/bin/env bash
# set -euxo pipefail
echo ""
#echo "# arguments called with ---->  ${@}     "
#echo "# \$1 ---------------------->  $1       "
#echo "# \$2 ---------------------->  $2       "
echo "# path to me --------------->  ${0}     "
echo "# parent path -------------->  ${0%/*}  "
echo "# my name ------------------>  ${0##*/} "
echo ""

set -x


# et -e

# DEPLOY INGRESS-NGINX
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh
# SOURCE: https://github.com/kyverno/kyverno/blob/67dee8d3316c3ddc8f2794b931dd4440f934d6a2/scripts/labs/argocd/1-ingress-nginx.sh

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

sleep 15

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# # just monitoring-crds
# # kubectl -n kube-system apply --server-side -f https://raw.githubusercontent.com/external-secrets/external-secrets/v0.9.11/deploy/crds/bundle.yaml || true
# just deploy-externalsecrets-vault


# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
# helm repo update
# helm template --version 4.9.0 --values apps/argocd/base/core/ingress-nginx/app/values.yaml ingress-nginx ingress-nginx/ingress-nginx -n kube-system | kubectl apply --server-side -f -

# just certs-only


# echo ""
# echo ""

# echo "waiting for ingress-nginx deployment.apps/ingress-nginx-controller"
# kubectl -n kube-system wait deployment ingress-nginx-controller --for condition=Available=True --timeout=300s

set +x
echo "END ------------------>  ${0##*/} "
echo ""
