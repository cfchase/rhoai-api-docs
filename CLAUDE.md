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
  - `projects.md`: **Reference implementation** - Comprehensive guide for Data Science Projects with full CRUD operations
  - `serving/modelcar.md`: Comprehensive guide for ML model deployment with KServe
- **index.md**: Homepage (currently minimal)

### Deployment
- **.github/workflows/pages.yml**: Automated GitHub Pages deployment on push to main

## Documentation Standards

### Reference Implementation: projects.md
The `docs/projects.md` file serves as the gold standard for all documentation in this repository. All new documentation should follow its comprehensive structure and approach.

### Required Documentation Structure
Every API resource documentation MUST include these sections in order:

1. **Title and Introduction**
   - Clear description of what the resource is
   - Its purpose in OpenShift AI context
   - Key features/capabilities enabled

2. **Overview Section**
   - Conceptual explanation
   - Relationship to other resources
   - Required labels/annotations explained

3. **Complete CRUD Operations**
   - **Creating**: Both declarative (YAML) and imperative (commands) methods
   - **Listing/Viewing**: Various ways to query and filter
   - **Updating**: Multiple update methods (apply, edit, patch, label, annotate)
   - **Deleting**: Safe deletion practices with warnings

4. **Examples Section**
   - Basic example (minimal configuration)
   - Standard example (common use case)
   - Advanced example (production-ready with all features)
   - Real-world scenarios

5. **Verification and Troubleshooting**
   - How to verify successful operations
   - Common issues and solutions
   - Permission checking
   - Debugging tips

6. **Best Practices**
   - Naming conventions
   - Label and annotation strategies
   - Security considerations
   - When to use declarative vs imperative

7. **Field Reference Table**
   - Complete field documentation
   - Type, Required/Optional, Description, Examples
   - Common custom annotations table

8. **MCP Server Compatibility Section**
   - Tool mapping table
   - Adapted commands for each CRUD operation
   - MCP limitations and workarounds
   - Best practices for MCP usage

9. **Related Resources**
   - Links to official documentation
   - Related guides

### Documentation Guidelines

#### For Human Readability
- Use progressive examples (simple → complex)
- Include troubleshooting for each operation
- Provide clear command syntax with all options explained
- Add practical, real-world scenarios
- Use consistent formatting and terminology

#### For LLM Compatibility
- Structure data in tables where appropriate
- Use consistent YAML formatting with proper indentation
- Include inline comments in all YAML examples
- Provide complete field references with types
- Use code blocks with language identifiers

#### For MCP Server Compatibility
- Always include MCP tool mappings
- Show how to adapt kubectl commands to MCP tools
- Document MCP limitations clearly
- Provide workarounds for unsupported operations

### YAML Examples Convention
- Always include complete, working YAML manifests
- Add inline comments explaining every non-obvious field
- Use meaningful names that indicate purpose
- Show progression: basic → standard → advanced
- Include both minimal and production-ready examples

### Command Examples Convention
- Show both `kubectl` and `oc` commands where applicable
- Include all relevant flags and options
- Provide output examples for verification
- Group related commands logically

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

## LLM Documentation Files (llms.txt and llms-full.txt)

This repository follows the llmstxt.org standard for providing LLM-friendly documentation summaries. These files are located in the repository root directory.

### llms.txt
- **Purpose**: Minimal overview following llmstxt.org format for quick LLM context
- **Structure**: 
  - H1 title with project name
  - Blockquote with brief summary
  - Short overview paragraph
  - Docs section with links to main documentation pages
- **Guidelines**: Keep extremely concise - only title, summary, overview, and doc links

### llms-full.txt
- **Purpose**: Extended context file containing complete documentation for deeper LLM assistance
- **Generation**: Automatically generated by concatenating all markdown files in nav_order sequence
- **Process**:
  1. Read all .md files (index.md and docs/*.md)
  2. Sort by nav_order from Jekyll frontmatter
  3. Remove only the frontmatter (between --- markers)
  4. Concatenate content in order without additional formatting
- **Important**: This is a generated file - do not edit manually

### Updating LLM Files
When documentation changes:
1. **ALWAYS** run the generation script after modifying any markdown files in the docs folder: `./generate-llms-txt.sh`
2. Review the updated llms.txt to ensure descriptions are accurate
3. Manually edit llms.txt header if the project overview changes
4. Ensure both files remain in the root directory

**Important**: You must run `./generate-llms-txt.sh` after any documentation changes to keep the LLM files in sync.

The `generate-llms-txt.sh` script automatically:
- Finds all markdown files with nav_order in frontmatter
- Sorts them by nav_order
- Generates llms-full.txt by concatenating content without frontmatter
- Updates the Docs section in llms.txt with current document titles, links, and descriptions
- Preserves the rest of llms.txt content (header, overview, etc.)

## Git Commit Guidelines

When creating commits in this repository:
- **DO NOT** include Claude Code attribution in commit messages
- **DO NOT** include Claude-specific references in commit messages
- **DO NOT** mention "Generated with Claude Code" or similar attributions
- **DO NOT** add Co-Authored-By references to Claude
- Focus commit messages on the technical changes made
- Use conventional commit format when appropriate (feat:, fix:, docs:, etc.)

## Git Push Guidelines

- **NEVER** push changes to remote without explicit user permission
- **ALWAYS** wait for the user to review changes before pushing
- When commits are ready, inform the user and wait for their approval to push
- The user will explicitly ask to "push" when they're ready
