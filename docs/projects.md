---
layout: page
title: Projects
nav_order: 2
permalink: /docs/projects/
---

# Data Science Projects

Data Science Projects in Red Hat OpenShift AI provide isolated environments for organizing your machine learning work. These projects are OpenShift projects (Kubernetes namespaces) with specific labels and annotations that enable integration with the OpenShift AI dashboard and features.

## Overview

A data science project is essentially an OpenShift project with the label `opendatahub.io/dashboard: 'true'`. This label makes the project visible in the OpenShift AI dashboard and enables AI/ML-specific features like:
- Workbench creation (Jupyter notebooks)
- Data connections
- Model serving
- Pipeline management
- Persistent storage

## Creating Projects

### Method 1: Declarative (Using YAML)

The declarative approach uses YAML files to define the desired state of your project. This method is recommended for:
- Version control and GitOps workflows
- Reproducible deployments
- Automated provisioning

#### Basic Project

```yaml
# project-basic.yaml
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: my-ds-project
  labels:
    # Required: Makes project visible in OpenShift AI dashboard
    opendatahub.io/dashboard: 'true'
    # Automatically added: Matches the project name
    kubernetes.io/metadata.name: my-ds-project
  annotations:
    # Human-readable display name shown in the dashboard
    openshift.io/display-name: My Data Science Project
    # Optional: Project description
    openshift.io/description: 'Project for machine learning experiments'
spec: {}
```

Apply the project:
```bash
kubectl apply -f project-basic.yaml
```

#### Standard Project with Common Annotations

```yaml
# project-standard.yaml
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: ml-fraud-detection
  labels:
    # Required for OpenShift AI
    opendatahub.io/dashboard: 'true'
    kubernetes.io/metadata.name: ml-fraud-detection
    # Optional: Custom labels for organization
    team: data-science
    environment: development
    project-type: ml-experiment
  annotations:
    openshift.io/display-name: Fraud Detection ML
    openshift.io/description: 'Machine learning models for credit card fraud detection'
    # Optional: Who requested/owns the project
    openshift.io/requester: john.doe@example.com
    # Optional: Project documentation link
    project.docs.url: 'https://wiki.example.com/fraud-detection'
spec: {}
```

#### Advanced Project with Resource Quotas

```yaml
# project-advanced.yaml
apiVersion: v1
kind: List
items:
  # The Project
  - apiVersion: project.openshift.io/v1
    kind: Project
    metadata:
      name: production-ml-models
      labels:
        opendatahub.io/dashboard: 'true'
        kubernetes.io/metadata.name: production-ml-models
        environment: production
        compliance: pci-dss
      annotations:
        openshift.io/display-name: Production ML Models
        openshift.io/description: 'Production-ready ML models with resource limits'
        openshift.io/requester: ml-ops-team@example.com
    spec: {}
  
  # Resource Quota (applied after project creation)
  - apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: compute-quota
      namespace: production-ml-models
    spec:
      hard:
        requests.cpu: "100"
        requests.memory: 200Gi
        requests.storage: 1Ti
        persistentvolumeclaims: "10"
        pods: "50"
        requests.nvidia.com/gpu: "4"
```

### Method 2: Imperative (Using Commands)

The imperative approach uses `oc` or `kubectl` commands directly. Note that while `kubectl` can create namespaces, the `oc new-project` command provides OpenShift-specific functionality.

#### Using oc (OpenShift CLI)

```bash
# Basic project creation
oc new-project my-ds-project

# With display name and description
oc new-project fraud-detection \
  --display-name="Fraud Detection ML" \
  --description="Machine learning models for fraud detection"

# Add the required label to make it visible in OpenShift AI
oc label project fraud-detection opendatahub.io/dashboard=true
```

#### Using kubectl

```bash
# Create a namespace (project)
kubectl create namespace my-ds-project

# Add required labels
kubectl label namespace my-ds-project opendatahub.io/dashboard=true

# Add annotations
kubectl annotate namespace my-ds-project \
  openshift.io/display-name="My Data Science Project" \
  openshift.io/description="Project for ML experiments"
```

## Listing and Viewing Projects

### List All Projects

```bash
# List all projects
kubectl get projects

# List with additional information
kubectl get projects -o wide

# List only data science projects
kubectl get projects -l opendatahub.io/dashboard=true

# Custom output showing key fields
kubectl get projects -o custom-columns=\
NAME:.metadata.name,\
DISPLAY:.metadata.annotations.openshift\\.io/display-name,\
STATUS:.status.phase
```

### View Specific Project

```bash
# Get project details
kubectl get project my-ds-project

# Get detailed description
kubectl describe project my-ds-project

# Get project in YAML format
kubectl get project my-ds-project -o yaml

# Get project in JSON format (useful for parsing)
kubectl get project my-ds-project -o json
```

### Filter Projects

```bash
# List projects by label
kubectl get projects -l team=data-science

# List projects by multiple labels
kubectl get projects -l opendatahub.io/dashboard=true,environment=production

# List projects with specific annotation (using jsonpath)
kubectl get projects -o jsonpath='{.items[?(@.metadata.annotations.openshift\.io/requester=="john.doe@example.com")].metadata.name}'
```

## Updating Projects

### Using kubectl apply (Declarative)

Modify your YAML file and reapply:
```bash
kubectl apply -f project-updated.yaml
```

### Using kubectl edit (Interactive)

```bash
# Opens project in your default editor
kubectl edit project my-ds-project
```

### Using kubectl patch

#### Update Annotations

```bash
# Add or update single annotation
kubectl annotate project my-ds-project \
  openshift.io/description="Updated ML project description" \
  --overwrite

# Add multiple annotations
kubectl annotate project my-ds-project \
  project.version="2.0" \
  project.owner="ml-team@example.com" \
  --overwrite

# Remove an annotation
kubectl annotate project my-ds-project project.version-
```

#### Update Labels

```bash
# Add or update labels
kubectl label project my-ds-project \
  environment=staging \
  compliance=hipaa \
  --overwrite

# Remove a label
kubectl label project my-ds-project compliance-
```

#### Using JSON Patch

```bash
# Update display name using JSON patch
kubectl patch project my-ds-project --type='json' \
  -p='[{"op": "replace", "path": "/metadata/annotations/openshift.io~1display-name", "value": "New Display Name"}]'

# Add multiple labels using merge patch
kubectl patch project my-ds-project --type='merge' \
  -p='{"metadata":{"labels":{"tier":"gpu-compute","cost-center":"ml-research"}}}'
```

## Deleting Projects

### Basic Deletion

```bash
# Delete a specific project
kubectl delete project my-ds-project

# Delete using YAML file
kubectl delete -f project.yaml

# Force deletion (use with caution)
kubectl delete project my-ds-project --force --grace-period=0
```

### Important Notes on Deletion

1. **Project deletion is irreversible** - All resources within the project will be deleted
2. **Terminating state** - Projects enter a "Terminating" state before complete removal
3. **Finalizers** - Some resources may have finalizers that prevent immediate deletion
4. **PVCs** - PersistentVolumeClaims might retain data depending on reclaim policy

### Check Deletion Status

```bash
# Monitor project deletion
kubectl get project my-ds-project -w

# Check for resources preventing deletion
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n 1 kubectl get --show-kind --ignore-not-found -n my-ds-project
```

## Practical Examples

### Example 1: Create a Complete Data Science Project

```bash
# Create project YAML
cat <<EOF > datascience-project.yaml
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: customer-churn-analysis
  labels:
    opendatahub.io/dashboard: 'true'
    kubernetes.io/metadata.name: customer-churn-analysis
    project-type: ml-classification
    team: customer-analytics
    cost-center: marketing
  annotations:
    openshift.io/display-name: Customer Churn Analysis
    openshift.io/description: 'ML models to predict customer churn using historical data'
    openshift.io/requester: sarah.chen@example.com
    project.start-date: '2024-01-15'
    project.ml-framework: 'pytorch,scikit-learn'
spec: {}
EOF

# Apply the project
kubectl apply -f datascience-project.yaml

# Verify creation
kubectl get project customer-churn-analysis
```

### Example 2: Migrate Existing Project to Data Science

```bash
# Add data science label to existing project
kubectl label project existing-project opendatahub.io/dashboard=true

# Update annotations for better organization
kubectl annotate project existing-project \
  openshift.io/display-name="Migrated ML Project" \
  openshift.io/description="Legacy project now enabled for OpenShift AI" \
  migration.date="$(date +%Y-%m-%d)" \
  --overwrite
```

### Example 3: Bulk Operations on Projects

```bash
# Add cost tracking label to all data science projects
kubectl get projects -l opendatahub.io/dashboard=true -o name | \
  xargs -I {} kubectl label {} cost-tracking=enabled --overwrite

# Export all data science projects
kubectl get projects -l opendatahub.io/dashboard=true -o yaml > all-ds-projects.yaml

# List projects with their descriptions
kubectl get projects -l opendatahub.io/dashboard=true \
  -o custom-columns=NAME:.metadata.name,DESCRIPTION:.metadata.annotations.openshift\\.io/description
```

## Verification and Troubleshooting

### Verify Project in OpenShift AI Dashboard

1. Check the label is present:
```bash
kubectl get project my-ds-project -o jsonpath='{.metadata.labels.opendatahub\.io/dashboard}'
```

2. Verify project appears in dashboard (via API):
```bash
# List all projects visible to OpenShift AI
kubectl get projects -l opendatahub.io/dashboard=true
```

### Common Issues and Solutions

#### Project Not Visible in Dashboard

```bash
# Check if label exists
kubectl get project my-ds-project --show-labels

# Add missing label
kubectl label project my-ds-project opendatahub.io/dashboard=true --overwrite
```

#### Permission Denied

```bash
# Check your permissions
kubectl auth can-i create projects

# Check specific project access
kubectl auth can-i get project my-ds-project
```

#### Project Stuck in Terminating

```bash
# Check what's preventing deletion
kubectl get all -n my-ds-project

# Check for finalizers
kubectl get project my-ds-project -o jsonpath='{.metadata.finalizers}'

# Remove finalizers if needed (use with caution)
kubectl patch project my-ds-project -p '{"metadata":{"finalizers":[]}}' --type=merge
```

## Best Practices

### Naming Conventions

1. **Use lowercase letters, numbers, and hyphens only**
   - Good: `ml-fraud-detection`, `customer-churn-v2`
   - Bad: `ML_Fraud_Detection`, `Customer.Churn`

2. **Include purpose in the name**
   - Good: `image-classification-prod`, `nlp-sentiment-dev`
   - Bad: `project1`, `test`

3. **Avoid generic names**
   - Use specific, descriptive names that indicate the project's purpose

### Label and Annotation Strategy

1. **Required Labels**
   ```yaml
   labels:
     opendatahub.io/dashboard: 'true'  # Required for OpenShift AI
   ```

2. **Recommended Labels**
   ```yaml
   labels:
     team: data-science              # Team ownership
     environment: development        # dev/staging/production
     project-type: ml-training      # Project category
     cost-center: ml-research       # Cost tracking
   ```

3. **Useful Annotations**
   ```yaml
   annotations:
     openshift.io/display-name: "Human Readable Name"
     openshift.io/description: "Detailed project description"
     openshift.io/requester: "email@example.com"
     project.docs.url: "https://docs.example.com/project"
     project.git.url: "https://github.com/org/repo"
   ```

### Security Considerations

1. **Limit project creation** to authorized users
2. **Use ResourceQuotas** to prevent resource exhaustion
3. **Apply NetworkPolicies** for network isolation
4. **Regular cleanup** of unused projects
5. **Audit project access** periodically

### When to Use Declarative vs Imperative

**Use Declarative (YAML) when:**
- Creating projects in production
- Need version control
- Automating with CI/CD
- Creating multiple related resources
- Need reproducible deployments

**Use Imperative (Commands) when:**
- Quick testing or development
- One-time operations
- Interactive troubleshooting
- Simple label/annotation updates

## Field Reference

| Field Path | Type | Required | Description | Example |
|------------|------|----------|-------------|---------|
| `apiVersion` | string | Yes | API version for Project resource | `project.openshift.io/v1` |
| `kind` | string | Yes | Resource type | `Project` |
| `metadata.name` | string | Yes | Project name (lowercase, hyphens) | `my-ds-project` |
| `metadata.labels` | object | No* | Key-value pairs for organization | `team: data-science` |
| `metadata.labels."opendatahub.io/dashboard"` | string | Yes** | Enable OpenShift AI integration | `'true'` |
| `metadata.labels."kubernetes.io/metadata.name"` | string | Auto | Automatically set to match name | `my-ds-project` |
| `metadata.annotations` | object | No | Non-identifying metadata | See below |
| `metadata.annotations."openshift.io/display-name"` | string | No | Human-readable name | `My Data Science Project` |
| `metadata.annotations."openshift.io/description"` | string | No | Project description | `ML experiments for customer analysis` |
| `metadata.annotations."openshift.io/requester"` | string | No | Project creator/owner | `john.doe@example.com` |
| `spec` | object | Yes | Project specification (usually empty) | `{}` |
| `status` | object | Read-only | Project status (set by system) | N/A |

\* Labels are optional but `opendatahub.io/dashboard` is required for OpenShift AI integration  
\** Required only for data science projects to appear in OpenShift AI dashboard

### Common Custom Annotations

| Annotation | Description | Example |
|------------|-------------|---------|
| `project.version` | Project version tracking | `'1.2.0'` |
| `project.owner` | Project owner/team | `ml-ops-team` |
| `project.docs.url` | Documentation link | `https://wiki.example.com/project` |
| `project.git.url` | Source code repository | `https://github.com/org/repo` |
| `project.jira.key` | Issue tracking reference | `MLOPS-123` |
| `project.start-date` | Project start date | `'2024-01-15'` |
| `project.ml-framework` | ML frameworks used | `tensorflow,pytorch` |
| `project.compliance` | Compliance requirements | `hipaa,pci-dss` |

## Using with Kubernetes MCP Server

If you're using the [Kubernetes MCP server](https://github.com/manusa/kubernetes-mcp-server) for AI-assisted operations, you'll need to adapt some commands since MCP tools work differently than direct kubectl commands.

### MCP Tool Mapping

| kubectl Command | MCP Tool | Parameters |
|----------------|----------|------------|
| `kubectl apply -f project.yaml` | `resources_create_or_update` | Pass YAML content as `resource` |
| `kubectl get projects` | `projects_list` | No parameters needed |
| `kubectl get project <name>` | `resources_get` | `apiVersion`, `kind`, `name` |
| `kubectl get projects -l <label>` | `resources_list` | `apiVersion`, `kind`, `labelSelector` |
| `kubectl delete project <name>` | `resources_delete` | `apiVersion`, `kind`, `name` |

### Creating Projects with MCP

Use the `resources_create_or_update` tool with the YAML content:

```yaml
# Pass this YAML to the resources_create_or_update tool
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: my-ds-project
  labels:
    opendatahub.io/dashboard: 'true'
    kubernetes.io/metadata.name: my-ds-project
  annotations:
    openshift.io/display-name: My Data Science Project
    openshift.io/description: 'Project for ML experiments'
spec: {}
```

### Listing Projects with MCP

```bash
# List all OpenShift projects
# Use: projects_list (no parameters)

# List projects with specific labels
# Use: resources_list with parameters:
apiVersion: project.openshift.io/v1
kind: Project
labelSelector: opendatahub.io/dashboard=true
```

### Getting a Specific Project

```bash
# Use: resources_get with parameters:
apiVersion: project.openshift.io/v1
kind: Project
name: my-ds-project
```

### Updating Projects with MCP

Since MCP doesn't support `kubectl patch` or `kubectl label` directly:

1. **Get the current project** using `resources_get`
2. **Modify the YAML** (add/update labels or annotations)
3. **Apply the updated YAML** using `resources_create_or_update`

Example workflow:
```yaml
# 1. Get current project state
# 2. Modify the returned YAML to add a label:
metadata:
  labels:
    opendatahub.io/dashboard: 'true'
    environment: production  # New label
# 3. Pass modified YAML to resources_create_or_update
```

### Deleting Projects with MCP

```bash
# Use: resources_delete with parameters:
apiVersion: project.openshift.io/v1
kind: Project
name: my-ds-project
```

### MCP Limitations

The following operations from our documentation are not directly supported by MCP:

1. **Interactive editing** (`kubectl edit`) - Use get, modify, and update workflow instead
2. **Direct label/annotation commands** (`kubectl label`, `kubectl annotate`) - Update full resource
3. **JSONPath queries** - MCP returns full resources; filtering happens client-side
4. **Watch operations** (`-w` flag) - Not supported
5. **Custom output columns** - MCP returns standard formats
6. **Imperative namespace creation** - Use declarative YAML approach

### Best Practices for MCP

1. **Use declarative YAML** - This aligns perfectly with MCP's design
2. **Batch operations** - Get all resources and process them programmatically
3. **Full resource updates** - Always work with complete resource definitions
4. **Leverage projects_list** - Use the dedicated tool for listing OpenShift projects

## Related Resources

- [OpenShift Projects Documentation](https://docs.openshift.com/container-platform/latest/applications/projects/working-with-projects.html)
- [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Red Hat OpenShift AI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/)
- [OpenShift AI Dashboard Guide](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2-latest/html/working_on_data_science_projects/)
- [Kubernetes MCP Server](https://github.com/manusa/kubernetes-mcp-server)