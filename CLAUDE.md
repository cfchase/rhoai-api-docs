# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Jekyll-based documentation site for OpenShift AI (Red Hat OpenShift AI) Kubernetes API. The site provides comprehensive guides for creating and managing OpenShift AI resources using Kubernetes manifests, with a focus on Data Science Projects and ModelCar serving for ML model deployment.

## Essential Commands

### Local Development
```bash
# Start the development server with live reload
./serve.sh
# Or manually:
bundle exec jekyll serve --livereload

# Build the site for production
bundle exec jekyll build

# Install/update dependencies
bundle install
```

### Deployment
The site automatically deploys to GitHub Pages when changes are pushed to the main branch via GitHub Actions workflow.

## Architecture & Key Files

### Site Configuration
- **_config.yml**: Jekyll configuration with "just-the-docs" theme, search settings, and GitHub Pages setup
- **Gemfile**: Ruby dependencies (Jekyll 4.3.0, just-the-docs theme)
- **.ruby-version**: Specifies Ruby 3.3.8

### Documentation Structure
- **docs/**: Main documentation content
  - `projects.md`: Tutorial for creating Data Science Projects
  - `modelcar-serving.md`: Comprehensive guide for ML model deployment with KServe
- **index.md**: Homepage (currently minimal)

### Deployment
- **.github/workflows/pages.yml**: Automated GitHub Pages deployment on push to main

## Key Development Patterns

### Adding New Documentation
1. Create markdown files in the `docs/` directory
2. Add front matter with `layout: default`, `title`, and `nav_order`
3. Follow the existing pattern of providing:
   - Clear explanations of concepts
   - Complete YAML examples with inline comments
   - Step-by-step instructions with kubectl commands
   - Troubleshooting sections

### YAML Examples Convention
- Always include complete, working YAML manifests
- Add inline comments explaining non-obvious fields
- Use real resource names and namespaces that match OpenShift AI patterns
- Include both minimal and production-ready examples

### OpenShift AI Resources
The documentation covers these custom resources:
- **DataScienceProject**: Custom projects with AI/ML-specific annotations
- **ServingRuntime**: Model serving configurations (e.g., vLLM for LLMs)
- **InferenceService**: KServe-based model deployments
- **AcceleratorProfile**: GPU configuration profiles

## Important Context

### Model Serving Focus
The modelcar-serving documentation emphasizes:
- GPU-accelerated serving with NVIDIA operator
- Red Hat registry models (Granite series)
- Production configurations with resource limits and autoscaling
- External access via OpenShift Routes

### Navigation Structure
Documents use `nav_order` in front matter for sidebar ordering. Current order:
1. Home (index.md)
2. Projects (projects.md)
3. ModelCar Serving (modelcar-serving.md)

### Theme Customization
The site uses "just-the-docs" theme with:
- Built-in search (Ctrl+K / Cmd+K)
- Responsive navigation
- Code syntax highlighting
- Clean technical documentation layout
## Git Commit Guidelines

When creating commits in this repository:
- **DO NOT** include Claude Code attribution in commit messages
- **DO NOT** include Claude-specific references in commit messages
- **DO NOT** mention "Generated with Claude Code" or similar attributions
- **DO NOT** add Co-Authored-By references to Claude
- Focus commit messages on the technical changes made
- Use conventional commit format when appropriate (feat:, fix:, docs:, etc.)
