
# Cache Action

An intelligent wrapper around GitHub's `actions/cache` that automatically manages repository
cache storage to prevent hitting GitHub's 10GB cache limit per repository. This **Smart Cache**
automatically cleaning up least-recently-used (LRU) caches before creating new ones, keeping
your cache usage optimal and your builds fast.

## Quick Start

### Basic Usage (Drop-in Replacement)

Replace your existing `actions/cache` steps:

```yaml
# Before
- uses: actions/cache@v4
  with:
    path: ~/.cache/go-build
    key: go-${{ hashFiles('go.sum') }}

# After  
- uses: Open-CMSIS-Pack/workflows-and-actions-collection/cache@v1
  with:
    path: ~/.cache/go-build
    key: go-${{ hashFiles('go.sum') }}
```

## Usage Examples

```yaml
- name: Cache Node modules
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/cache@v1
  with:
    path: node_modules
    key: node-${{ runner.os }}-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      node-${{ runner.os }}-
```

```yaml
- name: Cache Go dependencies
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/cache@v1
  with:
    path: |
      ~/.cache/go-build
      ~/go/pkg/mod
    key: go-${{ runner.os }}-${{ hashFiles('go.sum') }}
    restore-keys: |
      go-${{ runner.os }}-
```

## Configuration

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `path` | Files, directories, and wildcard patterns to cache | ✅ Yes | |
| `key` | Explicit key for restoring and saving the cache | ✅ Yes | |
| `restore-keys` | Ordered list of prefix-matched keys to use for restoring stale cache | No | |
| `max-cache-size-gb` | Maximum total cache size in GB before cleanup | No | `8` |
| `dry-run-cleanup` | Show what would be cleaned without actually deleting | No | `false` |
| `lookup-only` | Check if cache exists without downloading | No | `false` |
| `upload-chunk-size` | Chunk size for splitting large files during upload | No | |
| `enableCrossOsArchive` | Allow cross-OS cache sharing | No | `false` |
| `fail-on-cache-miss` | Fail workflow if cache entry is not found | No | `false` |

### Outputs

| Output | Description |
|--------|-------------|
| `cache-hit` | Boolean indicating exact match for primary key |
| `cache-primary-key` | Cache primary key passed in input |
| `cache-matched-key` | Key of the restored cache |
| `cleanup-performed` | Whether cleanup was performed before caching |
| `space-freed-mb` | Amount of space freed during cleanup in MB |

## Testing and Validation

### Dry Run Mode

Test your cache cleanup strategy without affecting actual caches:

```yaml
- name: Test cache cleanup strategy
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/cache@v1
  with:
    path: build/
    key: build-${{ github.sha }}
    dry-run-cleanup: "true"  # Shows what would be cleaned
```

### Using Outputs

```yaml
- name: Smart cache with monitoring
  id: cache
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/cache@v1
  with:
    path: ~/.cache/pip
    key: pip-${{ hashFiles('requirements.txt') }}

- name: Report cache status
  run: |
    echo "Cache hit: ${{ steps.cache.outputs.cache-hit }}"
    echo "Cleanup performed: ${{ steps.cache.outputs.cleanup-performed }}"
    echo "Space freed: ${{ steps.cache.outputs.space-freed-mb }}MB"
```

### Cleanup Strategy

**When cleanup triggers:**

1. **Projected size exceeds limit**: Current caches + estimated new cache > max size
2. **Current usage exceeds threshold**: Total cache usage > 80% of max size

**What gets cleaned:**

- ✅ **Least Recently Used (LRU)** caches first
- ✅ **Excludes current key** being created  
- ✅ **Stops when sufficient space** is available

### Example Cleanup Scenario

```txt
Current State:
- Repository limit: 8GB
- Current cache usage: 7.2GB (90% - exceeds 80% threshold)
- New cache estimate: 1.5GB
- Projected total: 8.7GB (exceeds limit)

Cleanup Decision:
- Target: Free at least 1.2GB to get under 80% threshold
- Strategy: Delete oldest caches until target met

Cleanup Actions:
Deleted: old-cache-key-1 (450MB, last used: 5 days ago)
Deleted: old-cache-key-2 (800MB, last used: 3 days ago)  
Stopped: Freed 1.25GB (target met)

Result:
- New cache usage: 6.95GB (87% → 69%)
- Space for new cache: ✅ Available
- Recent caches: ✅ Preserved
```

## Monitoring and Observability

### GitHub Step Summary

Smart Cache automatically generates rich summaries:

```txt
Smart Cache Summary

Cache operation performed
- Key: `build-linux-abc123`
- Cache Hit: false  
- Pre-cleanup: ✅ Freed 1,250MB using LRU strategy
- Estimated Size: 800MB
```

### Workflow Monitoring

```yaml
- name: Cache with monitoring
  id: smart-cache
  uses: Open-CMSIS-Pack/workflows-and-actions-collection/cache@v1
  with:
    path: build/
    key: build-${{ github.sha }}

- name: Send metrics to monitoring system
  if: steps.smart-cache.outputs.cleanup-performed == 'true'
  run: |
    echo "Cache cleanup performed"
    echo "Space freed: ${{ steps.smart-cache.outputs.space-freed-mb }}MB"
    # Send to your monitoring system
```

### Debug Mode

Enable verbose logging:

```yaml
- name: Debug smart cache
  uses: your-org/smart-cache@v1
  with:
    path: debug-cache/
    key: debug-${{ github.run_id }}
    dry-run-cleanup: "true"  # See what would happen without changes
  env:
    ACTIONS_STEP_DEBUG: true
```

## License

Licensed under the [Apache-2.0 license](../LICENSE).
