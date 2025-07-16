---
layout: page
title: ModelCars
nav_order: 3
permalink: /docs/modelcar-serving/
---

# Serving Models with ModelCars

ModelCars provide a simplified way to deploy and serve machine learning models on OpenShift AI using the KServe infrastructure with pre-configured serving runtimes.

## Tutorial: Deploying a Granite Model with KServe

This tutorial will guide you through deploying a Granite model using KServe on OpenShift AI. We'll use a pre-built model from Red Hat's registry and configure it to run on GPU hardware.

### Prerequisites

- OpenShift AI cluster with GPU nodes
- Access to the `my-ds-project` namespace (or your preferred namespace)
- `oc` CLI tool installed and configured
- NVIDIA GPU operator installed on the cluster

### Step 1: Check Available Accelerator Profiles

Before deploying the model, we need to check the available AcceleratorProfiles in the `redhat-ods-applications` namespace. These profiles define the GPU configurations available in your cluster.  If there are no profiles, you can still deploy the model with your own GPU configuration.

```bash
# List available accelerator profiles
kubectl get acceleratorprofiles -n redhat-ods-applications

# Get detailed information about a specific profile
kubectl get acceleratorprofile <profile-name> -n redhat-ods-applications -o yaml
```

For example, you might see output like this:
```yaml
apiVersion: dashboard.opendatahub.io/v1
kind: AcceleratorProfile
metadata:
  name: migrated-gpu
  namespace: redhat-ods-applications
spec:
  displayName: "NVIDIA GPU"
  enabled: true
  identifier: nvidia.com/gpu
  tolerations:
  - effect: NoSchedule
    key: nvidia.com/gpu
    operator: Exists
```

**Key Arguments:**

- `metadata.name`: The unique identifier for the profile name
- `metadata.spec.identifier`: The GPU identifier.  Will be used in the InferenceService configuration for requests/limits.
- `metadata.spec.tolerations`: The tolerations configuration.  Will be used in the InferenceService configuration for scheduling on tainted nodes.

We'll use these values in our ServingRuntime and InferenceService configurations. Make sure to replace the profile name and GPU configuration in the following steps with the values from your cluster.

### Step 2: Create the ServingRuntime

First, we need to create a ServingRuntime that defines how the model will be served. This runtime uses vLLM for efficient model serving.

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: granite
  annotations:
    opendatahub.io/accelerator-name: migrated-gpu
    opendatahub.io/apiProtocol: REST
    opendatahub.io/hardware-profile-name: migrated-gpu
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    openshift.io/display-name: granite
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: '8080'
  containers:
    - args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
      command:
        - python
        - '-m'
        - vllm.entrypoints.openai.api_server
      env:
        - name: HF_HOME
          value: /tmp/hf_home
      image: 'quay.io/modh/vllm:rhoai-2.20-cuda'
      name: kserve-container
      ports:
        - containerPort: 8080
          protocol: TCP
      volumeMounts:
        - mountPath: /dev/shm
          name: shm
  multiModel: false
  supportedModelFormats:
    - autoSelect: true
      name: vLLM
  volumes:
    - emptyDir:
        medium: Memory
        sizeLimit: 2Gi
      name: shm
```

**Key Arguments:**

- `metadata.name`: The name of your serving runtime, this should match the name of your InferenceService.
- `metadata.annotations.opendatahub.io/hardware-profile-name`: Should match your accelerator profile name.
- `metadata.annotations.opendatahub.io/recommended-accelerators`: The GPU identifier (e.g., "nvidia.com/gpu")
- `spec.containers[0].args`: Command line arguments for the vLLM server
  - `--port`: The port the server listens on
  - `--model`: The path where the model will be mounted
  - `--served-model-name`: The name of the model to serve
- `spec.containers[0].image`: The container image for vLLM serving
- `spec.volumes[0].emptyDir.sizeLimit`: The size limit for the shared memory volume (adjust based on model size)


Create your the ServingRuntime using your customized YAML.

### Step 3: Deploy the InferenceService

Next, we'll create an InferenceService that uses our ServingRuntime to serve the Granite model:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: granite
  annotations:
    openshift.io/display-name: Granite
    security.opendatahub.io/enable-auth: 'false'
    serving.kserve.io/deploymentMode: RawDeployment
  labels:
    networking.kserve.io/visibility: exposed
    opendatahub.io/dashboard: 'true'
spec:
  predictor:
    maxReplicas: 1
    minReplicas: 1
    model:
      args:
        - '--max-model-len=4096'
      modelFormat:
        name: vLLM
      resources:
        limits:
          cpu: '6'
          memory: 24Gi
          nvidia.com/gpu: '1'
        requests:
          cpu: '1'
          memory: 16Gi
          nvidia.com/gpu: '1'
      runtime: granite
      storageUri: 'oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-lab-v2:1.5'
    tolerations:
      - effect: NoSchedule
        key: nvidia.com/gpu
        operator: Exists
```

**Key Arguments:**

- `metadata.name`: The name of your inference service, this should match the name of your ServingRuntime.
- `metadata.annotations.openshift.io/display-name`: The display name shown in the OpenShift AI console
- `metadata.annotations.security.opendatahub.io/enable-auth`: Set to 'false' to disable authentication.  If set to 'true', you will need to create additional authentication resources.
- `metadata.annotations.serving.kserve.io/deploymentMode`: Set to 'RawDeployment' for direct pod management
- `spec.predictor.maxReplicas` and `minReplicas`: Control the number of model serving instances
- `spec.predictor.model.args`: Additional arguments for the model server
  - `--max-model-len`: Maximum sequence length for the model
- `spec.predictor.model.resources`: Resource allocation for the model
  - `limits`: Maximum resources allowed
    - `cpu`: CPU cores limit
    - `memory`: Memory limit
    - `nvidia.com/gpu`: Key should match the identifier from the AcceleratorProfile.  Value should be the number of GPUs per node.
  - `requests`: Minimum resources required
    - `cpu`: CPU cores request
    - `memory`: Memory request
    - `nvidia.com/gpu`: Key should match the identifier from the AcceleratorProfile.  Value should be the number of GPUs per node.
- `spec.predictor.model.runtime`: Must match the name of your ServingRuntime
- `spec.predictor.model.storageUri`: The location of your model.  For a list of available models, see the [Appendix: Available ModelCars](#appendix-available-modelcars) section.
  - Format: `oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-lab-v2:1.5`
- `spec.predictor.tolerations`: GPU node scheduling configuration.  Should match the tolerations from the AcceleratorProfile.
  - `effect`: Scheduling effect (NoSchedule)
  - `key`: GPU node label key
  - `operator`: Taint matching operator


Create your the InferenceService using your customized YAML.

```bash
kubectl apply -n my-ds-project -f inferenceservice-granite.yaml
```

### Step 4: Verify the Deployment

Check the status of your deployment:

```bash
# Check the InferenceService status
kubectl get -n my-ds-project inferenceservice granite

# Check the pods
kubectl get -n my-ds-project pods -l serving.kserve.io/inferenceservice=granite

# View the logs
kubectl logs -n my-ds-project -l serving.kserve.io/inferenceservice=granite
```

### Step 5: (Optional) Expose the Model Externally

By default, the model is accessible within the cluster. To expose it externally, you can create a Route. Here's an example Route configuration:

```yaml
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: granite
  labels:
    inferenceservice-name: granite
spec:
  to:
    kind: Service
    name: granite-predictor
    weight: 100
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
```

Create the route using your customized YAML.

```bash
kubectl apply -n my-ds-project -f route-granite.yaml
```

### Step 6: Access the Model

After creating the Route, you can access the model using the external URL:

```bash
# Get the external URL
EXTERNAL_URL=$(kubectl get route granite -o jsonpath='{.spec.host}')

# Test the model using the external URL
curl -X POST "https://$EXTERNAL_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "temperature": 0.1
  }'
```

### Troubleshooting

If you encounter issues:

1. Check pod status and logs:
```bash
kubectl describe pod -n my-ds-project -l serving.kserve.io/inferenceservice=granite
kubectl logs -n my-ds-project -l serving.kserve.io/inferenceservice=granite
```

### Cleanup

To remove the deployment:

```bash
kubectl delete inferenceservice granite
kubectl delete servingruntime granite

#optionally delete the route
kubectl delete route granite
```

## Appendix: Available ModelCars

The following table lists all available pre-built ModelCars from Red Hat's validated models collection. These models are optimized for deployment on OpenShift AI and can be used directly in the `storageUri` field of your InferenceService configuration.

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
