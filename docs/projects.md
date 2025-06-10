---
layout: page
title: Projects
nav_order: 2
permalink: /docs/projects/
---

# Data Science Projects

## Creating a Project Using YAML

This tutorial demonstrates how to create a Data Science Project using YAML configuration. Projects in OpenShift Data Science provide isolated environments for your data science work.

### Project YAML Structure

Here's an example of a basic project configuration:

```yaml
kind: Project
apiVersion: project.openshift.io/v1
metadata:
  name: my-ds-project
  labels:
    kubernetes.io/metadata.name: my-ds-project
    modelmesh-enabled: 'false'
    opendatahub.io/dashboard: 'true'
  annotations:
    openshift.io/description: 'My Data Science Project'
    openshift.io/display-name: My DS Project
    openshift.io/requester: admin
spec: {}
```

### Key Arguments

- `metadata.name`: The unique identifier for your project (must be lowercase and can contain hyphens)
- `metadata.labels.modelmesh-enabled`: Controls ModelMesh serving capability ('true' or 'false').  Generally set to 'false' as modelmesh is deprecated.
- `metadata.annotations.'openshift.io/display-name'`: Human-readable name for the project
- `metadata.annotations.'openshift.io/description'`: Optional project description
- `metadata.annotations.'openshift.io/requester'`: The user who requested the project

### Creating Your Project

To create a new project:

1. Create a YAML file (e.g., `my-project.yaml`) with your desired configuration
2. Apply the configuration using the OpenShift CLI:
   ```bash
   oc apply -f my-project.yaml
   ```

For more advanced configurations, refer to the [OpenShift Documentation](https://docs.openshift.com/).
