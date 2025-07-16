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
    opendatahub.io/dashboard: 'true'
  annotations:
    openshift.io/description: 'My Data Science Project'
    openshift.io/display-name: My DS Project
spec: {}
```

### Key Arguments

- `metadata.name`: The unique identifier for your project (must be lowercase and can contain hyphens)
- `metadata.annotations.'openshift.io/display-name'`: Human-readable name for the project
- `metadata.annotations.'openshift.io/description'`: Optional project description

