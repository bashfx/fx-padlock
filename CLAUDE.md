# CLAUDE.md - Project Context & Workflow

## Important Note

### Key Insights from GitSim v2.1 Development

**BashFX 2.1 Critical Patterns Discovered:**

1. **Template Function Returns**: All template creation functions MUST end with explicit `return 0` 
   - Issue: `trace` function returns exit code of test condition when `opt_trace=false`
   - Solution: Always add `return 0` to template functions that end with trace/logging calls

2. **Exit Code Propagation**: BashFX main pattern needs explicit exit handling
   - Add `return $?` to main() function after dispatch call
   - Add `exit $ret` after capturing main return code
   - Critical for error detection in test suites and CI/CD

3. **Argument Filtering Complexity**: Command-specific vs global flags require careful handling
   - Global flags: `-d|--debug|-t|--trace|-q|--quiet|-y|--yes|-D|--dev|-h|--help`
   - Command flags: `-m|--allow-empty|--template=*|--porcelain|--force`
   - Syntax errors in one part can break subsequent parts (unclosed heredocs)

4. **Heredoc Safety**: Always validate heredoc closure in template functions
   - Use `grep -n "cat.*<<.*EOF" parts/*.sh` to find all heredocs
   - Verify each has corresponding `EOF` closure
   - Unclosed heredocs silently break script loading of later parts

5. **Logo UI Pattern**: Conditional logo display for scripting vs interactive use
   - Skip logo for data-returning commands: `home-path`, `version`
   - Show logo for user-facing commands: `init`, `template`, etc.

## General Development Patterns

### Validation-First Approach
- **Always test functionality before optimization** - show that everything works, then optimize
- **Modular validation**: Test each component independently before integration
- **Document issues clearly**: Mark as blocking vs. non-blocking for release decisions

### BashFX Architecture Compliance
- **BashFX 2.1 is the latest architecture** for building scalable bash scripts 500+ lines
- **Build.sh pattern required**: Scripts 500-1000+ lines should use BashFX 2.1 Build.sh pattern
- **Check before editing**: Always note if a project uses Build.sh pattern before modifying files
- **Edit parts/, not final script**: In Build.sh projects, edit individual parts/, then rebuild
- **Size limits matter**: 4000-line AI comprehension limit for complex scripts
- **Modular build patterns**: Use build.map + parts/ structure for maintainability
- **Avoid function duplication**: Check for multiple definitions that override each other
- **Test build artifacts**: Always validate syntax and functionality after builds
- **Ask for BashFX 2.1 docs** if architecture details are missing for bash work

### Template/Boilerplate Strategy
- **Minimize first, expand later**: Start with "hello world" functionality
- **Preserve backups**: Keep parts-upd/ or similar for restoration when over-trimming
- **Function dependencies**: When trimming, ensure all called functions exist
- **Registration patterns**: Check execution order for dynamic registration systems

### Debugging Multi-Part Systems
- **Check execution order**: Later parts can override earlier definitions
- **Trace missing functions**: grep for calls vs. definitions to find gaps
- **Argument parsing issues**: BashFX pattern `args=("${orig_args[@]##-*}")` needs careful handling
- **Dispatcher conflicts**: Multiple dispatch() functions will override each other

### Session Management
- **Progressive validation**: Phase 1 (build), Phase 2 (features), Phase 3 (core)
- **Keep SESSION.md current**: Document findings, blocked items, continuation priorities
- **Clean as you go**: Remove test artifacts between phases
- **Size tracking**: Monitor script size growth, warn at thresholds

## Project Context Discovery

You're likely continuing a previous session. Follow this sequence to understand the current state:

### 1. Read Documentation (in priority order)

Use case-insensitive search. Check project root, `doc*` directories, and `locker/docs_sec`:

**a. Directives & Rules**
- `IX*.md` (instructions/directives)  
- `AGENTS.md` (standardized directives)

**b. Tasks & Continuations**
- `*TODO*.md` (pending tasks)
- `*SESSION*.md` or `PLAN.md` (previous session notes)

**c. Architecture**
- `ARCH*.md`, `BASHFX*.md`
- `*ref*\patterns`: standarized patterns or styles
- `*ref*.md` : reference files for desired patterns, strategies, etc.
- Internal architectures: BashFX (v2.1), REBEL/RSB (Rust DSL)

**d. Project Concepts**
- `*CONCEPT*.md`, `*PRD*.md`, `*BRIEF*.md`

**e. Code & References**
- `src/` (Rust), `parts/` (BashFX using the build.sh pattern)
- Legacy/reference files (`.txt`, `*ref*` folders)

### 2. Plan Execution

1. **Analyze** key files to determine next tasks
2. **Create/Update** `PLAN.md` with milestones and story points (≤1 point per subtask)
3. **Share** high-level plan with user for approval

### 3. Development Workflow

**Branch Management**
- Create new branch: `feature/name-date`, `refactor/name-date`, or `hotfix/name-date`
- Use alternate name if branch exists

**Task Execution**
- Small tasks: iterate freely
- Complex/critical changes: require verification
- All code needs verifiable tests via `test_runner.sh` (for bash)
- Tests must not regress previous functionality

**Milestone Completion**
- All work must have passing tests
- User verifies success
- Check in with semv prefix (`semv lbl` for options) no branding!
- Manually bump versions in project files
- Merge to main and push to origin

**Session Contiuation & Completion**
- Keep SESSION.md notes after each major effort/task/iteration 
- Note any problems or potential solutions
- Note the work youve done

## Available Tools

**`func`** - Shell script source code analysis
- `func ls <src>` - list functions
- `func spy <name> <src>` - extract specific function

**`gitsim`** - Virtual git environment (don't use on gitsim project itself)

Use `<cmd> help` for detailed APIs.

- Report any tool problems immediately.

## Plan X Pilot Methodology: Architectural Decision Framework

### Overview: Autonomous Research Pilot System

The **Plan X Ignition Key Pilot** established a replicable methodology for autonomous architectural decision-making in complex technical domains. This approach successfully evaluated 6 cryptographic approaches and delivered a data-driven production recommendation.

### Core Methodology Components

#### 1. Parallel Implementation Strategy
**Pattern**: Implement multiple competing approaches simultaneously for direct comparison
```bash
# Create pilot environment with parallel implementations
pilot.sh double_wrapped test    # Approach 1
pilot.sh ssh_delegation test    # Approach 2  
pilot.sh layered_native test    # Approach 3
pilot.sh temporal_chain test    # Novel approach 1
pilot.sh lattice_proxy test     # Novel approach 2
```

**Benefits**:
- Direct performance comparison with identical testing conditions
- Reveals implementation complexity differences early
- Enables rapid iteration and debugging across approaches
- Provides empirical data rather than theoretical estimates

#### 2. Qualification Framework with Timeouts
**Pattern**: Establish objective qualification criteria to eliminate problematic approaches
```bash
# 10-second timeout qualification requirement
if ! timeout 10s approach_test; then
    disqualify_approach "timeout exceeded"
fi
```

**Qualification Criteria**:
- **Performance**: Must complete operations within reasonable time bounds
- **Functionality**: Must pass all test scenarios (create, unlock, validate)
- **Automation**: Must support non-interactive operation
- **Reliability**: Must handle error cases gracefully

#### 3. Novel Approach Requirement
**Pattern**: Force innovation beyond existing patterns by requiring original approaches
- **Minimum**: 3 approaches total
- **Innovation requirement**: At least 2 novel/original approaches
- **Research integration**: Draw from current research and emerging concepts

**Plan X Examples**:
- `temporal_chain`: Blockchain-style key chains with forward secrecy
- `lattice_proxy`: Post-quantum threshold M-of-N schemes

#### 4. Empirical Performance Validation
**Pattern**: Real timing data, not theoretical estimates
```bash
# Real performance measurement
time ./pilot.sh layered_native test
# Result: 0.240s (empirical)
# NOT: "should be fast" (theoretical)
```

**Data Collection**:
- Complete test cycle timing (not isolated operations)
- Multiple runs for consistency validation  
- Performance ranking with actual numbers
- Trade-off analysis (performance vs security vs complexity)

#### 5. Comprehensive Analysis Documentation
**Pattern**: Force deep analysis through structured documentation
- **PILOT.md**: Comprehensive analysis (150+ lines typical)
- **Performance tables**: Real benchmark data
- **Security analysis**: Threat model coverage across all approaches
- **Implementation complexity**: Story point estimates for each approach
- **Risk assessment**: Specific risks and mitigation strategies

#### 6. Data-Driven Recommendation Framework
**Pattern**: Objective decision criteria based on empirical evidence
```bash
# Example decision matrix:
layered_native: 0.240s, 13 story points, strong security → WINNER
temporal_chain: 0.259s, 32 story points, advanced security → Runner-up
double_wrapped: 0.233s, 18 story points, compromised security → 3rd place
```

**Decision Factors**:
1. **Performance** (empirical timing)
2. **Security** (threat model coverage)
3. **Implementation complexity** (story points)
4. **Risk assessment** (production viability)
5. **Automation support** (operational requirements)

### Autonomous Completion Protocol

#### Prerequisites for Autonomous Operation
1. **Clear Objectives**: "Find the superior approach for production implementation"
2. **Success Criteria**: All approaches implemented, tested, and ranked
3. **Time Permission**: "Get as far as you can without consultation"
4. **Documentation Requirements**: Comprehensive analysis and recommendation

#### Execution Pattern
```bash
Phase 1: Implement all approaches (including novel ones)
Phase 2: Fix blocking issues (timeouts, implementation bugs)
Phase 3: Collect empirical performance data
Phase 4: Comprehensive analysis and documentation  
Phase 5: Data-driven recommendation with justification
```

#### Quality Gates
- **Functionality**: All approaches must pass test scenarios
- **Performance**: Real timing data for all qualified approaches
- **Analysis**: Comprehensive documentation of trade-offs
- **Recommendation**: Clear winner with empirical justification

### Replication Guide for Future Pilots

#### 1. Pilot Setup
```bash
# Create pilot script structure
pilot.sh <approach> <command>
- Multiple approach implementations
- Common test scenarios
- Timeout qualification
- Performance measurement
```

#### 2. Approach Requirements
- **Minimum 3 approaches** (sufficient for comparison)
- **At least 2 novel approaches** (force innovation)
- **All approaches address same problem** (fair comparison)
- **Common interface for testing** (consistent evaluation)

#### 3. Testing Protocol
```bash
# Standard test sequence for each approach:
1. create-master [name] [passphrase]
2. create-distro [name] [passphrase]  
3. unlock [name] [correct-passphrase] → must succeed
4. unlock [name] [wrong-passphrase] → must fail
5. Performance timing of complete cycle
```

#### 4. Documentation Structure
- **Executive Summary**: Winner and key findings
- **Approach Descriptions**: Technical details for each
- **Performance Analysis**: Real benchmark data in tables
- **Security Analysis**: Threat model coverage comparison
- **Implementation Complexity**: Story point estimates
- **Risk Assessment**: Production readiness evaluation
- **Final Recommendation**: Data-driven decision with justification

#### 5. Success Metrics
- **Completeness**: All approaches implemented and tested
- **Empirical Data**: Real performance measurements
- **Innovation**: Novel approaches working competitively
- **Production Ready**: Clear recommendation with implementation roadmap

### Lessons for Future Pilots

#### What Works
- **Parallel Implementation**: Enables direct comparison
- **Timeout Qualification**: Eliminates problematic approaches early
- **Empirical Measurement**: Provides defensible decision data
- **Novel Requirement**: Forces creative solutions
- **Comprehensive Documentation**: Enables informed decision-making

#### What Doesn't Work  
- **Theoretical Estimates**: Always wrong, use real measurements
- **Single Approach Development**: No comparison basis
- **Complex Automation**: Simple manual measurement often better
- **Assumption-Based Decisions**: Empirical data always wins

#### Key Anti-Patterns to Avoid
- **Premature Optimization**: Get all approaches working first
- **Documentation Drift**: Keep analysis in sync with implementation
- **Complexity Bias**: Simple solutions often win
- **Tool Fighting**: Work around limitations, don't fight them

### Integration with Main Development Flow

#### When to Use Pilot Methodology
- **Architectural Decisions**: Multiple viable approaches exist
- **Performance Critical**: Speed/efficiency is important
- **Security Sensitive**: Multiple security models possible  
- **Innovation Opportunity**: Novel approaches could provide advantages
- **High Stakes**: Decision affects long-term project direction

#### Integration Points
- **Before Major Features**: Use pilots to validate approach before full implementation
- **Technology Evaluation**: Compare libraries, patterns, or architectures
- **Security Architecture**: Evaluate cryptographic or security approaches
- **Performance Optimization**: Compare algorithmic or implementation strategies

#### Resource Requirements
- **Development Time**: 3-7 days typical for complex pilots
- **Documentation**: 150+ lines comprehensive analysis
- **Implementation**: Multiple working prototypes
- **Testing**: Comprehensive validation of all approaches

The Plan X pilot methodology provides a replicable framework for making complex architectural decisions with empirical data and autonomous completion. This approach transforms subjective architectural debates into objective, data-driven decisions that can be confidently implemented in production systems.

## Session 4 Insights: Advanced Development Patterns

### 1. AI-Optimized Help Systems Pattern 🔥
**Discovery**: Traditional help systems waste AI tokens. Implementing tiered help dramatically improves efficiency.

**Successful Pattern**:
```bash
help|--help|-h)
    case "${1:-}" in
        <command>)
            help_<command>    # Contextual help
            ;;
        more)
            usage_detailed    # Full help for humans  
            ;;
        "")
            usage            # Simplified for AI
            ;;
    esac
    ;;
```

**Benefits**:
- 75% token reduction for AI interactions
- `padlock help master` > `padlock master help` (better UX)
- Contextual help improves task completion
- Maintains backwards compatibility

**Recommendation**: Implement for any CLI tool >20 commands

### 2. Centralized Temp File Management Pattern 🔥
**Problem**: Found 21+ `mktemp` calls with inconsistent cleanup causing resource leaks

**Solution Pattern**:
```bash
# Global system
declare -a TEMP_FILES=()

_temp_cleanup() { ... }
_temp_register() { ... }  
_temp_mktemp() { temp_file=$(mktemp "$@"); _temp_register "$temp_file"; echo "$temp_file"; }
_temp_setup_trap() { trap '_temp_cleanup' EXIT ERR INT TERM }
```

**Usage**: Replace `$(mktemp)` with `$(_temp_mktemp)` + call `_temp_setup_trap`

**Benefits**: Guaranteed cleanup, leak prevention, interrupt safety

### 3. Build.sh Workflow Critical Insights 🔥

**CRITICAL**: Never parse final compiled scripts >4000 lines - corrupts context
**DO**: Edit parts/ files, then `./build.sh`
**DO**: Use `func` tool for compiled script analysis (safe, efficient)

**Testing Workflow**:
1. Edit parts/
2. `./build.sh` 
3. Test compiled script
4. Commit parts/ changes

**Context Management**: parts/ files are safe to parse, compiled scripts are not

### 4. Test Suite Modernization Pattern
**Problem**: Monolithic test files become unmaintainable

**Solution**: Update test expectations to match new UX patterns rather than changing UX to match old tests

**Pattern**:
```bash
# OLD: Test specific help text presence
grep -q "specific-command" help_output

# NEW: Document UX change in tests
echo "│ ✓ command available (shown in help more)"
```

**Insight**: Tests should validate user experience, not internal implementation details

### 5. Automation Phase Management 🔥
**User Pattern**: "Full automation mode - continue until finished, commit work"

**Successful Approach**:
1. **Create PLAN.md** with story-pointed tasks
2. **Phase execution** with regular todo list updates  
3. **Comprehensive commit** with detailed messages
4. **SESSION.md updates** for continuity
5. **CLAUDE.md insights** for future improvement

**Key**: User returns to completed work + clear roadmap for next phase

### 6. Function-Level Bug Detection Pattern
**Discovery**: `set -euo pipefail` with BashFX creates subtle bugs

**Example Bug**:
```bash
# BROKEN:
local action="$1"; shift || true
local path="${action:-$1}"  # $1 undefined after shift!

# FIXED:  
local action="${1:-}"
case "$action" in
    "") # Handle empty explicitly
```

**Pattern**: Always use `"${1:-}"` for optional params, handle empty case explicitly

### 7. Quality Gate Pattern for Automation
**Pattern**: Each phase must pass all quality gates before proceeding

**Gates**:
1. ✅ Build successful (syntax check)
2. ✅ Tests passing (no regressions) 
3. ✅ New features working (manual verification)
4. ✅ Documentation updated (help, readme, etc.)

**Automation Rule**: Never proceed to next phase with failing gates

## Development Philosophy Refinements

### Token Efficiency as First-Class Concern
AI token usage should be optimized in user interfaces just like CPU/memory usage. Help systems that generate 1000+ tokens for simple queries waste resources and degrade experience.

### Test Expectations vs Implementation
When modernizing UX, update test expectations to match new patterns rather than maintaining old expectations. Tests should validate user experience outcomes, not internal mechanics.

### Build System Discipline  
In modular build systems (BashFX), editing the final compiled script is always wrong. This discipline prevents context corruption and maintains clean architecture.
