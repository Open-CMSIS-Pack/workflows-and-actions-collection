# Workflows & Actions Collection

A collection of reusable GitHub Actions and workflow templates for the Open‑CMSIS‑Pack ecosystem to automate CI/CD
pipelines, enforce quality standards, and streamline DevOps processes across repositories.

| Workflow File | Description | Where it is used |
|---------------|-------------|------------------|
| `markdown-lint.yml` | A CI for linting markdown files. | `generator-bridge` |
| `generate-junit-to-html-report.yml` | A CI for consolidating JUNIT XML test reports into an HTML file. | `generator-bridge` |

## Purpose

Centralize GitHub automation patterns for:

- Workflows and CI/CD practices adopted by Open-CMSIS-Pack
- Serve as a central index of common reusable scripts/configs/workflows usage within the ecosystem

This helps maintain consistent best practices across repositories and reduces duplication.

## Example Caller Workflow

Below are some example jobs that demonstrate how to integrate linting, report generation, and quality/security checks using the shared workflows.

### Markdown Linting and Link Checking

This job runs markdown linting and validates links with the provided configuration files. You can also specify files to ignore.

```yaml
markdown-check:
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/markdown-lint.yml@main
  with:
    lint-config: '.github/markdownlint.jsonc'
    link-check-config: '.github/markdown-link-check.jsonc'
    ignore-files: 'third_party_licenses.md'
```

### Generate HTML Test Report

This job converts JUnit test results into an HTML report, with a custom header for easier identification. It is set to run after the test job finishes.

```yaml
html-test-report:
  needs: [ test ]
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/generate-junit-to-html-report.yml@main
  with:
    report_header: cbridge
```

### Quality and Security Checks

This job triggers a standard workflow that runs a set of quality assurance and security validation checks.

```yaml
quality-and-security-checks:
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/quality-security-checks.yml@main
```

## License

Licensed under the Apache-2.0 license.
