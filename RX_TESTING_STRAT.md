# RX Testing Strategy - Unified Test System

## Overview
The fx-padlock project now uses a unified test dispatcher system that replaces the previous dual test runners with a single, organized approach. This provides better maintainability, clearer test categorization, and improved developer experience.

## Architecture

### Test Dispatcher
- **Entry Point:** `./test.sh` - Single command for all testing needs
- **Categories:** Organized test suites by purpose and execution time
- **Discovery:** Automatic test discovery within category directories
- **Execution:** Granular control from category-wide to individual tests

### Directory Structure
```
tests/
├── smoke/              # Quick validation tests (2-3 min)
│   └── test_core.sh    # Basic functionality validation
├── integration/        # Full workflow tests (5-10 min)
│   ├── test_e2e.sh     # End-to-end scenarios
│   ├── test_backup.sh  # Backup/restore workflows
│   └── test_ignition.sh # Master key workflows
├── security/          # Security validation tests (3-5 min)
│   ├── test_security.sh       # Key management security (rotation, revocation, unlock)
│   └── injection_prevention.sh # Command injection & TTY subversion prevention
├── benchmark/         # Performance tests (1-2 min)
│   ├── debug.sh       # Debug benchmarking
│   ├── quick.sh       # Quick performance test
│   └── simple.sh      # Simple benchmark
├── advanced/          # Complex feature tests (3-5 min)
│   └── test_advanced.sh   # Advanced functionality
└── lib/               # Shared utilities
    └── harness.sh     # Test harness framework
```

## Usage

### Basic Commands
```bash
# Show all available tests
./test.sh list

# Show tests in specific category
./test.sh list security

# Run all tests in a category
./test.sh run smoke
./test.sh run security
./test.sh run integration

# Run specific test within category
./test.sh run security validation
./test.sh run benchmark quick

# Run all tests
./test.sh run all

# Show help
./test.sh help
```

### Test Categories

#### Smoke Tests (2-3 min)
- **Purpose:** Quick validation of core functionality
- **When to run:** Before commits, during development
- **Contents:** Basic command validation, core feature tests

#### Security Tests (3-5 min) 
- **Purpose:** Security vulnerability prevention and key management validation
- **When to run:** Before releases, after security changes
- **Contents:** 
  - **Key Management Security:** Rotation, revocation, master unlock functionality
  - **Injection Prevention:** Command injection, TTY subversion, dangerous passphrase handling

#### Integration Tests (5-10 min)
- **Purpose:** Full workflow validation
- **When to run:** Before releases, in CI/CD
- **Contents:** E2E scenarios, backup/restore, ignition workflows

#### Benchmark Tests (1-2 min)
- **Purpose:** Performance regression detection
- **When to run:** Performance optimization cycles
- **Contents:** Performance benchmarks, timing validations

#### Advanced Tests (3-5 min)
- **Purpose:** Complex feature validation
- **When to run:** Before releases, after advanced feature changes
- **Contents:** Complex feature interactions, edge cases

## Migration from Legacy System

### Deprecated (but still functional during transition)
- `test_runner.sh` - Basic test runner
- `test_runner_modular.sh` - Comprehensive test runner

### New Equivalent Commands
```bash
# Legacy → New
./test_runner.sh                → ./test.sh run smoke
./test_runner_modular.sh        → ./test.sh run all

# New granular options (not possible with legacy)
./test.sh run security          → Run only security tests
./test.sh run benchmark         → Run only performance tests
./test.sh list                  → Show all available tests
```

## Developer Workflow

### Development Cycle
1. **During development:** `./test.sh run smoke`
2. **Before commit:** `./test.sh run security` + `./test.sh run smoke`
3. **Before PR:** `./test.sh run all`
4. **Performance work:** `./test.sh run benchmark`

### Adding New Tests
1. **Choose category** based on test purpose and execution time
2. **Create test file** in appropriate `tests/{category}/` directory
3. **Make executable:** `chmod +x tests/{category}/new_test.sh`
4. **Follow naming:** Descriptive names without `test_` prefix (handled by category)
5. **Test discovery:** Automatic - no registration needed

### Test Development Guidelines
- **Use test harness:** `source "$SCRIPT_DIR/tests/lib/harness.sh"`
- **Follow BashFX patterns:** Consistent with project standards
- **Handle cleanup:** Proper temp file and resource management
- **Clear output:** Use harness functions for consistent formatting
- **Execution time:** Keep within category time expectations

## Benefits

### Improved Organization
- **Clear categorization** by purpose and execution time
- **Logical grouping** of related tests
- **Easier navigation** and maintenance

### Better Developer Experience  
- **Single entry point** for all testing
- **Granular control** - run specific categories or tests
- **Fast feedback** with targeted test execution
- **Clear help system** and command discovery

### Enhanced Maintainability
- **Consistent structure** across all test types
- **Shared utilities** in lib/ directory
- **Easier to extend** with new categories
- **Reduced duplication** of test harness code

## Architecture Evolution

### Test Modernization (2025-08-28)
The test suite underwent significant modernization to address architectural inconsistencies:

#### Problem: Mixed Test Paradigms
- **Legacy Era:** Ad-hoc `mktemp` directories, manual cleanup, fake environment harnesses
- **Modern Era:** Proper `gitsim` virtualization, automatic cleanup, real environment simulation

#### Solution: Architecture Standardization
- **Audit & Cleanup:** Removed 5 redundant legacy security tests using inferior temp file patterns
- **Modernization:** Converted remaining tests to consistent `gitsim` architecture
- **Coverage Preservation:** Maintained complete security coverage with focused, non-redundant tests

#### Current Standard Pattern
All tests now use proper `gitsim` virtualization:
```bash
# Standard gitsim test environment setup
if gitsim home-init test-name > /dev/null 2>&1; then
    sim_home=$(gitsim home-path 2>/dev/null)
    export HOME="$sim_home"
    cd "$sim_home"
    # Test work in isolated environment
else
    echo "⚠️ gitsim not available, skipping test"
    return 0
fi
```

#### Benefits Achieved
- **Consistent isolation:** All tests use proper virtualized environments
- **Eliminated redundancy:** Focused test coverage without duplication  
- **Improved reliability:** Real environment simulation vs fake harnesses
- **Better maintainability:** Unified patterns across all test categories

## Future Enhancements

### Planned Features
- **Parallel execution** for category-level tests
- **Test result reporting** with structured output
- **Integration with CI/CD** pipelines
- **Test coverage metrics** and reporting
- **Configuration-driven** test execution

### Extension Points
- **Custom categories** for specialized test types
- **Test filtering** by tags or patterns
- **Environment-specific** test configuration
- **Plugin system** for test enhancements

---
*Generated: 2025-08-28*  
*Architecture Modernized: 2025-08-28*  
*Part of fx-padlock unified testing system*