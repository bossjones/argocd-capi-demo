set shell := ["zsh", "-cu"]
LOCATION_PYTHON := `python -c "import sys;print(sys.executable)"`

# just manual: https://github.com/casey/just/#readme

# Ignore the .env file that is only used by the web service
set dotenv-load := false

K3D_VERSION := `k3d version`
CURRENT_DIR := "$(pwd)"
PATH_TO_TRAEFIK_CONFIG := CURRENT_DIR / "mounts/var/lib/rancer/k3s/server/manifests/traefik-config.yaml"

# base64_cmd := if "{{os()}}" == "macos" { "base64 -w 0 -i cert.pem -o ca.pem" } else { "base64 -b 0 -i cert.pem -o ca.pem" }
base64_cmd := if "{{os()}}" == "macos" { "base64 -w 0 -i cert.pem -o ca.pem" } else { "base64 -w 0 -i cert.pem > ca.pem" }
grep_cmd := if "{{os()}}" =~ "macos" { "ggrep" } else { "grep" }
conntrack_fix := if "{{os()}}" =~ "linux" { "--k3s-arg '--kube-proxy-arg=conntrack-max-per-core=0@server:*' --k3s-arg '--kube-proxy-arg=conntrack-max-per-core=0@agent:*'" } else { "" }

en0_ip := `ifconfig en0 | grep inet | cut -d' ' -f2 | grep -v ":"`

# # Initialize OS Setup
# init:
#     just _init-{{os()}}

# _init-linux:
#     # Linux init
#     wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.5.1 bash

#     curl --silent --location --remote-name \
#     "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v5.3.0/kustomize_kustomize.v5.3.0_linux_amd64" && \
#     chmod a+x kustomize_kustomize.v5.3.0_linux_amd64 && \
#     sudo mv kustomize_kustomize.v5.3.0_linux_amd64 /usr/local/bin/kustomize

#     curl -L https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux > /usr/local/bin/sop
#     $ chmod +x /usr/local/bin/sops

# _init-macos:
#     # macOS init

# _init-windows:
#     # Windows init


_default:
		@just --list

info:
		print "Python location: {{LOCATION_PYTHON}}"
		print "PATH_TO_TRAEFIK_CONFIG: {{PATH_TO_TRAEFIK_CONFIG}}"
		print "OS: {{os()}}"

# verify python is running under pyenv
which-python:
		python -c "import sys;print(sys.executable)"

helm:
  bash scripts/helm.sh
# install argocd
argocd-install:
  bash scripts/argocd-install.sh


# generate argocd templates
templates:
  retry -t 4 -- bash scripts/templates.sh
argocd-bridge:
  echo "no op"

argocd-proxy: argocd-bridge

check-prereq:
	@command -v pre-commit >/dev/null 2>&1 || { echo >&2 "pre-commit is required but it's not installed."; exit 1; }
	@command -v helm-docs >/dev/null 2>&1 || { echo >&2 "helm-docs is required but it's not installed."; exit 1; }
	@command -v vault >/dev/null 2>&1 || { echo >&2 "vault is required but it's not installed."; exit 1; }
	@command -v hostctl >/dev/null 2>&1 || { echo >&2 "hostctl is required but it's not installed."; exit 1; }
	@command -v mkcert >/dev/null 2>&1 || { echo >&2 "mkcert is required but it's not installed."; exit 1; }
	@command -v retry >/dev/null 2>&1 || { echo >&2 "retry is required but it's not installed."; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl is required but it's not installed."; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo >&2 "helm is required but it's not installed."; exit 1; }
	@command -v kustomize >/dev/null 2>&1 || { echo >&2 "kustomize is required but it's not installed."; exit 1; }
	@command -v k3d >/dev/null 2>&1 || { echo >&2 "k3d is required but it's not installed."; exit 1; }
	@command -v kubectl-slice >/dev/null 2>&1 || { echo >&2 "kubectl-slice is required but it's not installed."; exit 1; }


setup-cluster:
	mkdir -p /tmp/k3dvol 2>/dev/null || true
	k3d --verbose cluster create \
	--volume {{PATH_TO_TRAEFIK_CONFIG}}:/var/lib/rancer/k3s/server/manifests/traefik-config.yaml@all \
	--volume /tmp/k3dvol:/var/lib/rancher/k3s/storage@all \
	--api-port 6550 \
	-p "80:80@loadbalancer" \
	-p "443:443@loadbalancer" \
	-p "8900:30080@agent:0" -p "8901:30081@agent:0" -p "8902:30082@agent:0" \
	-p "4040:30083@agent:0" -p "9000:30084@agent:0" -p "8000:30085@agent:0" \
	--agents 2 k3d-playground \
	--runtime-ulimit "nofile=26677:26677" \
	--runtime-ulimit "nproc=26677:26677" \
	--runtime-ulimit "core=26677:26677" \
	--k3s-arg '--kubelet-arg=eviction-hard=imagefs.available<1%,nodefs.available<1%@agent:*' \
	--k3s-arg '--kubelet-arg=eviction-minimum-reclaim=imagefs.available=1%,nodefs.available=1%@agent:*' \
	--k3s-arg '--kubelet-arg=eviction-hard=imagefs.available<1%,nodefs.available<1%@server:0' \
	--k3s-arg '--kubelet-arg=eviction-minimum-reclaim=imagefs.available=1%,nodefs.available=1%@server:0' \
	--image rancher/k3s:v1.27.9-k3s1
# -p "32000-32767:32000-32767@loadbalancer" \
# --image rancher/k3s:v1.28.5+k3s1
# --image rancher/k3s:v1.27.9-k3s1
# The above command is creating another K3d cluster and mapping port 8888 on the host to port 80 on the containers that have a nodefilter of loadbalancer.

start-cluster:
	k3d cluster start k3d-playground 2>/dev/null || true

stop-cluster:
	k3d cluster stop k3d-playground 2>/dev/null || true

delete-cluster: stop-cluster
	k3d cluster delete k3d-playground 2>/dev/null || true

nuke-cluster: delete-cluster

reset-cluster: delete-cluster setup-cluster

# simple-cluster-reset: reset-cluster install

# install crds for the monitoring stack
monitoring-crds:
	bash scripts/deploy-monitoring-crds.sh

deploy-monitoring-crds: monitoring-crds

# k3d cluster delete demo
# # k3d cluster create --config config/cluster.yaml --trace --verbose --timestamps
# k3d cluster create --config config/cluster.yaml "{{conntrack_fix}}"
# echo -e "\nYour cluster has been created. Type 'k3d cluster list' to confirm."
# echo "Waiting for the cluster to be ready... (sleep 30)"

# # sleep
# # SOURCE: https://unix.stackexchange.com/questions/600868/verbose-sleep-command-that-displays-pending-time-seconds-minutes/600871#600871
# @yes | pv -SL1 -F 'Resuming in %e' -s 30 > /dev/null

# just apply-coredns-additions
# just argocd-secret
# just install-secret-0
# just deploy-ingress-nginx
# just install-mandatory-manifests

# Starts your local k3d cluster.
k3d-demo-bare:
	k3d cluster delete demo
	k3d cluster create --config config/cluster.yaml --trace --verbose --timestamps \
	--k3s-arg "--datastore-endpoint=mysql://root:raspberry\@tcp({{en0_ip}}:6033)/kine@server:*"
	echo -e "\nYour cluster has been created. Type 'k3d cluster list' to confirm."
	echo "Waiting for the cluster to be ready... (sleep 30)"

	# sleep
	# SOURCE: https://unix.stackexchange.com/questions/600868/verbose-sleep-command-that-displays-pending-time-seconds-minutes/600871#600871
	@yes | pv -SL1 -F 'Resuming in %e' -s 30 > /dev/null

	just apply-coredns-additions
	# just argocd-secret
	# just install-secret-0
	# just deploy-ingress-nginx
	# just install-mandatory-manifests

# SOURCE: https://github.com/casey/just/issues/531#issuecomment-1434096386
# Starts your local k3d cluster.
k3d-demo:
	just k3d-demo-{{os()}}

# Starts your local k3d cluster.
k3d-demo-macos:
	k3d cluster delete demo
	# k3d cluster create --config config/cluster.yaml --trace --verbose --timestamps
	k3d cluster create --config config/cluster.yaml -v "--datastore-endpoint=mysql://root:raspberry@tcp(192.168.3.13:6033)/kine@server:*"
	echo -e "\nYour cluster has been created. Type 'k3d cluster list' to confirm."
	echo "Waiting for the cluster to be ready... (sleep 30)"

	# sleep
	# SOURCE: https://unix.stackexchange.com/questions/600868/verbose-sleep-command-that-displays-pending-time-seconds-minutes/600871#600871
	@yes | pv -SL1 -F 'Resuming in %e' -s 30 > /dev/null

	just apply-coredns-additions
	just argocd-secret
	just install-secret-0
	just deploy-ingress-nginx
	just install-mandatory-manifests
# Starts your local k3d cluster.

k3d-demo-linux:
	sudo apt-get install sharutils -y
	# SOURCE: https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/assets/scripts/developer/k3d-dev.sh?ref_type=heads
	# SOURCE: https://istio.io/latest/docs/setup/platform-setup/prerequisites/
	@echo "Load required kernel modules"
	sudo modprobe br_netfilter
	sudo modprobe nf_conntrack
	# sudo modprobe nf_nat_redirect
	sudo modprobe xt_owner
	sudo modprobe xt_REDIRECT
	sudo modprobe xt_statistic
	sudo modprobe overlay
	echo br_netfilter | sudo tee /etc/modules-load.d/kubernetes.conf
	echo nf_conntrack | sudo tee -a /etc/modules-load.d/kubernetes.conf
	# echo nf_nat_redirect | sudo tee -a /etc/modules-load.d/kubernetes.conf
	echo xt_REDIRECT | sudo tee -a /etc/modules-load.d/kubernetes.conf
	echo xt_owner | sudo tee -a /etc/modules-load.d/kubernetes.conf
	echo xt_statistic | sudo tee -a /etc/modules-load.d/kubernetes.conf
	echo bridge | sudo tee -a /etc/modules-load.d/kubernetes.conf
	echo ip_tables | sudo tee -a /etc/modules-load.d/kubernetes.conf
	echo nf_nat | sudo tee -a /etc/modules-load.d/kubernetes.conf

	@echo "Set required networking parameters"
	echo "net.bridge.bridge-nf-call-iptables  = 1" | sudo tee /etc/sysctl.d/k8s.conf
	echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
	echo "net.ipv4.ip_forward                 = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
	# SOURCE: rowa78/k8s-gitops
	# echo "fs.inotify.max_user_watches         = 524288" | sudo tee -a /etc/sysctl.d/k8s.conf
	# echo "fs.inotify.max_user_instances       = 8192" | sudo tee -a /etc/sysctl.d/k8s.conf

	@echo "Apply sysctl params without reboot"
	sudo sysctl --system

	sudo sed -i "s,#NTP=,NTP=0.flatcar.pool.ntp.org 1.flatcar.pool.ntp.org 2.flatcar.pool.ntp.org 3.flatcar.pool.ntp.org,g" /etc/systemd/timesyncd.conf


	k3d cluster delete demo

	# -v "/etc:/etc@server:*\;agent:*" \
	@echo "Creat k3d cluster"
	k3d cluster create --config config/cluster.yaml  --trace --verbose --timestamps \
	--k3s-arg "--datastore-endpoint=mysql://root:raspberry\@tcp(192.168.2.11:6033)/kine@server:*" \
	--k3s-arg "--kube-proxy-arg=conntrack-max-per-core=0@server:*" \
	--k3s-arg "--kube-proxy-arg=conntrack-max-per-core=0@agent:*" \
	-v "/dev/log:/dev/log@server:*" \
	-v "/dev/log:/dev/log@agent:*" \
	-v "/run/systemd/private:/run/systemd/private@server:*" \
	-v "/run/systemd/private:/run/systemd/private@agent:*" \
	-v "/dev/mapper:/dev/mapper@all" \
	-v "/lib/modules:/lib/modules@all" \

	# -v "/etc/ssl/certs:/etc/ssl/certs@all" \
	echo -e "\nYour cluster has been created. Type 'k3d cluster list' to confirm."
	echo "Waiting for the cluster to be ready... (sleep 30)"

	# sleep
	# SOURCE: https://unix.stackexchange.com/questions/600868/verbose-sleep-command-that-displays-pending-time-seconds-minutes/600871#600871
	@yes | pv -SL1 -F 'Resuming in %e' -s 30 > /dev/null

	just apply-coredns-additions
	just argocd-secret
	just install-secret-0
	just deploy-ingress-nginx
	just install-mandatory-manifests

# install argocd secrets
argocd-secret:
	retry -t 4 -- bash scripts/argocd-secret.sh

# get argocd password
argocd-password:
	bash scripts/argocd-password.sh


# delete k3d demo cluster
demo-down:
	k3d cluster delete demo

# Creates the DNS entry required for the local domain to work.
dns:
	sudo hostctl add k8s -q < config/.etchosts
	echo -e "Added 'k8s.localhost' and related domains to your hosts file!"

# Initial cert creation steps
pre-certs:
	#!/usr/bin/env bash
	cd config/tls
	pwd
	rm cert.pem key.pem base/tls-secret.yaml ca.pem 2> /dev/null
	set -euxo pipefail
	mkcert -install
	mkcert -cert-file cert.pem -key-file key.pem -p12-file p12.pem "*.k8s.localhost" k8s.localhost "*.localhost" ::1 127.0.0.1 localhost 127.0.0.1 "*.internal.localhost" "*.local" 2> /dev/null
	cd -

# Post cert creation steps
post-certs:
	#!/usr/bin/env bash
	set -euxo pipefail
	cd config/tls
	pwd
	echo -e 'running eval "{{base64_cmd}}"\n'
	eval "{{base64_cmd}}"
	cd -

# generate certs
certs: pre-certs post-certs
	#!/usr/bin/env bash
	set -euxo pipefail
	cd config/tls
	pwd
	echo -e "Creating certificate secrets on Kubernetes for local TLS enabled by default\n"
	retry -t 4 -- kubectl --namespace=kube-system --cluster=k3d-demo create secret tls tls-secret --cert=cert.pem --key=key.pem --dry-run=client -o yaml >base/tls-secret.yaml
	retry -t 4 -- kubectl --namespace=kube-system --cluster=k3d-demo apply -k ./
	echo -e "\nCertificate resources have been created.\n"
	cd -

# generate certs ONLY
certs-only:
	#!/usr/bin/env bash
	set -euxo pipefail
	cd config/tls
	pwd
	echo -e "Creating certificate secrets on Kubernetes for local TLS enabled by default\n"
	retry -t 4 -- kubectl --namespace=kube-system --cluster=k3d-demo create secret tls tls-secret --cert=cert.pem --key=key.pem --dry-run=client -o yaml >base/tls-secret.yaml
	retry -t 4 -- kubectl --namespace=kube-system --cluster=k3d-demo apply -k ./
	echo -e "\nCertificate resources have been created.\n"
	cd -


# Add apps to argocd
monitoring-install:
	./scripts/run-kustomize.sh manifests/monitoring/kube-prometheus-stack

deploy-monitoring:
	kustomize build --enable-alpha-plugins apps/argocd/base/monitoring/kube-prometheus-stack | kubectl apply -f -

open-argocd:
	open https://localhost:8832

proxy-argocd: open-argocd argocd-proxy

# install secret-0
install-secret-0:
	retry -t 4 -- scripts/upload-secret-0.sh

# install-secretgenerator
install-secretgenerator:
	scripts/install-secretgenerator.sh

deploy-metallb:
	bash scripts/deploy-metallb.sh

deploy-cert-manager:
	bash scripts/deploy-cert-manager.sh

deploy-nginx-proxy:
	bash scripts/deploy-nginx-proxy.sh

deploy-ingress-nginx:
	bash scripts/deploy-ingress-nginx.sh

deploy-external-secrets:
	bash scripts/deploy-external-secrets.sh

deploy-externalsecrets-vault:
	bash scripts/deploy-externalsecrets-vault.sh

deploy-authentik-deps:
	bash scripts/deploy-authentik-deps.sh

machine-id:
	touch storage/machine-id

apply-coredns-additions:
	kubectl -n kube-system apply -f deploy/coredns/coredns-additions.yaml

# bring up k3d-demo cluster
demo: nuke-cluster helm k3d-demo argocd-install certs argocd-secret templates argocd-password argocd-bridge

# demo-prebuilt: nuke-cluster k3d-demo argocd-install certs-only argocd-secret templates monitoring-install argocd-password argocd-bridge
# bring up k3d-demo cluster but skip some steps
# demo-prebuilt: nuke-cluster k3d-demo deploy-metallb deploy-nginx-proxy argocd-install certs-only argocd-secret install-secret-0 templates argocd-password argocd-bridge
demo-prebuilt: machine-id nuke-cluster k3d-demo argocd-install deploy-ingress-nginx certs-only argocd-secret install-secret-0 templates argocd-password argocd-bridge

# bring up k3d-demo cluster but skip some steps
demo-prebuilt-no-nuke: argocd-install certs-only argocd-secret install-secret-0 templates argocd-password argocd-token open-homepage argocd-bridge

# apply secrets to cluster
demo-prebuilt-secrets-only: certs-only argocd-secret install-secret-0 templates argocd-password argocd-token argocd-bridge


# fix network policies in all namespaces
fix-network-policies:
	bash scripts/fix-network-policies.sh

fix-np: fix-network-policies

# demo-update: argocd-install certs-only argocd-secret templates argocd-password install-secret-0 install fix-np argocd-bridge

get-apps:
	kubectl -n argocd get applications.argoproj.io

tail-audit:
	tail -f audit/logs/audit.log | jq .


# Encrypt all sops secrets
encrypt target:
	./scripts/encrypt.sh {{target}}

# Decrypt all sops secrets
decrypt target:
	./scripts/decrypt.sh {{target}}

# Decrypt and re-encrypt all sops secrets
re-encrypt:
	scripts/re-encrypt.sh


install-mandatory-manifests:
	kubectl create namespace argocd 2>/dev/null || true
	kubectl create namespace databases 2>/dev/null || true
	kubectl create namespace cert-manager 2>/dev/null || true
	# just monitoring-crds

	just deploy-externalsecrets-vault
	# NOTE: This used to be here: kubectl -n kube-system apply --server-side -f https://raw.githubusercontent.com/external-secrets/external-secrets/v0.9.11/deploy/crds/bundle.yaml 2>/dev/null || true


	# sleep
	# SOURCE: https://unix.stackexchange.com/questions/600868/verbose-sleep-command-that-displays-pending-time-seconds-minutes/600871#600871
	@yes | pv -SL1 -F 'Resuming in %e' -s 20 > /dev/null

	# bash scripts/deploy-metallb.sh

	just deploy-cert-manager

	# kubectl -n databases apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.22.1/config/crd/bases/postgresql.cnpg.io_backups.yaml 2>/dev/null || true
	# kubectl -n databases apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.22.1/config/crd/bases/postgresql.cnpg.io_backups.yaml 2>/dev/null || true
	# kubectl -n databases apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.22.1/config/crd/bases/postgresql.cnpg.io_clusters.yaml 2>/dev/null || true
	# kubectl -n databases apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.22.1/config/crd/bases/postgresql.cnpg.io_poolers.yaml 2>/dev/null || true
	# kubectl -n databases apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.22.1/config/crd/bases/postgresql.cnpg.io_scheduledbackups.yaml 2>/dev/null || true

	# kustomize build --enable-alpha-plugins --enable-exec apps/argocd/base/monitoring/kube-prometheus-stack/app | kubectl apply --server-side -f -
	just decrypt apps/argocd/base/kube-system/external-secrets/app/connect/1passwordCredentials.sops.yaml
	just decrypt apps/argocd/base/kube-system/external-secrets/app/connect/accessToken.sops.yaml

	kubectl -n kube-system apply --server-side -f apps/argocd/base/kube-system/external-secrets/app/connect/1passwordCredentials.sops.yaml
	kubectl -n kube-system apply --server-side -f apps/argocd/base/kube-system/external-secrets/app/connect/accessToken.sops.yaml

	git restore apps/argocd/base/kube-system/external-secrets/app/connect/1passwordCredentials.sops.yaml
	git restore apps/argocd/base/kube-system/external-secrets/app/connect/accessToken.sops.yaml

	# kustomize build --enable-alpha-plugins --enable-exec apps/argocd/base/kube-system/external-secrets | kubectl apply --server-side -f -

	just decrypt apps/argocd/base/monitoring/kube-prometheus-stack/app/thanos-secret.sops.yaml
	kubectl -n monitoring apply --server-side -f apps/argocd/base/monitoring/kube-prometheus-stack/app/thanos-secret.sops.yaml
	git restore apps/argocd/base/monitoring/kube-prometheus-stack/app/thanos-secret.sops.yaml

	# kubectl -n kube-system apply --server-side -f apps/argocd/base/kube-system/external-secrets/app/connect/1passwordCredentials.sops.yaml

	kubectl -n argocd apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.9/manifests/crds/application-crd.yaml
	kubectl -n argocd apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.9/manifests/crds/applicationset-crd.yaml
	kubectl -n argocd apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.9/manifests/crds/appproject-crd.yaml

	# just deploy-authentik-deps

	# kubectl -n databases apply --server-side -f apps/argocd/base/database/cloudnative-pg/app/cluster/cluster.yaml
	# kubectl -n databases apply --server-side -f apps/argocd/base/database/cloudnative-pg/app/cluster/externalSecret.yaml
	# kubectl -n databases apply --server-side -f apps/argocd/base/database/cloudnative-pg/app/cluster/prometheusRule.yaml
	# kubectl -n databases apply --server-side -f apps/argocd/base/database/cloudnative-pg/app/cluster/scheduledbackup.yaml
	# kubectl -n databases apply --server-side -f apps/argocd/base/database/cloudnative-pg/app/cluster/service.yaml


dashboard-token:
	kubectl get secret kd-user -n monitoring -o jsonpath={".data.token"} | base64 -d | pbcopy

yamllint:
		bash -c "find apps -type f -name '*.y*ml' ! -name '*.venv' ! -name '*.vendor' ! -name '*.generated' -print0 | xargs -I FILE -t -0 -n1 yamllint FILE"

argocd-cli-login:
	argocd login argocd.k8s.localhost --grpc-web --username admin --password `_PASS=$(kubectl --cluster=k3d-demo -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d); echo $_PASS`

argocd-token:
	kubectl --cluster=k3d-demo -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | pbcopy

argo-render:
	kustomize build --enable-alpha-plugins --enable-exec --enable-helm apps/argocd/base/gitops/argo-workflows/app | pbcopy


loghose:
	docker-loghose | grep -v "couldn't get current server API group list" | grep -v "Applied manifest " | grep -v "8080" | ccze -A

open-homepage:
	open https://hajimari.k8s.localhost/

open-pgadmin:
	open https://pgadmin.k8s.localhost/

# open-argocd:
#   open https://argocd.k8s.localhost/

##############################################################################################################################
# Here's an example of how to install packages on the VM (htop in this case):
# docker run -it --rm --privileged --pid=host justincormack/nsenter
# $ mount -o remount,rw /
# $ mkdir /var/cache/apk
# $ apk add htop

# SOURCE: https://github.com/justincormack/nsenter1
# nsenter allows you to enter a shell in a running container (technically into the namespaces that provide a container's isolation and limited access to system resources). The crazy thing is that this image allows you to run a privileged container that runs nsenter for the process space running as pid 1. How is this useful?


# Well, this is useful when you are running a lightweight, container-optimized Linux distribution such as LinuxKit. Here is one simple example: say you want to teach a few people about Docker networking and you want to show them how to inspect the default bridge network after starting two containers using ip addr show; the problem is if you are demonstrating with Docker for Mac, for example, your containers are not running on your host directly, but are running instead inside of a minimal Linux OS virtual machine specially built for running containers, i.e., LinuxKit. But being a lightweight environment, LinuxKit isn't running sshd, so how do you get access to a shell so you can run nsenter to inspect the namespaces for the process running as pid 1?

# Well, you could run the following:

# $ screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty

##############################################################################################################################

# on macos drop you in a container with full permissions on the Docker VM
docker-host-container:
	echo "see https://gist.github.com/BretFisher/5e1a0c7bcca4c735e716abf62afad389 for more info"
	docker pull justincormack/nsenter1
	docker run -it --rm --privileged --pid=host justincormack/nsenter1

nsenter: docker-host-container

# SOURCE: https://github.com/surfer190/fixes/blob/master/docs/docker/docker-basics.md
# install ubuntu - If you ever have a need to access the underlying VM
nsenter-ubuntu:
	docker run -it --privileged --pid=host ubuntu:22.04 nsenter -t 1 -m -u -n -i sh

# Read the docker daemon logs
docker-macos-logs:
	tail -f ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log ~/Library/Containers/com.docker.docker/Data/log/vm/containerd.log | ccze -A

docker-logs: docker-macos-logs

# SOURCE: https://forums.docker.com/t/dockerd-using-100-cpu/94962/16
# It will give you a shell so you can see the files including the docker data root and the config file, but don't change anything there until the Graphical interface works. You can change the daemon config from the GUI. docker stats can also show you how much resources containers use and you can try docker system prune to remove
docker-desktop-nsenter:
	docker run --rm -it --privileged --pid host ubuntu:20.04 \
		nsenter --all -t 1 \
			-- ctr -n services.linuxkit task exec -t --exec-id test docker \
					sh

kine-mysql-up:
	# docker-compose build --pull
	docker-compose up -d

kine-mysql-down:
	docker-compose down

kine-mysql-reset:
	docker-compose down --remove-orphans >/dev/null 2>&1 2>/dev/null || true
	docker-compose down --remove-orphans >/dev/null 2>&1 2>/dev/null || true
	docker volume rm k3d-playground_kine_mysql >/dev/null 2>&1 2>/dev/null || true
	docker volume rm  k3d-playground_tmpvolume >/dev/null 2>&1 2>/dev/null || true
	docker-compose up -d

docker-compose-reset: kine-mysql-reset

docker-loghose:
	docker-loghose | grep -v "couldn't get current server API group list" | grep -v "Applied manifest " | grep -v "8080" | ccze -A

k3d-server-logs:
	bash scripts/k3d-server-logs.sh

mysqld-logs:
	tail -f storage/mysqllogs/* | ccze -A


k3d-server-exec:
	bash scripts/k3d-server-exec.sh

k3d-agent-exec:
	bash scripts/k3d-agent-exec.sh

netshoot-exec:
	bash scripts/docker-netshoot-exec.sh

docker-netshoot: netshoot-exec

sleep:
	yes | pv -SL1 -F 'Resuming in %e' -s 60 > /dev/null

# reset everyhitng having to do with k3d and kine
k3d-scorch-earth: demo-down kine-mysql-reset sleep demo-prebuilt demo-prebuilt-no-nuke

k8s-netshoot-help:
	@echo "SEE: https://github.com/nicolaka/netshoot"
	@echo "# spin up a throwaway pod for troubleshooting"
	@echo "kubectl netshoot run tmp-shell"
	@echo ""
	@echo "# debug using an ephemeral container in an existing pod"
	@echo "kubectl netshoot debug my-existing-pod"
	@echo ""
	@echo "# create a debug session on a node"
	@echo "kubectl netshoot debug node/my-node"


post-argocd-install: certs-only argocd-secret install-secret-0 templates argocd-password argocd-token argocd-bridge


delete-non-ready-pods:
	bash scripts/delete-non-ready-pods.sh


# generate certs ONLY
k8s-netshoot:
	#!/usr/bin/env bash
	set -euxo pipefail
	export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
	kubectl netshoot run tmp-shell

nodes-logs:
	kubectl get nodes -v=10 >> nodes.log

serverlb-logs-stats:
	bash scripts/k3d-ngxtop-logs.sh

k9s:
	retry -t 20 -- k9s

get-all-events:
	kubectl get events --all-namespaces --sort-by='.lastTimestamp'



# Add new app to argocd
add-argocd-app namespace app_name helm_repo chart_version:
	./scripts/add-argocd-app.sh -n {{namespace}} -a {{app_name}} -h {{helm_repo}} -c {{chart_version}}

oxker:
	oxker

delete-docker:
	docker-compose down --remove-orphans >/dev/null 2>&1 2>/dev/null || true
	docker-compose down --remove-orphans >/dev/null 2>&1 2>/dev/null || true
	docker volume rm k3d-playground_kine_mysql >/dev/null 2>&1 2>/dev/null || true
	docker volume rm  k3d-playground_tmpvolume >/dev/null 2>&1 2>/dev/null || true
	./scripts/delete-all-docker.sh

journalctl:
	sudo journalctl -f | ccze -A

k3d-vanilla: demo-down kine-mysql-reset sleep k3d-demo

# k3d-vanilla-the-rest:  argocd-install certs-only templates argocd-password argocd-bridge

# the rest of the normal steps we take to bring something up
k3d-vanilla-the-rest:  argocd-install templates argocd-password argocd-bridge

down: demo-down delete-docker

k3d-bare: demo-down kine-mysql-reset sleep k3d-demo-bare

k3d-bare-down: down

# k3d-bare-the-rest:  argocd-install certs-only templates argocd-password argocd-bridge

# the rest of the normal steps we take to bring something up
k3d-bare-the-rest:  argocd-install templates argocd-password argocd-bridge

# deploy-ingress-nginx certs-only

journal-errors:
	sudo journalctl -p err -b

# export VAULT_TOKEN=$(vault login -token-only -method oidc)
# login to vault
vault-login:
	export VAULT_ADDR="https://vault.k8s.localhost:8200"
	export VAULT_TOKEN=root

install-mkdocs:
	pip install mkdocs
	# EVENTUALLY make man pages
	pip install click-man
	# click-man --target path/to/man/pages mkdocs

build-docs-local:
		mkdocs build

serve-docs-local:
		mkdocs serve

screen-docker-desktop:
	screen ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty

apply-appsets:
	kustomize build --enable-alpha-plugins --enable-exec --enable-helm apps/argo/overlays/default | kubectl apply -f -

bootstrap:
	until kustomize build --enable-alpha-plugins --enable-exec --enable-helm bootstrap/install | kubectl apply -f -; do sleep 3; done
	just kind-secrets
	just argo-status

argo-status:
	bash scripts/argoproj-status.sh

kind-bootstrap: bootstrap

kind-secrets:
	bash scripts/kind-secrets.sh

kind-taint-controlplane:
	bash scripts/taint-control-plane.sh

kind-create:
	kind create cluster --config=kind-config.yaml --name=manager -v 9
	@yes | pv -SL1 -F 'Resuming in %e' -s 30 > /dev/null
	kubectl cluster-info
	just bootstrap

kind-reset:
	kind delete clusters --all
	@yes | pv -SL1 -F 'Resuming in %e' -s 10 > /dev/null
	just kind-create
