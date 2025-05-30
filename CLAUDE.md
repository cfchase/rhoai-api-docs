# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains comprehensive documentation for using Kubernetes API to create and manage OpenShift AI resources, including served models using ModelCars. It's built as a Jekyll-based GitHub Pages site.

## Repository Structure

- `_config.yml` - Jekyll configuration for GitHub Pages
- `_docs/` - Documentation pages (Markdown files)
- `_includes/` - Reusable HTML components
- `_layouts/` - Jekyll page layouts
- `_sass/` - Custom SCSS styles
- `assets/css/` - CSS assets
- `.github/workflows/` - GitHub Actions for deployment
- `Gemfile` - Ruby dependencies for Jekyll

## Development Commands

### Local Development
```bash
# Install dependencies
bundle install

# Serve locally with live reload
bundle exec jekyll serve

# Serve with drafts
bundle exec jekyll serve --drafts

# Build for production
bundle exec jekyll build
```

### Content Management
- Documentation pages are in `_docs/` directory
- All pages use Markdown with YAML front matter
- Code examples should use appropriate syntax highlighting
- Images and assets go in `assets/` directory

## Site Architecture

The site uses Jekyll with the Minima theme, customized with:
- Custom navigation in `_includes/navigation.html`
- OpenShift AI-themed styling in `_sass/custom.scss`
- Responsive design for mobile/desktop
- Automatic deployment via GitHub Actions

## Content Guidelines

- Focus on practical examples and real-world use cases
- Include complete YAML configurations
- Provide both kubectl/oc command examples
- Use consistent terminology (ModelCar, OpenShift AI, etc.)
- Include troubleshooting sections where appropriate

## Deployment

The site automatically deploys to GitHub Pages via GitHub Actions when changes are pushed to the main branch. The deployment workflow is in `.github/workflows/pages.yml`.

## License

The project uses Apache License 2.0.