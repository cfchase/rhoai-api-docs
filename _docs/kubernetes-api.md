---
layout: page
title: Kubernetes API Basics
permalink: /docs/kubernetes-api/
---

# Kubernetes API Basics for OpenShift AI

Understanding how OpenShift AI integrates with Kubernetes APIs is essential for managing data science workloads programmatically.

## OpenShift AI Custom Resource Definitions

OpenShift AI extends Kubernetes with several custom resources organized under different API groups:

### Core API Groups

- **`opendatahub.io/v1`** - Main OpenShift AI resources
- **`kubeflow.org/v1`** - Notebook and pipeline resources
- **`serving.kserve.io/v1beta1`** - Model serving resources (including ModelCars)
- **`ray.io/v1`** - Ray cluster resources for distributed computing

## Primary Resources

### DataScienceCluster

The main configuration resource for OpenShift AI installations.

```yaml
apiVersion: opendatahub.io/v1
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    dashboard:
      managementState: Managed
    workbenches:
      managementState: Managed
    modelmeshserving:
      managementState: Managed
    kserve:
      managementState: Managed
    modelregistry:
      managementState: Managed
```

**Key Operations:**
```bash
# View current configuration
oc get datasciencecluster default-dsc -o yaml

# List all DataScienceClusters
oc get datasciencecluster -A
```

### Notebooks (Workbenches)

Jupyter notebook instances for interactive data science work.

```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: my-workbench
  namespace: my-project
spec:
  template:
    spec:
      containers:
      - name: my-workbench
        image: quay.io/opendatahub/workbench-images:jupyter-datascience-notebook
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        volumeMounts:
        - name: workbench-storage
          mountPath: /opt/app-root/src
      volumes:
      - name: workbench-storage
        persistentVolumeClaim:
          claimName: my-workbench-pvc
```

**Management Commands:**
```bash
# Create a notebook
oc apply -f notebook.yaml

# List notebooks in current namespace
oc get notebooks

# Get notebook details
oc describe notebook my-workbench

# Delete a notebook
oc delete notebook my-workbench
```

### ModelCars

Simplified model serving using KServe infrastructure.

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: my-model
  namespace: my-project
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      runtime: kserve-sklearnserver
      storage:
        uri: s3://my-bucket/models/sklearn-model/
```

**Basic Operations:**
```bash
# Deploy a ModelCar
oc apply -f modelcar.yaml

# Check serving status
oc get modelcar my-model

# View detailed status
oc describe modelcar my-model

# Get prediction endpoint
oc get route my-model-predictor
```

## API Interaction Patterns

### Using kubectl/oc

**Basic CRUD Operations:**
```bash
# Create resources
oc apply -f resource.yaml

# Read resources
oc get <resource-type> [name]
oc describe <resource-type> <name>

# Update resources
oc patch <resource-type> <name> --patch '{"spec":{"key":"value"}}'
oc edit <resource-type> <name>

# Delete resources
oc delete <resource-type> <name>
```

### Using the Kubernetes API Directly

**REST API Endpoints:**
```bash
# Get API server URL
APISERVER=$(oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Get auth token
TOKEN=$(oc whoami -t)

# List ModelCars via API
curl -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/json" \
     "$APISERVER/apis/serving.kserve.io/v1beta1/namespaces/my-project/modelcars"
```

## Resource Relationships

### Typical Workflow Dependencies

1. **DataScienceCluster** - Cluster-wide configuration
2. **Namespace/Project** - Logical grouping
3. **Notebook** - Development environment
4. **PVC** - Persistent storage for data and models
5. **ModelCar** - Model deployment
6. **Route/Service** - External access

### Example Resource Chain

```bash
# 1. Create namespace
oc new-project ml-project

# 2. Create storage
oc apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: model-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# 3. Deploy notebook for development
oc apply -f notebook.yaml

# 4. Deploy trained model
oc apply -f modelcar.yaml
```

## Common API Patterns

### Status Checking

Most OpenShift AI resources provide status information:

```bash
# Check overall status
oc get notebook my-workbench -o jsonpath='{.status.conditions}'

# Watch for changes
oc get modelcar my-model --watch

# Get detailed status
oc describe modelcar my-model | grep -A 10 "Status:"
```

### Label and Annotation Usage

OpenShift AI uses labels and annotations for organization:

```yaml
metadata:
  labels:
    opendatahub.io/dashboard: "true"
    app.kubernetes.io/part-of: "my-ml-project"
  annotations:
    opendatahub.io/image-display-name: "My Data Science Image"
```

### Resource Quotas and Limits

Control resource usage in your namespace:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ml-compute-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    count/notebooks.kubeflow.org: "5"
    count/modelcars.serving.kserve.io: "10"
```

## Best Practices

### Resource Naming

- Use descriptive names that include purpose
- Follow kebab-case convention
- Include environment indicators when appropriate

### Configuration Management

- Store configurations in Git
- Use Kustomize for environment-specific variations
- Implement proper secret management

### Monitoring and Observability

```bash
# Check resource events
oc get events --sort-by='.lastTimestamp'

# Monitor resource usage
oc top pods

# View logs
oc logs deployment/my-model-predictor
```

## Next Steps

- [ModelCar Serving Guide](modelcar-serving) - Deep dive into model deployment
- [Complete Examples](examples) - Real-world configurations and scenarios