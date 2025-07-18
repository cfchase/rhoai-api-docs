---
layout: page
title: Setting Up PVCs for Model Storage
parent: Useful Extras
nav_order: 1
permalink: /docs/extras/model-pvc-setup/
---

# Setting Up PVCs for Model Storage

This guide explains how to create and configure Persistent Volume Claims (PVCs) for storing large language models that can be served by OpenShift AI. Using PVCs allows you to store models on shared storage and serve them across multiple deployments.

## Overview

PVC-based model storage is useful when you:
- Have models stored on shared file systems
- Need to modify or customize model files
- Want to avoid downloading models from external sources repeatedly
- Require ReadWriteMany (RWX) access for multiple pods

## Prerequisites

- Access to a Kubernetes/OpenShift cluster
- Storage class that supports RWX access mode (e.g., NFS, CephFS, GlusterFS)
- Sufficient storage quota for your models (LLMs can be 10-100+ GB)
- `kubectl` or `oc` CLI tool configured

## Creating a PVC for Model Storage

### Step 1: Determine Storage Requirements

First, check available storage classes that support RWX:

```bash
# List storage classes
kubectl get storageclass

# Check which support RWX (look for "ReadWriteMany" in the output)
kubectl describe storageclass <storage-class-name>
```

### Step 2: Create the PVC

Create a PVC with sufficient capacity for your models:

```yaml
# model-storage-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: model-pvc
  namespace: my-namespace
  labels:
    app: model-storage
    purpose: llm-serving
spec:
  accessModes:
    - ReadWriteMany  # Required for multiple pod access
  resources:
    requests:
      storage: 100Gi  # Adjust based on model size
  storageClassName: nfs-storage  # Replace with your RWX storage class
```

Apply the PVC:
```bash
kubectl apply -f model-storage-pvc.yaml -n my-namespace
```

Verify PVC is bound:
```bash
kubectl get pvc model-pvc -n my-namespace

# Expected output:
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
model-pvc   Bound    pvc-12345678-abcd-efgh-ijkl-123456789012   100Gi      RWX            nfs-storage    1m
```

## Downloading Models to PVC

### Method 1: Using a Job to Download Models

Create a Kubernetes Job to download models directly to the PVC:

```yaml
# download-model-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: download-llama-model
  namespace: my-namespace
spec:
  template:
    spec:
      containers:
      - name: downloader
        image: python:3.11-slim
        command: ["/bin/bash", "-c"]
        args:
          - |
            # Install required tools
            pip install huggingface-hub
            
            # Download model to PVC
            python -c "
            from huggingface_hub import snapshot_download
            
            # Download Llama-2-7B model
            snapshot_download(
                repo_id='meta-llama/Llama-2-7b-chat-hf',
                local_dir='/models/llama-2-7b-chat',
                local_dir_use_symlinks=False,
                token='YOUR_HF_TOKEN'  # Replace with your Hugging Face token
            )
            "
            
            echo "Model download complete!"
            ls -la /models/llama-2-7b-chat/
        volumeMounts:
        - name: model-storage
          mountPath: /models
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
      volumes:
      - name: model-storage
        persistentVolumeClaim:
          claimName: model-pvc
      restartPolicy: Never
  backoffLimit: 2
```

Run the job:
```bash
kubectl apply -f download-model-job.yaml -n my-namespace

# Monitor progress
kubectl logs -f job/download-llama-model -n my-namespace
```

### Method 2: Using a Temporary Pod

Create a temporary pod to manually download or copy models:

```yaml
# model-setup-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: model-setup
  namespace: my-namespace
spec:
  containers:
  - name: setup
    image: python:3.11
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: model-storage
      mountPath: /models
    resources:
      requests:
        memory: "4Gi"
        cpu: "2"
  volumes:
  - name: model-storage
    persistentVolumeClaim:
      claimName: model-pvc
```

Deploy and access the pod:
```bash
# Create the pod
kubectl apply -f model-setup-pod.yaml -n my-namespace

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/model-setup -n my-namespace

# Access the pod
kubectl exec -it model-setup -n my-namespace -- bash

# Inside the pod, download models
pip install huggingface-hub
python -c "from huggingface_hub import snapshot_download; snapshot_download('meta-llama/Llama-2-7b-chat-hf', local_dir='/models/llama-2-7b-chat', local_dir_use_symlinks=False)"

# Exit and delete the pod when done
exit
kubectl delete pod model-setup -n my-namespace
```

### Method 3: Copying from Local Machine

If you have models locally, copy them to the PVC:

```bash
# Create a temporary pod with the PVC mounted
kubectl run model-copy --image=busybox --restart=Never --rm -i --tty \
  --overrides='{"spec":{"volumes":[{"name":"model-storage","persistentVolumeClaim":{"claimName":"model-pvc"}}],"containers":[{"name":"model-copy","volumeMounts":[{"name":"model-storage","mountPath":"/models"}]}]}}' \
  -n my-namespace -- sh

# In another terminal, copy files to the pod
kubectl cp /local/path/to/model my-namespace/model-copy:/models/my-model

# The pod will automatically be deleted when you exit
```

## Verifying Model Files

Check that models are correctly stored on the PVC:

```bash
# Create a debug pod to inspect the PVC
kubectl run pvc-inspector --image=busybox --restart=Never --rm -i --tty \
  --overrides='{"spec":{"volumes":[{"name":"model-storage","persistentVolumeClaim":{"claimName":"model-pvc"}}],"containers":[{"name":"pvc-inspector","volumeMounts":[{"name":"model-storage","mountPath":"/models"}]}]}}' \
  -n my-namespace -- sh

# Inside the pod
ls -la /models/
du -sh /models/*
```

## Using PVC Storage in InferenceService

Once models are stored on the PVC, reference them in your InferenceService:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-model
  namespace: my-namespace
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: llama-runtime
      # Reference the PVC and model path
      storageUri: 'pvc://model-pvc/llama-2-7b-chat'
      resources:
        requests:
          nvidia.com/gpu: '1'
        limits:
          nvidia.com/gpu: '1'
```

## Best Practices

### Storage Sizing

- **Small models (< 10GB)**: 50Gi PVC
- **Medium models (10-50GB)**: 100Gi PVC
- **Large models (> 50GB)**: 200Gi+ PVC
- Add 20% overhead for temporary files and caching

### Access Modes

- Use **ReadWriteMany (RWX)** for:
  - Serving models from multiple pods
  - Updating models without downtime
  - Shared model repositories

- Use **ReadWriteOnce (RWO)** only if:
  - Single pod deployment
  - Cost is a major concern
  - RWX is not available

### Organization

Structure your models on the PVC:
```
/models/
├── llama-2-7b-chat/
│   ├── config.json
│   ├── model.safetensors
│   └── tokenizer.json
├── granite-3-1-8b/
│   └── ...
└── mistral-7b/
    └── ...
```

### Performance Considerations

1. **Storage Class**: Choose high-performance storage for production
2. **Caching**: Models are loaded into memory, so initial load time is most important
3. **Network**: Ensure good network connectivity between nodes and storage

## Troubleshooting

### PVC Won't Bind

```bash
# Check PVC events
kubectl describe pvc model-pvc -n my-namespace

# Common issues:
# - No storage class supports RWX
# - Insufficient quota
# - Storage class doesn't exist
```

### Model Loading Errors

```bash
# Check InferenceService logs
kubectl logs -l serving.kserve.io/inferenceservice=your-model -n my-namespace

# Common issues:
# - Wrong path in storageUri
# - Missing model files
# - Incorrect permissions
```

### Slow Model Loading

- Check storage performance: `kubectl exec -it <pod> -- dd if=/models/test of=/dev/null bs=1M count=1000`
- Consider using higher performance storage class
- Ensure nodes have good network connectivity to storage

## Related Resources

- [Serving Large Language Models](/docs/serving/llms/)
- [Data Connections](/docs/data-connections/)
- [Kubernetes Persistent Volumes Documentation](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)