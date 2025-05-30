---
layout: page
title: Complete Examples
permalink: /docs/examples/
---

# Complete Examples

This section provides end-to-end examples for common OpenShift AI scenarios using Kubernetes APIs.

## Example 1: Complete ML Pipeline Setup

### Project Setup and Storage

```yaml
# 1. Create namespace
apiVersion: v1
kind: Namespace
metadata:
  name: ml-pipeline-demo
  labels:
    opendatahub.io/dashboard: "true"
---
# 2. Create storage for data and models
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-storage
  namespace: ml-pipeline-demo
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: ocs-storagecluster-cephfs
---
# 3. AWS S3 credentials for model storage
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: ml-pipeline-demo
type: Opaque
data:
  AWS_ACCESS_KEY_ID: <base64-encoded-key>
  AWS_SECRET_ACCESS_KEY: <base64-encoded-secret>
---
# 4. Service account for model serving
apiVersion: v1
kind: ServiceAccount
metadata:
  name: model-serving-sa
  namespace: ml-pipeline-demo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: model-serving-rb
  namespace: ml-pipeline-demo
subjects:
- kind: ServiceAccount
  name: model-serving-sa
  namespace: ml-pipeline-demo
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

### Data Science Workbench

```yaml
# Development notebook for model training
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: ml-workbench
  namespace: ml-pipeline-demo
  labels:
    app: ml-workbench
    opendatahub.io/dashboard: "true"
spec:
  template:
    spec:
      serviceAccountName: model-serving-sa
      containers:
      - name: ml-workbench
        image: quay.io/opendatahub/workbench-images:jupyter-datascience-notebook-python-3.9-2023a-20230507
        ports:
        - containerPort: 8888
          name: notebook-port
          protocol: TCP
        resources:
          requests:
            cpu: "1"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
        env:
        - name: JUPYTER_ENABLE_LAB
          value: "yes"
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: AWS_ACCESS_KEY_ID
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: AWS_SECRET_ACCESS_KEY
        volumeMounts:
        - name: workbench-storage
          mountPath: /opt/app-root/src
        - name: shared-data
          mountPath: /opt/app-root/src/data
      volumes:
      - name: workbench-storage
        persistentVolumeClaim:
          claimName: ml-workbench-storage
      - name: shared-data
        persistentVolumeClaim:
          claimName: shared-storage
---
# Storage for notebook workspace
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ml-workbench-storage
  namespace: ml-pipeline-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

### Model Deployment

```yaml
# Deploy trained model using ModelCar
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: fraud-detection
  namespace: ml-pipeline-demo
  labels:
    app: fraud-detection
    version: "1.0"
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 10
    scaleTarget: 70
    serviceAccountName: model-serving-sa
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
          memory: "2Gi"
        limits:
          cpu: "2"
          memory: "4Gi"
      env:
      - name: MODEL_NAME
        value: "fraud-detection"
```

### Deployment Script

```bash
#!/bin/bash
# deploy-ml-pipeline.sh

# Apply all resources
echo "Creating ML Pipeline Demo..."
oc apply -f - <<EOF
$(cat examples/ml-pipeline/*.yaml)
EOF

# Wait for notebook to be ready
echo "Waiting for workbench to be ready..."
oc wait --for=condition=Ready notebook/ml-workbench -n ml-pipeline-demo --timeout=300s

# Wait for model to be ready
echo "Waiting for model to be ready..."
oc wait --for=condition=Ready modelcar/fraud-detection -n ml-pipeline-demo --timeout=600s

# Get access information
echo "=== Access Information ==="
echo "Notebook URL: $(oc get route ml-workbench -n ml-pipeline-demo -o jsonpath='{.spec.host}')"
echo "Model Endpoint: $(oc get route fraud-detection-predictor -n ml-pipeline-demo -o jsonpath='{.spec.host}')"
```

## Example 2: Multi-Model Serving Setup

```yaml
# A/B Testing with multiple model versions
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: recommendation-v1
  namespace: ml-pipeline-demo
  labels:
    model: recommendation
    version: v1
spec:
  predictor:
    minReplicas: 2
    maxReplicas: 5
    model:
      modelFormat:
        name: tensorflow
      runtime: kserve-tensorflow-serving
      storage:
        uri: s3://ml-models/recommendation/v1/
      resources:
        requests:
          cpu: "1"
          memory: "2Gi"
---
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: recommendation-v2
  namespace: ml-pipeline-demo
  labels:
    model: recommendation
    version: v2
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 3
    model:
      modelFormat:
        name: tensorflow
      runtime: kserve-tensorflow-serving
      storage:
        uri: s3://ml-models/recommendation/v2/
      resources:
        requests:
          cpu: "1"
          memory: "2Gi"
---
# Load balancer for A/B testing
apiVersion: v1
kind: Service
metadata:
  name: recommendation-lb
  namespace: ml-pipeline-demo
spec:
  selector:
    app: recommendation-router
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recommendation-router
  namespace: ml-pipeline-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: recommendation-router
  template:
    metadata:
      labels:
        app: recommendation-router
    spec:
      containers:
      - name: router
        image: nginx:alpine
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: router-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: router-config
  namespace: ml-pipeline-demo
data:
  default.conf: |
    upstream recommendation_v1 {
        server recommendation-v1-predictor:80 weight=80;
    }
    
    upstream recommendation_v2 {
        server recommendation-v2-predictor:80 weight=20;
    }
    
    server {
        listen 8080;
        
        location /v1 {
            proxy_pass http://recommendation_v1;
        }
        
        location /v2 {
            proxy_pass http://recommendation_v2;
        }
        
        location / {
            # 80/20 split for A/B testing
            if ($arg_version = "v2") {
                proxy_pass http://recommendation_v2;
            }
            proxy_pass http://recommendation_v1;
        }
    }
```

## Example 3: GPU Model Serving

```yaml
# NVIDIA GPU-accelerated model serving
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: llm-model
  namespace: ml-pipeline-demo
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 2
    model:
      modelFormat:
        name: pytorch
      runtime: kserve-torchserve
      storage:
        uri: s3://ml-models/llm/pytorch-model/
      resources:
        requests:
          cpu: "2"
          memory: "8Gi"
          nvidia.com/gpu: "1"
        limits:
          cpu: "4"
          memory: "16Gi"
          nvidia.com/gpu: "1"
      env:
      - name: TORCH_DEVICE
        value: "cuda"
    nodeSelector:
      accelerator: nvidia-tesla-v100
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
```

## Example 4: Custom Runtime with Model Ensemble

```yaml
# Custom model ensemble serving
apiVersion: serving.kserve.io/v1beta1
kind: ModelCar
metadata:
  name: ensemble-model
  namespace: ml-pipeline-demo
spec:
  predictor:
    containers:
    - name: ensemble-server
      image: my-registry/ensemble-server:v1.0
      ports:
      - containerPort: 8080
        protocol: TCP
      env:
      - name: MODEL_STORAGE_URI
        value: "s3://ml-models/ensemble/"
      - name: SKLEARN_MODEL_PATH
        value: "/models/sklearn/model.pkl"
      - name: XGBOOST_MODEL_PATH
        value: "/models/xgboost/model.json"
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: AWS_ACCESS_KEY_ID
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: AWS_SECRET_ACCESS_KEY
      resources:
        requests:
          cpu: "1"
          memory: "4Gi"
        limits:
          cpu: "2"
          memory: "8Gi"
      volumeMounts:
      - name: model-cache
        mountPath: /models
    volumes:
    - name: model-cache
      emptyDir:
        sizeLimit: 10Gi
    initContainers:
    - name: model-fetcher
      image: amazon/aws-cli:latest
      command:
      - sh
      - -c
      - |
        aws s3 sync s3://ml-models/ensemble/ /models/
      env:
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: AWS_ACCESS_KEY_ID
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: AWS_SECRET_ACCESS_KEY
      volumeMounts:
      - name: model-cache
        mountPath: /models
```

## Example 5: Model Monitoring and Alerting

```yaml
# ServiceMonitor for Prometheus scraping
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: modelcar-metrics
  namespace: ml-pipeline-demo
spec:
  selector:
    matchLabels:
      serving.kserve.io/inferenceservice: fraud-detection
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
---
# PrometheusRule for alerting
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: modelcar-alerts
  namespace: ml-pipeline-demo
spec:
  groups:
  - name: modelcar.rules
    rules:
    - alert: ModelCarHighErrorRate
      expr: rate(kserve_request_duration_seconds_count{code!="200"}[5m]) > 0.1
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High error rate for ModelCar {{ $labels.model }}"
        description: "Error rate is {{ $value }} errors per second"
    
    - alert: ModelCarHighLatency
      expr: histogram_quantile(0.95, rate(kserve_request_duration_seconds_bucket[5m])) > 1.0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High latency for ModelCar {{ $labels.model }}"
        description: "95th percentile latency is {{ $value }} seconds"
```

## Testing Examples

### Model Inference Testing

```bash
#!/bin/bash
# test-model-inference.sh

MODEL_URL="https://$(oc get route fraud-detection-predictor -n ml-pipeline-demo -o jsonpath='{.spec.host}')"

# Test data
TEST_DATA='{
  "instances": [
    [1.0, 2.5, 3.2, 0.8, 1.5],
    [2.1, 1.8, 2.9, 1.2, 2.0]
  ]
}'

echo "Testing model inference..."
curl -X POST "$MODEL_URL/v1/models/fraud-detection:predict" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d "$TEST_DATA" \
     -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
```

### Load Testing

```bash
#!/bin/bash
# load-test.sh

MODEL_URL="https://$(oc get route fraud-detection-predictor -n ml-pipeline-demo -o jsonpath='{.spec.host}')"

# Install hey if not available
# go install github.com/rakyll/hey@latest

echo "Running load test..."
hey -n 1000 -c 10 -m POST \
    -H "Content-Type: application/json" \
    -d '{"instances": [[1.0, 2.0, 3.0, 4.0, 5.0]]}' \
    "$MODEL_URL/v1/models/fraud-detection:predict"
```

## Cleanup Scripts

```bash
#!/bin/bash
# cleanup.sh

echo "Cleaning up ML Pipeline Demo..."

# Delete ModelCars
oc delete modelcar --all -n ml-pipeline-demo

# Delete notebooks
oc delete notebook --all -n ml-pipeline-demo

# Delete PVCs
oc delete pvc --all -n ml-pipeline-demo

# Delete secrets (optional)
# oc delete secret aws-credentials -n ml-pipeline-demo

# Delete namespace (removes everything)
# oc delete namespace ml-pipeline-demo

echo "Cleanup complete!"
```

## Quick Reference Commands

```bash
# Deployment
oc apply -k examples/ml-pipeline/

# Status checking
oc get modelcar,notebook,pvc -n ml-pipeline-demo

# Logs
oc logs -l serving.kserve.io/inferenceservice=fraud-detection -n ml-pipeline-demo

# Scaling
oc patch modelcar fraud-detection -n ml-pipeline-demo --patch '{"spec":{"predictor":{"maxReplicas":20}}}'

# Port forwarding for local testing
oc port-forward svc/fraud-detection-predictor 8080:80 -n ml-pipeline-demo
```

These examples demonstrate real-world patterns for deploying and managing machine learning workloads on OpenShift AI using Kubernetes APIs and ModelCars.