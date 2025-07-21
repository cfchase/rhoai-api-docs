---
layout: page
title: Pipeline Setup
parent: Pipelines
nav_order: 1
permalink: /docs/pipelines/setup/
---

# Enabling Data Science Pipelines

The DataSciencePipelinesApplication (DSPA) resource enables Data Science Pipeline capabilities in your Red Hat OpenShift AI namespace. By deploying a DSPA, you set up the infrastructure needed to create and run machine learning workflows using Kubeflow Pipelines.

## Overview

A DataSciencePipelinesApplication (DSPA) deploys and manages the infrastructure components required for running ML pipelines in your namespace, including:
- Pipeline API server
- Pipeline scheduler
- Pipeline persistence agent
- Metadata storage (MariaDB)
- Object storage (Minio)
- ML pipeline UI

**Prerequisites:**
- OpenShift AI operator installed
- A data science project (namespace with `opendatahub.io/dashboard: 'true'` label)
- Sufficient resources for pipeline components

## Creating a Basic DSPA

This example deploys a simple, self-contained pipeline infrastructure with built-in object storage:

```yaml
# dspa-basic.yaml
apiVersion: datasciencepipelinesapplications.opendatahub.io/v1
kind: DataSciencePipelinesApplication
metadata:
  name: dspa                             # DSPA instance name
  namespace: my-ds-project               # Must be in a data science project
spec:
  dspVersion: v2                         # Use Kubeflow Pipelines v2
  apiServer:
    enableSamplePipeline: true           # Include sample pipelines for testing
  objectStorage:
    enableExternalRoute: true            # Enable artifact download links
    minio:
      deploy: true                       # Deploy built-in Minio storage
      image: 'quay.io/opendatahub/minio:RELEASE.2019-08-14T20-37-41Z-license-compliance'
  mlpipelineUI:
    image: quay.io/opendatahub/ds-pipelines-frontend:latest  # Pipeline UI
```

Apply the configuration:
```bash
kubectl apply -f dspa-basic.yaml
```

## Verifying the Deployment

Check that the DSPA is ready:
```bash
# Check DSPA status
kubectl get dspa dspa

# Watch deployment progress
kubectl get dspa dspa -w

# Check all pipeline pods are running
kubectl get pods -l component=data-science-pipelines
```

## Next Steps

After enabling pipeline infrastructure:
1. Access the Pipelines section through the OpenShift AI dashboard
2. Create pipeline definitions using the KFP SDK or visual tools
3. Upload and run your ML pipelines
4. Monitor pipeline runs and view artifacts

## Related Resources

- [Data Science Projects](/docs/projects/) - Create projects before enabling pipeline infrastructure
- [Kubeflow Pipelines Documentation](https://www.kubeflow.org/docs/components/pipelines/)
- [OpenShift AI Pipeline Guide](https://docs.redhat.com/en/documentation/red_hat_openshift_ai/)