# Padlock Rust Port Plan

> **Porting fx-padlock from Bash to Rust using REBEL/RSB Architecture**

This document outlines the comprehensive plan for porting the 4,000+ line bash-based fx-padlock security tool to Rust using the **REBEL** (Rust Equalized Beyond Esoteric Lingo) philosophy and **RSB** (Rebel String-Biased Architecture) framework.

## 🎯 **Project Overview**

**Current State**: fx-padlock is a mature bash-based repository security tool with:
- Modular BashFX architecture (9 component files)  
- Advanced git integration (hooks, filters, attributes)
- Comprehensive encryption system using age
- Namespace-aware artifact backup system
- Complex workflows (clamp, lock/unlock, repair, migrate)
- 4,000+ lines of battle-tested bash code

**Target State**: A Rust-based `padlock` binary that:
- Maintains 100% feature parity with the bash version
- Uses RSB architecture for string-biased, shell-like patterns
- Provides improved performance and reliability
- Maintains the same CLI interface for seamless migration

## 📋 **Architecture Translation**

### **BashFX → RSB Function Ordinality Mapping**

The existing bash modular structure maps cleanly to RSB patterns:

| BashFX Component | RSB Module | Function Pattern | Description |
|------------------|------------|------------------|-------------|
| `01_header.sh` | `main.rs` | Entry point | Standard RSB bootstrap/dispatch |
| `02_config.sh` | `padlock/config.rs` | `_helpers` | Configuration constants and paths |
| `03_stderr.sh` | `padlock/output.rs` | `__utilities` | Message formatting and colors |
| `04_helpers.sh` | `padlock/crypto.rs` | `_helpers` | Age encryption/decryption logic |
| `05_printers.sh` | `padlock/templates.rs` | `_helpers` | Git hooks and file generation |
| `06_api.sh` | `padlock/core.rs` | `pub fn` | Main command implementations |
| `07_core.sh` | `main.rs` | Entry point | Command dispatch and help |
| `08_main.sh` | `main.rs` | Entry point | Args processing and execution |
| `09_footer.sh` | `lib.rs` | Library exports | Public API surface |

### **RSB Project Structure**

```
src/
├── main.rs                    # RSB standard entry point
├── lib.rs                     # Optional public API
├── prelude.rs                 # User convenience imports  
├── padlock.rs                 # Nice neighbor for padlock/
└── padlock/                   # Implementation namespace
    ├── core.rs                # Public command functions (do_*)
    ├── crypto.rs              # Encryption/decryption helpers (_*)  
    ├── templates.rs           # Git hook/file generation (_*)
    ├── config.rs              # Configuration management (_*)
    ├── output.rs              # Formatting and messaging (__*)
    ├── repair.rs              # Repository repair logic (_*)
    ├── backup.rs              # Artifact backup system (_*)
    └── adapters/              # Type abstraction layer
        ├── mod.rs             # Adapter interface
        ├── age_client.rs      # Age encryption abstraction  
        ├── git_client.rs      # Git operations abstraction
        └── fs_client.rs       # File system operations
```

## 🔗 **Core Command Mapping**

### **Standard RSB Entry Point**

```rust
use rsb::prelude::*;

fn main() {
    let args = bootstrap!();
    
    // Pre-config commands (install, version)
    pre_dispatch!(&args, {
        "install" => do_install,
        "version" => do_version  
    });
    
    // Load configuration
    src!("~/.local/etc/padlock/config", "./padlock.conf");
    
    // Main command dispatch
    dispatch!(&args, {
        "clamp" => do_clamp,
        "setup" => do_setup, 
        "lock" => do_lock,
        "unlock" => do_unlock,
        "status" => do_status,
        "key" => do_key,
        "map" => do_map,
        "path" => do_path,
        "remote" => do_remote,
        "repair" => do_repair,
        "list" => do_list,
        "export" => do_export,
        "import" => do_import,
        "declamp" => do_declamp,
        "overdrive" => do_overdrive,
        "ignite" => do_ignite,
        "revoke" => do_revoke
    });
}
```

### **Command Function Signatures**

All commands follow RSB string-biased patterns:

```rust
// PUBLIC API FUNCTIONS (User fault error handling)
pub fn do_clamp(mut args: Args) -> i32 {
    let repo_path = args.get_or(1, ".");
    let generate = args.has_pop("--generate");
    let global_key = args.has_pop("--global-key");
    let ignition_key = args.has_val("--ignition");
    
    require_dir!(&repo_path);
    validate!(_is_git_repo(&repo_path), "Directory is not a git repository");
    
    info!("🔒 Deploying padlock security layer...");
    
    let result = _deploy_padlock(&repo_path, generate, global_key, ignition_key);
    if result == 0 {
        okay!("✓ Padlock deployed successfully");
        _backup_repo_artifacts(&repo_path);
    }
    result
}

// CRATE-INTERNAL FUNCTIONS (App fault error handling)
fn _deploy_padlock(path: &str, generate: bool, global: bool, ignition: Option<String>) -> i32 {
    let locker_path = format!("{}/locker", path);
    mkdir_p(&locker_path);
    
    _create_locker_structure(&locker_path);
    _install_git_hooks(path);
    _configure_git_filters(path);
    
    if generate {
        _generate_repo_key(path)
    } else if global {
        _use_global_key(path)
    } else {
        _setup_ignition_mode(path, ignition)
    }
}

// LOW-LEVEL UTILITIES (System fault error handling) 
fn __write_git_hook(path: &str, hook_type: &str, content: &str) -> bool {
    let hook_path = format!("{}/.githooks/{}", path, hook_type);
    match write_file(&hook_path, content) {
        Ok(_) => {
            __make_executable(&hook_path);
            true
        },
        Err(e) => {
            error!("Failed to write git hook: {}", e);
            false
        }
    }
}
```

## 🔐 **Encryption Architecture Translation**

### **Age Integration Using RSB Adapters**

```rust
// src/padlock/adapters/age_client.rs

use rsb::prelude::*;

pub fn age_encrypt(content: &str, recipients: &str) -> String {
    validate!(!content.is_empty(), "Cannot encrypt empty content");
    validate!(!recipients.is_empty(), "Age recipients required");
    
    let recipients_args = recipients
        .split(',')
        .map(|r| format!("-r {}", r.trim()))
        .collect::<Vec<_>>()
        .join(" ");
    
    let encrypted = pipe!(content)
        .pipe_to_cmd(&format!("age {}", recipients_args))
        .to_string();
        
    validate!(!encrypted.is_empty(), "Age encryption failed");
    encrypted
}

pub fn age_decrypt(encrypted: &str, key_file: &str) -> String {
    require_file!(key_file);
    validate!(!encrypted.is_empty(), "Cannot decrypt empty content");
    
    let decrypted = pipe!(encrypted)
        .pipe_to_cmd(&format!("age -d -i {}", key_file))
        .to_string();
        
    validate!(!decrypted.is_empty(), "Age decryption failed");
    decrypted
}

pub fn age_keygen() -> String {
    cmd!("age-keygen").to_string()
}
```

### **Locker Operations**

```rust
// src/padlock/crypto.rs

pub fn do_lock(mut args: Args) -> i32 {
    let repo_root = _get_repo_root(".");
    let locker_path = format!("{}/locker", repo_root);
    
    require_dir!(&locker_path);
    validate!(!test!(-f format!("{}/.locked", repo_root)), "Repository already locked");
    
    info!("🔒 Encrypting locker directory...");
    
    let file_count = _count_files(&locker_path);
    let checksum = _calculate_checksum(&locker_path);
    let archive = _create_tar_archive(&locker_path);
    
    let config = _load_padlock_config(&locker_path);
    let encrypted = age_encrypt(&archive, &config.recipients);
    
    write_file(&format!("{}/locker.age", repo_root), &encrypted);
    write_file(&format!("{}/.locked", repo_root), "locked");
    write_file(&format!("{}/.locker_checksum", repo_root), &checksum);
    
    rm_rf(&locker_path);
    
    okay!("✓ Locked: locker/ → locker.age ({} files)", file_count);
    _backup_repo_artifacts(&repo_root);
    0
}

fn _calculate_checksum(path: &str) -> String {
    cmd!("find {} -type f -exec md5sum {{}} \\;", path)
        .pipe_to_cmd("sort")
        .pipe_to_cmd("md5sum")
        .cut(1, " ")
        .to_string()
}
```

## 📁 **Artifact Backup System**

### **Namespace-Aware Storage**

```rust
// src/padlock/backup.rs

use rsb::prelude::*;

pub fn do_remote(mut args: Args) -> i32 {
    let repo_path = args.get_or(1, ".");
    
    info!("🔗 Padlock Remote Update");
    
    let (old_path, new_path) = _get_migration_paths(&repo_path);
    
    if test!(-d &new_path) {
        okay!("✓ Artifacts already updated for remote namespace"); 
        return 0;
    }
    
    require_dir!(&old_path);
    
    let remote_url = cmd!("git -C {} remote get-url origin", repo_path).to_string();
    info!("🔗 Git remote: {}", remote_url);
    
    echo!("📋 Update plan:");
    echo!("  From: {}", old_path);  
    echo!("  To:   {}", new_path);
    
    let artifacts = _list_artifacts(&old_path);
    echo!("📁 Artifacts to update:");
    for artifact in &artifacts {
        echo!("  • {}", artifact);
    }
    
    if !confirm!("Proceed with remote namespace update?", default: true) {
        info!("Update cancelled");
        return 0;
    }
    
    if _migrate_artifacts(&old_path, &new_path) {
        okay!("✓ Artifacts updated successfully");
        rm_rf(&old_path);
        info!("🎯 Remote namespace update complete!");
        0
    } else {
        error!("Update failed - old artifacts preserved");
        1  
    }
}

fn _get_migration_paths(repo_path: &str) -> (String, String) {
    let repo_name = path_split!(repo_path, basename);
    let padlock_etc = param!("PADLOCK_ETC", default: "~/.local/etc/padlock");
    
    let old_path = format!("{}/repos/local/{}", padlock_etc, repo_name);
    
    let remote_url = cmd!("git -C {} remote get-url origin", repo_path).to_string();
    let (namespace, repo_id) = _parse_remote_namespace(&remote_url, &repo_name);
    
    let new_path = format!("{}/repos/{}/{}", padlock_etc, namespace, repo_id);
    (old_path, new_path)
}

fn _parse_remote_namespace(remote_url: &str, fallback: &str) -> (String, String) {
    if remote_url.is_empty() {
        return ("local".to_string(), fallback.to_string());
    }
    
    // Parse GitHub/GitLab patterns
    if let Some(captures) = regex_match!(remote_url, r"github\.com[/:]([^/]+)/([^/]+)") {
        return ("github.com".to_string(), format!("{}/{}", captures[0], captures[1]));
    }
    
    if let Some(captures) = regex_match!(remote_url, r"gitlab\.com[/:]([^/]+)/([^/]+)") {
        return ("gitlab.com".to_string(), format!("{}/{}", captures[0], captures[1]));
    }
    
    // Parse SSH profiles and custom hosts
    if let Some(captures) = regex_match!(remote_url, r"@([^:]+):([^/]+)/([^/]+)") {
        return (captures[0].to_string(), format!("{}/{}", captures[1], captures[2]));
    }
    
    ("unknown".to_string(), fallback.to_string())
}
```

## 🔧 **Git Integration**

### **Hook and Filter Generation**

```rust
// src/padlock/templates.rs

use rsb::prelude::*;

const PRE_COMMIT_TEMPLATE: &str = include_str!("../templates/pre-commit.sh");
const POST_CHECKOUT_TEMPLATE: &str = include_str!("../templates/post-checkout.sh");
const AGE_WRAPPER_TEMPLATE: &str = include_str!("../templates/age-wrapper.sh");

pub fn do_setup(mut args: Args) -> i32 {
    let repo_path = args.get_or(1, ".");
    
    info!("🔧 Setting up padlock infrastructure...");
    
    _create_directory_structure(&repo_path);
    _install_git_hooks(&repo_path);  
    _configure_git_attributes(&repo_path);
    _create_padlock_binary(&repo_path);
    
    okay!("✓ Padlock infrastructure ready");
    0
}

fn _install_git_hooks(repo_path: &str) -> i32 {
    let hooks_dir = format!("{}/.githooks", repo_path);
    mkdir_p(&hooks_dir);
    
    // Generate hooks with repo-specific context
    let repo_root = path_split!(repo_path, absolute);
    
    let pre_commit = PRE_COMMIT_TEMPLATE
        .replace("${REPO_ROOT}", &repo_root)
        .replace("${PADLOCK_ETC}", &param!("PADLOCK_ETC"));
        
    let post_checkout = POST_CHECKOUT_TEMPLATE
        .replace("${REPO_ROOT}", &repo_root);
    
    __write_executable_file(&format!("{}/pre-commit", hooks_dir), &pre_commit);
    __write_executable_file(&format!("{}/post-checkout", hooks_dir), &post_checkout);
    
    // Configure git to use our hooks
    cmd!("git -C {} config core.hooksPath .githooks", repo_path);
    
    info!("✓ Git hooks installed");
    0
}

fn _configure_git_attributes(repo_path: &str) -> i32 {
    let gitattributes_content = format!(
        "{}\n{}\n{}\n{}\n",
        "# Padlock Security Configuration",
        "locker.age filter=locker-crypt diff=locker-crypt merge=binary",
        "bin/* -diff -merge",
        ".githooks/* -diff -merge"
    );
    
    append_file(&format!("{}/.gitattributes", repo_path), &gitattributes_content);
    
    // Configure git filters  
    let age_wrapper = format!("{}/bin/age-wrapper", repo_path);
    cmd!("git -C {} config filter.locker-crypt.clean '{} encrypt'", repo_path, age_wrapper);
    cmd!("git -C {} config filter.locker-crypt.smudge '{} decrypt'", repo_path, age_wrapper);
    
    info!("✓ Git filters configured");
    0
}
```

## 🧪 **Testing Strategy**

### **RSB Testing Patterns**

```rust
// src/padlock/core.rs

#[cfg(test)]
mod tests {
    use super::*;
    use rsb::testing::*;
    
    #[test]
    fn test_extract_namespace_github() {
        let result = _parse_remote_namespace("git@github.com:user/repo.git", "fallback");
        assert_eq!(result, ("github.com".to_string(), "user/repo".to_string()));
    }
    
    #[test]
    fn test_extract_namespace_ssh_profile() {
        let result = _parse_remote_namespace("git@myhost:team/project.git", "fallback");  
        assert_eq!(result, ("myhost".to_string(), "team/project".to_string()));
    }
    
    #[test]
    fn test_checksum_calculation() {
        let test_dir = create_test_dir!();
        write_file(&format!("{}/test.txt", test_dir), "content");
        
        let checksum = _calculate_checksum(&test_dir);
        assert!(!checksum.is_empty());
        assert_eq!(checksum.len(), 32); // MD5 length
    }
    
    #[test]
    fn test_lock_unlock_cycle() {
        let test_repo = create_test_repo!();
        setup_test_locker!(&test_repo);
        
        // Test locking
        let result = do_lock(Args::from(&["lock"]));
        assert_eq!(result, 0);
        assert!(test!(-f format!("{}/locker.age", test_repo)));
        assert!(!test!(-d format!("{}/locker", test_repo)));
        
        // Test unlocking  
        let result = do_unlock(Args::from(&["unlock"]));
        assert_eq!(result, 0);
        assert!(!test!(-f format!("{}/locker.age", test_repo)));
        assert!(test!(-d format!("{}/locker", test_repo)));
    }
}
```

### **Integration Tests**

```rust
// tests/integration_test.rs

use rsb::prelude::*;
use padlock::*;

#[test]
fn test_complete_clamp_workflow() {
    let test_repo = create_isolated_git_repo!();
    
    // Deploy padlock
    let result = do_clamp(Args::from(&["clamp", &test_repo, "--generate"]));
    assert_eq!(result, 0);
    
    // Verify structure
    assert!(test!(-d format!("{}/locker", test_repo)));
    assert!(test!(-d format!("{}/.githooks", test_repo))); 
    assert!(test!(-f format!("{}/bin/padlock", test_repo)));
    
    // Test lock/unlock cycle
    write_file(&format!("{}/locker/test.txt", test_repo), "secret");
    
    let result = run_in_repo!(&test_repo, "git add . && git commit -m 'test'");
    assert_eq!(result.exit_code, 0);
    assert!(test!(-f format!("{}/locker.age", test_repo)));
    
    let result = run_in_repo!(&test_repo, "git checkout HEAD");
    assert_eq!(result.exit_code, 0);
    assert!(test!(-d format!("{}/locker", test_repo)));
    
    cleanup_test_repo!(test_repo);
}
```

## 📦 **Cargo Configuration**

```toml
# Cargo.toml
[package]
name = "padlock"
version = "2.0.0"
authors = ["BashFX Team"]
edition = "2021"
description = "Git repository security orchestrator using age encryption"
license = "MIT"
readme = "README.md"
repository = "https://github.com/bashfx/fx-padlock"
keywords = ["git", "encryption", "security", "age", "cli"]

[dependencies]
rsb = { path = "../rsb" }  # RSB framework dependency
regex = "1.10"
serde_json = "1.0"
clap = { version = "4.4", optional = true }  # Only if needed for complex args

[dev-dependencies] 
tempfile = "3.8"
rsb-testing = { path = "../rsb/testing" }

[[bin]]
name = "padlock"
path = "src/main.rs"

[features]
default = []
advanced-cli = ["clap"]  # Optional complex argument parsing
```

## 🚀 **Migration Strategy**

### **Phase 1: Core Infrastructure (Week 1-2)**
1. Set up RSB project structure
2. Implement basic CLI dispatch and args parsing
3. Create age encryption adapters
4. Port configuration management  
5. Basic lock/unlock functionality

### **Phase 2: Git Integration (Week 3)**
1. Git hook generation and installation
2. Git filter configuration  
3. Repository clamp/declamp operations
4. Status and path commands

### **Phase 3: Advanced Features (Week 4)**
1. Artifact backup system with namespace detection
2. Remote namespace migration
3. Repair command with orphan detection
4. Export/import functionality

### **Phase 4: Complex Operations (Week 5)**
1. Ignition mode and chest operations
2. Overdrive mode (full repo encryption)
3. Key management (generation, rotation, recovery)
4. Map command for selective inclusion

### **Phase 5: Polish & Compatibility (Week 6)**
1. Comprehensive testing suite
2. Error message parity with bash version
3. Performance optimization
4. Documentation and migration guide

## 🎯 **Success Criteria**

### **Feature Parity**
- [ ] All 20+ commands implemented with identical behavior
- [ ] Git integration works seamlessly (hooks, filters, attributes)
- [ ] Encryption/decryption maintains compatibility with bash version
- [ ] Artifact backup system preserves data across namespace transitions
- [ ] CLI interface remains unchanged for seamless user migration

### **Performance Goals** 
- [ ] 2-5x faster than bash version for common operations
- [ ] Sub-100ms response time for status/path commands
- [ ] Efficient handling of large repository archives
- [ ] Memory usage scales linearly with repository size

### **Quality Standards**
- [ ] 95%+ test coverage including integration tests
- [ ] Zero data loss during migration from bash version
- [ ] Error messages as helpful as bash version
- [ ] Cross-platform compatibility (Linux, macOS, Windows)

## 🌊 **RSB Framework Requirements**

To implement this port successfully, the RSB framework needs:

### **Core Macros & Functions**
- `bootstrap!()`, `dispatch!()`, `pre_dispatch!()`
- `cat!()`, `cmd!()`, `pipe!()` stream processing
- `test!()`, `validate!()`, `require_*!()` validation
- `param!()` with bash-style parameter expansion
- `echo!()`, `info!()`, `okay!()`, `error!()` messaging

### **File System Operations**
- `read_file()`, `write_file()`, `append_file()`
- `mkdir_p()`, `rm_rf()`, `cp_r()`, `mv()`, `touch()`
- `path_split!()` for path manipulation
- File test operations via `test!()` macro

### **Shell Integration**
- Command execution with proper error handling
- Stream processing that mimics Unix pipes
- Environment variable management
- Exit code handling following shell conventions

### **Testing Framework**
- Test helper macros for temporary directories/repos
- Stream testing utilities
- Integration test patterns for CLI tools
- Mock adapters for external dependencies

## 📝 **Implementation Notes**

### **REBEL Philosophy Adherence**
- **String-biased interfaces**: All public APIs use `&str` parameters
- **Function ordinality**: Clear separation of public/crate/private functions
- **Shell-like patterns**: Familiar Unix command equivalents
- **Error handling**: Fault-level appropriate error messages
- **Type abstraction**: Complex Rust types hidden behind adapters

### **Compatibility Considerations**
- Maintain exact CLI interface for user migration
- Preserve `.padlock` configuration file format
- Keep artifact storage locations identical
- Ensure encrypted data remains compatible
- Support existing git hook configurations

### **Performance Optimizations**
- Use Rust's native performance for file operations
- Stream processing without unnecessary allocations
- Efficient regex compilation and reuse
- Parallel processing where appropriate
- Memory-mapped file operations for large archives

This RSB-based Rust port will provide a robust, performant, and maintainable evolution of fx-padlock while preserving the accessibility and shell-like experience that made the original successful.