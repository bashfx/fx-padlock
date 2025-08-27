# Padlock Feature Completion Plan

## Executive Summary
The padlock security system has most features implemented but needs completion of the ignition API and resolution of several feature gaps identified in STATUS.md and FEATURES.md. This tool is extremely powerful and can irreversibly lock/encrypt systems, so all changes must be made carefully with thorough testing.

## Current State Analysis

### ✅ Working Features
- Standard lock/unlock with age encryption
- Git hooks and filter integration  
- Master key generation and management
- Repository tracking via manifest
- Team collaboration (add-recipient)
- Export/import for migration
- Repair functionality
- Map/unmap file tracking
- Clean artifact management (.chest pattern)

### 🔴 Critical Issues Identified

1. **Missing Ignition API Implementation**
   - The `ignite` command exists but is incomplete
   - Missing proper passphrase-based encryption flow
   - No integration with clamp's `-K|--ignition` flag
   - Functions exist but aren't fully connected

2. **Incomplete Features**
   - Overdrive mode has variable scoping issues
   - Some tar timestamp warnings in overdrive
   - Ignition backup creation needs validation

3. **Architecture Compliance**
   - Must follow BashFX 2.1 patterns strictly
   - Template functions need explicit `return 0`
   - Exit code propagation must be handled correctly

## Implementation Milestones

### Milestone 1: Complete Ignition API (1.5 points)
**Priority: CRITICAL**

#### Subtasks:
- [ ] Fix ignition key generation during clamp (0.5 points)
- [ ] Implement proper passphrase encryption flow (0.5 points)
- [ ] Connect ignite command to chest operations (0.5 points)

#### Technical Details:
- The `_ignition_lock` and `_ignition_unlock` functions exist
- Need to properly integrate with `do_clamp` when `-K` flag is used
- Must create chest directory structure for ignition mode
- Passphrase should encrypt age key for secure collaboration

### Milestone 2: Fix Overdrive Mode (1 point)
**Priority: HIGH**

#### Subtasks:
- [ ] Fix variable scoping in unlock script (0.5 points)
- [ ] Resolve tar timestamp warnings (0.25 points)
- [ ] Test edge cases comprehensively (0.25 points)

### Milestone 3: Validate & Test All Features (2 points)
**Priority: CRITICAL**

#### Subtasks:
- [ ] Run comprehensive test suite (0.5 points)
- [ ] Test with gitsim virtualization (0.5 points)
- [ ] Test ignition workflow end-to-end (0.5 points)
- [ ] Test overdrive lock/unlock cycle (0.5 points)

### Milestone 4: BashFX 2.1 Compliance (1 point)
**Priority: HIGH**

#### Subtasks:
- [ ] Add explicit `return 0` to all template functions (0.25 points)
- [ ] Fix exit code propagation in main() (0.25 points)
- [ ] Verify no function duplication (0.25 points)
- [ ] Check heredoc closure in all parts (0.25 points)

## Risk Assessment

### High Risk Areas
1. **Encryption Operations**: Any mistakes can cause data loss
2. **Key Management**: Improper key handling can lock users out
3. **Git Integration**: Broken hooks can corrupt repositories

### Mitigation Strategy
1. Use gitsim for all testing (virtual environment)
2. Create backups before any destructive operations
3. Test each change incrementally
4. Maintain SESSION.md with all findings

## Testing Strategy

### Phase 1: Unit Testing
- Test each function in isolation using func tool
- Verify all commands return proper exit codes
- Check help messages and error handling

### Phase 2: Integration Testing
- Test complete workflows with gitsim
- Verify git hooks work correctly
- Test manifest tracking and cleanup

### Phase 3: End-to-End Testing
- Full ignition workflow (clamp with -K, lock, unlock)
- Overdrive mode (lock entire repo, restore)
- Team collaboration (add recipients, share access)
- Migration (export/import across systems)

## Implementation Order

1. **First**: Fix ignition API (most critical missing feature)
2. **Second**: Run existing tests to establish baseline
3. **Third**: Fix any broken tests
4. **Fourth**: Implement missing ignition functionality
5. **Fifth**: Fix overdrive mode issues
6. **Sixth**: Comprehensive testing with gitsim
7. **Final**: Update documentation and SESSION.md

## Success Criteria

- [ ] All test_runner.sh tests pass 100%
- [ ] Ignition mode works end-to-end
- [ ] Overdrive mode completes without errors
- [ ] No function duplication in built padlock.sh
- [ ] All commands follow BashFX 2.1 patterns
- [ ] Comprehensive gitsim testing completed
- [ ] SESSION.md documents all changes

## Notes

- The system already has 100% test coverage per STATUS.md, but we need to verify this claim
- Some documentation may be stale - must verify all claims
- Must be extremely careful with this tool due to its power
- Use func and gitsim tools extensively for safe testing

## Next Steps

1. Review this plan with user for approval
2. Create feature branch for development
3. Begin implementation starting with ignition API
4. Test incrementally at each step
5. Document all findings in SESSION.md