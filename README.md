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

```yaml
markdown-check:
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/markdown-lint.yml@main
  with:
    lint-config: '.github/markdownlint.jsonc'
    link-check-config: '.github/markdown-link-check.jsonc'
    ignore-files: 'third_party_licenses.md'
```
```yaml
html-test-report:
  needs: [ test ]
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/generate-junit-to-html-report.yml@main
  with:
    report_header: cbridge
```

## License

Licensed under the Apache-2.0 license.
