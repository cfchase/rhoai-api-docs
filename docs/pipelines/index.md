---
layout: page
title: Pipelines
has_children: true
nav_order: 4
permalink: /docs/pipelines/
---

# Data Science Pipelines

Data Science Pipelines in Red Hat OpenShift AI provide infrastructure for automating and orchestrating machine learning workflows. By deploying a DataSciencePipelinesApplication (DSPA) in your namespace, you enable the use of Kubeflow Pipelines for creating reproducible, scalable ML workflows.

## Overview

The Data Science Pipelines infrastructure enables you to:
- **Automate ML workflows**: Deploy infrastructure for running data preprocessing, model training, and deployment pipelines
- **Track experiments**: Provide version control capabilities for data, code, and models
- **Scale operations**: Support distributed training and batch inference
- **Collaborate effectively**: Enable teams to share pipelines and results

## Key Components

When you deploy a DSPA, it sets up:
1. **API Server**: Core service for managing pipeline definitions and runs
2. **Persistence Agent**: Tracks pipeline execution state
3. **Scheduled Workflow Controller**: Manages pipeline scheduling
4. **Optional Components**: Object storage (Minio), database (MariaDB), UI, and metadata services

## Getting Started

To begin using Data Science Pipelines:

1. [Enable pipeline infrastructure](/docs/pipelines/setup/) - Deploy a DataSciencePipelinesApplication in your namespace
2. Create pipeline definitions using the KFP SDK or visual tools
3. Submit and execute pipeline runs
4. Monitor results through the dashboard or API

## In This Section

- [Pipeline Setup](/docs/pipelines/setup/) - Enable pipeline capabilities in your namespace by deploying DataSciencePipelinesApplication resources

## Prerequisites

Before working with pipelines, ensure you have:
- A [Data Science Project](/docs/projects/) with the required labels
- Appropriate permissions to create resources
- Storage configured for pipeline artifacts

## Related Resources

- [Projects](/docs/projects/) - Create data science projects
- [Data Connections](/docs/data-connections/) - Configure S3 storage for artifacts
- [Model Serving](/docs/serving/) - Deploy trained models