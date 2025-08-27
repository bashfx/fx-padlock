# 🔥 Padlock Ignition System - Product Requirements Document (PRD)

## Executive Summary

**Problem**: AI systems and automation tools cannot access padlock-encrypted repositories because age encryption requires interactive key management, making automation impossible.

**Solution**: Implement an ignition key system that provides passphrase-based repository access for third-party automation while maintaining security through controlled key hierarchies and revocation capabilities.

**Impact**: Enables seamless AI collaboration with encrypted repositories using simple environment variables (`PADLOCK_IGNITION_PASS="phrase"`).

---

## User Stories & Acceptance Criteria

### **Epic 1: Repository Owner - Ignition Setup**

#### **User Story 1.1: Enable Ignition on Repository**
**As a** repository owner  
**I want to** enable ignition access on my encrypted repository  
**So that** I can safely share access with AI systems and automation tools

**Acceptance Criteria:**
- ✅ `padlock clamp /repo --with-ignition` creates repo with ignition enabled
- ✅ Creates I key (repo-ignition master) for managing distributed access
- ✅ Repository status shows "Ignition: enabled" 
- ✅ Backward compatible: existing repos without ignition continue working
- ✅ `padlock status` clearly indicates ignition availability

#### **User Story 1.2: Create Distributed Access Keys**
**As a** repository owner  
**I want to** create named access keys for different AI systems  
**So that** I can track and manage access per system

**Acceptance Criteria:**
- ✅ `padlock ignite new --name=ai-bot` creates distributed ignition key  
- ✅ `padlock ignite new --name=ai-bot --phrase=custom` uses custom passphrase
- ✅ Auto-generated passphrases are human-readable (word-based)
- ✅ Key creation displays passphrase for distribution
- ✅ `padlock ignite list` shows all created distributed keys
- ✅ Each key has unique name and cannot conflict

### **Epic 2: AI/Automation - Repository Access**

#### **User Story 2.1: Simple Passphrase Access**
**As an** AI system or automation tool  
**I want to** access encrypted repositories with a simple passphrase  
**So that** I can work with encrypted content without complex key management

**Acceptance Criteria:**
- ✅ `PADLOCK_IGNITION_PASS="phrase" padlock ignite unlock` decrypts repository
- ✅ Works in non-interactive environments (CI/CD, automation scripts)
- ✅ `padlock ignite unlock --name=ai-bot` uses specific named key
- ✅ Unlocked repository works with all standard padlock commands
- ✅ Clear error messages when passphrase is incorrect or missing

#### **User Story 2.2: Status and Verification**  
**As an** AI system  
**I want to** check ignition system status and verify my access  
**So that** I can troubleshoot access issues and confirm repository state

**Acceptance Criteria:**
- ✅ `padlock ignite status` shows available keys and repository state
- ✅ `padlock ignite verify --key=/path/key` tests if key can access repository  
- ✅ `padlock ignite verify --key=/path/key --phrase=pass` dry-run test with passphrase
- ✅ Commands return proper exit codes (0=success, 1=failure) for automation
- ✅ Status includes last unlock time and key used

### **Epic 3: Repository Owner - Access Management**

#### **User Story 3.1: Revoke Individual Access**
**As a** repository owner  
**I want to** revoke access for specific AI systems  
**So that** I can immediately cut off access without affecting other systems

**Acceptance Criteria:**
- ✅ `padlock ignite revoke --name=ai-bot` invalidates specific distributed key
- ✅ Revoked key immediately fails authentication
- ✅ Other distributed keys continue working normally  
- ✅ `padlock ignite list` shows revoked keys as inactive
- ✅ Revocation is permanent and irreversible

#### **User Story 3.2: Rotate All Access Keys**
**As a** repository owner  
**I want to** rotate all ignition access keys at once  
**So that** I can refresh security for all AI systems simultaneously

**Acceptance Criteria:**
- ✅ `padlock ignite rotate` invalidates ALL distributed keys for repository
- ✅ Creates new I key (repo-ignition master)
- ✅ All existing distributed keys stop working immediately
- ✅ Repository owner can create new distributed keys after rotation
- ✅ Clear warning about impact before rotation executes

#### **User Story 3.3: Nuclear Reset**
**As a** repository owner  
**I want to** completely remove ignition access from repository  
**So that** I can return to traditional key-only access

**Acceptance Criteria:**
- ✅ `padlock ignite reset` removes all ignition infrastructure
- ✅ Deletes I key and all D keys
- ✅ Clears ignition manifest and metadata
- ✅ Repository continues working with traditional R key access
- ✅ Requires confirmation prompt (destructive action)

### **Epic 4: Advanced Management**

#### **User Story 4.1: Key Discovery and Registration**
**As a** repository owner  
**I want to** discover and register existing ignition keys  
**So that** I can manage keys created outside normal workflows

**Acceptance Criteria:**
- ✅ `padlock ignite register --key=/path/key` adds existing D key to manifest
- ✅ `padlock ignite maybe --key=/path/key` checks if wayward D key belongs to different repo
- ✅ `padlock ignite integrity` verifies all I/D key relationships are valid
- ✅ Registration fails if key cannot access repository
- ✅ Integrity check reports all inconsistencies

#### **User Story 4.2: Automatic Expiration**
**As a** repository owner  
**I want** ignition keys to automatically expire after 6 months  
**So that** long-term access doesn't become a security risk

**Acceptance Criteria:**
- ✅ Repository tracks I key creation date in manifest
- ✅ `padlock ignite unlock` checks expiration and auto-rotates if needed
- ✅ Auto-rotation invalidates all D keys and shows warning
- ✅ Expiration period configurable (default 180 days)
- ✅ Cannot be bypassed by changing system clock or filenames

---

## Technical Requirements

### **Core Architecture**
- **Key Hierarchy**: X → M → R → I → D (authority flows down)
- **Ignition Keys**: Passphrase-wrapped age keys with embedded metadata
- **Recipient Chain**: All parent keys are recipients of child key data
- **Authority Model**: Any parent key can manage its children

### **Security Requirements**
- **Isolation**: D keys cannot access other repositories or manage other keys
- **Revocation**: Rotating I key immediately invalidates all D keys  
- **Master Authority**: M key retains emergency access to all ignition keys
- **Non-Repudiation**: All key operations logged with timestamps

### **Performance Requirements**
- **Unlock Speed**: < 3 seconds for standard repository unlock
- **Key Creation**: < 5 seconds for distributed key generation
- **Scalability**: Support 50+ distributed keys per repository
- **Storage**: Minimal overhead (< 1MB for ignition infrastructure)

### **Integration Requirements**  
- **Backward Compatibility**: Existing repos work without modification
- **Git Hooks**: Seamless integration with existing lock/unlock workflows
- **Status Integration**: All status commands show ignition information
- **Export/Import**: Ignition keys included in repository backups

### **Platform Requirements**
- **Age/Rage Compatibility**: Works with both age and rage encryption
- **Automation Friendly**: All commands work in non-interactive environments
- **Error Handling**: Clear error messages and recovery guidance
- **Documentation**: Complete usage examples and troubleshooting guide

---

## Implementation Phases

### **Phase 1: Core Ignition System (MVP)**
**Timeline**: 2-3 days  
**Scope**: Basic I/D key creation and unlock functionality

**Deliverables:**
- ✅ `padlock ignite create` - Create I key (repo-ignition master)
- ✅ `padlock ignite new --name=ai-bot` - Create D key (distributed)
- ✅ `padlock ignite unlock --name=ai-bot` - Unlock with D key
- ✅ Basic passphrase wrapping with fake TTY workaround
- ✅ Simple manifest tracking

**Success Criteria:**  
- AI system can unlock repository with `PADLOCK_IGNITION_PASS`
- Repository owner can create and use distributed keys
- Basic error handling and validation

### **Phase 2: Management & Security (Production)**
**Timeline**: 3-4 days  
**Scope**: Full management API and security features

**Deliverables:**
- ✅ `padlock ignite revoke --name=ai-bot` - Revoke specific D key
- ✅ `padlock ignite rotate` - Rotate all access keys
- ✅ `padlock ignite list` - Show all distributed keys
- ✅ Auto-expiration with upstream repository control
- ✅ Complete integration with clamp/status/export commands

**Success Criteria:**
- Complete access management lifecycle
- Security boundaries enforced and tested
- Full integration with existing padlock workflows

### **Phase 3: Advanced Features (Enhancement)**
**Timeline**: 2-3 days  
**Scope**: Discovery, verification, and edge case handling

**Deliverables:**
- ✅ `padlock ignite verify/register/maybe/integrity` commands
- ✅ Comprehensive error handling and recovery guidance
- ✅ Performance optimization and scalability testing
- ✅ Complete documentation and usage examples

**Success Criteria:**
- Handles all edge cases gracefully
- Performance meets requirements
- Documentation enables self-service adoption

---

## Success Metrics

### **Functional Metrics**
- **Key Creation Success Rate**: > 99% (D key creation completes successfully)  
- **Unlock Success Rate**: > 99% (valid passphrase unlocks repository)
- **Revocation Effectiveness**: 100% (revoked keys immediately stop working)
- **Integration Coverage**: 100% (all padlock commands work with ignition repos)

### **Performance Metrics**
- **Unlock Latency**: < 3 seconds average (passphrase to unlocked repository)
- **Key Creation Time**: < 5 seconds (new distributed key generated)
- **Storage Overhead**: < 1MB (ignition infrastructure per repository)
- **Scalability**: 50+ distributed keys per repository without degradation

### **Security Metrics**  
- **Isolation Verification**: 100% (D keys cannot cross-access repositories)
- **Authority Enforcement**: 100% (only authorized keys can manage others)
- **Revocation Speed**: < 1 second (key invalidation takes effect)
- **Expiration Compliance**: 100% (auto-rotation cannot be bypassed)

### **Usability Metrics**
- **Setup Complexity**: 1 command (enable ignition on repository)
- **AI Integration**: 1 environment variable (PADLOCK_IGNITION_PASS)
- **Error Recovery**: Clear guidance for all failure scenarios
- **Documentation Coverage**: 100% (all commands and workflows documented)

---

## Risk Assessment & Mitigation

### **High Risk: Age Encryption Limitations**
**Risk**: Age `-p` passphrase mode only works interactively, blocking automation
**Impact**: Core ignition functionality impossible without workarounds  
**Mitigation**: Implement fake TTY solution or migrate to rage with custom pinentry
**Owner**: Implementation team
**Status**: Mitigation planned

### **Medium Risk: Key Hierarchy Complexity**
**Risk**: I/D key relationships could become confusing for users
**Impact**: User errors in key management, security vulnerabilities
**Mitigation**: Clear documentation, comprehensive error messages, integrity checking
**Owner**: Product team  
**Status**: Addressed in design

### **Medium Risk: Backward Compatibility**
**Risk**: Ignition changes could break existing padlock repositories
**Impact**: User data loss, workflow disruption  
**Mitigation**: Extensive testing, graceful fallbacks, migration tools
**Owner**: QA team
**Status**: Testing planned

### **Low Risk: Performance at Scale**
**Risk**: Many distributed keys could slow down operations
**Impact**: User experience degradation with large teams
**Mitigation**: Performance testing, optimization, scalability limits
**Owner**: Implementation team
**Status**: Monitoring planned

---

## Dependencies & Assumptions

### **Technical Dependencies**
- **Age/Rage**: Encryption backend must support passphrase operations
- **BashFX 2.1**: Build system and architectural patterns  
- **Git Hooks**: Integration with existing lock/unlock automation
- **XDG Directories**: Standard configuration and key storage locations

### **User Assumptions**
- **Repository Owners**: Have sufficient technical knowledge to manage access keys
- **AI Systems**: Can handle environment variables and basic error recovery
- **Network Access**: Available for rage remote key scenarios (if implemented)
- **Backup Practices**: Users maintain proper key backup and recovery procedures

### **Business Assumptions**
- **AI Adoption**: Demand for AI repository access will continue growing
- **Security Requirements**: Current threat model (repo scrapers, not nation-states) remains valid
- **Platform Evolution**: Age/rage ecosystem will continue supporting automation use cases
- **User Base**: Primarily technical users comfortable with command-line tools

---

## Acceptance & Launch Criteria

### **Technical Acceptance**
- ✅ All user stories meet acceptance criteria with automated tests
- ✅ Integration tests pass on Linux, macOS, and Windows (WSL)
- ✅ Performance benchmarks meet requirements under load testing
- ✅ Security audit confirms isolation and authority enforcement
- ✅ Backward compatibility verified with existing repositories

### **Documentation Acceptance**
- ✅ Complete command reference with examples
- ✅ Integration guide for AI systems and automation tools  
- ✅ Troubleshooting guide covering common error scenarios
- ✅ Security model explanation for repository owners
- ✅ Migration guide for existing padlock users

### **Launch Readiness**
- ✅ Feature flags enable gradual rollout
- ✅ Rollback procedure tested and documented
- ✅ Support team trained on ignition system troubleshooting
- ✅ User feedback collection mechanism in place
- ✅ Monitoring and alerting configured for key operations

---

## Post-Launch Support

### **Monitoring & Metrics**
- Key operation success rates and latency
- User adoption and feature usage patterns
- Error rates and common failure scenarios  
- Performance metrics under various load conditions

### **User Support**
- Dedicated ignition troubleshooting documentation
- Community forum for user questions and solutions
- Direct support escalation for security-related issues
- Regular user feedback collection and feature requests

### **Maintenance & Evolution**  
- Regular security reviews and threat model updates
- Performance optimization based on usage patterns
- Feature enhancements based on user feedback
- Integration with emerging AI platforms and tools

---

**This PRD provides complete product requirements for implementing the Padlock Ignition System with clear acceptance criteria, success metrics, and launch readiness requirements.**