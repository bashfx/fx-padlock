# Phase 1 Ignition API Implementation Roadmap
**Source**: PILOT_PLANX.md integration plan  
**Current Status**: 33% complete (1 of 3 major phases done)  
**Branch**: pilot/ignition  
**Target**: Complete ignition key system with I & D key functionality

## Implementation Progress Overview

### **✅ COMPLETED (Phase 1a - Core Innovation)**
**TTY Subversion Foundation** - The breakthrough that makes everything possible
- **TASK-001**: ✅ TTY subversion functions (_age_interactive_encrypt/decrypt)
- **TASK-001-FIX**: ✅ Security hardening (command injection eliminated via named pipes)
- **Innovation**: Age gets TTY interaction, we get automation - philosophical breakthrough
- **Security**: Production-ready with zero vulnerabilities

### **🚨 BLOCKED (Phase 1b - API Activation)**
**Function Duplication Issue** - Simple fix blocks major functionality  
- **TASK-002**: Enhanced do_ignite() implementation EXISTS but inactive
- **TASK-002-FIX**: 🚨 CRITICAL - Remove stub function (line 1625+), keep enhanced (line 1281)
- **Impact**: All advanced ignition features currently inactive
- **Fix Time**: 5-15 minutes (0.1 story points)

### **⏳ REMAINING (67% of implementation)**
**Clear roadmap following PILOT_PLANX blueprint**

---

## PILOT_PLANX Implementation Mapping

### **Phase 1: Core Implementation** (Week 1-2) 
*Foundation for all ignition operations*

| **PILOT_PLANX Component** | **Current Task** | **Status** | **Description** |
|---------------------------|------------------|------------|----------------|
| **1.1 BashFX v3 Command Surface** | TASK-002 | ❌ **BLOCKED** | Complete API implemented, needs activation |
| **1.2 TTY Subversion Functions** | TASK-001 | ✅ **DONE** | `_age_interactive_*` functions operational |
| **1.3 Enhanced do_ignite()** | TASK-002 | ❌ **BLOCKED** | Mini-dispatcher pattern with environment support |

**Commands Ready After TASK-002-FIX**:
```bash
padlock ignite create [name] [--phrase="..."]     # Ignition master (I)
padlock ignite new --name=NAME [--phrase="..."]   # Distributed key (D)  
padlock ignite unlock [name]                       # Unlock with passphrase
padlock ignite list                                # Show available keys
padlock ignite status [name]                       # Key metadata
```

### **Phase 2: Storage & Key Management** (Week 2)
*Secure key storage and metadata system*

| **PILOT_PLANX Component** | **Current Task** | **Status** | **Description** |
|---------------------------|------------------|------------|----------------|
| **2.1 Directory Structure** | TASK-003 | ⏳ **QUEUED** | `.padlock/ignition/` hierarchy |
| **2.2 Key Bundle Creation** | TASK-003 | ⏳ **QUEUED** | TTY magic + metadata integration |

**Storage Architecture**:
```
.padlock/
├── master.key              # Existing master key (M)
├── ignition/               # New ignition system
│   ├── keys/              
│   │   ├── [name].ikey    # Ignition master keys (I) 
│   │   └── [name].dkey    # Distributed keys (D)
│   ├── metadata/
│   │   ├── [name].json    # Key metadata & authority
│   │   └── cache/         
│   └── .derived/          # Deterministic key cache
│       └── [hash].key     # Performance optimization
```

### **Phase 3: Integration & Testing** (Week 3)
*System integration and comprehensive validation*

| **PILOT_PLANX Component** | **Current Task** | **Status** | **Description** |
|---------------------------|------------------|------------|----------------|
| **3.1 Dispatcher Integration** | TASK-006 | ⏳ **QUEUED** | Router updates in parts/07_core.sh |
| **3.2 Help System** | TASK-002 | ✅ **READY** | Contextual help in enhanced do_ignite() |
| **3.3 Utility Functions** | TASK-003/004 | ⏳ **QUEUED** | Key listing, validation, management |

### **Phase 4: Security & Validation** (Week 4)  
*Production-ready security framework*

| **PILOT_PLANX Component** | **Current Task** | **Status** | **Description** |
|---------------------------|------------------|------------|----------------|
| **4.1 Authority Validation** | TASK-004 | ⏳ **QUEUED** | Master key authority chains |
| **4.2 Edge Cases & Risk** | TASK-004 | ⏳ **QUEUED** | Error handling, security boundaries |
| **4.3 Implementation Safeguards** | TASK-004 | ⏳ **QUEUED** | Validation framework |
| **4.4 gitsim Testing** | TASK-005 | ⏳ **QUEUED** | Comprehensive security scenarios |

---

## Detailed Task Breakdown

### **IMMEDIATE: TASK-002-FIX** 🚨
**Criticality**: BLOCKING - Prevents all other progress  
**Effort**: 0.1 story points (5-15 minutes)  
**Fix**: Delete duplicate function in parts/06_api.sh line 1625+

**Required Actions**:
1. Remove stub `do_ignite()` at line 1625+ 
2. Keep enhanced `do_ignite()` at line 1281
3. Run `./build.sh` to validate
4. QA validation to confirm features active

### **NEXT: TASK-003** - Key Storage Architecture
**Effort**: 1 story point  
**Dependencies**: TASK-002-FIX completion

**Implementation Scope**:
- Directory structure creation (`_setup_ignition_directories`)
- Key bundle format with JSON metadata 
- File naming conventions (.ikey, .dkey, .json)
- Master key authority validation hooks
- Derived key caching system for performance

**Key Functions to Implement**:
```bash
_setup_ignition_directories()      # Create storage hierarchy
_create_ignition_metadata()        # JSON metadata generation  
_store_key_bundle()               # Secure key storage
_load_key_bundle()                # Key retrieval with validation
_cache_derived_key()              # Performance optimization
```

### **FOLLOWING: TASK-004** - Security Framework
**Effort**: 1 story point  
**Dependencies**: TASK-003 completion

**Implementation Scope**:
- Authority validation chains (M → R → I → D)
- Error handling and user feedback
- Security boundary enforcement
- Passphrase validation and strength checking
- Environment variable security (PADLOCK_IGNITION_PASS)

**Security Requirements**:
- No passphrase exposure in process lists
- Proper temp file cleanup
- Master key authority maintained
- Derived key cache security

### **THEN: TASK-005** - gitsim Security Test Suite  
**Effort**: 1 story point  
**Dependencies**: TASK-004 completion

**Test Scenarios** (from PILOT_PLANX):
- Master key compromise simulation
- Passphrase brute force protection
- Authority validation edge cases
- Environment variable exposure prevention
- Multi-repository key isolation
- Key corruption recovery testing

### **FINALLY: TASK-006** - Build Integration
**Effort**: 1 story point  
**Dependencies**: TASK-005 completion

**Integration Tasks**:
- Dispatcher routing in parts/07_core.sh
- Build system validation and optimization  
- Final performance benchmarking
- Regression testing for existing functionality
- Documentation updates

---

## Success Criteria & Quality Gates

### **Phase 1 Completion Requirements**
- [ ] All 6 tasks completed and validated
- [ ] Complete ignition key system operational
- [ ] Full security test suite passing  
- [ ] Performance within Plan X benchmarks (~0.240s)
- [ ] No regressions in existing functionality
- [ ] Production-ready implementation

### **Quality Gates per ITERATION.md**
- ✅ All tests must pass (`./test_runner.sh`)
- ✅ No regression of existing functionality  
- ✅ BashFX v3.0 architecture compliance
- ✅ Security validation via gitsim
- ✅ Performance within Plan X benchmarks

### **Command Surface Completion**
**Core Commands** (Phase 1 target):
- `padlock ignite create/new` - Key generation with TTY magic
- `padlock ignite unlock` - Passphrase and environment unlock
- `padlock ignite list/status` - Key management utilities

**Advanced Commands** (Future phases):
- `padlock ignite allow <pubkey>` - Public key authorization  
- `padlock ignite rotate/revoke` - Key lifecycle management
- `padlock ignite verify/reset` - Advanced validation tools

---

## Strategic Context

### **Competitive Advantages Ready**
Post-Phase 1 positioning from research assets:
- **Post-Quantum Integration**: Hybrid cryptography pathway established
- **TTY Framework Extraction**: Reusable automation beyond age  
- **Zero-Knowledge Architecture**: Enterprise privacy capabilities
- **AI-Native Security**: Intelligent decision engine concepts

### **Proven Methodology**
**5-Agent Coordination System** operational:
- Security-first approach catching vulnerabilities early
- Research-driven solutions (Named Pipe Strategy success)
- Quality gates preventing production issues
- Real-time architectural validation

### **Technical Foundation**
- **BashFX 3.0**: Excellent architectural compliance maintained
- **Build System**: Stable 7006-line compilation with 9 modules  
- **Security**: Command injection eliminated, production-ready
- **Innovation**: TTY subversion technique philosophically superior

---

## Implementation Notes

### **Key Design Decisions from PILOT_PLANX**
1. **Layered Native Approach**: Chosen over 5 alternatives for optimal performance/security balance
2. **TTY Subversion**: Work WITH age rather than against it - philosophical breakthrough
3. **Master Key Authority**: All ignition keys encrypted with master key for control
4. **JSON Metadata**: Rich metadata embedded in key files for management
5. **Environment Variable Support**: PADLOCK_IGNITION_PASS for automation

### **Critical Success Factors**
- **Function Deduplication**: TASK-002-FIX must be resolved first
- **Security Testing**: gitsim validation cannot be skipped
- **Performance Compliance**: Must maintain ~0.240s benchmark
- **Architecture Discipline**: BashFX 3.0 patterns throughout
- **Quality Gates**: Each task must pass security → architecture → QA review

---
*Roadmap compiled from PILOT_PLANX.md integration plan and current implementation analysis*  
*Updated: 2025-08-28 for consolidated project planning*