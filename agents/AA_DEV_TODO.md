# Architecture Alignment Tasks
**Generated**: 2025-09-08  
**FXAA Analysis**: Critical BashFX violations identified  
**Priority**: Address blocking issues before RSB migration  

## BLOCKING ISSUES (Fix Immediately)

- [ ] **[BLOCKING]** Subdivide parts/06_api.sh (4,518 lines → max 500) - violates BashFX part size limits by 900%
  - **File**: `parts/06_api.sh` (lines 1-4518)  
  - **Issue**: Single part contains 61% of entire codebase (72 functions)
  - **Fix**: Split into logical domains: 06a_master_api.sh, 06b_ignition_api.sh, 06c_repo_api.sh, 06d_key_api.sh
  - **Impact**: Critical maintainability violation, exceeds AI comprehension limits

- [ ] **[BLOCKING]** Reduce parts/04_helpers.sh size (1,479 lines → target <1000) - exceeds BashFX recommendations by 196%  
  - **File**: `parts/04_helpers.sh` (lines 1-1479)
  - **Issue**: Helper part contains 20% of codebase (55 functions), insufficient separation of concerns
  - **Fix**: Separate into themed helpers: 04a_core_helpers.sh, 04b_key_helpers.sh, 04c_git_helpers.sh
  - **Impact**: Architecture imbalance, violates modular design principles

- [ ] **[BLOCKING]** Document Function Ordinality mapping across all 127+ functions  
  - **Files**: All parts files, especially 06_api.sh and 04_helpers.sh
  - **Issue**: No clear documentation of High-Order vs Mid-Level vs Low-Level function placement
  - **Fix**: Create ordinality matrix showing which functions belong in which ordinal tier
  - **Impact**: Function placement violations, architectural ambiguity

## HIGH PRIORITY (Architecture Hardening)

- [ ] **[NON-BLOCKING]** Create Part Responsibility Matrix documentation
  - **Files**: All 9 parts files  
  - **Issue**: Unclear boundaries between parts leads to function misplacement
  - **Fix**: Document explicit responsibilities and boundaries for each part
  - **Impact**: Prevents future architecture drift

- [ ] **[NON-BLOCKING]** Implement build.sh part size monitoring alerts
  - **File**: `build.sh` (build system)
  - **Issue**: No automated detection when parts exceed BashFX size recommendations  
  - **Fix**: Add size checking that warns when parts exceed 500 lines
  - **Impact**: Prevents future size violations

- [ ] **[NON-BLOCKING]** Standardize error handling patterns across parts
  - **Files**: All parts, especially 06_api.sh, 04_helpers.sh, 07_core.sh
  - **Issue**: Inconsistent return code patterns and error propagation
  - **Fix**: Define standard error handling patterns following BashFX v3 conventions
  - **Impact**: Improves reliability and debugging consistency

- [ ] **[NON-BLOCKING]** Fix function prefix pattern violations  
  - **Files**: Multiple parts with mixed `_` vs `__` patterns
  - **Issue**: Inconsistent adherence to BashFX private function naming standards
  - **Fix**: Audit and standardize all function prefixes according to ordinality rules
  - **Impact**: Code clarity and BashFX v3 compliance

## RSB MIGRATION PREPARATION  

- [ ] **[NON-BLOCKING]** Analyze cross-part function dependencies
  - **Files**: All parts, focus on 06_api.sh → 04_helpers.sh calls
  - **Issue**: Need dependency map before RSB migration to avoid breaking changes  
  - **Fix**: Document which functions call across part boundaries
  - **Impact**: Critical for successful RSB porting strategy

- [ ] **[NON-BLOCKING]** Create RSB migration priority matrix for 06_api.sh functions
  - **File**: `parts/06_api.sh` (72 functions)
  - **Issue**: Need systematic approach to porting 4,518 lines to Rust
  - **Fix**: Categorize functions by complexity, security sensitivity, and performance needs
  - **Impact**: Enables phased RSB migration approach

- [ ] **[NON-BLOCKING]** Document security boundary definitions  
  - **Files**: 06_api.sh, 04_helpers.sh (key management functions)
  - **Issue**: Unclear which functions handle sensitive operations for RSB boundary planning
  - **Fix**: Identify and document all functions that handle keys, passphrases, or encryption
  - **Impact**: Critical for RSB security architecture design

## LONG-TERM IMPROVEMENTS

- [ ] **[NON-BLOCKING]** Design FFI bridge architecture for Rust-Bash integration
  - **Context**: Post part-subdivision, pre-RSB migration
  - **Issue**: Need clean interface between future Rust core and Bash CLI layer
  - **Fix**: Design FFI patterns for hybrid architecture
  - **Impact**: Enables successful RSB migration without breaking existing workflows

- [ ] **[NON-BLOCKING]** Create comprehensive testing strategy for parts-based architecture  
  - **Files**: Test infrastructure, all parts
  - **Issue**: Current tests don't reflect parts-based organization
  - **Fix**: Implement part-specific testing that matches architectural boundaries
  - **Impact**: Better test coverage, prevents regression during refactoring

- [ ] **[NON-BLOCKING]** Establish size monitoring and complexity metrics
  - **Context**: Build system integration  
  - **Issue**: Need automated tracking to prevent future architecture violations
  - **Fix**: Implement metrics collection and reporting in build pipeline
  - **Impact**: Prevents architectural drift, maintains BashFX compliance

---

## SEVERITY CLASSIFICATION

**BLOCKING**: Violates BashFX architectural standards, prevents maintainability  
**NON-BLOCKING**: Improves compliance, enables better architecture, reduces technical debt  

## COMPLETION CRITERIA

- [ ] All parts under 1,000 lines (target <500)
- [ ] Function ordinality clearly documented  
- [ ] Part responsibilities explicitly defined
- [ ] RSB migration plan completed
- [ ] Architecture documentation updated

**Total Tasks**: 12  
**Blocking**: 3  
**High Priority**: 4  
**RSB Preparation**: 3  
**Long-term**: 2  

---

**QA Triage Required**: Blocking issues must be addressed before continuing development