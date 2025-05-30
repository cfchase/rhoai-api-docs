---
layout: page
title: ModelCar Serving
permalink: /docs/modelcar-serving/
---

# ModelCar Serving Guide

ModelCars provide a simplified way to deploy and serve machine learning models on OpenShift AI using the KServe infrastructure with pre-configured serving runtimes.

## What is a ModelCar?

A ModelCar is a Kubernetes custom resource that:
- Simplifies model deployment compared to raw KServe InferenceServices
- Provides pre-built serving runtimes for popular ML frameworks
- Handles automatic scaling and load balancing
- Integrates seamlessly with OpenShift AI workflows

## Supported Model Formats

ModelCars support various model formats out of the box:

### Scikit-learn Models
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: sklearn-model
  namespace: my-project
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      runtime: kserve-sklearnserver
      storage:
        uri: s3://my-bucket/sklearn-iris-model/
```

### TensorFlow Models
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: tensorflow-model
  namespace: my-project
spec:
  predictor:
    model:
      modelFormat:
        name: tensorflow
      runtime: kserve-tensorflow-serving
      storage:
        uri: s3://my-bucket/tensorflow-model/1/
```

### PyTorch Models
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: pytorch-model
  namespace: my-project
spec:
  predictor:
    model:
      modelFormat:
        name: pytorch
      runtime: kserve-torchserve
      storage:
        uri: s3://my-bucket/pytorch-model/
```

### ONNX Models
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: onnx-model
  namespace: my-project
spec:
  predictor:
    model:
      modelFormat:
        name: onnx
      runtime: kserve-tritonserver
      storage:
        uri: s3://my-bucket/onnx-model/
```

### Custom Runtime
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: custom-model
  namespace: my-project
spec:
  predictor:
    containers:
    - name: kserve-container
      image: my-registry/custom-model-server:latest
      ports:
      - containerPort: 8080
        protocol: TCP
      env:
      - name: MODEL_NAME
        value: "my-model"
```

## Storage Configuration

ModelCars can load models from various storage backends:

### S3-Compatible Storage
```yaml
spec:
  predictor:
    model:
      storage:
        uri: s3://bucket-name/model-path/
        storageSpec:
          s3:
            secretKey: aws-secret
```

### Persistent Volume Claims
```yaml
spec:
  predictor:
    model:
      storage:
        uri: pvc://model-storage/path/to/model
```

### HTTP/HTTPS URLs
```yaml
spec:
  predictor:
    model:
      storage:
        uri: https://my-server.com/models/my-model.tar.gz
```

## Advanced Configuration

### Resource Requirements
```yaml
spec:
  predictor:
    model:
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2"
          memory: "4Gi"
```

### Auto Scaling
```yaml
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 10
    scaleTarget: 70  # Target CPU utilization percentage
```

### Environment Variables
```yaml
spec:
  predictor:
    model:
      env:
      - name: MODEL_NAME
        value: "my-model"
      - name: BATCH_SIZE
        value: "32"
```

### Service Account and Security
```yaml
spec:
  predictor:
    serviceAccountName: model-serving-account
    model:
      runtimeVersion: "0.11.0"
```

## Complete ModelCar Example

Here's a comprehensive example deploying a scikit-learn model:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: fraud-detection-model
  namespace: fraud-detection
  labels:
    app: fraud-detection
    version: v1.0
  annotations:
    serving.kserve.io/deploymentMode: "Serverless"
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 5
    scaleTarget: 70
    model:
      modelFormat:
        name: sklearn
      runtime: kserve-sklearnserver
      runtimeVersion: "0.11.0"
      storage:
        uri: s3://ml-models/fraud-detection/v1.0/
        storageSpec:
          s3:
            secretKey: aws-credentials
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2"
          memory: "4Gi"
      env:
      - name: MODEL_NAME
        value: "fraud-detection"
      - name: LOG_LEVEL
        value: "INFO"
    serviceAccountName: fraud-detection-sa
    imagePullSecrets:
    - name: registry-credentials
```

## Deployment and Management

### Deploying a ModelCar
```bash
# Apply the ModelCar configuration
oc apply -f modelcar.yaml

# Check deployment status
oc get modelcar fraud-detection-model

# Watch the deployment process
oc get modelcar fraud-detection-model --watch
```

### Checking Model Status
```bash
# Get detailed status
oc describe modelcar fraud-detection-model

# Check predictor pods
oc get pods -l serving.kserve.io/inferenceservice=fraud-detection-model

# View logs
oc logs -l serving.kserve.io/inferenceservice=fraud-detection-model
```

### Accessing the Model
```bash
# Get the model endpoint
oc get route fraud-detection-model-predictor

# Get service details
oc get service fraud-detection-model-predictor

# Test the model endpoint
MODEL_URL=$(oc get route fraud-detection-model-predictor -o jsonpath='{.spec.host}')
curl -X POST "https://$MODEL_URL/v1/models/fraud-detection:predict" \
     -H "Content-Type: application/json" \
     -d '{"instances": [[1.0, 2.0, 3.0, 4.0]]}'
```

## Model Testing and Validation

### Inference Request Examples

**Classification Model:**
```bash
curl -X POST "$MODEL_URL/v1/models/my-model:predict" \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [
      [5.1, 3.5, 1.4, 0.2],
      [6.7, 3.1, 4.4, 1.4]
    ]
  }'
```

**Regression Model:**
```bash
curl -X POST "$MODEL_URL/v1/models/my-model:predict" \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [
      {"feature1": 1.0, "feature2": 2.0, "feature3": 3.0}
    ]
  }'
```

### Health Checks
```bash
# Check model readiness
curl "$MODEL_URL/v1/models/my-model"

# Check server health
curl "$MODEL_URL/v1/health/ready"
```

## Monitoring and Observability

### Viewing Metrics
```bash
# Check resource usage
oc top pods -l serving.kserve.io/inferenceservice=fraud-detection-model

# Get events
oc get events --field-selector involvedObject.name=fraud-detection-model
```

### Common Status Conditions
- **PredictorReady** - Model is loaded and ready to serve
- **IngressReady** - Ingress/Route is configured
- **Ready** - Overall service is ready

## Troubleshooting

### Common Issues

**Model fails to load:**
```bash
# Check storage accessibility
oc describe modelcar my-model | grep -A 10 "Storage"

# Verify secrets
oc get secret aws-credentials -o yaml
```

**Pod crashes or restarts:**
```bash
# Check resource limits
oc describe modelcar my-model | grep -A 5 "Resources"

# View pod logs
oc logs -l serving.kserve.io/inferenceservice=my-model --previous
```

**Inference requests fail:**
```bash
# Check service and route configuration
oc get svc,route -l serving.kserve.io/inferenceservice=my-model

# Test internal connectivity
oc run debug --image=curlimages/curl --rm -it -- \
  curl http://my-model-predictor/v1/models/my-model
```

## Best Practices

### Model Organization
- Use consistent naming conventions
- Tag models with versions and environments
- Store model artifacts in versioned locations

### Resource Management
- Set appropriate resource requests and limits
- Configure auto-scaling based on expected load
- Use node selectors for GPU requirements

### Security
- Use service accounts with minimal required permissions
- Store credentials in Kubernetes secrets
- Enable mTLS for production deployments

### Performance
- Choose appropriate serving runtimes for your model type
- Optimize model format (e.g., TensorRT for NVIDIA GPUs)
- Monitor and tune scaling parameters

## Next Steps

- [Examples](examples) - Complete deployment scenarios
- [Kubernetes API Basics](kubernetes-api) - Understanding the underlying APIs