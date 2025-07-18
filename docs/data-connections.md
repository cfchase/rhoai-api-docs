---
layout: page
title: Data Connections
nav_order: 3
permalink: /docs/data-connections/
---

# Data Connections

Data Connections in Red Hat OpenShift AI provide secure access to external data sources and model registries. These connections enable workbenches, model serving, and pipelines to access S3-compatible object storage, model files on persistent volumes, and container registries without embedding credentials directly in your code.

## Overview

A data connection is a Kubernetes Secret with the label `opendatahub.io/dashboard: 'true'` and specific annotations that define the connection type. OpenShift AI recognizes these secrets and makes them available through the dashboard for use in:

- Jupyter workbenches (as environment variables)
- Model serving deployments
- Data science pipelines
- Direct API access for custom applications

### Connection Types

OpenShift AI supports two primary connection types:

1. **S3 Connections** (`opendatahub.io/connection-type: s3`)
   - For S3-compatible object storage (AWS S3, MinIO, OpenShift Data Foundation)
   - Used for datasets, model artifacts, pipeline storage, and model serving
   - Provides AWS-style credentials

2. **URI Connections** (`opendatahub.io/connection-type-ref: uri-v1`)
   - For storing model URIs that can be copied to InferenceService configurations
   - Supports PVC paths (`pvc://`), OCI registries (`oci://`), HTTP/HTTPS URLs
   - Provides a convenient way to manage and organize model locations
   - URI values are manually copied to `storageUri` in InferenceServices

### Required Labels and Annotations

All data connections must include:
- Label: `opendatahub.io/dashboard: 'true'` - Makes the connection visible in the dashboard
- Annotation: `openshift.io/display-name` - Human-readable name shown in the UI
- Connection type annotation - Defines how the connection is interpreted

## Creating Data Connections

### Method 1: Declarative (Using YAML)

The declarative approach is recommended for version control, automation, and reproducible deployments.

#### Basic S3 Connection

```yaml
# data-connection-s3-basic.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-s3-storage
  namespace: my-project
  labels:
    # Required: Makes connection available in OpenShift AI
    opendatahub.io/dashboard: 'true'
    # Optional: Indicates this is managed by the dashboard
    opendatahub.io/managed: 'true'
  annotations:
    # Required: Specifies this is an S3 connection
    opendatahub.io/connection-type: s3
    # Required: Display name in the dashboard
    openshift.io/display-name: My S3 Storage
type: Opaque
stringData:
  # Required: S3 access key ID
  AWS_ACCESS_KEY_ID: my-access-key
  # Required: S3 secret access key  
  AWS_SECRET_ACCESS_KEY: my-secret-key
  # Required: S3 endpoint URL
  AWS_S3_ENDPOINT: https://s3.amazonaws.com
  # Required: S3 bucket name
  AWS_S3_BUCKET: my-bucket
  # Optional: AWS region (defaults to us-east-1)
  AWS_DEFAULT_REGION: us-west-2
```

Apply the connection:
```bash
kubectl apply -f data-connection-s3-basic.yaml
```

#### Standard S3 Connection with Custom Endpoint

```yaml
# data-connection-s3-minio.yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-storage
  namespace: my-project
  labels:
    opendatahub.io/dashboard: 'true'
    opendatahub.io/managed: 'true'
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: MinIO Storage
    # Optional: Additional description
    openshift.io/description: 'Local MinIO instance for development'
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: minio
  AWS_SECRET_ACCESS_KEY: minio123
  # Custom endpoint for MinIO
  AWS_S3_ENDPOINT: https://minio-service.minio-namespace.svc.cluster.local:9000
  AWS_S3_BUCKET: ml-datasets
  AWS_DEFAULT_REGION: us-east-1
```

#### Basic URI Connection for PVC

```yaml
# data-connection-uri-pvc.yaml
apiVersion: v1
kind: Secret
metadata:
  name: model-pvc-connection
  namespace: my-project
  labels:
    opendatahub.io/dashboard: 'true'
  annotations:
    # Required: Specifies URI connection type
    opendatahub.io/connection-type-ref: uri-v1
    openshift.io/display-name: Model PVC Storage
    openshift.io/description: 'Points to models stored on PVC'
type: Opaque
stringData:
  # PVC URI format: pvc://<mount-path>/<model-path>
  URI: pvc://models/llama-2-7b-chat
```

#### URI Connection for OCI Registry

```yaml
# data-connection-uri-oci.yaml
apiVersion: v1
kind: Secret
metadata:
  name: model-registry-connection
  namespace: my-project
  labels:
    opendatahub.io/dashboard: 'true'
  annotations:
    opendatahub.io/connection-type-ref: uri-v1
    openshift.io/display-name: Red Hat Model Registry
type: Opaque
stringData:
  # OCI URI format for container registries
  URI: oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5
```

### Method 2: Imperative (Using Commands)

#### Create S3 Connection

```bash
# Create secret with S3 credentials
kubectl create secret generic my-s3-connection \
  --from-literal=AWS_ACCESS_KEY_ID=my-key \
  --from-literal=AWS_SECRET_ACCESS_KEY=my-secret \
  --from-literal=AWS_S3_ENDPOINT=https://s3.amazonaws.com \
  --from-literal=AWS_S3_BUCKET=my-bucket \
  --from-literal=AWS_DEFAULT_REGION=us-east-1 \
  -n my-project

# Add required labels and annotations
kubectl label secret my-s3-connection \
  opendatahub.io/dashboard=true \
  opendatahub.io/managed=true \
  -n my-project

kubectl annotate secret my-s3-connection \
  opendatahub.io/connection-type=s3 \
  openshift.io/display-name="My S3 Connection" \
  -n my-project
```

#### Create URI Connection

```bash
# Create secret with URI
kubectl create secret generic model-uri-connection \
  --from-literal=URI=pvc://models/my-model \
  -n my-project

# Add required labels and annotations
kubectl label secret model-uri-connection \
  opendatahub.io/dashboard=true \
  -n my-project

kubectl annotate secret model-uri-connection \
  opendatahub.io/connection-type-ref=uri-v1 \
  openshift.io/display-name="Model URI Connection" \
  -n my-project
```

## Listing and Viewing Data Connections

### List All Data Connections

```bash
# List all data connections in current namespace
kubectl get secrets -l opendatahub.io/dashboard=true

# List with more details
kubectl get secrets -l opendatahub.io/dashboard=true \
  -o custom-columns=NAME:.metadata.name,TYPE:.metadata.annotations.opendatahub\.io/connection-type,DISPLAY:.metadata.annotations.openshift\.io/display-name

# List across all namespaces
kubectl get secrets --all-namespaces -l opendatahub.io/dashboard=true
```

### View Specific Connection

```bash
# View connection details (without showing secret data)
kubectl describe secret my-s3-connection

# View connection with decoded data (be careful with credentials)
kubectl get secret my-s3-connection -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d

# View as YAML
kubectl get secret my-s3-connection -o yaml
```

### Filter Connections by Type

```bash
# List only S3 connections
kubectl get secrets -l opendatahub.io/dashboard=true \
  -o json | jq -r '.items[] | select(.metadata.annotations."opendatahub.io/connection-type" == "s3") | .metadata.name'

# List only URI connections
kubectl get secrets -l opendatahub.io/dashboard=true \
  -o json | jq -r '.items[] | select(.metadata.annotations."opendatahub.io/connection-type-ref" == "uri-v1") | .metadata.name'
```

## Updating Data Connections

### Using kubectl apply (Declarative)

Update your YAML file and reapply:

```bash
kubectl apply -f data-connection-s3-basic.yaml
```

### Using kubectl edit (Interactive)

```bash
# Edit connection interactively
kubectl edit secret my-s3-connection
```

### Using kubectl patch

#### Update S3 Credentials

```bash
# Update S3 credentials (base64 encode the values)
kubectl patch secret my-s3-connection --type='json' -p='[
  {"op": "replace", "path": "/data/AWS_ACCESS_KEY_ID", "value": "'$(echo -n "new-key" | base64)'"},
  {"op": "replace", "path": "/data/AWS_SECRET_ACCESS_KEY", "value": "'$(echo -n "new-secret" | base64)'"}
]'
```

#### Update Display Name

```bash
# Update display name annotation
kubectl annotate secret my-s3-connection \
  openshift.io/display-name="Production S3 Storage" \
  --overwrite
```

#### Add or Update S3 Endpoint

```bash
# Add new field or update existing
kubectl patch secret my-s3-connection --type='json' -p='[
  {"op": "add", "path": "/data/AWS_S3_ENDPOINT", "value": "'$(echo -n "https://new-endpoint.com" | base64)'"}
]'
```

## Deleting Data Connections

### Basic Deletion

```bash
# Delete a specific connection
kubectl delete secret my-s3-connection

# Delete multiple connections
kubectl delete secret my-s3-connection another-connection

# Delete by label selector
kubectl delete secrets -l opendatahub.io/dashboard=true,environment=dev
```

### Important Notes on Deletion

**WARNING**: Before deleting a data connection:
1. Ensure no workbenches are using the connection
2. Check that no model deployments reference the connection
3. Verify no pipelines depend on the connection
4. Consider backing up the connection configuration

### Check Connection Usage

```bash
# Check if any pods are using the S3 connection as environment variables
kubectl get pods -o json | jq -r '.items[] | select(.spec.containers[].envFrom[]?.secretRef.name == "my-s3-connection") | .metadata.name'

# Check if any InferenceServices reference S3 connections
kubectl get inferenceservices -o json | jq -r '.items[] | select(.spec.predictor.model.storage.key == "my-s3-connection") | .metadata.name'

# Note: URI connections are not directly referenced by InferenceServices
# Their values are manually copied to storageUri fields
```

## Practical Examples

### Example 1: Create S3 Connection for Dataset Storage

```yaml
# dataset-storage-connection.yaml
apiVersion: v1
kind: Secret
metadata:
  name: dataset-storage
  namespace: fraud-detection-project
  labels:
    opendatahub.io/dashboard: 'true'
    opendatahub.io/managed: 'true'
    purpose: dataset-storage
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: Fraud Detection Datasets
    openshift.io/description: 'S3 bucket containing fraud detection training data'
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: fraud-detection-key
  AWS_SECRET_ACCESS_KEY: fraud-detection-secret
  AWS_S3_ENDPOINT: https://s3.us-west-2.amazonaws.com
  AWS_S3_BUCKET: fraud-detection-datasets
  AWS_DEFAULT_REGION: us-west-2
---
# Usage in a workbench pod
apiVersion: v1
kind: Pod
metadata:
  name: data-prep-workbench
  namespace: fraud-detection-project
spec:
  containers:
  - name: jupyter
    image: quay.io/modh/odh-minimal-notebook-container:v2-2023a
    envFrom:
    # Inject all S3 credentials as environment variables
    - secretRef:
        name: dataset-storage
    env:
    # Override specific values if needed
    - name: DATA_BUCKET
      value: fraud-detection-datasets/processed
```

### Example 2: Create URI Connection for Model Serving

```yaml
# model-uri-connection.yaml
apiVersion: v1
kind: Secret
metadata:
  name: granite-model-uri
  namespace: nlp-project
  labels:
    opendatahub.io/dashboard: 'true'
    model-type: llm
    model-family: granite
  annotations:
    opendatahub.io/connection-type-ref: uri-v1
    openshift.io/display-name: Granite 3.1 8B Model
    openshift.io/description: 'Red Hat Granite model from registry'
type: Opaque
stringData:
  URI: oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5
---
# Use in InferenceService - copy URI value to storageUri
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: granite-deployment
  namespace: nlp-project
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: granite-runtime
      # Copy the URI value directly (not a reference)
      storageUri: oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5
```

### Example 3: Pipeline Artifacts Connection

```yaml
# pipeline-artifacts-connection.yaml
apiVersion: v1
kind: Secret
metadata:
  name: pipeline-artifacts
  namespace: ml-pipelines
  labels:
    opendatahub.io/dashboard: 'true'
    opendatahub.io/managed: 'true'
    component: data-science-pipelines
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: ML Pipeline Artifacts
    openshift.io/description: 'Storage for Kubeflow pipeline artifacts and metadata'
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: pipeline-access
  AWS_SECRET_ACCESS_KEY: pipeline-secret-123
  AWS_S3_ENDPOINT: https://minio-service.minio.svc.cluster.local:9000
  AWS_S3_BUCKET: mlpipeline
  AWS_DEFAULT_REGION: us-east-1
  # Additional fields for pipeline configuration
  AWS_S3_USE_PATH_STYLE: 'true'
  AWS_S3_VERIFY_SSL: 'false'  # For self-signed certificates
```

## Verification and Troubleshooting

### Verify Connection Visibility

```bash
# Check if connection appears in dashboard list
kubectl get secret my-s3-connection -o jsonpath='{.metadata.labels.opendatahub\.io/dashboard}'

# Verify required annotations
kubectl get secret my-s3-connection -o jsonpath='{.metadata.annotations}' | jq
```

### Test S3 Connection

```bash
# Create a test pod with AWS CLI
kubectl run s3-test --rm -i --tty --image=amazon/aws-cli:latest \
  --env-from=secret/my-s3-connection \
  --command -- /bin/bash

# Inside the pod, test the connection
aws s3 ls s3://$AWS_S3_BUCKET --endpoint-url $AWS_S3_ENDPOINT
```

### Common Issues and Solutions

#### Connection Not Visible in Dashboard

```bash
# Check label is exactly 'true' (string, not boolean)
kubectl get secret my-s3-connection -o yaml | grep "opendatahub.io/dashboard"

# Fix incorrect label
kubectl label secret my-s3-connection opendatahub.io/dashboard=true --overwrite
```

#### Invalid Credentials Error

```bash
# Verify credentials are base64 encoded correctly
kubectl get secret my-s3-connection -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d

# Re-encode and update if needed
echo -n "correct-access-key" | base64
# Then update using kubectl patch or edit
```

#### Connection Type Not Recognized

```bash
# Ensure annotation uses correct key and value
kubectl annotate secret my-s3-connection \
  opendatahub.io/connection-type=s3 --overwrite

# For URI connections, use different annotation
kubectl annotate secret my-uri-connection \
  opendatahub.io/connection-type-ref=uri-v1 --overwrite
```

#### Debugging Connection Usage

```bash
# Find all resources using a specific connection
kubectl get all -o json | jq -r '.. | objects | select(.secretRef?.name == "my-s3-connection" or .valueFrom?.secretKeyRef?.name == "my-s3-connection") | "\(.kind)/\(.metadata.name)"' 2>/dev/null | sort -u
```

## Best Practices

### Secure Credential Management

1. **Never commit credentials to version control**
   ```yaml
   # Use environment variables or external secret management
   stringData:
     AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}  # Set via CI/CD
     AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
   ```

2. **Use separate connections per environment**
   ```bash
   # Development
   kubectl apply -f connections/dev-s3-connection.yaml -n dev-project
   
   # Production  
   kubectl apply -f connections/prod-s3-connection.yaml -n prod-project
   ```

3. **Implement least-privilege access**
   - Create S3 policies that only grant necessary permissions
   - Use separate credentials for different purposes

### Naming Conventions

1. **Use descriptive names indicating purpose**
   - Good: `training-data-s3`, `model-artifacts-storage`
   - Avoid: `s3-connection-1`, `my-connection`

2. **Include environment in name**
   - `dev-dataset-storage`
   - `prod-model-registry`

3. **Use consistent prefixes for grouping**
   - `dataset-` (for training/test datasets)
   - `model-` (for model storage and serving)
   - `experiment-` (for experiment tracking)

### When to Use Each Connection Type

**Use S3 Connections for:**
- Training datasets
- Model artifacts and checkpoints
- Model serving (loading models from S3 buckets)
- Pipeline intermediate results
- Experiment tracking data
- General file storage

**Use URI Connections for:**
- Storing and organizing model URIs in the OpenShift AI dashboard
- Managing references to models in PVCs (`pvc://`)
- Managing references to models in container registries (`oci://`)
- Creating a catalog of available models for easy reference

### Using URI Connections

Unlike S3 connections which provide credentials, URI connections simply store URI values that can be:
1. Viewed in the OpenShift AI dashboard for reference
2. Manually copied into InferenceService `storageUri` fields
3. Used as documentation for available model locations

**Note**: URI connections are not automatically injected or referenced by InferenceServices. The URI value must be manually copied to the appropriate configuration.

### Integration with Workbenches

1. **Environment variable injection**
   ```yaml
   # Workbench automatically receives all secret fields as env vars
   envFrom:
   - secretRef:
       name: my-s3-connection
   ```

2. **Custom environment mapping**
   ```yaml
   # Map to specific variable names
   env:
   - name: TRAINING_DATA_BUCKET
     valueFrom:
       secretKeyRef:
         name: dataset-storage
         key: AWS_S3_BUCKET
   ```

## Field Reference

### S3 Connection Fields

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| AWS_ACCESS_KEY_ID | string | Yes | S3 access key identifier | `AKIAIOSFODNN7EXAMPLE` |
| AWS_SECRET_ACCESS_KEY | string | Yes | S3 secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| AWS_S3_ENDPOINT | string | Yes | S3 endpoint URL | `https://s3.amazonaws.com` |
| AWS_S3_BUCKET | string | Yes | S3 bucket name | `my-ml-datasets` |
| AWS_DEFAULT_REGION | string | No | AWS region (default: us-east-1) | `us-west-2` |
| AWS_S3_USE_PATH_STYLE | string | No | Use path-style URLs | `true` or `false` |
| AWS_S3_VERIFY_SSL | string | No | Verify SSL certificates | `true` or `false` |

### URI Connection Fields

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| URI | string | Yes | Model or resource URI | `pvc://models/llama-2-7b` |

### Common Annotations

| Annotation | Type | Required | Description | Example |
|------------|------|----------|-------------|---------|
| opendatahub.io/connection-type | string | For S3 | Specifies S3 connection | `s3` |
| opendatahub.io/connection-type-ref | string | For URI | Specifies URI connection | `uri-v1` |
| openshift.io/display-name | string | Yes | Human-readable name | `Production Dataset Storage` |
| openshift.io/description | string | No | Extended description | `S3 bucket for production ML datasets` |

## Using with Kubernetes MCP Server

The MCP Kubernetes server provides tools for managing secrets but has limitations for data connections.

### MCP Tool Mapping

| Operation | MCP Tool | Notes |
|-----------|----------|-------|
| Create Secret | `resources_create_or_update` | Requires base64 encoding |
| List Secrets | `resources_list` | Can filter by labels |
| Get Secret | `resources_get` | Returns base64 encoded data |
| Update Secret | `resources_create_or_update` | Full replacement |
| Delete Secret | `resources_delete` | Standard deletion |

### Creating Data Connections with MCP

```yaml
# Note: stringData is not supported, must use base64 encoded data
apiVersion: v1
kind: Secret
metadata:
  name: mcp-s3-connection
  namespace: my-project
  labels:
    opendatahub.io/dashboard: 'true'
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: MCP S3 Connection
type: Opaque
data:
  # Values must be base64 encoded
  AWS_ACCESS_KEY_ID: bXktYWNjZXNzLWtleQ==
  AWS_SECRET_ACCESS_KEY: bXktc2VjcmV0LWtleQ==
  AWS_S3_ENDPOINT: aHR0cHM6Ly9zMy5hbWF6b25hd3MuY29t
  AWS_S3_BUCKET: bXktYnVja2V0
  AWS_DEFAULT_REGION: dXMtZWFzdC0x
```

### Listing Data Connections with MCP

Use `resources_list` with label selector:
```
apiVersion: v1
kind: Secret
labelSelector: opendatahub.io/dashboard=true
namespace: my-project
```

### Getting a Specific Connection

Use `resources_get`:
```
apiVersion: v1
kind: Secret
name: my-s3-connection
namespace: my-project
```

### Updating Connections with MCP

MCP requires full resource replacement:
1. Get current connection with `resources_get`
2. Modify the YAML
3. Apply with `resources_create_or_update`

### Deleting Connections with MCP

Use `resources_delete`:
```
apiVersion: v1
kind: Secret
name: my-s3-connection
namespace: my-project
```

### MCP Limitations

1. **No stringData support** - Must base64 encode all values manually
2. **No patch operations** - Must replace entire resource
3. **No imperative commands** - Cannot use simple create/label/annotate workflow
4. **Limited filtering** - Basic label selection only

### Best Practices for MCP

1. **Prepare base64 values externally**
   ```bash
   echo -n "my-access-key" | base64
   ```

2. **Use templates for consistency**
   - Create template YAML files
   - Replace only the base64 encoded values

3. **Verify with native kubectl**
   - After MCP operations, verify with kubectl
   - Check dashboard visibility

## Related Resources

- [OpenShift AI Documentation - Data Connections](https://docs.redhat.com/en/documentation/red_hat_openshift_ai/latest/html/working_with_data_connections)
- [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [AWS S3 Environment Variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
- [KServe Storage Spec](https://kserve.github.io/website/latest/modelserving/storage/)