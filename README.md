# OpenShift AI Kubernetes API Documentation

A comprehensive guide for using Kubernetes API to create and manage OpenShift AI resources, including served models using ModelCars.

## 🚀 Live Documentation

Visit the documentation at: **https://cfchase.github.io/rhoai-api-docs**

## 📖 What's Included

This documentation covers:

- **Getting Started** - Environment setup and prerequisites
- **Kubernetes API Basics** - Understanding OpenShift AI custom resources
- **ModelCar Serving** - Deploying ML models with simplified ModelCar resources
- **Complete Examples** - Real-world YAML configurations and scenarios

## 🛠️ Local Development

### Prerequisites

- Ruby 3.1+
- Bundler
- Git

### Setup

```bash
# Clone the repository
git clone https://github.com/cfchase/rhoai-api-docs.git
cd rhoai-api-docs

# Install dependencies
bundle install

# Serve locally
bundle exec jekyll serve

# Visit http://localhost:4000
```

### Building for Production

```bash
bundle exec jekyll build
```

## 📁 Repository Structure

```
├── _config.yml              # Jekyll configuration
├── _docs/                   # Documentation pages
│   ├── getting-started.md
│   ├── kubernetes-api.md
│   ├── modelcar-serving.md
│   └── examples.md
├── _includes/               # Reusable components
│   └── navigation.html
├── _layouts/                # Page layouts
│   └── default.html
├── _sass/                   # Custom styles
│   └── custom.scss
├── assets/css/              # CSS assets
├── .github/workflows/       # GitHub Actions
│   └── pages.yml           # Deployment workflow
├── Gemfile                  # Ruby dependencies
└── index.md                # Homepage
```

## 🔧 Key Resources Covered

### OpenShift AI Custom Resources

- **DataScienceCluster** - Main cluster configuration
- **Notebook** - Jupyter notebook instances
- **ModelCar** - Simplified model serving
- **InferenceService** - KServe-based serving

### ModelCar Benefits

- Pre-configured serving runtimes
- Automatic scaling and load balancing
- Built-in monitoring and observability
- Easy integration with OpenShift AI workflows

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `bundle exec jekyll serve`
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Resources

- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai)
- [OpenDataHub Project](https://github.com/opendatahub-io)
- [KServe Documentation](https://kserve.github.io/website/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)