# Smart Cache Action

An intelligent cache wrapper that manages space before creating new caches using LRU (Least Recently Used) strategy.

## Features

- 🧹 **Automatic cleanup** using LRU strategy when cache storage approaches limits
- 📊 **Size estimation** for new caches with buffer calculations
- 🏥 **Repository-wide** cache health monitoring
- 🔍 **Dry-run mode** to preview cleanup actions without actual deletion
- 🌐 **Cross-platform** support (Ubuntu, macOS, Windows)
- 📈 **Detailed reporting** with GitHub step summaries
- ⚡ **Modular architecture** for easy maintenance and testing

## Quick Start

```yaml
- name: Smart Cache
  uses: ./cache
  with:
    path: |
      ~/.npm
      node_modules
    key: npm-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      npm-
    max-cache-size: "10"  # GB
```

## Architecture

The action uses a modular architecture with separate scripts for different responsibilities:

```
cache/
├── action.yml                    # Main workflow definition
├── scripts/
│   ├── cache-strategy.sh         # Determine cache strategy
│   ├── size-estimator.sh         # Estimate cache sizes
│   ├── pre-cleanup.sh            # Pre-cache cleanup logic
│   ├── repo-cleanup.sh           # Repository cleanup logic
│   ├── cache-summary.sh          # Generate summaries
│   └── lib/
│       ├── common.sh             # Shared utilities
│       └── api-client.sh         # GitHub API wrapper
└── README.md
```

## Inputs

### Standard Cache Inputs
- `path` - Files/directories to cache (required)
- `key` - Cache key (required)
- `restore-keys` - Fallback keys for restoration
- `upload-chunk-size` - Chunk size for uploads
- `enableCrossOsArchive` - Cross-platform archive support
- `fail-on-cache-miss` - Fail if cache not found
- `lookup-only` - Only check cache existence

### Smart Cache Inputs
- `max-cache-size` - Maximum total cache size in GB (default: 8)
- `dry-run-cleanup` - Preview cleanup without deletion (default: false)

## Outputs

- `cache-hit` - Exact cache match found
- `cache-primary-key` - Primary cache key
- `cache-matched-key` - Matched restoration key
- `cleanup-performed` - Whether pre-cleanup was performed
- `space-freed-mb` - Space freed during pre-cleanup (MB)
- `repo-cleanup-performed` - Whether repository cleanup was performed
- `repo-space-freed-mb` - Space freed during repository cleanup (MB)

## Examples

### Basic Usage
```yaml
- uses: ./cache
  with:
    path: ~/.cache/pip
    key: pip-${{ hashFiles('requirements.txt') }}
```

### Advanced Configuration
```yaml
- uses: ./cache
  with:
    path: |
      ~/.npm
      node_modules
      .next/cache
    key: build-${{ runner.os }}-${{ hashFiles('package-lock.json', '.next/**') }}
    restore-keys: |
      build-${{ runner.os }}-
      build-
    max-cache-size: "15"
    dry-run-cleanup: "true"
    enableCrossOsArchive: "true"
```

### Lookup Only
```yaml
- uses: ./cache
  with:
    path: dist/
    key: build-${{ github.sha }}
    lookup-only: "true"
```

## Cross-Platform Support

The action includes comprehensive cross-platform support:

- **macOS**: Compatible with Bash 3.2, BSD utilities
- **Ubuntu**: Works with GNU utilities and latest Bash
- **Windows**: Compatible with Git Bash and MSYS2 environment

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   - Ensure `gh` (GitHub CLI) and `jq` are available
   - Most GitHub runners include these by default

2. **Permission Issues**
   - Ensure `GITHUB_TOKEN` has appropriate permissions
   - The action requires `actions:write` scope for cache operations

3. **Large Cache Sizes**
   - Adjust `max-cache-size` based on your repository needs
   - Monitor cleanup logs for space management insights

### Debug Mode

Enable debug logging by setting the `DEBUG` environment variable:

```yaml
- uses: ./cache
  env:
    DEBUG: "true"
  with:
    path: ~/.cache
    key: my-cache-key
```

## Contributing

1. Make changes to individual script files in `scripts/`
2. Test across all supported platforms
3. Update documentation and examples
4. Submit pull request

## License

MIT License - see LICENSE file for details.
