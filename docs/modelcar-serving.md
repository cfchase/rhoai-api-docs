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
oc get acceleratorprofiles -n redhat-ods-applications

# Get detailed information about a specific profile
oc get acceleratorprofile <profile-name> -n redhat-ods-applications -o yaml
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

- `metadata.name`: The name of your serving runtime
- `metadata.annotations.opendatahub.io/hardware-profile-name`: Should match your accelerator profile name.
- `metadata.annotations.opendatahub.io/recommended-accelerators`: The GPU identifier (e.g., "nvidia.com/gpu")
- `spec.containers[0].args`: Command line arguments for the vLLM server
  - `--port`: The port the server listens on
  - `--model`: The path where the model will be mounted
  - `--served-model-name`: The name of the model to serve
- `spec.containers[0].image`: The container image for vLLM serving
- `spec.volumes[0].emptyDir.sizeLimit`: The size limit for the shared memory volume (adjust based on model size)


Save the customized ServingRuntime as `servingruntime-granite.yaml` and apply it:

```bash
oc apply -n my-ds-project -f servingruntime-granite.yaml
```

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

- `metadata.name`: The name of your inference service
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
- `spec.predictor.model.storageUri`: The location of your model
  - Format: `oci://registry.redhat.io/rhelai1/modelcar-granite-3-1-8b-lab-v2:1.5`
- `spec.predictor.tolerations`: GPU node scheduling configuration.  Should match the tolerations from the AcceleratorProfile.
  - `effect`: Scheduling effect (NoSchedule)
  - `key`: GPU node label key
  - `operator`: Taint matching operator


Save this as `inferenceservice-granite.yaml` and apply it:

```bash
oc apply -n my-ds-project -f inferenceservice-granite.yaml
```

### Step 4: Verify the Deployment

Check the status of your deployment:

```bash
# Check the InferenceService status
oc get -n my-ds-project inferenceservice granite

# Check the pods
oc get -n my-ds-project pods -l serving.kserve.io/inferenceservice=granite

# View the logs
oc logs -n my-ds-project -l serving.kserve.io/inferenceservice=granite
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

Save this as `route-granite.yaml` and apply it:

```bash
oc apply -n my-ds-project -f route-granite.yaml
```

### Step 6: Access the Model

After creating the Route, you can access the model using the external URL:

```bash
# Get the external URL
EXTERNAL_URL=$(oc get route granite -o jsonpath='{.spec.host}')

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
oc describe pod -n my-ds-project -l serving.kserve.io/inferenceservice=granite
oc logs -n my-ds-project -l serving.kserve.io/inferenceservice=granite
```

### Cleanup

To remove the deployment:

```bash
oc delete inferenceservice granite
oc delete servingruntime granite

#optionally delete the route
oc delete route granite
```




