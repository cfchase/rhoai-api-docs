---
layout: home
title: OpenShift AI Kubernetes API Documentation
---

# OpenShift AI Kubernetes API Documentation

Welcome to the comprehensive guide for using Kubernetes API to create and manage OpenShift AI resources, including served models using ModelCars.

## What You'll Learn

This documentation covers:

- **Kubernetes API Fundamentals** - Understanding how to interact with OpenShift AI using native Kubernetes APIs
- **ModelCar Serving** - Creating and managing served models using the ModelCar custom resource
- **Resource Management** - Working with DataScienceCluster, Notebook, and other OpenShift AI resources
- **Practical Examples** - Real-world YAML configurations and kubectl commands

## Quick Start

1. [Getting Started](docs/getting-started) - Set up your environment and prerequisites
2. [Kubernetes API Basics](docs/kubernetes-api) - Learn the fundamentals of OpenShift AI resources
3. [ModelCar Serving](docs/modelcar-serving) - Deploy and serve ML models using ModelCars
4. [Examples](docs/examples) - Complete YAML examples and use cases

## Key Resources

### Core OpenShift AI Custom Resources

- **DataScienceCluster** - Main cluster configuration for OpenShift AI
- **Notebook** - Jupyter notebook instances for data science workloads
- **ModelCar** - Served model deployments with built-in serving runtimes
- **InferenceService** - KServe-based model serving (alternative to ModelCar)

### ModelCar Benefits

ModelCars provide a simplified approach to model serving with:
- Pre-configured serving runtimes
- Automatic scaling and load balancing
- Built-in monitoring and observability
- Easy integration with OpenShift AI workflows

## Prerequisites

- OpenShift cluster with OpenShift AI operator installed
- `kubectl` or `oc` CLI configured
- Basic understanding of Kubernetes resources and YAML

---

Ready to get started? Begin with our [Getting Started guide](docs/getting-started).