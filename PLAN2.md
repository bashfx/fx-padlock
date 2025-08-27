# PLAN2.md - Phase 2 Opportunistic Improvements

## Overview
Phase 2 improvements based on comprehensive code analysis after completing command refactoring phase. Focus on user experience, performance optimization, and code quality improvements.

## Priority 1: Help System Enhancement (User Request)

### 1.1 Contextual Help System ⭐
**User Requirement**: Implement `padlock help master` instead of `padlock master help`

**Implementation**:
- Add `help` handler in `dispatch()` that processes second argument
- Create contextual help functions: `help_master()`, `help_sec()`, `help_rotate()`, etc.
- Maintain backward compatibility with existing help patterns

**Story Points**: 0.8

### 1.2 Tiered Help System ⭐
**User Requirement**: Implement `help more` pattern for AI token efficiency

**Implementation**:
- Create simplified help output (basic commands only)
- Add `help more` to show detailed help with all options
- Reduce token waste for AI parsing while keeping full help accessible

**Story Points**: 0.6

## Priority 2: Performance & Code Quality

### 2.1 Temporary File Management Cleanup
**Analysis**: Found 21 `mktemp` calls across codebase

**Implementation**:
- Create `_temp_cleanup()` function with trap-based cleanup
- Standardize temporary file patterns
- Add automatic cleanup for interrupted operations

**Story Points**: 0.7

### 2.2 Command Organization Optimization
**Analysis**: 3813-line parts/06_api.sh could benefit from better organization

**Implementation**:
- Consider splitting large command groups into logical sections
- Maintain current function-based patterns
- Add internal documentation headers for function groups

**Story Points**: 0.5

### 2.3 Error Handling Enhancement
**Analysis**: Inconsistent error return patterns in some functions

**Implementation**:
- Standardize error handling with consistent return codes
- Improve error messages for user clarity
- Add validation for edge cases identified in previous testing

**Story Points**: 0.6

## Priority 3: Documentation & Downstream Updates (Deferred from Phase 1)

### 3.1 Test Suite Updates ⭐
**Status**: High priority - tests need updating for new command structure

**Implementation**:
- Update `test_runner.sh` with new command names (sec/dec/release/master)
- Ensure all mini-dispatcher commands are tested
- Validate predicate enforcement works correctly

**Story Points**: 0.9

### 3.2 Documentation Updates
**Implementation**:
- Update `README.md` with new command examples
- Update help text examples in documentation
- Add mini-dispatcher usage patterns

**Story Points**: 0.4

## Priority 4: Advanced Features (Future-Ready)

### 4.1 Git Hook Refactor (Deferred)
**Analysis**: Git hooks currently call lock/unlock directly

**Implementation**:
- Create `_on_commit()` and `_on_checkout()` functions as specified in CONCEPTS.md
- Refactor git hooks to call `_on_*` functions instead of direct commands
- Maintain current functionality while improving architecture

**Story Points**: 0.8
**Priority**: Low - current system works well

### 4.2 Performance Profiling
**Implementation**:
- Add optional performance tracing for large repository operations
- Optimize file scanning patterns for better performance
- Consider caching for frequently accessed metadata

**Story Points**: 0.7
**Priority**: Medium - optimize only if needed

## Implementation Strategy

### Phase 2A: Core UX Improvements (Immediate)
1. **Help System Enhancement** (1.4 points)
2. **Test Suite Updates** (0.9 points)
3. **Temporary File Cleanup** (0.7 points)

**Total Phase 2A**: 3.0 story points

### Phase 2B: Code Quality & Documentation (Follow-up) 
1. **Error Handling Enhancement** (0.6 points)
2. **Code Organization** (0.5 points)  
3. **Documentation Updates** (0.4 points)

**Total Phase 2B**: 1.5 story points

### Phase 2C: Advanced Features (Optional)
1. **Git Hook Refactor** (0.8 points)
2. **Performance Profiling** (0.7 points)

**Total Phase 2C**: 1.5 story points

## Success Criteria

### Phase 2A Success:
- [ ] `padlock help master` shows master command help
- [ ] `padlock help` shows simplified interface, `padlock help more` shows full details
- [ ] All tests updated and passing with new command structure
- [ ] Temporary files cleaned up properly in all error scenarios
- [ ] All improvements maintain backward compatibility

### Phase 2B Success:
- [ ] Consistent error handling across all functions
- [ ] Better code organization and internal documentation
- [ ] Updated README and documentation reflects new command structure

### Phase 2C Success:
- [ ] Git hooks use `_on_*` functions as architectural layer
- [ ] Performance improvements measurable in large repositories

## Technical Notes

### Help System Implementation Pattern
```bash
# In dispatch():
help)
    case "${2:-}" in
        master|sec|rotate|revoke|ignite)
            "help_$2" "${@:3}"
            ;;
        more)
            usage_detailed
            ;;
        *)
            usage  # Simplified help
            ;;
    esac
    ;;
```

### Temporary File Cleanup Pattern
```bash
_temp_cleanup() {
    local temp_files=("$@")
    for temp_file in "${temp_files[@]}"; do
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
    done
}

# Usage:
temp_file=$(mktemp)
trap "_temp_cleanup '$temp_file'" EXIT ERR
```

### Risk Assessment

**Low Risk**:
- Help system changes (additive only)
- Documentation updates
- Temporary file cleanup (improves reliability)

**Medium Risk**:
- Test suite updates (must not break existing functionality)
- Code reorganization (maintain function boundaries)

**Future Risk**:
- Git hook refactor (touches critical security integration)

## Automation Approach

Execute Phase 2A immediately with comprehensive testing after each component. Phase 2B and 2C can be tackled based on testing results and user feedback.

**Next Action**: Begin Phase 2A implementation starting with help system enhancement.