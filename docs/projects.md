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

### Key Components Explained

1. **Basic Metadata**:
   - `kind`: Specifies the resource type as "Project"
   - `apiVersion`: Defines the API version for OpenShift projects
   - `metadata.name`: The unique identifier for your project (must be lowercase and can contain hyphens)

2. **Labels**:
   - `kubernetes.io/metadata.name`: Matches the project name
   - `modelmesh-enabled`: Controls ModelMesh serving capability ('true' or 'false')
   - `opendatahub.io/dashboard`: Enables the Open Data Hub dashboard ('true' or 'false')

3. **Annotations**:
   - `openshift.io/display-name`: Human-readable name for the project
   - `openshift.io/description`: Optional project description
   - `openshift.io/requester`: The user who requested the project

### Creating Your Project

To create a new project:

1. Create a YAML file (e.g., `my-project.yaml`) with your desired configuration
2. Apply the configuration using the OpenShift CLI:
   ```bash
   oc apply -f my-project.yaml
   ```

### Best Practices

1. **Naming Convention**:
   - Use lowercase letters
   - Hyphens are allowed
   - Keep names descriptive but concise
   - Avoid special characters

2. **Labels and Annotations**:
   - Set `modelmesh-enabled: 'false'` unless you plan to use ModelMesh serving.  If you are using single-model serving, it's not needed.
   - Enable the dashboard with `opendatahub.io/dashboard: 'true'` for better visibility
   - Add meaningful descriptions in the annotations

3. **Security**:
   - Review and set appropriate access controls
   - Consider resource quotas for production projects
   - Document project purpose in the description

### Next Steps

After creating your project, you can:
1. Set up your development environment
2. Configure resource quotas if needed
3. Add team members and set appropriate permissions
4. Deploy your data science applications

For more advanced configurations, refer to the [OpenShift Documentation](https://docs.openshift.com/).
