#!/bin/bash

CLUSTER_NAME="wonderful-poc"
DB_PASSWORD="mysecretpassword"

install_utils() {
    brew install k3d helm kubectl helmfile
}

open_docker() {
    open -a docker
}

create_cluster() {
    k3d cluster create ${CLUSTER_NAME} \
        --port '5432:30000@loadbalancer' \
        --port '3000:30001@loadbalancer'
}

get_cluster_info() {
    kubectl cluster-info
}

configure_helm() { (
    helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update
); }

# Remove or comment out the PV and PVC creation functions
# create_persistent_volume() { ... }
# create_persistent_volume_claim() { ... }

install_postgres_using_helm() {
    (
        helm install pg bitnami/postgresql \
            --set primary.persistence.storageClass="local-path" \
            --set primary.persistence.size="5Gi" \
            --set auth.postgresPassword=${DB_PASSWORD}
    )
}

forward_db_port() {
    kubectl port-forward --namespace default svc/pg-postgresql 5432:5432 &
}

pg_prompt() {
    export POSTGRES_PASSWORD=$(kubectl get secret --namespace default pg-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
    export PGPASSWORD="$POSTGRES_PASSWORD"
    psql --host 127.0.0.1 -U postgres -d postgres -p 5432
}

cleanup_experiment() {
    # Uninstall the PostgreSQL Helm release
    helm uninstall pg

    # Delete the PostgREST deployment and service
    kubectl delete deployment postgrest
    kubectl delete service postgrest

    # Delete any PVCs created by the Helm chart
    kubectl delete pvc -l app.kubernetes.io/instance=pg

    # Delete the Kubernetes cluster
    k3d cluster delete ${CLUSTER_NAME}
}

set_up_experiment() {
    create_cluster
    configure_helm
    install_postgres_using_helm
    sleep 10
    forward_db_port
    sleep 10
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=120s
    # Deploy PostgREST
    deploy_postgrest
    # Wait for PostgREST to be ready
    kubectl wait --for=condition=ready pod -l app=postgrest --timeout=120s
    pg_prompt
}

deploy_postgrest() {
    # Create the deployment
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgrest
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgrest
  template:
    metadata:
      labels:
        app: postgrest
    spec:
      containers:
      - name: postgrest
        image: postgrest/postgrest:latest
        env:
        - name: PGRST_DB_URI
          value: "postgres://postgres:${DB_PASSWORD}@pg-postgresql.default.svc.cluster.local:5432/postgres"
        - name: PGRST_DB_SCHEMA
          value: "public"
        - name: PGRST_DB_ANON_ROLE
          value: "web_anon"
        ports:
        - containerPort: 3000
EOF

    # Create the service
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: postgrest
spec:
  type: NodePort
  selector:
    app: postgrest
  ports:
  - protocol: TCP
    port: 3000
    targetPort: 3000
    nodePort: 30001
EOF
}
