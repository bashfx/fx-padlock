# Function Categorization Plan for 06_api.sh Partition

**Target:** Split 4,518 lines / 72 functions into 4 manageable parts (<1000 lines each)

## 06a_master_api.sh - Core API Commands & Master Key Operations (~18 functions)
**Purpose:** Primary user-facing API commands and master key management
**Target Size:** ~1,200 lines → split further if needed

### Core API Commands (High-Order Functions):
- `do_clamp` - Repository clamping (primary workflow)
- `do_status` - Status checking 
- `do_lock` - Locking operations
- `do_unlock` - Unlocking operations  
- `do_clean_manifest` - Manifest cleaning
- `do_list` / `do_ls` - Listing operations
- `do_setup` - Initial setup

### Master Key Operations:
- `do_master_unlock` - Master key unlock
- `do_emergency_unlock` - Emergency unlock procedures
- `_master_unlock` - Internal master unlock logic
- `do_master` - Master key management
- `do_sec` - Security operations
- `do_setup` - Setup procedures
- `do_repair` - Repair operations

### Repository Lifecycle:
- `do_declamp` - Repository declamping
- `do_snapshot` - Create snapshots
- `do_rewind` - Rewind operations

## 06b_ignition_api.sh - Ignition System Functions (~22 functions) 
**Purpose:** Complete ignition workflow and key distribution system
**Target Size:** ~1,100 lines

### Main Ignition Entry:
- `do_ignite` - Main ignition dispatcher

### Ignition Operations (All _do_ignite_* functions):
- `_do_ignite_create` - Create ignition keys
- `_do_ignite_new` - New ignition setup  
- `_do_ignite_unlock` - Ignition unlock
- `_do_ignite_allow` - Allow access
- `_do_ignite_list` - List ignition keys
- `_do_ignite_status` - Ignition status
- `_do_ignite_export` - Export ignition keys
- `_do_ignite_revoke` - Revoke access
- `_do_ignite_rotate` - Key rotation
- `_do_ignite_reset` - Reset ignition
- `_do_ignite_verify` - Verify ignition
- `_do_ignite_help` - Help system

### Ignition Support Functions:
- `_get_ignite_passphrase` - Passphrase handling
- `_parse_ignite_command_args` - Command parsing
- `_extract_flag_values` - Flag processing
- `_ignite_operation` - Core operations
- `_ignite_help` / `_ignite_help_detailed` - Help systems
- `_ignition_lock` / `_ignition_unlock` - Lock/unlock
- `_chest_status` - Status checking

### TTY Magic Functions:
- `_create_ignition_master_with_tty_magic` - TTY master creation
- `_create_ignition_distro_with_tty_magic` - TTY distribution  
- `_unlock_ignition_with_tty_magic` - TTY unlock operations

## 06c_repo_api.sh - Repository Operations & Git Functions (~16 functions)
**Purpose:** Repository lifecycle, git operations, and file management
**Target Size:** ~1,100 lines

### Repository Artifacts:
- `_backup_repo_artifacts` - Backup repository data
- `_restore_repo_artifacts` - Restore repository data  
- `_add_to_manifest` - Manifest management
- `_merge_manifests` - Manifest merging

### Import/Export Operations:
- `do_import` - Import functionality
- `do_export` - Export functionality
- `do_rotate` - Key rotation

### Installation & Management:
- `do_install` - Install operations
- `do_uninstall` - Uninstall operations

### Overdrive System:
- `do_overdrive` - Overdrive management
- `_overdrive_unlock` - Overdrive unlock
- `_overdrive_status` - Overdrive status  
- `_overdrive_lock` - Overdrive lock

### Path & Mapping:
- `do_map` / `do_automap` - Path mapping
- `_is_mapped` - Check mapping status
- `_should_exclude` - Exclusion logic
- `_add_automap` - Add automatic mapping
- `do_unmap` - Remove mapping
- `do_path` - Path operations
- `_migrate_artifacts_namespace` - Migration support

### Remote Operations:
- `do_remote` - Remote management

## 06d_key_api.sh - General Key Management & Storage Functions (~16 functions)
**Purpose:** Key storage, bundle management, and general key operations  
**Target Size:** ~1,100 lines

### Key Management:
- `do_key` - General key operations
- `do_revoke` - Key revocation
- `_revoke_local_access` - Local revocation
- `_revoke_ignition_access` - Ignition revocation

### Key Storage & Bundles:
- `_setup_ignition_directories` - Directory setup
- `_create_ignition_metadata` - Metadata creation
- `_store_key_bundle` - Bundle storage
- `_load_key_bundle` - Bundle loading

**Total Functions Allocated:** 72 functions across 4 files
**Estimated Size Reduction:** 4,518 lines → ~1,100 lines per file (75% size reduction per file)

## Dependencies to Verify:
- Function call relationships across partitions
- Shared helper function dependencies  
- Global variable usage patterns
- Build system integration requirements

## Next Steps:
1. Create each partition file with proper BashFX part structure
2. Copy functions maintaining exact formatting and dependencies
3. Update build.sh to integrate new parts
4. Test functionality preservation
5. Git commit each successful partition step