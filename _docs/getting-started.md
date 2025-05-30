---
layout: page
title: Getting Started
permalink: /docs/getting-started/
---

# Getting Started with OpenShift AI Kubernetes API

This guide helps you set up your environment to work with OpenShift AI resources using the Kubernetes API.

## Prerequisites

### Required Components

1. **OpenShift Cluster** with OpenShift AI operator installed
2. **Kubernetes CLI** (`kubectl` or `oc`)
3. **Cluster Access** with appropriate permissions

### Required Permissions

Your user or service account needs permissions to:
- Create and manage custom resources in OpenShift AI namespaces
- Access the `opendatahub.io` and `serving.kserve.io` API groups
- Manage deployments, services, and routes

## Installation Verification

### Check OpenShift AI Operator

```bash
# Verify the OpenShift AI operator is installed
oc get csv -n openshift-operators | grep rhods

# Check DataScienceCluster status
oc get datasciencecluster -n opendatahub
```

### Verify API Resources

```bash
# List available OpenShift AI custom resources
oc api-resources | grep opendatahub

# Check ModelCar CRD availability
oc get crd modelcars.serving.kserve.io
```

Expected output should include resources like:
- `datascienceclusters.opendatahub.io`
- `notebooks.kubeflow.org`
- `modelcars.serving.kserve.io`

## Setting Up Your Workspace

### Create a Project/Namespace

```bash
# Create a new project for your data science work
oc new-project my-datascience-project

# Or use kubectl to create a namespace
kubectl create namespace my-datascience-project
```

### Configure CLI Context

```bash
# Set your current context to the new project
oc project my-datascience-project

# Or with kubectl
kubectl config set-context --current --namespace=my-datascience-project
```

## Basic Resource Discovery

### Explore Available Resources

```bash
# Get all OpenShift AI related custom resources
oc get crd | grep -E "(opendatahub|kubeflow|serving)"

# Describe a specific resource to understand its schema
oc describe crd datascienceclusters.opendatahub.io
```

### Check Existing Resources

```bash
# List existing DataScienceCluster configurations
oc get datasciencecluster -A

# Check for existing notebooks
oc get notebooks -A

# Look for any existing ModelCars
oc get modelcars -A
```

## Authentication and Access

### Service Account Setup (Optional)

For programmatic access, create a service account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: datascience-api-user
  namespace: my-datascience-project
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: datascience-api-access
  namespace: my-datascience-project
subjects:
- kind: ServiceAccount
  name: datascience-api-user
  namespace: my-datascience-project
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

Apply the service account configuration:

```bash
oc apply -f service-account.yaml
```

## Next Steps

Now that your environment is set up:

1. **Learn the API Structure** - Continue to [Kubernetes API Basics](kubernetes-api)
2. **Deploy Your First Model** - Jump to [ModelCar Serving](modelcar-serving)
3. **Explore Examples** - Check out [Complete Examples](examples)

## Troubleshooting

### Common Issues

**"No resources found" errors:**
- Verify OpenShift AI operator is installed and running
- Check that you're in the correct namespace/project
- Ensure you have proper RBAC permissions

**CRD not found:**
- Confirm OpenShift AI version supports the resource
- Check if the operator installation completed successfully

**Permission denied:**
- Verify your user has cluster-admin or appropriate project permissions
- Check role bindings for your user or service account