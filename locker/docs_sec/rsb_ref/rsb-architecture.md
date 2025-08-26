# RSB Architecture Framework 

**RSB** (Rebel String-Biased Architecture) provides systematic patterns for building accessible, maintainable Rust tools following the **REBEL** (Rust Equalized Beyond Esoteric Lingo) philosophy.

RSB is inspired by and builds upon **BashFX** - a mature bash scripting architecture that emphasizes function ordinality, rewindable operations, and systematic script organization. BashFX has proven itself through years of production bash script development, providing battle-tested patterns for building maintainable automation tools.

RSB translates BashFX's proven architectural concepts into Rust, maintaining the same emphasis on:
- **Function ordinality** (clear responsibility hierarchy)
- **String-biased operations** (opinionated preference for simple interfaces)
- **Systematic organization** (predictable project structure)
- **Developer accessibility** (practical patterns over academic abstractions)

RSB is a key implementation of REBEL principles and part of the broader **Oxidex** framework ecosystem.

This document provides concrete implementation patterns and architectural guidelines for RSB-based tools.

## Part I: Core Design Philosophy

### 1.1 Why RSB Exists

We love Rust as a language - its safety, performance, and reliability are unmatched. However, we find Rustland (the Rust ecosystem) generally unwelcoming to newcomers due to esoteric terminology and academic abstractions that obscure standard engineering patterns.

RSB isn't "Rust Best Practices" - it deliberately abstracts away complex patterns to make a newcomer's first foray into Rustland more welcoming. We prioritize giving power to create quick tools and utilities without the mental load required to understand quirky naming schemes for fundamental concepts.

**Note**: We aren't suggesting you send the first human to Mars using RSB patterns... but you might just duct tape your way there with powerful RSB abstractions without bursting too many brain cells. RSB is a stepping stone - it helps people get comfortable building simple tools and eases their way into larger, more complex projects using Standard Rust™ patterns over time. But it's also useful in its own right for creating snappy utilities that don't need the full ceremonial complexity parade.

### 1.2 String-Biased Philosophy

RSB is opinionated about using strings as the primary interface type, hiding Rust's type complexity behind familiar operations. Yes, `String` is technically a type (not to mention the occasional `bool`, `i32`, and `Option<T>` that sneak in), but it's pretty much the *only* type you need to think about.

```rust
// ✅ RSB Pattern: String-biased signatures
pub fn read_config(path: &str) -> String;
pub fn process_logs(input: &str, pattern: &str) -> String;
pub fn send_alert(message: &str, recipient: &str) -> i32;

// ❌ Anti-Pattern: Complex type signatures
pub fn process<T, E>(input: Result<Option<T>, E>) -> Result<Vec<Config>, ProcessError>
where T: Deserialize + Clone, E: Error + Send;
```

**Important**: You can still do normal Rust stuff when you need it. RSB is built so you don't *have to* wrestle with complex types, but it leaves room to start blending in more mature Rust patterns as you develop expertise or encounter requirements that demand them.

### 1.3 Why Strings/Streams Over Types

**The Unix Philosophy Foundation**: RSB embraces the Unix philosophy that "everything is a string, everything is a file." This isn't just nostalgia - it's a proven approach to building composable, debuggable systems that has worked for decades.

**The Problem with Types**: Rust's type system, while powerful, creates barriers for newcomers and quick tool development. Every operation requires understanding lifetimes, ownership, traits, and error handling patterns.

**The String Bias Solution**: 
- **Familiar**: Strings work like bash variables and Unix pipes - simple, predictable
- **Composable**: String operations chain naturally like Unix command pipelines
- **Debuggable**: Easy to inspect and understand intermediate states at every step
- **Universal**: Every system speaks strings - files, networks, processes, APIs
- **Unix Heritage**: Follows the time-tested principle that text streams are the universal interface

**Stream Processing Benefits**:
- **Mental Model**: Works like Unix pipes that developers already understand
- **Chainable**: Operations flow naturally from input to output
- **Testable**: Easy to verify transformations at each step  
- **Performant**: Rust's string handling is still fast, even with the abstraction

```rust
// RSB: Unix pipe-like operations (familiar mental model)
let results = cat!("access.log")
    .grep("ERROR")
    .cut(4, " ")
    .sort()
    .uniq()
    .to_string();

// Traditional Rust: Type-heavy equivalent that breaks the Unix flow
let file = std::fs::File::open("access.log")?;
let reader = std::io::BufReader::new(file);
let lines: Result<Vec<String>, _> = reader.lines().collect();
let filtered: Vec<String> = lines?
    .into_iter()
    .filter(|line| line.contains("ERROR"))
    .filter_map(|line| line.split_whitespace().nth(3).map(String::from))
    .collect();
let mut unique: Vec<String> = filtered;
unique.sort();
unique.dedup();
```

**Note**: Some `Vec` usage is unavoidable in the internal implementation, but RSB hides this complexity behind string-based interfaces. You work with strings, RSB handles the vector juggling behind the scenes.

### 1.4 Function-Based Development

**One function, one responsibility.** Each function should be independently testable:

```rust
// ✅ RSB Pattern: Single-purpose functions
pub fn extract_ip(log_line: &str) -> String;
pub fn validate_ip(ip: &str) -> bool;  
pub fn lookup_location(ip: &str) -> String;

// ❌ Anti-Pattern: Kitchen sink functions
pub fn process_log_entry_and_validate_and_geolocate_and_alert(line: &str) -> ComplexResult;
```

### 1.5 BashFX Function Ordinality in Rust

RSB adapts BashFX's proven function ordinality system to Rust's scoping mechanisms. BashFX established this hierarchy through years of production bash script development, creating clear separation of concerns and predictable call stacks.

**BashFX Origins**: Function ordinality prevents the "everything in one function" problem common in shell scripts by enforcing responsibility layers - user-facing orchestrators call business logic helpers, which call raw utilities.

**Error Handling Alignment**:
- **High-level (public)**: User fault errors - invalid arguments, missing files, configuration issues
- **Mid-level (crate)**: App fault errors - business logic failures, data processing issues  
- **Low-level (private)**: System fault errors - network failures, permission denied, disk full

```rust
// PUBLIC API FUNCTIONS (User fault error handling)
// No prefix - User-facing orchestrators, validate all inputs
pub fn do_process_logs(args: Args) -> i32 {
    let input_file = args.get_or(1, "access.log");
    
    // Handle user errors with helpful messages
    if input_file.is_empty() {
        fatal!("Input file required: ./tool process <logfile>");
    }
    
    if !test!(-f input_file) {
        fatal!("File not found: {}", input_file);
    }
    
    let errors = _extract_errors(&input_file);    // Delegate to mid-level
    let alerts = _format_alerts(&errors);         
    __send_raw_notification(&alerts);             // Delegate to low-level
    0
}

// CRATE-INTERNAL FUNCTIONS (App fault error handling)  
// _prefix - Business logic, assume valid inputs from public layer
fn _extract_errors(file: &str) -> String {
    let content = cat!(file);
    
    // Handle app logic errors
    if content.is_empty() {
        error!("Log file is empty, no errors to extract");
        return String::new();
    }
    
    content.grep("ERROR").to_string()
}

fn _format_alerts(errors: &str) -> String {
    if errors.is_empty() {
        return String::new();
    }
    
    errors.lines()
        .map(|line| format!("ALERT: {}", line))
        .collect::<Vec<_>>()
        .join("\n")
}

// LOW-LEVEL UTILITY FUNCTIONS (System fault error handling)
// __prefix - "Blind faith" functions, handle only system-level errors
fn __send_raw_notification(message: &str) {
    // Handle system errors, but trust caller provided valid input
    let result = std::process::Command::new("notify-send")
        .arg(message)
        .status();
        
    // Only handle system-level failures (command not found, permission denied)
    if let Err(e) = result {
        error!("System notification failed: {}", e);
    }
}
```

**RSB Function Ordinality Rules** (adapted from BashFX):
- **`pub fn api_function`**: User-facing, full input validation, user fault errors
- **`fn _helper_function`**: Business logic, app fault errors, assumes valid inputs  
- **`fn __blind_faith_function`**: System operations, system fault errors only

### 1.6 Standard RSB Function Interface

Every RSB tool follows the same entry point pattern, providing a bash-like API:

```rust
fn main() {
    let args = bootstrap!();           // Initialize context, load config
    
    pre_dispatch!(&args, {            // Early commands (before config)
        "install" => do_install,
        "init" => do_init
    });
    
    options!(&args);                  // Process CLI flags, set context variables
    
    dispatch!(&args, {                // Main command routing
        "process" => do_process,
        "monitor" => do_monitor,
        "report" => do_report
    });
}

// Custom options implementation
fn options(args: &Args) {
    if args.has_flag("--verbose") || args.has_flag("-v") {
        set_var("VERBOSE", "true");
    }
    
    if args.has_flag("--quiet") || args.has_flag("-q") {
        set_var("QUIET", "true");
    }
    
    if args.has_flag("--debug") {
        set_var("DEBUG", "true");
        set_var("VERBOSE", "true");
    }
    
    if let Some(config) = args.get_flag_value("--config") {
        set_var("CONFIG_FILE", &config);
        src!(&config);  // Load custom config
    }
}
```

## Part II: Bash-like API Patterns

### 2.1 RSB vs Bash: Familiar Operations

RSB provides bash-like patterns through its library and macros, making the transition natural for shell script developers:

**File Processing:**
```bash
# Bash
cat access.log | grep "ERROR" | cut -d' ' -f4 | sort | uniq > errors.txt
```

```rust
// RSB - Same mental model, Rust safety
cat!("access.log")
    .grep("ERROR")
    .cut(4, " ")
    .sort()
    .uniq()
    .to_file("errors.txt");
```

**Variable Expansion:**
```bash
# Bash
CONFIG_FILE="${CONFIG_FILE:-app.conf}"
echo "Loading config from $CONFIG_FILE"
```

```rust
// RSB - Same parameter expansion syntax
let config_file = param!("CONFIG_FILE", default: "app.conf");
echo!("Loading config from $CONFIG_FILE");
```

**Conditional Logic:**
```bash
# Bash
if [[ -f "$file" && -r "$file" ]]; then
    echo "Processing $file"
fi
```

```rust
// RSB - Same test patterns
if test!(-f file) && test!(-r file) {
    echo!("Processing $file");
}
```

**Command Execution:**
```bash
# Bash  
result=$(git status --porcelain)
if [ -n "$result" ]; then
    echo "Repository has changes"
fi
```

```rust
// RSB - Similar command substitution
let result = shell!("git status --porcelain");
if test!(-n result) {
    echo!("Repository has changes");
}
```

### 2.2 Stream Processing Examples

RSB's stream processing maintains the Unix pipe mental model while adding Rust's safety:

**Log Analysis Pipeline:**
```rust
// Extract unique IP addresses from Apache logs
let unique_ips = cat!("access.log")
    .grep(r"\d+\.\d+\.\d+\.\d+")        // Find lines with IP patterns
    .cut(1, " ")                        // Extract first field (IP)
    .filter(|ip| !ip.starts_with("192.168"))  // Remove private IPs
    .sort()                             // Sort addresses
    .uniq()                             // Remove duplicates
    .head(20)                           // Take top 20
    .to_vec();                          // Collect results

for ip in unique_ips {
    info!("External IP: {}", ip);
}
```

**Configuration Processing:**
```rust
// Process configuration files with validation
let valid_configs = cat!("config1.conf", "config2.conf", "config3.conf")
    .grep("^[A-Z_]+=")                  // Find variable assignments
    .filter(|line| !line.starts_with("#"))  // Remove comments
    .map(|line| line.trim().to_string())     // Clean whitespace
    .filter(|line| line.contains("="))       // Ensure valid format
    .to_string();

// Apply configurations
for line in valid_configs.lines() {
    let parts: Vec<&str> = line.splitn(2, '=').collect();
    if parts.len() == 2 {
        set_var(parts[0], parts[1]);
        debug!("Set {}: {}", parts[0], parts[1]);
    }
}
```

**Data Transformation Pipeline:**
```rust
// Transform CSV data with string-biased processing
let processed_data = cat!("users.csv")
    .grep(",")                          // Ensure CSV format
    .sed(r"([^,]+),([^,]+),([^,]+)", "$1: $3")  // name: email format using regex
    .grep(":")                          // Keep only valid transformations
    .sort()                             // Alphabetical order
    .tee("processed_users.txt")         // Save intermediate result
    .to_string();

info!("Processed {} user records", processed_data.lines().count());

// Alternative: Use RSB string utilities to hide complexity
let user_count = processed_data
    .lines()
    .filter(|line| !line.is_empty())    // RSB keeps it simple
    .count();

// Apply configurations with string operations
src!("processed_users.txt");           // RSB way: load as config
```

## Part III: Error Handling & Communication

### 2.1 Error Strategy: Fault-Level Alignment

RSB's error handling aligns with function ordinality - each level handles appropriate error types:

```rust
// ✅ User fault errors (public functions)
fn do_process(args: Args) -> i32 {
    let input = args.get_or(1, "");
    if input.is_empty() {
        fatal!("Input file required");  // User provided invalid args
    }
    
    if !test!(-f input) {
        fatal!("File not found: {}", input);  // User specified wrong file
    }
    
    // Continue processing...
    0
}

// ✅ App fault errors (crate functions)
fn _validate_config(path: &str) -> i32 {
    let content = cat!(path);
    if content.is_empty() {
        error!("Config file is empty");  // App logic issue
        return 1;
    }
    
    if !content.contains("=") {
        error!("Invalid config format");  // App parsing issue  
        return 1;
    }
    
    0
}

// ✅ System fault errors (private functions) 
fn __write_to_disk(path: &str, data: &str) -> bool {
    match std::fs::write(path, data) {
        Ok(_) => true,
        Err(e) => {
            error!("System write failed: {}", e);  // Disk full, permissions, etc.
            false
        }
    }
}
```

### 2.2 stderr Communication

All user messages go to stderr, stdout reserved for data:

```rust
// ✅ REBEL Pattern: Clear communication channels
fn do_list_users(args: Args) -> i32 {
    info!("Loading user database...");        // stderr: progress
    
    let users = cat!("users.csv")              
        .cut(1, ",")                          // stdout: actual data
        .to_string();
        
    okay!("Found {} users", users.lines().count()); // stderr: success
    echo!("{}", users);                       // stdout: piped data
    0
}
```

## Part IV: Project Structure Standards

### 3.1 Standard RSB Project Layout

Use namespace bundling with appropriate separation of concerns:

**Binary Project Structure:**
```
src/
├── main.rs              // Entry point with standard RSB interface
├── lib.rs               // Optional - only if publishing library functions
├── prelude.rs           // User convenience imports
├── myapp.rs             // Nice neighbor for myapp/ directory  
├── myapp/               // Implementation namespace
│   ├── core.rs          // Core business logic (_helper functions)
│   ├── utils.rs         // Low-level utilities (__blind_faith functions)  
│   ├── adapters/        // Type abstraction layer (optional)
│   │   ├── mod.rs       // Adapter module interface
│   │   ├── database.rs  // SQL abstraction
│   │   └── http.rs      // HTTP client abstraction
│   └── queries/         // SQL files (when using database adapter)
│       ├── users.sql
│       └── reports.sql
└── tests/               // Integration tests (separate from src/)
    ├── common/
    └── integration_tests.rs
```

**Library Project Structure:**
```  
src/
├── lib.rs               // Public API and re-exports
├── prelude.rs           // User convenience imports
├── mylib.rs             // Nice neighbor pattern
└── mylib/               // Implementation namespace
    ├── core.rs          // Public API functions
    ├── internal.rs      // Private helpers
    └── adapters/        // Type abstractions
```

**Key Principles:**
- **Binary OR Library** - typically not both in same project
- **Tests outside src/** - integration tests in `tests/` directory
- **SQL files separate** - queries in dedicated directory, loaded as constants
- **Adapters optional** - only when integrating complex external libraries

### 3.2 SQL Integration Pattern

Use external `.sql` files loaded as constants for maintainable database integration:

```rust
// src/myapp/adapters/database.rs

use std::include_str;

// Load SQL queries as compile-time constants
const FIND_USERS_SQL: &str = include_str!("../queries/find_users.sql");
const CREATE_USER_SQL: &str = include_str!("../queries/create_user.sql");
const UPDATE_USER_SQL: &str = include_str!("../queries/update_user.sql");

// RSB string-first database interface
pub fn db_query(db_path: &str, query_name: &str, params: &[&str]) -> String {
    let query = match query_name {
        "find_users" => FIND_USERS_SQL,
        "create_user" => CREATE_USER_SQL,  
        "update_user" => UPDATE_USER_SQL,
        _ => {
            fatal!("Unknown query: {}", query_name);
        }
    };
    
    let final_query = _substitute_params(query, params);
    _execute_query(db_path, &final_query)
}

fn _execute_query(db_path: &str, query: &str) -> String {
    use rusqlite::{Connection, Result as SqlResult};
    
    let conn = Connection::open(db_path).unwrap_or_else(|_| {
        fatal!("Cannot open database: {}", db_path);
    });
    
    let mut results = Vec::new();
    let mut stmt = conn.prepare(query).unwrap_or_else(|_| {
        fatal!("Invalid SQL: {}", query);
    });
    
    let rows = stmt.query_map([], |row| {
        let value: String = row.get(0).unwrap_or_default();
        Ok(value)
    }).unwrap();
    
    for row in rows {
        results.push(row.unwrap());
    }
    
    results.join("\n")
}

fn _substitute_params(query: &str, params: &[&str]) -> String {
    let mut result = query.to_string();
    for (i, param) in params.iter().enumerate() {
        let placeholder = format!("${}", i + 1);
        result = result.replace(&placeholder, param);
    }
    result
}

// Simple public interface
pub fn find_users(pattern: &str) -> String {
    db_query("app.db", "find_users", &[pattern])
}

pub fn create_user(name: &str, email: &str) -> String {
    db_query("app.db", "create_user", &[name, email])
}
```

**SQL File Examples:**

```sql
-- src/myapp/queries/find_users.sql
SELECT name, email, created_at 
FROM users 
WHERE name LIKE '%$1%' 
ORDER BY created_at DESC;
```

```sql
-- src/myapp/queries/create_user.sql  
INSERT INTO users (name, email, created_at)
VALUES ('$1', '$2', datetime('now'))
RETURNING id;
```

### 3.3 Module Interface Standards

```rust
// src/lib.rs - Public API only
pub mod prelude;

// Re-export user-facing items only
pub use crate::myapp::core::*;          // Main functions
pub use crate::myapp::utils::*;         // Helper functions
// DON'T export adapters - they're implementation details

// src/prelude.rs - Convenience imports
pub use crate::*;
pub use rsb::prelude::*;                // Include RSB framework
```

## Part V: Testing Philosophy

### 4.1 Function-First Testing

Test each function independently before integration:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    // ✅ Test individual functions
    #[test]
    fn test_extract_ip() {
        let log_line = "192.168.1.1 - - [25/Dec/2023] GET /index.html";
        assert_eq!(extract_ip(log_line), "192.168.1.1");
    }

    #[test]
    fn test_validate_ip() {
        assert!(validate_ip("192.168.1.1"));
        assert!(!validate_ip("invalid.ip"));
        assert!(!validate_ip(""));
    }

    // ✅ Test business logic
    #[test]
    fn test_process_single_log_line() {
        let result = _process_log_line("192.168.1.1 - ERROR - Connection failed");
        assert!(result.contains("192.168.1.1"));
        assert!(result.contains("ERROR"));
    }

    // ✅ Integration tests after unit tests pass
    #[test]
    fn test_full_log_processing_workflow() {
        write_file("test.log", "192.168.1.1 - ERROR - Test\n10.0.0.1 - INFO - Normal");
        
        let result = do_process(Args::from(&["", "test.log"]));
        assert_eq!(result, 0);
        
        // Verify expected side effects
        assert!(test!(-f "alerts.txt"));
    }
}
```

### 4.2 AI Code Generation Guidelines

When using LLMs to generate code, enforce REBEL patterns:

```rust
// ✅ REBEL-compliant AI prompt result
fn do_backup_files(args: Args) -> i32 {
    let source_dir = args.get_or(1, ".");
    let backup_dir = param!("BACKUP_DIR", default: "/tmp/backup");
    
    info!("Starting backup from {} to {}", source_dir, backup_dir);
    
    let file_count = _count_files(&source_dir);
    let copied = _copy_files(&source_dir, &backup_dir);
    let verified = _verify_backup(&backup_dir);
    
    if verified == file_count {
        okay!("✓ Backup completed: {} files", verified);
        0
    } else {
        error!("✗ Backup incomplete: {}/{} files", verified, file_count);
        1
    }
}

// Each helper is independently testable
fn _count_files(dir: &str) -> i32 { /* ... */ }
fn _copy_files(src: &str, dest: &str) -> i32 { /* ... */ }  
fn _verify_backup(dir: &str) -> i32 { /* ... */ }
```

## Part VII: Patterns and Anti-Patterns

### 5.1 String Processing Patterns

```rust
// ✅ REBEL Pattern: Chainable string operations
let processed = cat!("input.txt")
    .grep("ERROR")
    .sed("old_server", "new_server")
    .cut(4, " ")
    .sort()
    .uniq()
    .to_string();

// ✅ REBEL Pattern: Simple validation
validate!(!processed.is_empty(), "No errors found to process");

// ❌ Anti-Pattern: Complex parsing with types
struct LogEntry { timestamp: DateTime<Utc>, level: LogLevel, message: String }
let entries: Result<Vec<LogEntry>, ParseError> = parse_complex_log(input)?;
```

### 5.2 Configuration Patterns

```rust
// ✅ REBEL Pattern: String-based configuration
src!("app.conf");                           // Load key=value pairs
let api_key = param!("API_KEY", default: "demo-key");
let timeout = param!("TIMEOUT", default: "30");

if get_var("DEBUG") == "true" {
    debug!("API key: {}", api_key);
}

// ❌ Anti-Pattern: Complex config structures
#[derive(Deserialize)]
struct Config {
    api: ApiConfig,
    database: DatabaseConfig,
    features: HashMap<String, FeatureConfig>,
}
```

### 5.3 Error Handling Anti-Patterns

```rust
// ❌ Anti-Pattern: Result chaining madness
let result = read_file(path)?
    .parse::<Config>()?
    .validate()?
    .transform()?
    .execute()?;

// ✅ REBEL Pattern: Clear error handling
require_file!(path);
let content = cat!(path);
validate!(!content.is_empty(), "Config file is empty");

let processed = _parse_config(&content);
if processed.is_empty() {
    fatal!("Invalid configuration format");
}

_apply_config(&processed);
okay!("✓ Configuration loaded");
```

## Part VI: Integration Guidelines

### 6.1 Standard RSB Adapters *(TBD/ROADMAP)*

RSB may provide standard adapters for common integrations to avoid repetitive type abstraction:

```rust
// Future RSB standard adapters (part of Oxidex framework)
// ⚠️  NOT YET AVAILABLE - ROADMAP FEATURE

// Database adapter
use rsb::adapters::database::*;
let users = db_query("app.db", "find_users", &["john"]);

// HTTP adapter  
use rsb::adapters::http::*;
let response = http_get("https://api.example.com/users");

// JSON adapter
use rsb::adapters::json::*;
let name = json_extract(&response, "user.name");

// File system adapter
use rsb::adapters::fs::*;
let config = read_toml("config.toml", "database.url");
```

### 6.2 Custom Adapter Development *(Current Approach)*

Until standard adapters are available, create project-specific ones:

```rust
// src/myapp/adapters/mod.rs
pub mod custom_api;
pub mod database;        // Local SQL adapter
pub mod http_client;     // Local HTTP adapter

// src/myapp/adapters/custom_api.rs  
pub fn api_call(endpoint: &str, data: &str) -> String {
    // Hide complex HTTP client behind string interface
    // Use external files + constants pattern for API templates
}
```

**Note**: Standard adapters are planned for the Oxidex framework to reduce boilerplate across RSB projects.

```rust
// src/myapp/adapters.rs

// ✅ Hide reqwest complexity behind string interface
pub fn http_get(url: &str) -> String {
    use reqwest::blocking::get;
    
    match get(url) {
        Ok(response) => match response.text() {
            Ok(body) => body,
            Err(e) => {
                error!("Failed to read response from {}: {}", url, e);
                String::new()
            }
        },
        Err(e) => {
            error!("HTTP request failed for {}: {}", url, e);
            String::new()
        }
    }
}

pub fn http_post(url: &str, data: &str) -> String {
    // Similar string-first wrapper
}

// ✅ Simple public interface
pub fn check_website_status(url: &str) -> i32 {
    let response = http_get(url);
    if response.is_empty() {
        1  // Error
    } else {
        0  // Success
    }
}
```

### 6.2 Type System Abstraction

```rust
// ✅ REBEL Principle: Hide type complexity
pub fn json_extract(json_str: &str, key: &str) -> String {
    // Use serde_json internally, but expose string interface
    match serde_json::from_str::<serde_json::Value>(json_str) {
        Ok(value) => {
            value.get(key)
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string()
        },
        Err(_) => {
            error!("Invalid JSON input");
            String::new()
        }
    }
}

// User sees simple string operations
let name = json_extract(&api_response, "user_name");
let email = json_extract(&api_response, "email");
```

## Part VII: Documentation Standards

### 7.1 Function Documentation

```rust
/// Extracts IP addresses from Apache log format.
/// 
/// Similar to: `awk '{print $1}' access.log`
///
/// # Example
/// ```rust
/// let ip = extract_ip("192.168.1.1 - - [25/Dec/2023] GET /");
/// assert_eq!(ip, "192.168.1.1");
/// ```
///
/// # Common Usage
/// ```rust  
/// cat!("access.log")
///     .each(|line| {
///         let ip = extract_ip(line);
///         if !ip.is_empty() {
///             info!("Request from: {}", ip);
///         }
///     });
/// ```
pub fn extract_ip(log_line: &str) -> String {
    // Implementation...
}
```

### 7.2 Module Documentation

```rust
//! # User Management Module
//!
//! Provides string-first interfaces for user operations.
//!
//! ## Quick Start
//! 
//! ```rust
//! use myapp::users::*;
//! 
//! let user_id = create_user("john", "john@example.com");
//! let users = find_users("john");
//! delete_user(&user_id);
//! ```
//!
//! ## Integration
//!
//! This module abstracts away database complexity and provides
//! simple string-based operations suitable for shell-like workflows.
```

## Conclusion

## Conclusion & Contribution Guidelines

RSB Architecture ensures that Rust tools remain accessible to practitioners by:

1. **Following BashFX ordinality** with proper Rust scoping alignment
2. **Hiding complexity** behind string-biased interfaces following Unix philosophy
3. **Enforcing testability** through function-based development
4. **Maintaining standard structure** with clear project organization
5. **Using shell-style exit codes** (0 = success, non-zero = failure)
6. **Enabling automation** through consistent, LLM-friendly patterns
7. **Providing stepping stones** to more complex Rust patterns when needed
8. **Offering standard adapters** through the broader Oxidex ecosystem *(planned)*

**Note**: RSB doesn't yet implement BashFX's rewindable operations and friendly script principles - these patterns are planned for future development as the architecture matures.

### This Is Version 1.0

This is the first iteration of RSB Architecture, and it will likely evolve based on real-world usage. We welcome contributions, but with a caveat: if you're looking for strict adherence to Rust orthodoxy, you'll need to play somewhere else.

RSB/REBEL follows the paradigm of **"Good Enough"** engineering - also known as **"Junkyard Engineering."** Make do with what you have right in front of you, only reach for the power tools when absolutely necessary. This is slightly different from "best tool for the job" - instead, everything becomes a tool if you add enough duct tape.

The goal isn't to avoid Rust's power, but to harness it without requiring a PhD in type theory. Sometimes you just need to process some logs, check some files, or automate a workflow. You shouldn't need to architect the next Mars rover just to write a backup script.

*"The best architecture is the one that gets used by practitioners who solve real problems without having to decode academic hieroglyphics first. Everything is a string, everything works, and nobody gets hurt in the process."*
