# Enhanced Build System

The padlock project now uses an enhanced modular build system that combines the stability of the original build.sh with advanced management features inspired by protobuild.sh.

## New Capabilities

### Build Management Commands

The build.sh now supports advanced commands for managing the build order:

```bash
# List modules in build order
./build.sh list

# Insert a new module at a specific position
./build.sh insert new_module.sh 6

# Swap two modules by position
./build.sh swap 3 7  

# Regenerate build map from filesystem
./build.sh remap
```

### Build Map Management

The enhanced system provides powerful tools for reorganizing modules:

- **Insert**: Add new modules at specific positions, automatically adjusting the build map
- **Swap**: Reorder modules by swapping positions
- **Remap**: Automatically regenerate the build map from all .sh files in the parts directory

### Splitting Large Modules

The new capabilities make it easy to split large modules like `06_api.sh`:

1. **Create sub-modules**: Split `06_api.sh` into smaller files like:
   - `06a_api_core.sh`
   - `06b_api_crypto.sh`
   - `06c_api_git.sh`

2. **Insert at correct positions**:
   ```bash
   ./build.sh insert 06a_api_core.sh 6
   ./build.sh insert 06b_api_crypto.sh 7
   ./build.sh insert 06c_api_git.sh 8
   ```

3. **Auto-reindex**: The system automatically adjusts all subsequent module numbers

## Usage Examples

### Basic Build
```bash
./build.sh                    # Build with current configuration
./build.sh -c                 # Clean build (remove existing output first)
```

### Module Management
```bash
./build.sh list               # See current module order
./build.sh remap              # Regenerate map from filesystem
./build.sh swap 5 6           # Swap positions 5 and 6
```

### Development Workflow
```bash
# 1. Create new module
echo "# New functionality" > parts/new_feature.sh

# 2. Insert at desired position
./build.sh insert new_feature.sh 5

# 3. Verify order
./build.sh list

# 4. Build and test
./build.sh && ./padlock.sh --help
```

## Build Map Format

The `parts/build.map` file controls module order:

```
# Padlock Build Map  
# Format: NN : target_filename.sh

01 : 01_header.sh
02 : 02_config.sh  
03 : 03_stderr.sh
04 : 04_helpers.sh
05 : 05_printers.sh
06 : 06_api.sh
07 : 07_core.sh
08 : 08_main.sh
09 : 09_footer.sh
```

## Benefits

1. **Zero Functional Regression**: All existing padlock functionality preserved
2. **Advanced Module Management**: Easy insertion, swapping, and reordering
3. **Automatic Indexing**: No manual renumbering needed
4. **Split Large Files**: Tools ready for breaking up `06_api.sh`
5. **Filesystem Sync**: `remap` command keeps build map current

## Migration Notes

- The enhanced build.sh is 100% backward compatible
- All existing build options (`-o`, `-p`, `-r`, `-l`, `-v`, `-c`) still work
- New commands use simple word syntax (no dashes): `list`, `insert`, `swap`, `remap`
- Original protobuild.sh removed after successful integration

This enhancement provides the foundation needed for splitting the large `06_api.sh` file while maintaining a stable and reliable build process.