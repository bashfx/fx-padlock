

# RSB: The Comprehensive Reference Guide

**RSB** is a Rust framework for building command-line tools that feel like powerful, modern shell scripts. It is the implementation of the **REBEL** (**R**ust **E**qualized **B**eyond **E**soteric **L**ingo) philosophy, which prioritizes practitioner productivity and familiar patterns over Rust's idiomatic complexity.

This guide is for developers and AI assistants who will use RSB to port existing `BashFX` scripts or write new, robust tools. It focuses on practical patterns and API usage.

## 1. The Standard RSB Application

Every RSB application follows a consistent lifecycle for initialization, configuration, and execution.

### 1.1. Application Structure & Lifecycle

```rust
use rsb::prelude::*;

fn main() {
    // 1. Initialize RSB, load environment, and get command-line args.
    let args = bootstrap!();

    // 2. (Optional) Run "pre-config" commands like `install` or `init`.
    if pre_dispatch!(&args, { "install" => do_install }) {
        return; // Exit if a pre_dispatch command was run.
    }

    // 3. Load configuration files. Values in later files override earlier ones.
    info!("Loading configuration...");
    src!("~/.config/myapp/config.conf", "./app.conf");

    // 4. Route the main command to its handler function.
    dispatch!(&args, {
        "build"   => do_build,
        "deploy"  => do_deploy,
        "config"  => do_manage_config
    });
}

// Handler functions receive an `Args` struct and return an exit code (0 for success).
fn do_build(mut args: Args) -> i32 {
    let target = args.get_or(1, "debug");
    info!("Building target: {}", target);
    // ... logic ...
    okay!("Build successful.");
    0
}

fn do_deploy(mut args: Args) -> i32 { /* ... */ 0 }
fn do_install(mut args: Args) -> i32 { /* ... */ 0 }
fn do_manage_config(mut args: Args) -> i32 { /* ... */ 0 }
```

### 1.2. The `Args` Parser

The `Args` struct, passed to every handler, provides a simple API for parsing arguments. It automatically tracks consumed arguments.

| Method | Description | Example |
| :--- | :--- | :--- |
| `.get(n)` | Get the Nth positional argument (1-indexed). | `args.get(1)` |
| `.get_or(n, default)` | Get positional arg or a default value. | `args.get_or(1, "default")` |
| `.has_pop(flag)` | Check for a boolean flag (e.g., `--force`) and consume it. | `let force = args.has_pop("--force");` |
| `.has_val(flag)` | Get the value of a flag (e.g., `--file f.txt` or `--file=f.txt`). | `let file = args.has_val("--file");` |
| `.get_kv(key)` | Get value from a key-value pair (e.g., `output=/tmp`). | `args.get_kv("output")` |
| `.get_array(key)` | Get a comma-separated array (e.g., `features=a,b,c`). | `args.get_array("features")`|
| `.remaining()` | Get all unprocessed arguments as a `Vec<String>`. | `let files = args.remaining();` |

## 2. Variables & Parameter Expansion

RSB mimics the shell's environment with a global context.

### 2.1. Basic Variable Context

| Function | Description |
| :--- | :--- |
| `set_var(key, value)` | Set a variable. |
| `get_var(key)` | Get a variable (returns `""` if not set). |
| `has_var(key)` | Check if a variable is set. |
| `unset_var(key)` | Remove a variable. |

### 2.2. Parameter Expansion (`param!`)

The `param!` macro provides powerful, bash-style `${...}` string manipulations.

| `param!` Expression | Bash Equivalent | Description |
| :--- | :--- | :--- |
| `param!("VAR")` | `$VAR` | Get variable value. |
| `param!("VAR", default: "val")` | `${VAR:-val}` | Use default if `VAR` is empty. |
| `param!("VAR", alt: "val")` | `${VAR:+val}` | Use alternate value if `VAR` is not empty. |
| `param!("VAR", len)` | `${#VAR}` | Get string length. |
| `param!("VAR", sub: 7, 5)` | `${VAR:7:5}` | Substring (offset, length). |
| `param!("VAR", prefix: "p*")` | `${VAR#p*}` | Remove shortest prefix (glob pattern). |
| `param!("VAR", prefix: "p*", longest)` | `${VAR##p*}` | Remove longest prefix (glob pattern). |
| `param!("VAR", suffix: "*.log")` | `${VAR%*.log}` | Remove shortest suffix (glob pattern). |
| `param!("VAR", suffix: "*.log", longest)` | `${VAR%%*.log}` | Remove longest suffix (glob pattern). |
| `param!("VAR", replace: "a" => "b")` | `${VAR/a/b}` | Replace first occurrence. |
| `param!("VAR", replace: "a" => "b", all)` | `${VAR//a/b}` | Replace all occurrences. |
| `param!("VAR", upper)` | `${VAR^^}` | Convert to uppercase. |
| `param!("VAR", lower)` | `${VAR,,}` | Convert to lowercase. |
| `param!("VAR", upper: first)` | `${VAR^}` | Convert first char to uppercase. |

## 3. Stream Processing (Unix Pipes)

RSB's `Stream` API provides a fluent, chainable interface for text processing, just like Unix pipes.

### 3.1. Creating a Stream (Sources)

| Macro | Description |
| :--- | :--- |
| `cat!(path, ...)` | Creates a stream from one or more files. |
| `cmd!(command)` | Creates a stream from a shell command's `stdout`. |
| `pipe!(string)` | Creates a stream from a literal string or variable. |
| `stream!(...)` | Versatile constructor: `stream!(var: "NAME")`, `stream!(array: &vec)`. |

### 3.2. Manipulating a Stream (Operators)

These methods transform the stream and pass it to the next link in the chain.

| Method | Description | Bash Equivalent |
| :--- | :--- | :--- |
| `.grep(pattern)` | Keep lines containing `pattern`. | `grep` |
| `.sed(from, to)` | Replace first `from` with `to` on each line. | `sed 's/from/to/'` |
| `.cut(field, delim)` | Extract the Nth field (1-indexed). | `cut` |
| `.sort()` | Sort lines alphabetically. | `sort` |
| `.unique()` | Remove all duplicate lines (use after `.sort()`). | `sort \| uniq` |
| `.head(n)` | Take the first `n` lines. | `head -n` |
| `.tail(n)` | Take the last `n` lines. | `tail -n` |
| `.pipe_to_cmd(cmd)`| Pipe the stream as `stdin` to an external command. | `\| cmd` |
| `.tee(path)` | Write stream to a file and pass it through. | `tee` |
| `.each(\|line\| {..})`| Perform an action for each line and pass stream through. | `while read; do..`|

### 3.3. Consuming a Stream (Sinks)

These methods terminate the chain and produce a final result.

| Method | Description |
| :--- | :--- |
| `.to_string()` | Consume the stream into a single `String`. |
| `.to_vec()` | Consume the stream into a `Vec<String>`. |
| `.to_file(path)` | Write the stream's content to a file. |
| `.append_to_file(path)`| Append the stream's content to a file. |
| `.count()` | Consume the stream and return the number of lines. |

## 4. Conditional Logic & Validation

### 4.1. The `test!` Macro

The `test!` macro is a direct replacement for bash's `[[ ... ]]` conditional tests.

| Test Expression | Description |
| :--- | :--- |
| `test!(-f path)` | True if `path` is a regular file. |
| `test!(-d path)` | True if `path` is a directory. |
| `test!(-e path)` | True if `path` exists. |
| `test!(-n str)` | True if `str` is not empty. |
| `test!(-z str)` | True if `str` is empty. |
| `test!(a, ==, b)` | String equality. |
| `test!(str, =~, pattern)` | Regex match. |
| `test!(num_a, -gt, num_b)` | Numeric "greater than". Also `-eq`, `-ne`, `-lt`, `-le`, `-ge`. |

### 4.2. Validation Macros (Exit on Failure)

These macros are the primary error-handling mechanism in RSB. They check a condition and exit with an error message if it's false.

| Macro | Description |
| :--- | :--- |
| `validate!(condition, msg)` | Exits with an error if `condition` is false. |
| `require_file!(path)` | Exits if `path` is not a file. |
| `require_dir!(path)` | Exits if `path` is not a directory. |
| `require_command!(cmd)` | Exits if `cmd` is not found in the `PATH`. |
| `require_var!(var)` | Exits if the context variable `var` is not set. |

## 5. File System and Directory Operations

| Macro / Function | Description | Bash Equivalent |
| :--- | :--- | :--- |
| `read_file(path)` | Reads an entire file into a string. | `cat` or `$(<file)` |
| `write_file(path, content)` | Writes a string to a file, overwriting it. | `echo ".." > file` |
| `append_file(path, content)` | Appends a string to a file. | `echo ".." >> file` |
| `mkdir_p(path)` | Creates a directory and any parent directories. | `mkdir -p` |
| `rm_rf(path)` | Recursively removes a file or directory. | `rm -rf` |
| `cp_r(src, dest)` | Recursively copies a file or directory. | `cp -r` |
| `mv(src, dest)` | Moves or renames a file or directory. | `mv` |
| `touch(path)` | Creates an empty file or updates its timestamp. | `touch` |
| `path_split!(path, into: "P")` | Splits a path into `P_parent`, `P_file_name`, etc. | `dirname`/`basename` |
| `file_in!(var in dir => {..})` | Iterates over all entries in a directory. | `for f in dir/*` |

## 6. Porting from BashFX to RSB

Use this table for direct translation of common BashFX patterns.

| BashFX Pattern | RSB Equivalent | Notes |
| :--- | :--- | :--- |
| `VAR="value"` | `set_var("VAR", "value");` | |
| `echo "$VAR"` | `echo!("$VAR");` | RSB macros automatically expand variables. |
| `${VAR:-default}` | `param!("VAR", default: "default")` | |
| `if [[ -f "$FILE" ]];` | `if test!(-f FILE) { ... }` | |
| `cmd1 \| cmd2` | `cmd!("cmd1").pipe_to_cmd("cmd2")` | Or use native stream methods like `.grep()`. |
| `cat file \| grep ..`| `cat!("file").grep("..")` | |
| `declare -a ARR` | `set_array("ARR", &["a", "b"]);` | |
| `for i in "${ARR[@]}"`| `for_in!(i in "ARR" => { ... })`| |
| `source "file.conf"`| `src!("file.conf");` | |
| `die "Error"` | `fatal!("Error"); std::process::exit(1);` | `validate!` is often a better choice. |

## 7. RSB Cookbook: Common Recipes

### Recipe 1: A Complete CLI Command

This example shows a command that takes a positional argument, a value flag, and a boolean flag.

```rust
// dispatched as "process" => do_process_files
fn do_process_files(mut args: Args) -> i32 {
    // 1. Get arguments
    let input_dir = args.get_or(1, "./input");
    let output_file = args.has_val("--output").unwrap_or_else(|| "results.txt".to_string());
    let force_overwrite = args.has_pop("--force");

    // 2. Validate inputs
    require_dir!(&input_dir);
    if !force_overwrite {
        validate!(!test!(-f &output_file), "Output file exists. Use --force to overwrite.");
    }

    // 3. Perform logic
    info!("Processing files from '{}' into '{}'...", input_dir, output_file);
    let result = cmd!("find {} -type f", input_dir)
        .grep(".log")
        .to_file(&output_file);

    okay!("Processing complete. Results saved to '{}'.", output_file);
    0
}
```

### Recipe 2: Log File Analysis

This recipe reads a log file, finds all unique IP addresses associated with errors, and prints them.

```rust
fn do_analyze_logs(mut args: Args) -> i32 {
    let log_file = args.get_or(1, "access.log");
    require_file!(&log_file);

    info!("Finding unique IP addresses from error logs in '{}'...", log_file);

    let unique_ips = cat!(&log_file)
        .grep("ERROR")
        .cut(1, " ") // Assumes IP is the first space-delimited field
        .sort()
        .unique()
        .to_vec();

    if unique_ips.is_empty() {
        okay!("No errors with IPs found.");
    } else {
        echo!("Found {} unique IPs with errors:", unique_ips.len());
        for ip in unique_ips {
            echo!("- {}", ip);
        }
    }
    0
}
```

### Recipe 3: Working with Config Files

This example loads a configuration file, uses a value with a default, and saves a new value.

```rust
// myapp.conf
# Application settings
API_URL=https://api.example.com
```

```rust
fn do_configure_app(mut args: Args) -> i32 {
    // Assumes `src!("myapp.conf")` was called in `main`.

    // 1. Get value from config, with a fallback default.
    let timeout = param!("TIMEOUT", default: "30");
    info!("Using API timeout: {} seconds.", timeout);

    // 2. Update a configuration value from a command argument.
    if let Some(new_key) = args.get_kv("api_key") {
        info!("Setting new API key.");
        set_var("API_KEY", &new_key);
        save_config_file("myapp.conf", &["API_KEY", "API_URL"]); // Save specific keys
        okay!("API key saved to myapp.conf.");
    } else {
        require_var!("API_KEY"); // Ensure API_KEY is set
        info!("API_KEY is already set.");
    }
    0
}```




### Recipe 4: Interactive User Prompts

This recipe demonstrates how to build an interactive setup command.

```rust
fn do_interactive_setup(_args: Args) -> i32 {
    info!("🔧 Welcome to the interactive setup wizard!");
    let separator = str_line!('-', 40);
    echo!("{}", separator);

    // Prompt for a simple string value with a default.
    let project_name = prompt!("Enter project name", default: "my-project");
    set_var("PROJECT_NAME", &project_name);

    // Prompt for confirmation with a default.
    let enable_docker = confirm!("Enable Docker support?", default: true);
    if enable_docker {
        set_var("USE_DOCKER", "true");
        touch!("Dockerfile");
        info!("✓ Dockerfile created.");
    }

    // Save the configuration.
    let config_file = "setup.conf";
    save_config_file(config_file, &["PROJECT_NAME", "USE_DOCKER"]);

    echo!("{}", separator);
    okay!("✓ Configuration saved to '{}'.", config_file);
    0
}
```

### Recipe 5: The Adapter Pattern in Practice

When you need to interact with a system that isn't command-line based (like a REST API), you use an adapter.

**1. Create the Adapter (`src/adapters/api_client.rs`)**

```rust
// This file hides the complexity of using a library like `reqwest`.
// It exposes a simple, string-first interface.
use rsb::prelude::*;

pub fn api_get(endpoint: &str) -> String {
    let base_url = param!("API_URL", default: "https://api.example.com");
    let full_url = format!("{}/{}", base_url, endpoint);
    
    // Internally, this would use a real HTTP client. We simulate with `curl`.
    let response = shell!("curl -s -L {}", full_url, silent);

    if response.is_empty() {
        error!("API request to {} failed.", full_url);
    }
    
    response
}
```

**2. Use the Adapter in a Command**

```rust
// Import the adapter's functions.
use crate::adapters::api_client::*;

fn do_fetch_user_data(mut args: Args) -> i32 {
    let user_id = args.get_or(1, "1");
    require_var!("API_URL"); // Ensure the base URL is configured.

    info!("Fetching data for user '{}' from API...", user_id);

    // Use the simple, string-first adapter function.
    let user_data_json = api_get(&format!("users/{}", user_id));
    
    validate!(!user_data_json.is_empty(), "Failed to get user data from API.");

    // Even JSON parsing can be done with shell tools if desired.
    let user_name = pipe!(&user_data_json)
        .pipe_to_cmd("jq -r .name")
        .to_string();

    okay!("Successfully fetched user: {}", user_name.trim());
    0
}
```

## 8. Conclusion: The REBEL Way

The RSB framework is designed to be the bridge between the simplicity of shell scripting and the power of systems programming. By adhering to its core patterns, you can build robust, maintainable, and highly effective command-line tools without getting bogged down by Rust's ceremonial complexity.

*   **Think in Strings and Streams:** Embrace the Unix philosophy.
*   **Fail Fast and Clear:** Use `validate!` and `require_*` macros to handle errors declaratively.
*   **Isolate Complexity:** Use the **Adapter Pattern** when you need to integrate with non-shell systems.

