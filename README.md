# Workflows & Actions Collection

A collection of reusable GitHub Actions and workflow templates for the
Open‑CMSIS‑Pack ecosystem to automate CI/CD pipelines, enforce quality
standards, and streamline DevOps processes across repositories.

<!-- markdownlint-disable MD013 -->

| Workflow File | Description |
|---------------|-------------|
| [`build-and-verify.yml`](.github/workflows/build-and-verify.yml) | Run standard quality and security checks, Build, Test Go binaries for selected OS/arch. |
| [`markdown-lint.yml`](.github/workflows/markdown-lint.yml) | CI job for linting markdown files. |

| Action | Description |
|---------------|-------------|
| [`cache`](./cache/README.md) | Cache that automatically clean up least-recently-used (LRU) caches before creating new ones. |

<!-- markdownlint-enable MD013 -->

## Purpose

Centralize GitHub automation patterns for:

- Workflows and CI/CD practices adopted by Open-CMSIS-Pack
- Serve as a central index of common reusable scripts/configs/workflows usage

This helps maintain consistent best practices across repositories and reduces
duplication.

## Example Caller Workflow

Below are some example jobs that demonstrate how to integrate linting, report
generation, and quality/security checks using the shared workflows.

### Build and Verify Binaries

This reusable job performs quality assurance, security validation, and then
builds and tests a Go program across the specified OS/Arch combinations.

#### Example Usage

```yaml
build:
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/build-and-verify.yml@v1.0.0
  with:
    program: 'cbridge' # Name of the binary to build
    build-matrix: '[{"goos":"linux","arch":"amd64"},{"goos":"windows","arch":"arm64"}]'
    test-matrix: '[{"platform":"ubuntu-24.04","arch":"amd64"},{"platform":"macos-14","arch":"arm64"}]'
    go-version-file: ./go.mod # Path to go.mod file for Go version detection
```

or

```yaml
build:
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/build-and-verify.yml@v1.0.0
  with:
    program: 'cbridge'              # Name of the binary to build
    go-version-file: ./go.mod       # Path to go.mod file for Go version detection
    artifact-retention-days: 1      # Days to retain build artifacts (default: 7)
```

If no custom matrix is provided, the workflow uses the following defaults:

- **Build Matrix** (`build-matrix`)

  ```json
  [
    {"goos":"windows","arch":"amd64"},
    {"goos":"windows","arch":"arm64"},
    {"goos":"linux","arch":"amd64"},
    {"goos":"linux","arch":"arm64"},
    {"goos":"darwin","arch":"amd64"},
    {"goos":"darwin","arch":"arm64"}
  ]
  ```

- **Test Matrix** (`test-matrix`)

  ```json
  [
    {"platform":"windows-2022","arch":"amd64"},
    {"platform":"windows-2022","arch":"arm64"},
    {"platform":"ubuntu-24.04","arch":"amd64"},
    {"platform":"ubuntu-24.04","arch":"arm64"},
    {"platform":"macos-14","arch":"amd64"},
    {"platform":"macos-14","arch":"arm64"}
  ]
  ```

### Markdown Linting and Link Checking

This job runs markdown linting and validates links with the provided
configuration files. You can also specify files to ignore.

```yaml
markdown-check:
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/markdown-lint.yml@v1.0.0
  with:
    lint-config: '.github/markdownlint.jsonc'
    link-check-config: '.github/markdown-link-check.jsonc'
    ignore-files: 'third_party_licenses.md'
```

## Keeping the Workflows Up To Date

There is a workflow which keeps the go-workflows up to date. This should be included in the
.github/workflows directory alongside any go-workflows.

Here is how to use it in an extension repository:

```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: "30 3 * * *"

jobs:
  update-workflows:
    uses: Open-CMSIS-Pack/workflows-and-actions-collection/.github/workflows/update-workflows.yml@v1.0.0
    secrets:
      TOKEN_ACCESS: ${{ secrets.PR_ACCESS_TOKEN }}
```

If there is a new version of vscode-workflows available a PR will be created which updates all the
workflows to use the latest version, including the update workflow itself.

## License

Licensed under the Apache-2.0 license.
