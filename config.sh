#!/bin/bash

CLUSTER_NAME="wonderful-poc"
DB_PASSWORD="mysecretpassword"

install_utils() {
  brew install k3d helm kubectl helmfile
}

open_docker() {
  open -a docker
}

get_cluster_info() {
  kubectl cluster-info
}

forward_db_port() {
  kubectl port-forward --namespace default svc/pg-postgresql 5432:5432 &
}

pg_prompt() {
  export POSTGRES_PASSWORD=$(kubectl get secret --namespace default pg-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
  export PGPASSWORD="$POSTGRES_PASSWORD"
  psql --host 127.0.0.1 -U postgres -d postgres -p 5432
}

set_up_experiment() {
  create_cluster
  configure_helm
  install_postgres_using_helm
  sleep 10
  forward_db_port
  sleep 10
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=120s
  deploy_postgrest
  kubectl wait --for=condition=ready pod -l app=postgrest --timeout=120s
  pg_prompt
}

check_postgrest_logs() {
  kubectl logs -n default $(kubectl get pods -n default -l "app.kubernetes.io/name=postgrest" -o name)
}
aqpply_admin_user() {
  kubectl -n default apply -f admin-user.yml
}
