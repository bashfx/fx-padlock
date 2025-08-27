# RUST_PORT_PLAN.md - Padlock Rust Port Strategy

## Executive Summary

This document outlines the strategy for porting Padlock from Bash/BashFX to Rust, incorporating lessons learned from the Plan X ignition key pilot and establishing a roadmap for enhanced performance, security, and maintainability.

## Background Context

### Current State Assessment (Post-Plan X Pilot)

**Bash Implementation Strengths**:
- **Proven Architecture**: BashFX 2.1 pattern successfully scales to 5000+ lines
- **Rapid Prototyping**: Plan X pilot demonstrated ability to quickly test multiple approaches
- **Shell Integration**: Native integration with existing shell workflows
- **Ignition API Ready**: layered_native approach validated and integration-ready

**Bash Implementation Limitations**:
- **Performance Ceiling**: Even fastest approach (layered_native: 0.240s) could be much faster in Rust
- **Cryptographic Constraints**: Limited to age binary, no direct crypto library access
- **Error Handling**: Bash error handling less sophisticated than Rust Result types
- **Type Safety**: No compile-time validation of key formats, metadata, etc.
- **Concurrency**: No parallel key operations, all sequential
- **Memory Management**: Shell process overhead for crypto operations

### Plan X Pilot Insights for Rust Port

**Validated Architectural Decisions**:
1. **layered_native approach**: Proven optimal for performance/security/complexity balance
2. **Deterministic key derivation**: passphrase → SHA256 → key pattern works well
3. **Master key authority**: All ignition keys encrypted with master key validation
4. **JSON metadata**: Rich metadata embedding valuable for debugging/management
5. **Environment variable support**: Critical for automation workflows

**Novel Approaches for Future Integration**:
- **temporal_chain**: Forward secrecy concepts applicable to long-term roadmap
- **lattice_proxy**: Post-quantum threshold schemes for enterprise/government use
- **Timeout qualification**: Robustness requirements transferable to Rust

## Rust Port Strategy

### Phase 1: Core Architecture Translation (Months 1-2)

#### 1.1 Crypto Foundation
```rust
// Replace age binary with rust crypto libraries
use ring::{digest, hkdf, aead};
use age::{armor, Decryptor, Encryptor}; // rust age library

// Deterministic key derivation (from layered_native)
fn derive_key_from_passphrase(passphrase: &str) -> Result<SecretKey, Error> {
    let salt = b"padlock_ignition_v1"; // version-specific salt
    let material = digest::digest(&digest::SHA256, passphrase.as_bytes());
    let okm = hkdf::extract_and_expand(&hkdf::HKDF_SHA256, &material.as_ref(), salt, b"");
    SecretKey::from_bytes(&okm[..32])
}
```

**Key Improvements over Bash**:
- **Direct crypto**: No shell process overhead for cryptographic operations
- **Type safety**: Compile-time validation of key types and formats
- **Memory safety**: No key material leakage in process memory
- **Performance**: Expected 10-50x improvement over bash (0.240s → 0.005-0.024s)

#### 1.2 Core Data Structures
```rust
#[derive(Debug, Serialize, Deserialize)]
pub struct IgnitionMetadata {
    key_type: KeyType,
    name: String,
    created: DateTime<Utc>,
    algorithm: String,
    authority: AuthorityChain,
    expires: Option<DateTime<Utc>>,
}

#[derive(Debug)]
pub enum KeyType {
    IgnitionMaster,
    DistributedKey,
}

pub struct IgnitionKey {
    metadata: IgnitionMetadata,
    private_key: SecretKey,
    public_key: PublicKey,
}
```

**Advantages**:
- **Structured data**: No more JSON string parsing in critical paths
- **Type validation**: Impossible to create invalid key structures
- **Serialization**: Consistent JSON handling with serde
- **Error types**: Rich error information with detailed context

#### 1.3 Authority Validation Chain
```rust
pub struct AuthorityChain {
    master_fingerprint: String,
    signature: Vec<u8>,
    chain_height: u64,
}

impl IgnitionKey {
    pub fn validate_authority(&self, master_key: &PublicKey) -> Result<(), AuthorityError> {
        // Cryptographic validation that key was created with master authority
        master_key.verify(&self.authority.signature, &self.key_hash())?;
        Ok(())
    }
}
```

### Phase 2: Advanced Features Integration (Months 3-4)

#### 2.1 Concurrency & Performance
```rust
// Parallel key operations
use tokio::task;
use futures::future::join_all;

pub async fn batch_create_keys(requests: Vec<CreateKeyRequest>) -> Vec<Result<IgnitionKey, Error>> {
    let tasks = requests.into_iter().map(|req| {
        task::spawn(async move { create_ignition_key(req).await })
    });
    
    join_all(tasks).await
        .into_iter()
        .map(|result| result.unwrap()) // Handle join errors
        .collect()
}
```

**Performance Improvements**:
- **Batch operations**: Create/unlock multiple keys in parallel
- **Async I/O**: Non-blocking file system operations
- **Memory efficiency**: Zero-copy operations where possible
- **CPU optimization**: Native crypto vs subprocess calls

#### 2.2 Enhanced Security Features
```rust
// Implement temporal_chain concepts for high-security mode
pub struct TemporalChain {
    blocks: Vec<KeyBlock>,
    forward_secrecy: bool,
}

impl TemporalChain {
    pub fn create_time_bound_key(&mut self, passphrase: &str, duration: Duration) -> Result<IgnitionKey, Error> {
        let expires = Utc::now() + duration;
        let key = self.derive_temporal_key(passphrase, expires)?;
        self.add_block(key.clone())?;
        Ok(key)
    }
}

// Implement lattice_proxy concepts for enterprise
pub struct ThresholdScheme {
    threshold: usize,
    total_shares: usize,
    shares: Vec<KeyShare>,
}
```

#### 2.3 Configuration Management
```rust
#[derive(Debug, Deserialize)]
pub struct PadlockConfig {
    pub ignition: IgnitionConfig,
    pub security: SecurityConfig,
    pub performance: PerformanceConfig,
}

#[derive(Debug, Deserialize)] 
pub struct IgnitionConfig {
    pub default_algorithm: String,
    pub key_expiration: Option<Duration>,
    pub require_passphrase_strength: bool,
    pub enable_temporal_chains: bool,
    pub enable_threshold_schemes: bool,
}
```

### Phase 3: Integration & Migration (Months 5-6)

#### 3.1 Backward Compatibility
```rust
// Read existing bash-created keys
pub fn migrate_bash_key(bash_key_path: &Path) -> Result<IgnitionKey, MigrationError> {
    let bash_content = fs::read_to_string(bash_key_path)?;
    let metadata = extract_bash_metadata(&bash_content)?;
    let key_data = extract_bash_key_data(&bash_content)?;
    
    IgnitionKey::from_bash_format(metadata, key_data)
}

// Maintain CLI compatibility  
#[derive(Parser)]
#[command(name = "padlock")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    Clamp { path: PathBuf, ignition: bool },
    Declamp { path: PathBuf },
    Ignite(IgniteCommand),
}
```

#### 3.2 Performance Benchmarking
```rust
// Built-in benchmarking for performance validation
pub async fn benchmark_approach(approach: &str, operations: usize) -> BenchmarkResult {
    let start = Instant::now();
    
    for i in 0..operations {
        let key_name = format!("bench-{}", i);
        let key = create_ignition_key(&key_name, "test-passphrase").await?;
        unlock_ignition_key(&key_name, "test-passphrase").await?;
    }
    
    BenchmarkResult {
        approach: approach.to_string(),
        operations,
        duration: start.elapsed(),
        ops_per_second: operations as f64 / start.elapsed().as_secs_f64(),
    }
}
```

**Target Performance**:
- **Key Creation**: < 5ms (vs 240ms in bash)
- **Key Unlock**: < 2ms (vs 240ms in bash) 
- **Batch Operations**: 100 keys in < 50ms
- **Memory Usage**: < 10MB for typical operations

### Phase 4: Advanced Features & Ecosystem (Months 7-12)

#### 4.1 Web Integration
```rust
// HTTP API for web integration
use axum::{routing::post, Json, Router};

async fn create_ignition_api(
    Json(request): Json<CreateIgnitionRequest>,
) -> Result<Json<IgnitionKey>, ApiError> {
    let key = create_ignition_key(&request.name, &request.passphrase).await?;
    Ok(Json(key))
}

pub fn api_router() -> Router {
    Router::new()
        .route("/ignition/create", post(create_ignition_api))
        .route("/ignition/unlock", post(unlock_ignition_api))
}
```

#### 4.2 Plugin Architecture
```rust
// Plugin system for custom key derivation algorithms
pub trait KeyDerivationPlugin: Send + Sync {
    fn name(&self) -> &str;
    fn derive_key(&self, passphrase: &str) -> Result<SecretKey, Error>;
}

pub struct PluginRegistry {
    plugins: HashMap<String, Box<dyn KeyDerivationPlugin>>,
}
```

#### 4.3 Hardware Security Module Integration
```rust
// HSM integration for enterprise deployments
pub trait HsmProvider: Send + Sync {
    fn generate_key(&self, key_spec: &KeySpec) -> Result<HsmKey, HsmError>;
    fn sign(&self, key_id: &str, data: &[u8]) -> Result<Vec<u8>, HsmError>;
}

pub struct YubiHsmProvider {
    session: YhSession,
}
```

## Migration Strategy

### Phase 1: Parallel Development (Bash + Rust)
- **Bash**: Continue with Plan X layered_native implementation
- **Rust**: Begin core library development
- **Testing**: Cross-validation between implementations
- **Timeline**: 2-3 months parallel development

### Phase 2: Feature Parity
- **API Compatibility**: Rust CLI matches bash CLI exactly
- **Key Format Compatibility**: Rust can read/write bash key formats
- **Performance Validation**: Rust significantly faster than bash
- **Timeline**: 1-2 months integration work

### Phase 3: Migration Tools
```rust
// Automated migration tooling
pub struct PadlockMigrator {
    bash_padlock_path: PathBuf,
    rust_padlock_path: PathBuf,
}

impl PadlockMigrator {
    pub async fn migrate_repository(&self, repo_path: &Path) -> Result<MigrationReport, Error> {
        // Automated migration of existing padlock repositories
        // Validates data integrity throughout process
        // Provides rollback capability if issues found
    }
}
```

### Phase 4: Deployment Strategy
- **Gradual Rollout**: Start with new repositories, migrate existing ones
- **A/B Testing**: Compare performance and reliability
- **Fallback Plan**: Maintain bash version as backup
- **Timeline**: 2-3 months careful rollout

## Risk Assessment & Mitigation

### High-Risk Areas

#### 1. Key Format Compatibility (HIGH)
**Risk**: Rust port cannot read existing bash-created keys
**Mitigation**: Extensive cross-compatibility testing, migration tools
**Validation**: Automated test suite with hundreds of bash-created keys

#### 2. Performance Regression (MEDIUM)
**Risk**: Rust port slower than expected due to implementation issues
**Mitigation**: Continuous benchmarking, performance-focused design
**Target**: 10x minimum improvement over bash (0.240s → 0.024s)

#### 3. Cryptographic Compatibility (HIGH)
**Risk**: Age library differences between bash (CLI) and rust (library)
**Mitigation**: Use same age-rust library, extensive crypto validation
**Validation**: Cross-decryption tests between implementations

#### 4. Feature Regression (MEDIUM)
**Risk**: Missing bash features in initial rust port
**Mitigation**: Comprehensive feature parity checklist
**Timeline**: Allow extra month for edge case handling

### Low-Risk Areas

#### 1. CLI Compatibility (LOW)
**Risk**: Command-line interface changes break user workflows
**Mitigation**: Exact CLI argument compatibility, comprehensive help system

#### 2. Build System (LOW)  
**Risk**: Rust build more complex than bash
**Mitigation**: Standard cargo tooling, container-based builds

## Success Metrics

### Performance Targets
- **Key Operations**: 10-50x faster than bash
- **Memory Usage**: < 50MB peak for large operations
- **Binary Size**: < 10MB statically linked
- **Cold Start**: < 100ms for simple operations

### Quality Targets
- **Test Coverage**: > 95% line coverage
- **Cross-Compatibility**: 100% bash key format compatibility
- **Zero Regressions**: All bash functionality preserved
- **Security Audit**: Clean security audit from external firm

### Adoption Targets
- **Migration Rate**: 80% of repositories migrated within 6 months
- **Performance Reports**: Documented performance improvements
- **User Satisfaction**: Positive feedback on speed and reliability

## Future Evolution Path

### Year 1: Foundation
- Core rust implementation with feature parity
- Performance optimization and security hardening
- Migration tooling and deployment

### Year 2: Enhancement  
- Advanced features from Plan X novel approaches
- Plugin ecosystem development
- Web API and integration capabilities

### Year 3: Ecosystem
- Hardware security module integration
- Enterprise features and compliance
- Multi-language bindings (Python, Node.js)

---

*This Rust port plan leverages the proven architectures and performance insights from Plan X pilot to guide a successful migration from bash to a modern, high-performance Rust implementation while maintaining full backward compatibility and operational continuity.*