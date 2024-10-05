# Makefile

# Variables
CLUSTER_NAME = wonderful-poc

cluster:
	k3d cluster create $(CLUSTER_NAME) \
	    --port '5432:30000@loadbalancer' \
	    --port '9000:30001@loadbalancer'

install:
	helmfile sync

forward:
	kubectl port-forward --namespace default svc/pg-postgresql 5432:5432 &
	kubectl port-forward --namespace default svc/postgrest 9000:9000 &

cleanup:
	helmfile destroy
	k3d cluster delete $(CLUSTER_NAME)

all: cluster install
