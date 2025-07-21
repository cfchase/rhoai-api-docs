---
layout: page
title: Serving Large Language Models (LLMs)
parent: Serving
nav_order: 1
permalink: /docs/serving/llms/
---

# Serving Large Language Models (LLMs)

Red Hat OpenShift AI provides a comprehensive solution for deploying and serving Large Language Models (LLMs) at scale. Using the KServe infrastructure, you can deploy models from various storage sources including pre-built ModelCars (OCI registries), S3-compatible storage, and Persistent Volume Claims (PVCs).

**Quick Start**: This guide begins with a [complete working example](#complete-working-example) that deploys a Granite 3.1 8B model on a single GPU with external access. After showing this full example, we explain each component in detail and provide additional deployment patterns.

## Overview

A complete model serving deployment in OpenShift AI consists of three key resources working together:

1. **ServingRuntime**: Defines HOW models are served
   - Specifies the serving container (e.g., vLLM, Triton, MLServer)
   - Configures runtime parameters and environment
   - Sets hardware acceleration annotations and model serving arguments

2. **InferenceService**: Defines WHAT model to serve
   - References the ServingRuntime to use
   - Specifies the model location (storageUri or storage)
   - Controls deployment parameters (replicas, resources, tolerations)
   - Manages the model lifecycle

3. **Route** (Optional): Provides external access
   - Exposes the model endpoint outside the cluster
   - Configures TLS termination
   - Enables secure external access

These resources must be created together to deploy a functional model serving endpoint. **Important**: The ServingRuntime and InferenceService names MUST match exactly - this is a requirement for the OpenShift AI dashboard to properly display and manage the model deployment. Together they create the pods, services, and other Kubernetes resources needed to serve your model.

## Important: Naming Convention

**The ServingRuntime and InferenceService names MUST be identical.** This is a critical requirement for the OpenShift AI dashboard to properly:
- Display the model deployment
- Show serving runtime details
- Enable management features
- Link the resources correctly

For example, if your InferenceService is named `granite-model`, then your ServingRuntime must also be named `granite-model`. This naming convention is enforced throughout all examples in this guide.

### Template Variables in ServingRuntime

OpenShift AI provides template variables that get replaced at runtime with values from the InferenceService:

- `{{.Name}}` - The name of the InferenceService
- Common usage: `--served-model-name={{.Name}}` in vLLM args

This ensures the model server uses the same name as the InferenceService, maintaining consistency across the deployment.

## Prerequisites

Before deploying models with ModelCars, ensure you have:

1. **OpenShift AI cluster** with appropriate permissions
2. **GPU nodes** (if using GPU-accelerated models)
3. **CLI tools**: `kubectl` or `oc` installed and configured
4. **Namespace access**: Create or use an existing namespace for deployments
5. **NVIDIA GPU operator** installed (for GPU workloads)

### Checking Available AcceleratorProfiles

AcceleratorProfiles define GPU configurations available in your cluster. While optional, understanding available profiles helps configure proper GPU resource requests and node tolerations.

#### List AcceleratorProfiles

```bash
# List all accelerator profiles
kubectl get acceleratorprofiles -n redhat-ods-applications

# Example output:
NAME           DISPLAY NAME    ENABLED   IDENTIFIER        TOLERATIONS
migrated-gpu   NVIDIA GPU      true      nvidia.com/gpu    1 toleration(s)
nvidia-a100    NVIDIA A100     true      nvidia.com/gpu    1 toleration(s)
```

#### View Specific AcceleratorProfile

```bash
# Get detailed profile information
kubectl get acceleratorprofile migrated-gpu -n redhat-ods-applications -o yaml

# Or use describe for a summary
kubectl describe acceleratorprofile migrated-gpu -n redhat-ods-applications
```

Example AcceleratorProfile:
```yaml
apiVersion: dashboard.opendatahub.io/v1
kind: AcceleratorProfile
metadata:
  name: migrated-gpu
  namespace: redhat-ods-applications
spec:
  displayName: "NVIDIA GPU"
  enabled: true
  identifier: nvidia.com/gpu      # GPU resource identifier
  tolerations:                     # Node scheduling tolerations
  - effect: NoSchedule
    key: nvidia.com/gpu
    operator: Exists
```

#### Extract Configuration for Model Deployment

From the AcceleratorProfile, note:
- **identifier**: Use in `resources.requests` and `resources.limits` (e.g., `nvidia.com/gpu: '1'`)
- **tolerations**: Copy to your InferenceService spec for proper node scheduling

If no AcceleratorProfiles exist, you can still deploy models by manually specifying GPU resources and tolerations based on your cluster configuration.

## Storage Options for LLMs

OpenShift AI supports three primary storage methods for serving LLMs. Each method has specific use cases and configuration requirements:

### 1. ModelCars (OCI Registry)

Pre-built, optimized container images from Red Hat's registry or other OCI-compliant registries.

**When to use:**
- Quick deployment of Red Hat validated models
- Models that are pre-optimized and containerized
- When you don't need to modify model files

**Configuration:**
```yaml
spec:
  predictor:
    model:
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5'
```

**See examples:**
- [Complete Working Example](#complete-working-example) - Full deployment with GPU and external access
- [Examples 1-4](#example-1-custom-vllm-arguments) - All use ModelCar storage

### 2. S3-Compatible Storage

Models stored in S3-compatible object storage (AWS S3, MinIO, OpenShift Data Foundation).

**When to use:**
- Models stored in object storage
- When you need to share models across multiple deployments
- Integration with existing S3 infrastructure

**Configuration:**
```yaml
spec:
  predictor:
    model:
      storage:
        key: aws-connection-my-storage  # Name of your S3 data connection
        path: models/granite-7b-instruct/  # Path within the S3 bucket
```

**Prerequisites:**
- Create an S3 data connection in your namespace (see [Data Connections](/docs/data-connections/))
- Ensure the model files are uploaded to the specified S3 path

**See example:**
- [Example 5: S3 Storage Deployment](#example-5-s3-storage-deployment)

### 3. Persistent Volume Claims (PVC)

Models stored on Kubernetes persistent volumes.

**When to use:**
- Models already available on shared storage
- When you need ReadWriteMany (RWX) access
- Custom model files or modified versions

**Configuration:**
```yaml
spec:
  predictor:
    model:
      storageUri: 'pvc://model-pvc/llama-3.1-8b-instruct'  # pvc://<pvc-name>/<model-path>
```

**Prerequisites:**
- PVC must exist in the same namespace
- Model files must be copied to the PVC (see [Setting Up PVCs for Model Storage](/docs/extras/model-pvc-setup/))

**See example:**
- [Example 6: PVC Storage Deployment](#example-6-pvc-storage-deployment)

### Choosing a Storage Method

| Storage Type | Best For | Pros | Cons |
|-------------|----------|------|------|
| **ModelCars (OCI)** | Production deployments | Pre-optimized, versioned, easy to deploy | Limited to available images |
| **S3 Storage** | Shared models, cloud environments | Centralized storage, easy updates | Requires S3 setup, potential latency |
| **PVC Storage** | Custom models, on-premise | Full control, no external dependencies | Requires PVC management, manual uploads |

## Creating Model Deployments

Model deployments require creating both a ServingRuntime and InferenceService. Optionally, you can also create a Route for external access. The resources should be created in order: ServingRuntime → InferenceService → Route.

**Important for External Access**: To expose your model externally with a Route, you MUST add the label `networking.kserve.io/visibility: exposed` to your InferenceService. Without this label, the service will only be accessible internally within the cluster.

### Complete Working Example

Here's a complete example that deploys a Granite 3.1 8B model on a single GPU with external access. This example includes all the essential configurations for a production-ready deployment:

**1. ServingRuntime** (`granite-model-runtime.yaml`):
```yaml
# granite-model-runtime.yaml - defines HOW to serve the model
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: granite-model  # Must match InferenceService name
  annotations:
    opendatahub.io/accelerator-name: migrated-gpu  # GPU accelerator profile
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'  # Compatible GPU types
  labels:
    opendatahub.io/dashboard: 'true'  # Show in OpenShift AI dashboard
spec:
  containers:
    - name: kserve-container
      image: 'quay.io/modh/vllm:rhoai-2.20-cuda'  # vLLM serving image with CUDA support
      args:
        - '--port=8080'                          # Server port
        - '--model=/mnt/models'                  # Model mount path
        - '--served-model-name={{.Name}}'        # Use InferenceService name
        - '--max-model-len=4096'                 # Maximum context length
      volumeMounts:
        - mountPath: /dev/shm        # Shared memory mount for GPU performance
          name: shm
  volumes:
    - name: shm                      # Shared memory volume for GPU operations
      emptyDir:
        medium: Memory
        sizeLimit: 2Gi
  supportedModelFormats:
    - name: vLLM
      autoSelect: true               # Automatically select this runtime for vLLM models
```

**2. InferenceService** (`granite-model-service.yaml`):
```yaml
# granite-model-service.yaml - defines WHAT model to serve
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: granite-model
  annotations:
    openshift.io/display-name: 'Granite 3.1 8B Instruct'  # Human-readable name
  labels:
    opendatahub.io/dashboard: 'true'                      # Show in dashboard
    networking.kserve.io/visibility: exposed               # REQUIRED for external Route
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM                                         # Model format (must match runtime)
      runtime: granite-model                               # Reference to ServingRuntime
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5'  # Model location
      resources:
        requests:
          cpu: '2'                                         # CPU request
          memory: 16Gi                                     # Memory request
          nvidia.com/gpu: '1'                              # GPU request
        limits:
          cpu: '4'                                         # CPU limit
          memory: 24Gi                                     # Memory limit
          nvidia.com/gpu: '1'                              # GPU limit (must match runtime)
    tolerations:                                           # Node scheduling tolerations
      - effect: NoSchedule
        key: nvidia.com/gpu
        operator: Exists                                   # Schedule on GPU nodes
```

**3. Route** (`granite-model-route.yaml`):
```yaml
# granite-model-route.yaml - provides external HTTPS access
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: granite-model
  labels:
    inferenceservice-name: granite-model                   # Links to InferenceService
spec:
  to:
    kind: Service
    name: granite-model-predictor                          # Auto-created service name
    weight: 100
  port:
    targetPort: http
  tls:                                                     # TLS configuration
    termination: edge                                      # TLS terminated at router
    insecureEdgeTerminationPolicy: Redirect                # Force HTTPS
  wildcardPolicy: None
```

**Deploy the complete example:**
```bash
# 1. Create ServingRuntime first
kubectl apply -f granite-model-runtime.yaml -n my-namespace

# 2. Create InferenceService
kubectl apply -f granite-model-service.yaml -n my-namespace

# 3. Wait for the model to be ready (this may take several minutes)
kubectl wait --for=condition=Ready inferenceservice/granite-model --timeout=600s -n my-namespace

# 4. Create the Route for external access
kubectl apply -f granite-model-route.yaml -n my-namespace

# 5. Get the external URL
ROUTE_URL=$(kubectl get route granite-model -n my-namespace -o jsonpath='{.spec.host}')
echo "Model endpoint available at: https://$ROUTE_URL/v2/models/granite-model"

# 6. Test the deployment
curl -X POST "https://$ROUTE_URL/v2/models/granite-model/infer" \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [{"name": "text_input", "shape": [1], "datatype": "BYTES", "data": ["What is machine learning?"]}],
    "parameters": {"temperature": 0.7, "max_tokens": 100}
  }'
```

### Understanding the Example

This complete example demonstrates:

1. **GPU Configuration**: The model is configured to run on a single NVIDIA GPU with proper resource allocation and node tolerations
2. **Memory Optimization**: Includes shared memory volume for better GPU performance
3. **Model Parameters**: Sets context length and GPU memory utilization for optimal performance
4. **External Access**: The Route provides secure HTTPS access to the model endpoint
5. **Dashboard Integration**: Both resources are visible in the OpenShift AI dashboard

The following sections explain each component and configuration option in detail.

### Key Components Explained

The complete example above contains all the essential elements for a production deployment. Let's break down each component:

#### GPU and Hardware Acceleration

GPU support requires three key configurations:

1. **Accelerator Annotations** (in ServingRuntime):
   ```yaml
   annotations:
     opendatahub.io/accelerator-name: migrated-gpu
     opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
   ```

2. **Resource Requests/Limits** (in InferenceService only):
   ```yaml
   resources:
     requests:
       nvidia.com/gpu: '1'
     limits:
       nvidia.com/gpu: '1'
   ```

3. **Node Tolerations** (in InferenceService):
   ```yaml
   tolerations:
     - effect: NoSchedule
       key: nvidia.com/gpu
       operator: Exists
   ```

**See also:**
- [Example 4: Single Node, Multi GPU](#example-4-single-node-multi-gpu) - Multi-GPU with tensor parallelism

#### Memory and Performance Optimization

Shared memory volumes improve GPU performance by allowing efficient inter-process communication:

```yaml
# In ServingRuntime spec:
volumes:
  - name: shm
    emptyDir:
      medium: Memory
      sizeLimit: 2Gi        # Increase for larger models

# In ServingRuntime container:
volumeMounts:
  - mountPath: /dev/shm
    name: shm
```

**Why shared memory matters:**
- Enables efficient GPU kernel operations
- Required for tensor parallelism
- Improves model loading and inference speed

**See also:**
- [Example 4: Single Node, Multi GPU](#example-4-single-node-multi-gpu) - Uses 32Gi shared memory for large models

#### Model-Specific Arguments

vLLM arguments are specified in the ServingRuntime container args. Common configurations:

```yaml
# In ServingRuntime container args:
args:
  - '--port=8080'                    # Required: serving port
  - '--model=/mnt/models'            # Required: model mount path
  - '--served-model-name={{.Name}}'  # Use InferenceService name
  - '--max-model-len=4096'           # Context window size
```

**Common argument patterns:**
- **Small models (7-8B)**: `--max-model-len=4096`
- **Large models (70B+)**: `--max-model-len=8192`, `--tensor-parallel-size=4`, `--distributed-executor-backend=mp`
- **Production**: Consider resource limits and autoscaling

**Important**: When using `--tensor-parallel-size` greater than 1, you must also include `--distributed-executor-backend=mp`

**See also:**
- [Example 1: Custom vLLM Arguments](#example-1-custom-vllm-arguments) - Various configurations
- [Example 4: Single Node, Multi GPU](#example-4-single-node-multi-gpu) - Multi-GPU specific arguments

#### Monitoring and Observability

Enable Prometheus metrics collection for monitoring:

```yaml
# In ServingRuntime metadata.annotations:
annotations:
  prometheus.io/scrape: 'true'
  prometheus.io/path: /metrics
  prometheus.io/port: '8080'

# In InferenceService metadata.annotations:
annotations:
  serving.kserve.io/enable-prometheus-scraping: 'true'
```

**Metrics available:**
- Request latency and throughput
- GPU utilization
- Model loading time
- Token generation speed

#### Display Names and Dashboard Integration

Make your deployments easily identifiable:

```yaml
# In metadata.annotations:
annotations:
  openshift.io/display-name: 'Granite 3.1 8B Instruct'

# In metadata.labels:
labels:
  opendatahub.io/dashboard: 'true'  # Required for dashboard visibility
```

**Dashboard features enabled:**
- Model deployment status
- Endpoint URLs
- Resource usage monitoring
- Log access

### Minimal Configuration

If you need a minimal deployment with basic GPU support:

**Minimal ServingRuntime:**
```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: minimal-model
  annotations:
    opendatahub.io/accelerator-name: migrated-gpu
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  containers:
    - name: kserve-container
      image: 'quay.io/modh/vllm:rhoai-2.20-cuda'
      args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
  supportedModelFormats:
    - name: vLLM
      autoSelect: true
```

**Minimal InferenceService:**
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: minimal-model
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: minimal-model
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5'
      resources:
        requests:
          memory: 16Gi
          nvidia.com/gpu: '1'
        limits:
          memory: 24Gi
          nvidia.com/gpu: '1'
    tolerations:
      - effect: NoSchedule
        key: nvidia.com/gpu
        operator: Exists
```

**Note**: This minimal configuration includes basic GPU support. For a complete example with external access and optimizations, see the [Complete Working Example](#complete-working-example) above.

## Runtime Images and Hardware Support

The examples above use `quay.io/modh/vllm:rhoai-2.20-cuda` for NVIDIA GPUs. OpenShift AI provides different runtime images for various architectures:

- **NVIDIA GPUs**: `quay.io/modh/vllm:rhoai-2.20-cuda`
- **AMD GPUs**: `quay.io/modh/vllm:rhoai-2.20-rocm`
- **Intel Habana**: `quay.io/modh/vllm:rhoai-2.20-gaudi`
- **CPU only**: `quay.io/modh/vllm:rhoai-2.20-cpu` (Note: CPU-only runtimes are primarily provided for ppc64le and s390x architectures)

Example deployment for AMD GPUs:

**ServingRuntime** (`amd-model-runtime.yaml`):
```yaml
# amd-model-runtime.yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: amd-model  # Must match InferenceService name
  annotations:
    # AMD GPU-specific accelerator type
    opendatahub.io/recommended-accelerators: '["amd.com/gpu"]'  # AMD instead of NVIDIA
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  containers:
    - name: kserve-container
      # ROCm-specific image for AMD GPU support
      image: 'quay.io/modh/vllm:rhoai-2.20-rocm'  # ROCm instead of CUDA
      args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
      command:
        - python
        - '-m'
        - vllm.entrypoints.openai.api_server
  supportedModelFormats:
    - name: vLLM
      autoSelect: true
```

**InferenceService** (`amd-model-service.yaml`):
```yaml
# amd-model-service.yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: amd-model
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: amd-model
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5'
      resources:
        requests:
          memory: 16Gi
          amd.com/gpu: '1'  # AMD GPU resource identifier
        limits:
          memory: 24Gi
          amd.com/gpu: '1'  # AMD GPU resource identifier
```

Deploy AMD GPU model:
```bash
kubectl apply -f amd-model-runtime.yaml
kubectl apply -f amd-model-service.yaml
```


## Listing and Viewing Model Deployments

### List All Model Deployments

List all InferenceServices (the primary resource representing model deployments):

```bash
# List all InferenceServices in current namespace
kubectl get inferenceservices

# List with more details
kubectl get inferenceservices -o wide

# List across all namespaces
kubectl get inferenceservices --all-namespaces

# Custom output showing key fields
kubectl get inferenceservices -o custom-columns=\
NAME:.metadata.name,\
RUNTIME:.spec.predictor.model.runtime,\
MODEL:.spec.predictor.model.storageUri,\
READY:.status.conditions[?(@.type=='Ready')].status,\
URL:.status.url
```

### List Associated Resources

```bash
# List all ServingRuntimes
kubectl get servingruntimes

# List Routes for external access
kubectl get routes -l inferenceservice-name

# List all resources for a specific model deployment
MODEL_NAME="granite-model"
kubectl get servingruntime,inferenceservice,route,service,deployment,pod \
  -l serving.kserve.io/inferenceservice=$MODEL_NAME
```

### View Specific Model Deployment

```bash
# View InferenceService details
kubectl describe inferenceservice granite-model

# Get InferenceService in YAML format
kubectl get inferenceservice granite-model -o yaml

# View ServingRuntime details
kubectl describe servingruntime granite-runtime

# Check deployment status
kubectl get inferenceservice granite-model -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

### Filter Model Deployments

```bash
# Filter by label
kubectl get inferenceservices -l environment=production


# List deployments using specific runtime
RUNTIME="granite-runtime"
kubectl get inferenceservices -o json | \
  jq --arg runtime "$RUNTIME" '.items[] | select(.spec.predictor.model.runtime == $runtime) | .metadata.name'

# List GPU-enabled deployments
kubectl get inferenceservices -o json | \
  jq '.items[] | select(.spec.predictor.model.resources.requests["nvidia.com/gpu"] != null) | .metadata.name'
```

## Updating Model Deployments

Model deployments can be updated to change models, adjust resources, or modify configurations. Updates should be done carefully to minimize downtime.

### Update Model Version

```bash
# Update to a new model version
kubectl patch inferenceservice granite-model --type='json' -p='[
  {"op": "replace", "path": "/spec/predictor/model/storageUri", 
   "value": "oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.6"}
]'

# Or using kubectl set (if supported)
kubectl set env inferenceservice/granite-model \
  STORAGE_URI=oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.6
```

### Scale Model Deployment

```bash
# Update replica count
kubectl patch inferenceservice granite-model --type='merge' -p='
{
  "spec": {
    "predictor": {
      "minReplicas": 2,
      "maxReplicas": 5
    }
  }
}'

# Enable autoscaling
kubectl patch inferenceservice granite-model --type='merge' -p='
{
  "spec": {
    "predictor": {
      "minReplicas": 1,
      "maxReplicas": 10,
      "scaleTarget": 80,
      "scaleMetric": "cpu"
    }
  }
}'
```

### Update Resource Allocations

```bash
# Increase memory and CPU
kubectl patch inferenceservice granite-model --type='merge' -p='
{
  "spec": {
    "predictor": {
      "model": {
        "resources": {
          "requests": {
            "cpu": "4",
            "memory": "32Gi"
          },
          "limits": {
            "cpu": "8",
            "memory": "48Gi"
          }
        }
      }
    }
  }
}'
```

### Update ServingRuntime Configuration

```bash
# Update runtime arguments
kubectl patch servingruntime granite-runtime --type='json' -p='[
  {"op": "replace", "path": "/spec/containers/0/args", 
   "value": ["--port=8080", "--model=/mnt/models", "--tensor-parallel-size=2", "--distributed-executor-backend=mp", "--max-model-len=8192"]}
]'

# Update container image
kubectl patch servingruntime granite-runtime --type='merge' -p='
{
  "spec": {
    "containers": [{
      "name": "kserve-container",
      "image": "quay.io/modh/vllm:rhoai-2.21-cuda"
    }]
  }
}'
```


### Update Route Configuration

```bash
# Update TLS configuration
kubectl patch route granite-model --type='merge' -p='
{
  "spec": {
    "tls": {
      "termination": "reencrypt",
      "certificate": "-----BEGIN CERTIFICATE-----\n<YOUR_CERTIFICATE_CONTENT>\n-----END CERTIFICATE-----",
      "key": "-----BEGIN PRIVATE KEY-----\n<YOUR_PRIVATE_KEY_CONTENT>\n-----END PRIVATE KEY-----"
    }
  }
}'
```

## Deleting Model Deployments

When deleting model deployments, remove resources in the reverse order of creation to ensure clean cleanup.

### Basic Deletion

```bash
# Delete in reverse order: Route → InferenceService → ServingRuntime
kubectl delete route granite-model
kubectl delete inferenceservice granite-model
kubectl delete servingruntime granite-runtime
```

### Delete All Resources for a Model

```bash
# Delete all resources with a specific label
MODEL_NAME="granite-model"
kubectl delete route,inferenceservice,servingruntime \
  -l serving.kserve.io/inferenceservice=$MODEL_NAME

# Force deletion if stuck
kubectl delete inferenceservice granite-model --force --grace-period=0
```

### Important Notes on Deletion

⚠️ **Warning**: Deleting an InferenceService will:
- Remove all associated pods and services
- Delete any in-memory model cache
- Terminate active inference requests
- Remove autoscaling configurations

### Cleanup Verification

```bash
# Verify all resources are deleted
kubectl get all -l serving.kserve.io/inferenceservice=granite-model

# Check for lingering PVCs
kubectl get pvc -l serving.kserve.io/inferenceservice=granite-model

# Check for finalizers preventing deletion
kubectl get inferenceservice granite-model -o jsonpath='{.metadata.finalizers}'
```

## Practical Examples

This section provides additional deployment examples for specific use cases, building on the complete working example shown earlier.

### Example 1: Custom vLLM Arguments

This example demonstrates various vLLM arguments for different use cases:

**ServingRuntime** (`custom-args-runtime.yaml`):
```yaml
# custom-args-runtime.yaml - custom vLLM configurations
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: custom-args-model
  annotations:
    opendatahub.io/accelerator-name: migrated-gpu
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  containers:
    - name: kserve-container
      image: 'quay.io/modh/vllm:rhoai-2.20-cuda'
      args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
        # Custom vLLM arguments for specific use cases
        - '--max-model-len=8192'         # Larger context window
        - '--download-dir=/tmp/models'   # Custom download directory
        - '--trust-remote-code'          # Allow custom model code
        - '--disable-log-requests'       # Reduce logging overhead
  supportedModelFormats:
    - name: vLLM
      autoSelect: true
```

**Common vLLM argument use cases:**
- **Larger contexts**: `--max-model-len=8192` or higher for long documents
- **Custom models**: `--trust-remote-code` for models with custom implementations
- **Performance tuning**: `--disable-log-requests` to reduce overhead
- **Storage management**: `--download-dir` to specify model cache location

### Example 2: Internal Only (No Route)

Deploy a model that is only accessible within the cluster, without external route exposure:

**ServingRuntime** (`internal-model-runtime.yaml`):
```yaml
# internal-model-runtime.yaml - for internal cluster access only
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: internal-model
  annotations:
    opendatahub.io/accelerator-name: migrated-gpu
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  containers:
    - name: kserve-container
      image: 'quay.io/modh/vllm:rhoai-2.20-cuda'
      args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
        - '--max-model-len=4096'
  supportedModelFormats:
    - name: vLLM
      autoSelect: true
```

**InferenceService** (`internal-model-service.yaml`):
```yaml
# internal-model-service.yaml - NO external visibility label
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: internal-model
  labels:
    opendatahub.io/dashboard: 'true'
    # NOTE: No networking.kserve.io/visibility label = internal only
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: internal-model
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5'
      resources:
        requests:
          cpu: '2'
          memory: 16Gi
          nvidia.com/gpu: '1'
        limits:
          cpu: '4'
          memory: 24Gi
          nvidia.com/gpu: '1'
    tolerations:
      - effect: NoSchedule
        key: nvidia.com/gpu
        operator: Exists
```

**Key differences for internal-only deployment:**
- **No visibility label**: Omit `networking.kserve.io/visibility: exposed`
- **No Route creation**: OpenShift won't create an external route
- **Cluster access only**: Model endpoint only accessible from within the cluster

**Accessing the internal model:**
```bash
# From another pod in the cluster
kubectl run test-client --image=curlimages/curl --rm -it -- sh

# Inside the test pod, access the model using the service URL
curl -X POST http://internal-model-predictor.my-namespace.svc.cluster.local/v2/models/internal-model/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [{
      "name": "text_input",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["What is OpenShift AI?"]
    }]
  }'
```

**Use cases for internal-only models:**
- Backend services that don't need external access
- Models used by other cluster workloads
- Development/testing environments
- Security-sensitive deployments

### Example 3: Alternate GPU (AMD)

Deploy models on AMD GPUs using ROCm-enabled images:

**ServingRuntime** (`amd-gpu-runtime.yaml`):
```yaml
# amd-gpu-runtime.yaml - for AMD GPU deployment
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: amd-gpu-model
  annotations:
    opendatahub.io/accelerator-name: amd.com/gpu  # AMD GPU annotation
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  containers:
    - name: kserve-container
      image: 'quay.io/modh/vllm:rhoai-2.20-rocm'  # ROCm-enabled image
      args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
        - '--max-model-len=4096'
  supportedModelFormats:
    - name: vLLM
      autoSelect: true
```

**InferenceService** (`amd-gpu-service.yaml`):
```yaml
# amd-gpu-service.yaml - using AMD GPU resources
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: amd-gpu-model
  labels:
    opendatahub.io/dashboard: 'true'
    networking.kserve.io/visibility: exposed
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: amd-gpu-model
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5'
      resources:
        requests:
          cpu: '2'
          memory: 16Gi
          amd.com/gpu: '1'                         # Request AMD GPU
        limits:
          cpu: '4'
          memory: 24Gi
          amd.com/gpu: '1'                         # Limit AMD GPU
    tolerations:
      - effect: NoSchedule
        key: amd.com/gpu                           # AMD GPU toleration
        operator: Exists
```

**AMD GPU deployment notes:**
- **Image selection**: Use ROCm-enabled vLLM images (`-rocm` suffix)
- **Resource type**: Replace `nvidia.com/gpu` with `amd.com/gpu`
- **Accelerator annotation**: Use `amd.com/gpu` in annotations
- **Tolerations**: Update to match AMD GPU node taints
- **Compatibility**: Ensure models are tested with ROCm/AMD GPUs

**Verify AMD GPU availability:**
```bash
# Check for AMD GPU nodes
kubectl get nodes -L amd.com/gpu

# Verify AMD GPU resources
kubectl describe node <node-name> | grep amd.com/gpu
```

### Example 4: Single Node, Multi GPU

Deploy large models across multiple GPUs on a single node using tensor parallelism:

**ServingRuntime** (`multi-gpu-model-runtime.yaml`):
```yaml
# multi-gpu-model-runtime.yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: multi-gpu-model  # Must match InferenceService name
  annotations:
    opendatahub.io/accelerator-name: nvidia-a100  # Target specific GPU type
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  containers:
    - name: kserve-container
      image: 'quay.io/modh/vllm:rhoai-2.20-cuda'
      args:
        - '--port=8080'
        - '--model=/mnt/models'
        # Multi-GPU specific configurations
        - '--tensor-parallel-size=4'     # Split model across 4 GPUs
        - '--distributed-executor-backend=mp'  # Required for multi-GPU
        - '--max-model-len=8192'         # Larger context enabled by more memory
      env:
        - name: VLLM_ATTENTION_BACKEND
          value: FLASHINFER  # Performance optimization for large models
      volumeMounts:
        - mountPath: /dev/shm  # Shared memory critical for multi-GPU
          name: shm
  supportedModelFormats:
    - name: vLLM
      autoSelect: true
  volumes:
    - name: shm  # Larger shared memory for multi-GPU communication
      emptyDir:
        medium: Memory
        sizeLimit: 32Gi
```

**InferenceService** (`multi-gpu-model-service.yaml`):
```yaml
# multi-gpu-model-service.yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: multi-gpu-model
  annotations:
    serving.kserve.io/enable-prometheus-scraping: 'true'  # Monitor multi-GPU usage
  labels:
    networking.kserve.io/visibility: exposed
    opendatahub.io/dashboard: 'true'
spec:
  predictor:
    # Autoscaling configuration for production
    minReplicas: 1
    maxReplicas: 3       # Scale horizontally across nodes
    scaleTarget: 80      # CPU utilization target
    scaleMetric: cpu
    model:
      modelFormat:
        name: vLLM
      runtime: multi-gpu-model  # Must match ServingRuntime name
      # Large model requiring multiple GPUs
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-llama-3-3-70b-instruct:1.5'
      resources:
        requests:
          cpu: '16'
          memory: 160Gi
          nvidia.com/gpu: '4'  # Must match runtime GPU count
        limits:
          cpu: '32'
          memory: 192Gi
          nvidia.com/gpu: '4'  # Ensure same GPU count as runtime
    tolerations:
      - effect: NoSchedule
        key: nvidia.com/gpu
        operator: Exists
      - effect: NoSchedule               # A100-specific toleration
        key: nvidia.com/gpu-model
        operator: Equal
        value: A100
```

**Route** (`multi-gpu-model-route.yaml`):
```yaml
# multi-gpu-model-route.yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: multi-gpu-model
spec:
  to:
    kind: Service
    name: multi-gpu-model-predictor
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

Deploy multi-GPU model:
```bash
kubectl apply -f multi-gpu-model-runtime.yaml
kubectl apply -f multi-gpu-model-service.yaml
# Wait for service to be created, then apply route
kubectl wait --for=condition=Ready inferenceservice/multi-gpu-model --timeout=300s
kubectl apply -f multi-gpu-model-route.yaml
```

### Example 5: S3 Storage Deployment

Deploy a model from S3-compatible storage with included data connection:

**S3 Data Connection Secret** (`s3-model-secret.yaml`):
```yaml
# s3-model-secret.yaml - S3 data connection
apiVersion: v1
kind: Secret
metadata:
  name: model-s3-storage
  labels:
    opendatahub.io/dashboard: 'true'
    opendatahub.io/managed: 'true'
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: Model S3 Storage
type: Opaque
stringData:
  # Replace with your S3 credentials
  AWS_ACCESS_KEY_ID: your-access-key
  AWS_SECRET_ACCESS_KEY: your-secret-key
  AWS_S3_ENDPOINT: https://s3.amazonaws.com
  AWS_S3_BUCKET: your-model-bucket
  AWS_DEFAULT_REGION: us-east-1
```

**ServingRuntime** (`s3-model-runtime.yaml`):
```yaml
# s3-model-runtime.yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: s3-model
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  containers:
    - name: kserve-container
      image: 'quay.io/modh/vllm:rhoai-2.20-cuda'
      args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
  supportedModelFormats:
    - name: vLLM
      autoSelect: true
```

**InferenceService** (`s3-model-service.yaml`):
```yaml
# s3-model-service.yaml - using S3 storage
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: s3-model
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: s3-model
      # Use storage field for S3 connections
      storage:
        key: model-s3-storage  # Reference to the Secret
        path: models/llama-3.1-8b-instruct/  # Path within the S3 bucket
      args:
        - '--max-model-len=4096'
      resources:
        requests:
          nvidia.com/gpu: '1'
        limits:
          nvidia.com/gpu: '1'
    tolerations:
      - effect: NoSchedule
        key: nvidia.com/gpu
        operator: Exists
```

Deploy from S3 storage:
```bash
# Create the S3 data connection first
kubectl apply -f s3-model-secret.yaml
# Deploy the runtime and service
kubectl apply -f s3-model-runtime.yaml
kubectl apply -f s3-model-service.yaml
```

### Example 6: PVC Storage Deployment

Deploy a model from a Persistent Volume Claim:

**ServingRuntime** (`pvc-model-runtime.yaml`):
```yaml
# pvc-model-runtime.yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: pvc-model
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  containers:
    - name: kserve-container
      image: 'quay.io/modh/vllm:rhoai-2.20-cuda'
      args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
  supportedModelFormats:
    - name: vLLM
      autoSelect: true
```

**InferenceService** (`pvc-model-service.yaml`):
```yaml
# pvc-model-service.yaml - using PVC storage
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: pvc-model
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: pvc-model
      # Use storageUri with pvc:// scheme
      storageUri: 'pvc://model-pvc/llama-3.1-8b-instruct'  # pvc://<pvc-name>/<model-path>
      args:
        - '--max-model-len=4096'
      resources:
        requests:
          nvidia.com/gpu: '1'
        limits:
          nvidia.com/gpu: '1'
    tolerations:
      - effect: NoSchedule
        key: nvidia.com/gpu
        operator: Exists
```

Deploy from PVC storage:
```bash
# Note: PVC must already exist with model files
# See "Setting Up PVCs for Model Storage" guide
kubectl apply -f pvc-model-runtime.yaml
kubectl apply -f pvc-model-service.yaml
```

**Prerequisites for PVC storage:**
1. Create a PVC named `model-pvc` with RWX access mode
2. Copy model files to the PVC at path `llama-3.1-8b-instruct/`
3. See [Setting Up PVCs for Model Storage](/docs/extras/model-pvc-setup/) for detailed instructions

### Deployment Commands for All Examples

```bash
# Complete Working Example (from earlier section)
kubectl apply -f granite-model-runtime.yaml
kubectl apply -f granite-model-service.yaml
kubectl wait --for=condition=Ready inferenceservice/granite-model --timeout=600s
kubectl apply -f granite-model-route.yaml

# Example 1: Custom vLLM Arguments
kubectl apply -f custom-args-runtime.yaml
kubectl apply -f custom-args-service.yaml

# Example 2: Internal Only (No Route)
kubectl apply -f internal-model-runtime.yaml
kubectl apply -f internal-model-service.yaml

# Example 3: Alternate GPU (AMD)
kubectl apply -f amd-gpu-runtime.yaml
kubectl apply -f amd-gpu-service.yaml

# Example 4: Multi-GPU
kubectl apply -f multi-gpu-model-runtime.yaml
kubectl apply -f multi-gpu-model-service.yaml
kubectl wait --for=condition=Ready inferenceservice/multi-gpu-model --timeout=300s
kubectl apply -f multi-gpu-model-route.yaml

# Example 5: S3 Storage
kubectl apply -f s3-model-secret.yaml
kubectl apply -f s3-model-runtime.yaml
kubectl apply -f s3-model-service.yaml

# Example 6: PVC Storage
kubectl apply -f pvc-model-runtime.yaml
kubectl apply -f pvc-model-service.yaml

# Monitor deployment status
kubectl get inferenceservice -w

# Test endpoints (internal)
kubectl port-forward service/<model-name>-predictor 8080:80
curl http://localhost:8080/v2/models

# Test external routes
ROUTE_URL=$(kubectl get route <model-name> -o jsonpath='{.spec.host}')
curl https://$ROUTE_URL/v2/models
```

## Verification and Troubleshooting

### Verify Deployment Status

```bash
# Check InferenceService readiness
kubectl get inferenceservice <model-name> -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'

# Watch deployment progress
kubectl get inferenceservice <model-name> -w

# Check all components
kubectl get pods,services,deployments -l serving.kserve.io/inferenceservice=<model-name>
```

### View Logs

```bash
# View predictor pod logs
kubectl logs -l serving.kserve.io/inferenceservice=<model-name> -c kserve-container

# Stream logs
kubectl logs -f -l serving.kserve.io/inferenceservice=<model-name>

# View previous container logs (if crashed)
kubectl logs -l serving.kserve.io/inferenceservice=<model-name> -c kserve-container --previous
```

### Common Issues and Solutions

#### Model Not Loading

```bash
# Check pod events
kubectl describe pod -l serving.kserve.io/inferenceservice=<model-name>

# Common causes:
# - Insufficient memory: Increase memory limits
# - Wrong model format: Verify storageUri and model compatibility
# - GPU not available: Check node labels and tolerations
```


#### Route Not Accessible

```bash
# Check route status
kubectl get route <model-name> -o jsonpath='{.status.ingress[0].conditions[?(@.type=="Admitted")]}'

# Verify service exists
kubectl get service <model-name>-predictor

# Test internal connectivity
kubectl run test-curl --image=curlimages/curl:latest --rm -it -- \
  curl http://<model-name>-predictor.<namespace>.svc.cluster.local:80/v1/models
```

#### GPU Allocation Issues

```bash
# Check node GPU availability
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPUs:.status.capacity.nvidia\\.com/gpu

# Verify pod GPU requests
kubectl get pod -l serving.kserve.io/inferenceservice=<model-name> -o jsonpath='{.items[0].spec.containers[0].resources}'

# Check GPU operator status
kubectl get pods -n nvidia-gpu-operator
```

### Performance Troubleshooting

```bash
# Check resource usage
kubectl top pod -l serving.kserve.io/inferenceservice=<model-name>

# View HPA status (if autoscaling enabled)
kubectl get hpa

# Check response times
kubectl exec -it <pod-name> -- curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8080/v1/models
```

## Best Practices

### Naming Conventions

- Use consistent names for ServingRuntime and InferenceService (e.g., both named `granite-model`)
- Include model version in names for easy identification (e.g., `llama-70b-v1`)
- Use descriptive prefixes for environment separation (e.g., `prod-`, `dev-`, `test-`)

### Resource Allocation

- **Development**: Start with minimal resources and scale up as needed
- **Production**: 
  - Set resource requests to guarantee minimum performance
  - Set resource limits 20-30% above requests for burst capacity
  - Use GPU only when necessary (some models run efficiently on CPU)

### Security Considerations

- Use TLS termination at the route level
- Implement network policies to restrict access
- Regularly update serving runtime images
- Consider implementing authentication for production deployments

### Model Selection Guidelines

- Choose quantized models (FP8, W8A8) for better GPU memory efficiency
- Use tensor parallelism for models larger than single GPU memory
- Consider model size vs. accuracy trade-offs

### Production Deployment Checklist

- [ ] Enable authentication
- [ ] Configure autoscaling
- [ ] Set appropriate resource requests/limits
- [ ] Add health checks and readiness probes
- [ ] Configure monitoring and alerts
- [ ] Document model version and parameters
- [ ] Test rollback procedures
- [ ] Verify GPU node affinity and tolerations

## Field Reference

### ServingRuntime Fields

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `metadata.name` | string | Yes | Unique runtime identifier | `vllm-runtime` |
| `metadata.annotations.opendatahub.io/accelerator-name` | string | No | Accelerator profile reference | `nvidia-a100` |
| `metadata.annotations.opendatahub.io/recommended-accelerators` | JSON array | No | List of compatible GPU types | `["nvidia.com/gpu"]` |
| `metadata.labels.opendatahub.io/dashboard` | string | No | Show in OpenShift AI dashboard | `'true'` |
| `spec.containers[].name` | string | Yes | Container name | `kserve-container` |
| `spec.containers[].image` | string | Yes | Serving container image | `quay.io/modh/vllm:rhoai-2.20-cuda` |
| `spec.containers[].args` | array | No | Container arguments | `["--port=8080"]` |
| `spec.containers[].env` | array | No | Environment variables | See examples |
| `spec.supportedModelFormats[].name` | string | Yes | Model format name | `vLLM` |
| `spec.supportedModelFormats[].autoSelect` | boolean | No | Auto-select this format | `true` |
| `spec.volumes` | array | No | Volume definitions | See examples |

### InferenceService Fields

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `metadata.name` | string | Yes | Unique model identifier | `granite-model` |
| `metadata.annotations.serving.kserve.io/deploymentMode` | string | No | Deployment mode | `RawDeployment` |
| `metadata.labels.networking.kserve.io/visibility` | string | No | Network visibility (REQUIRED for external Route access) | `exposed` |
| `spec.predictor.minReplicas` | integer | No | Minimum pod replicas | `1` |
| `spec.predictor.maxReplicas` | integer | No | Maximum pod replicas | `5` |
| `spec.predictor.scaleTarget` | integer | No | Autoscaling target percentage | `80` |
| `spec.predictor.scaleMetric` | string | No | Autoscaling metric | `cpu` or `memory` |
| `spec.predictor.model.modelFormat.name` | string | Yes | Model format | `vLLM` |
| `spec.predictor.model.runtime` | string | Yes | ServingRuntime reference | `vllm-runtime` |
| `spec.predictor.model.storageUri` | string | Yes | Model location | `oci://registry.redhat.io/...` |
| `spec.predictor.model.args` | array | No | Model server arguments | `["--max-model-len=4096"]` |
| `spec.predictor.model.resources` | object | No | Resource requirements | See examples |
| `spec.predictor.tolerations` | array | No | Node scheduling tolerations | See examples |

### Common Annotations

| Annotation | Resource | Description | Values |
|------------|----------|-------------|--------|
| `opendatahub.io/dashboard` | Both | Display in OpenShift AI dashboard | `'true'` |
| `openshift.io/display-name` | Both | Human-readable name | Any string |
| `serving.kserve.io/deploymentMode` | InferenceService | Deployment strategy | `RawDeployment`, `Serverless` |
| `serving.kserve.io/enable-prometheus-scraping` | InferenceService | Enable metrics | `'true'` |
| `prometheus.io/scrape` | ServingRuntime | Enable Prometheus scraping | `'true'` |
| `prometheus.io/port` | ServingRuntime | Metrics port | `'8080'` |
| `prometheus.io/path` | ServingRuntime | Metrics endpoint | `/metrics` |

## Using with Kubernetes MCP Server

The Kubernetes MCP server provides programmatic access to manage model serving resources. Below are the tool mappings and usage patterns.

### MCP Tool Mapping

| Operation | MCP Tool | Description |
|-----------|----------|-------------|
| Create resources | `mcp__Kubernetes__resources_create_or_update` | Create ServingRuntime, InferenceService, Route |
| List resources | `mcp__Kubernetes__resources_list` | List model deployments |
| Get specific resource | `mcp__Kubernetes__resources_get` | View details of specific resources |
| Update resources | `mcp__Kubernetes__resources_create_or_update` | Update existing resources |
| Delete resources | `mcp__Kubernetes__resources_delete` | Remove model deployments |
| View logs | `mcp__Kubernetes__pods_log` | Check model server logs |
| Execute commands | `mcp__Kubernetes__pods_exec` | Run commands in pods |

### Creating Model Deployments with MCP

```javascript
// Create ServingRuntime
await mcp__Kubernetes__resources_create_or_update({
  resource: JSON.stringify({
    apiVersion: "serving.kserve.io/v1alpha1",
    kind: "ServingRuntime",
    metadata: {
      name: "mcp-model-runtime",
      namespace: "default"
    },
    spec: {
      containers: [{
        name: "kserve-container",
        image: "quay.io/modh/vllm:rhoai-2.20-cuda",
        args: ["--port=8080", "--model=/mnt/models"]
      }],
      supportedModelFormats: [{
        name: "vLLM",
        autoSelect: true
      }]
    }
  })
});

// Create InferenceService
await mcp__Kubernetes__resources_create_or_update({
  resource: JSON.stringify({
    apiVersion: "serving.kserve.io/v1beta1",
    kind: "InferenceService",
    metadata: {
      name: "mcp-model",
      namespace: "default"
    },
    spec: {
      predictor: {
        model: {
          modelFormat: { name: "vLLM" },
          runtime: "mcp-model-runtime",
          storageUri: "oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5"
        }
      }
    }
  })
});
```

### Listing Model Deployments with MCP

```javascript
// List all InferenceServices
const inferenceServices = await mcp__Kubernetes__resources_list({
  apiVersion: "serving.kserve.io/v1beta1",
  kind: "InferenceService",
  namespace: "default"
});

// List all ServingRuntimes
const servingRuntimes = await mcp__Kubernetes__resources_list({
  apiVersion: "serving.kserve.io/v1alpha1",
  kind: "ServingRuntime",
  namespace: "default"
});
```

### Monitoring with MCP

```javascript
// Get model deployment status
const model = await mcp__Kubernetes__resources_get({
  apiVersion: "serving.kserve.io/v1beta1",
  kind: "InferenceService",
  name: "mcp-model",
  namespace: "default"
});

// View model server logs
const pods = await mcp__Kubernetes__pods_list_in_namespace({
  namespace: "default",
  labelSelector: "serving.kserve.io/inferenceservice=mcp-model"
});

if (pods.items.length > 0) {
  const logs = await mcp__Kubernetes__pods_log({
    name: pods.items[0].metadata.name,
    namespace: "default",
    container: "kserve-container"
  });
}
```

### MCP Limitations

- Cannot use `kubectl apply` with file paths - must provide full resource JSON
- No support for `kubectl patch` - use full resource updates
- Cannot use shell redirections or pipes
- Limited support for complex label selectors

### Best Practices for MCP

1. Always specify namespace explicitly
2. Use JSON.stringify() for resource specifications
3. Check resource existence before updates
4. Handle API version compatibility
5. Implement proper error handling for failed operations

## Appendix: Pre-built ModelCars

The following table lists all available pre-built ModelCars from Red Hat's validated models collection. These models are optimized for deployment on OpenShift AI and can be used with the OCI registry storage method by specifying the URI in the `storageUri` field of your InferenceService configuration.

| Model ID | ModelCar URI |
|----------|-------------|
| `RedHatAI/Llama-4-Scout-17B-16E-Instruct-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-llama-4-scout-17b-16e-instruct-fp8-dynamic:1.5` |
| `RedHatAI/Llama-4-Scout-17B-16E-Instruct-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-llama-4-scout-17b-16e-instruct-quantized-w4a16:1.5` |
| `RedHatAI/Llama-4-Scout-17B-16E-Instruct` | `oci://registry.redhat.io/rhelai1/modelcar-llama-4-scout-17b-16e-instruct:1.5` |
| `RedHatAI/Llama-4-Maverick-17B-128E-Instruct` | `oci://registry.redhat.io/rhelai1/modelcar-llama-4-maverick-17b-128e-instruct:1.5` |
| `RedHatAI/Llama-4-Maverick-17B-128E-Instruct-FP8` | `oci://registry.redhat.io/rhelai1/modelcar-llama-4-maverick-17b-128e-instruct-fp8:1.5` |
| `RedHatAI/Mistral-Small-3.1-24B-Instruct-2503-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-mistral-small-3-1-24b-instruct-2503-fp8-dynamic:1.5` |
| `RedHatAI/Mistral-Small-3.1-24B-Instruct-2503-quantized.w8a8` | `oci://registry.redhat.io/rhelai1/modelcar-mistral-small-3-1-24b-instruct-2503-quantized-w8a8:1.5` |
| `RedHatAI/Mistral-Small-3.1-24B-Instruct-2503-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-mistral-small-3-1-24b-instruct-2503-quantized-w4a16:1.5` |
| `RedHatAI/Mistral-Small-3.1-24B-Instruct-2503` | `oci://registry.redhat.io/rhelai1/modelcar-mistral-small-3-1-24b-instruct-2503:1.5` |
| `RedHatAI/Mistral-Small-24B-Instruct-2501-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-mistral-small-24b-instruct-2501-fp8-dynamic:1.5` |
| `RedHatAI/Mistral-Small-24B-Instruct-2501-quantized.w8a8` | `oci://registry.redhat.io/rhelai1/modelcar-mistral-small-24b-instruct-2501-quantized-w8a8:1.5` |
| `RedHatAI/Mistral-Small-24B-Instruct-2501` | `oci://registry.redhat.io/rhelai1/modelcar-mistral-small-24b-instruct-2501:1.5` |
| `RedHatAI/phi-4` | `oci://registry.redhat.io/rhelai1/modelcar-phi-4:1.5` |
| `RedHatAI/phi-4-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-phi-4-quantized-w4a16:1.5` |
| `RedHatAI/phi-4-quantized.w8a8` | `oci://registry.redhat.io/rhelai1/modelcar-phi-4-quantized-w8a8:1.5` |
| `RedHatAI/phi-4-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-phi-4-fp8-dynamic:1.5` |
| `RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-3-70b-instruct-fp8-dynamic:1.5` |
| `RedHatAI/Llama-3.3-70B-Instruct` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-3-70b-instruct:1.5` |
| `RedHatAI/granite-3.1-8b-instruct-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct-fp8-dynamic:1.5` |
| `RedHatAI/granite-3.1-8b-instruct` | `oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5` |
| `RedHatAI/Qwen2.5-7B-Instruct-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-qwen2-5-7b-instruct-fp8-dynamic:1.5` |
| `RedHatAI/Qwen2.5-7B-Instruct` | `oci://registry.redhat.io/rhelai1/modelcar-qwen2-5-7b-instruct:1.5` |
| `RedHatAI/Llama-3.1-8B-Instruct` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-1-8b-instruct:1.5` |
| `RedHatAI/Llama-3.1-Nemotron-70B-Instruct-HF-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-1-nemotron-70b-instruct-hf-fp8-dynamic:1.5` |
| `RedHatAI/Mixtral-8x7B-Instruct-v0.1` | `oci://registry.redhat.io/rhelai1/modelcar-mixtral-8x7b-instruct-v0-1:1.4` |
| `RedHatAI/Llama-3.1-Nemotron-70B-Instruct-HF` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-1-nemotron-70b-instruct-hf:1.5` |
| `RedHatAI/Llama-3.3-70B-Instruct-quantized.w8a8` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-3-70b-instruct-quantized-w8a8:1.5` |
| `RedHatAI/Llama-3.3-70B-Instruct-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-3-70b-instruct-quantized-w4a16:1.5` |
| `RedHatAI/granite-3.1-8b-instruct-quantized.w8a8` | `oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct-quantized-w8a8:1.5` |
| `RedHatAI/granite-3.1-8b-instruct-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct-quantized-w4a16:1.5` |
| `RedHatAI/Qwen2.5-7B-Instruct-quantized.w8a8` | `oci://registry.redhat.io/rhelai1/modelcar-qwen2-5-7b-instruct-quantized-w8a8:1.5` |
| `RedHatAI/Qwen2.5-7B-Instruct-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-qwen2-5-7b-instruct-quantized-w4a16:1.5` |
| `RedHatAI/granite-3.1-8b-base-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-base-quantized-w4a16:1.5` |
| `RedHatAI/Mistral-Small-24B-Instruct-2501-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-mistral-small-24b-instruct-2501-quantized-w4a16:1.5` |
| `RedHatAI/Meta-Llama-3.1-8B-Instruct-quantized.w8a8` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-1-8b-instruct-quantized-w8a8:1.5` |
| `RedHatAI/Meta-Llama-3.1-8B-Instruct-FP8-dynamic` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-1-8b-instruct-fp8-dynamic:1.5` |
| `RedHatAI/Meta-Llama-3.1-8B-Instruct-quantized.w4a16` | `oci://registry.redhat.io/rhelai1/modelcar-llama-3-1-8b-instruct-quantized-w4a16:1.5` |
| `RedHatAI/gemma-2-9b-it-FP8` | `oci://registry.redhat.io/rhelai1/modelcar-gemma-2-9b-it-FP8:1.5` |
| `RedHatAI/gemma-2-9b-it` | `oci://registry.redhat.io/rhelai1/modelcar-gemma-2-9b-it:1.5` |

### Usage Notes

- **Model Selection**: Choose models based on your hardware constraints and performance requirements
- **Quantization**: Models with `FP8-dynamic`, `w4a16`, or `w8a8` quantization require less GPU memory
- **GPU Requirements**: Larger models (70B parameters) require more GPU memory and compute resources
- **Version**: Most models use version `1.5`, except `Mixtral-8x7B-Instruct-v0.1` which uses `1.4`
- **Registry**: All models are hosted in the Red Hat registry at `registry.redhat.io/rhelai1/`

### Example Usage

To use any of these models in your InferenceService, simply replace the `storageUri` field:

```yaml
spec:
  predictor:
    model:
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-instruct:1.5'
```

For more information about each model, visit the [Red Hat AI validated models collection](https://huggingface.co/collections/RedHatAI/red-hat-ai-validated-models-v10-682613dc19c4a596dbac9437) on Hugging Face.
