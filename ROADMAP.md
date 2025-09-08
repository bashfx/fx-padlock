# Padlock MVP to RSB Migration Roadmap

## Overview
Practical roadmap to bring padlock from current state to minimal viable product (MVP) with baseline functionality, then migrate to RSB framework for long-term sustainability.

**Current Status**: 98% feature complete, but unsafe for production use  
**Goal**: MVP → RSB Migration (not additional features)  
**Priority**: Basic functionality + lockout prevention over extensive security

## Phase 0: Critical MVP Stabilization (2-4 weeks)
*Make current BashFX version "sufficient" - baseline functionality with safety*

### 0.1 Repository Safety (Week 1) - CRITICAL
**Priority**: Prevent permanent repository lockout

- **Fix TODO Security Stubs** (5 critical functions in parts/06_api.sh)
  - `revoke()` - basic implementation for key removal
  - `rotate()` - basic key rotation without breaking existing locks
  - `reset()` - emergency repository unlock mechanism
  - `verify()` - basic integrity checking
  - `status()` - repository lock status reporting

- **Implement Basic Recovery Mechanisms**
  - Emergency unlock command (`padlock emergency-unlock`)
  - Repository state validation before operations
  - Backup key storage and retrieval
  - Safe-mode operation for corrupted states

- **Add Concurrent Access Protection**
  - Basic file locking to prevent race conditions
  - Simple collision detection and waiting
  - Process cleanup on interrupt

### 0.2 TTY Automation - Baseline (Week 2)
**Priority**: Basic automation, not perfect solution

- **Implement Simplest Working TTY Solution** (from pilot research)
  - Choose one of the 8+ researched methods that works
  - Focus on "good enough" rather than "perfect"
  - Document known limitations
  - Provide fallback manual mode

- **Basic Error Handling**
  - Graceful fallback when TTY automation fails  
  - Clear error messages for common failure modes
  - Manual intervention prompts when needed

### 0.3 Architecture Remediation (Week 3-4)
**Priority**: Prepare for RSB migration

- **Subdivide parts/06_api.sh** (4,518 lines → manageable parts)
  - Split by functional areas: auth, crypto, storage, management
  - Maintain BashFX build compatibility
  - Create parts/06_api_*.sh structure
  - Update build.sh accordingly

- **Basic Testing Framework**
  - Simple smoke tests for core operations
  - Repository safety validation tests
  - Regression prevention for existing functionality
  - Use gitsim for safe testing environment

## Phase 1: RSB Migration Planning (1-2 weeks)
*Prepare for technology transition*

### 1.1 RSB Architecture Specification
- **Hybrid Architecture Design**
  - Bash CLI layer (lightweight orchestration)
  - RSB core library (security, crypto, complex logic)
  - Clear interface boundaries between layers

- **Migration Component Mapping**
  - Identify Bash-appropriate components (CLI, config, simple utilities)
  - Identify RSB-appropriate components (crypto, security, complex state management)
  - Design FFI interface between layers

### 1.2 Development Environment Setup
- **RSB Project Structure** 
  - Create parallel RSB project structure
  - Set up Rust development dependencies
  - Design build integration between Bash and RSB components

## Phase 2: RSB Core Migration (4-6 weeks)
*Gradual migration of complex components*

### 2.1 Security Core Migration (Week 1-2)
- **Migrate crypto operations** from parts/06_api.sh to RSB
- **Implement safe key management** in Rust
- **Create FFI bridge** for Bash to call RSB functions

### 2.2 State Management Migration (Week 3-4)
- **Move repository state management** to RSB
- **Implement safe file operations** with proper locking
- **Add comprehensive error handling** with Rust's Result types

### 2.3 Integration and Testing (Week 5-6)
- **Integrate Bash CLI with RSB core**
- **Comprehensive testing** of hybrid architecture
- **Performance validation** and optimization
- **Safety testing** with gitsim scenarios

## Success Criteria

### Phase 0 MVP Requirements
- ✅ **No permanent repository lockouts** possible
- ✅ **Basic operations work** (lock, unlock, key management)
- ✅ **TTY automation functional** (even if imperfect)
- ✅ **Recovery mechanisms** available for failures
- ✅ **Safe for testing** on non-critical repositories

### Phase 2 RSB Migration Success
- ✅ **All MVP functionality** preserved in hybrid architecture
- ✅ **Improved safety** through Rust's type system
- ✅ **Better maintainability** with proper separation of concerns
- ✅ **Foundation for future enhancements** without complexity explosion

## Non-Goals (Explicitly Deferred)
- Advanced security features beyond MVP
- Performance optimization beyond basic requirements
- Additional command surface expansion
- Enterprise-grade audit logging
- Post-quantum cryptography integration
- AI-native security features

## Risk Mitigation
- **Use gitsim extensively** for all testing
- **Maintain backup/recovery options** throughout
- **Incremental migration approach** (not big-bang)
- **Preserve working functionality** during transition
- **Clear rollback plan** if RSB migration fails

## Quality Gates
- Each phase must pass basic safety tests
- No regressions in working functionality
- Repository lockout prevention validated
- TTY automation working for common cases
- Build system remains functional throughout

---
*Focus: Practical completion over perfection*  
*Goal: Safe, functional tool ready for RSB evolution*  
*Updated: 2025-09-08*