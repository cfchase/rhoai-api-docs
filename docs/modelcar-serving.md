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
  name: migrated-gpu-mglzi-serving
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

Note the following important values from the profile:
- The profile name (e.g., `migrated-gpu-mglzi-serving`)
- The GPU identifier (e.g., `nvidia.com/gpu`)
- The tolerations configuration


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
    opendatahub.io/hardware-profile-name: migrated-gpu-mglzi-serving
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    opendatahub.io/template-display-name: vLLM NVIDIA GPU ServingRuntime for KServe
    opendatahub.io/template-name: vllm-cuda-runtime
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

Save this as `servingruntime-granite.yaml` and apply it:

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

### Step 5: Access the Model

Once the deployment is ready, you can access the model through the provided URL:

```bash
# Get the model endpoint
MODEL_URL=$(oc get route granite-predictor -o jsonpath='{.spec.host}')

# Test the model
curl -X POST "https://$MODEL_URL/v1/models/granite:predict" \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Hello, how are you?"}'
```

### Step 6: (Optional) Expose the Model Externally

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

After creating the Route, you can access the model using the external URL:

```bash
# Get the external URL
EXTERNAL_URL=$(oc get route granite -o jsonpath='{.spec.host}')

# Test the model using the external URL
curl -X POST "https://$EXTERNAL_URL/v1/models/granite:predict" \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Hello, how are you?"}'
```

Note: The Route uses reencrypt TLS termination, which means:
- Traffic to the model is encrypted
- The connection between the router and the model service is also encrypted
- Insecure traffic is redirected to HTTPS

### Configuration Details

Let's break down the key components of our deployment:

#### ServingRuntime Configuration
- Uses vLLM for efficient model serving
- Configured for GPU acceleration
- Includes shared memory volume for better performance
- Supports REST API protocol

#### InferenceService Configuration
- Deploys in RawDeployment mode for better control
- Requests 1 GPU and 16Gi memory
- Sets maximum model length to 4096 tokens
- Uses the pre-built Granite model from Red Hat's registry
- Includes GPU tolerations for proper scheduling

### Monitoring and Management

#### Viewing Metrics
```bash
# Check resource usage
oc top pods -n my-ds-project -l serving.kserve.io/inferenceservice=granite

# Get events
oc get events -n my-ds-project --field-selector involvedObject.name=granite
```

#### Common Status Conditions
- **PredictorReady** - Model is loaded and ready to serve
- **IngressReady** - Ingress/Route is configured
- **Ready** - Overall service is ready

### Troubleshooting

If you encounter issues:

1. Check pod status and logs:
```bash
oc describe pod -n my-ds-project -l serving.kserve.io/inferenceservice=granite
oc logs -n my-ds-project -l serving.kserve.io/inferenceservice=granite
```

2. Verify GPU allocation:
```bash
oc describe node | grep nvidia.com/gpu
```

3. Check model loading:
```bash
oc describe inferenceservice granite | grep -A 10 "Model"
```

### Cleanup

To remove the deployment:

```bash
oc delete inferenceservice granite
oc delete servingruntime granite
```

## Next Steps

- [Examples](examples) - More deployment scenarios
- [Kubernetes API Basics](kubernetes-api) - Understanding the underlying APIs
- [Model Monitoring](monitoring) - Setting up monitoring and observability



