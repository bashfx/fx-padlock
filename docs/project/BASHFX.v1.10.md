
### BashFX Architecture v.1.10
```
Version:1.10
Last_Update:08/16/2025
Density:Very High

```

# Part I: The Guiding Philosophy

## The "Herding Cats Architecture" for "Junkyard Engineering"

### 1.0 The Naming Ethos

The **FX** moniker stems from a deep fascination with functions (`f(x)`), set notation, logic, and discrete mathematics. Whenever these monikers are used in BashFX, it's an expression of joy and wonder at elegant systems. Similarly, other monikers in this realm exist: **GX** for generator (`g(x)`), **IX** for instruction (`i(x)`), among others. These are used consistently across various software solutions.

This preference for variables that resemble quasi-math notation aligns squarely with Unix's penchant for abbreviated namespacing. This desire is baked into BashFX, leading to a strong preference for terse variable and function names that are more emblematic of mathematical expressions, while allowing for deviation as necessary for clarity. BashFX will prefer, for example, iterators like `i, j, k`; spatial markers like `x, y, z`; set or comparison markers like `a, b, c`; and grammar or logic markers like `p, q, r`.

### 1.1 The Principles

These are the established conventions. They are not divine law, but ignoring them has a tendency to lead to long, unpleasant nights of debugging.

| Principle       | Description                                                                                                                                              |
| :-------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Self-Contained**  | All installation artifacts (libraries, configurations, binaries) must reside within a single, predictable root directory (e.g., `~/.local`). Don't make a mess in my home. |
| **Invisible**     | Don't throw your junk everywhere. No new dotfiles in `$HOME`. A good tool is heard from when called upon, and silent otherwise.                           |
| **Rewindable**      | Do no harm. Every action must have a clear and effective undo. An install without an uninstall is just graffiti.                                       |
| **Confidable**      | Don't phone home. Don't leak secrets. Trust is a non-renewable resource.                                                                                 |
| **Friendly**        | Follow the rules of engagement. Be proactive in communicating your state and use tasteful visual cues (color, symbols) for those of us who think with our eyes. |
| **Self-Reliance**   | A BashFX tool should not require a trip to the package manager for its core function. We build with what's already on the floor: `bash`, `sed`, `awk`, `grep`. |
| **Transparency**    | The system should be inspectable. A clever one-liner is admirable, but a black box is a liability. Favor clear, explicit actions over solutions that hide their intent. |






# Part II: System Structure & XDG Compliance

This part defines BashFX's hierarchical approach to system structure and its adherence to the XDG Base Directory Specification.

### 2.0 Layered Standards: XDG(0), XDG(1), XDG(2)

This architecture employs a layered approach to system standards.

- The first layer comprises standards aligned with widely adopted Linux/Unix conventions, collectively referred to as **XDG (standards)** or `XDG(0)`. This represents the upstream XDG Base Directory Specification.
- The second layer defines **Super Standards**, referred to as XDG+ or `XDG(1)`, which supersede, override, replace, or add preferred conventions for BashFX. This means XDG+ includes XDG(0), except where explicitly or implicitly overridden. XDG(1) is the default standard for BashFX compliance.
- Furthermore, XDG+ provides for additional layering: optional, extended, or use-case specific standards are referred to as **Extended Standards or `XDG(2)`.

When "XDG" is used as a flag, variable, prefix, or other code asset in any context within this architecture, it generally refers to XDG+ overall, without distinguishing between XDG(0) and XDG(1). However, additional custom namespacing may be used for XDG(2). 

The "XDG" phrasing serves as a hat-tip to upstream Linux standards and carries special meaning in code. Typically, any setup, launch, or base configurations will use XDG prefixes and names to indicate an early-stage setup, distinct from a runtime (post-install) setup. Conceptually, however, XDG+ is interchangeable with mentions of "**FX**," which encapsulates the essence and spirit of the BashFX architecture.

### 2.1 XDG Standard - XDG(0)

The XDG Base Directory Specification (**XDG(0)**) defines the following environment variables and their default paths for user-specific data:

| Variable          | Default Path        | Description                                                       |
| :---------------- | :------------------ | :---------------------------------------------------------------- |
| `XDG_CONFIG_HOME` | `~/.config`         | User-specific configuration files.                                |
| `XDG_CACHE_HOME`  | `~/.cache`          | User-specific non-essential data files.                           |
| `XDG_DATA_HOME`   | `~/.local/share`    | User-specific data files.                                         |
| `XDG_RUNTIME_DIR` | `/run/user/<uid>`   | User-specific runtime files and other file objects.               |

BashFX maintains a minimum respect for these **XDG(0)** standards, ensuring it does not clobber other libraries that adhere to them.

### 2.2 XDG+ Standard - XDG(1)

BashFX's **XDG(1)** standard represents a pragmatic deviation from **XDG(0)** due to its principles of no-pollution, self-containment, and "Don't F**k With Home" (**DFWH**). While **XDG(0)** scatters configuration and cache directories directly into `$HOME` and lumps everything else into `$HOME/share` without providing clean namespaces for common conventions like `etc`, `lib`, and `data`, BashFX streamlines this by primarily utilizing `$HOME/.local`.

BashFX uses `$HOME/.local` as its primary clean-up mechanism for the `$HOME` directory, defining its structure as follows:

| Variable    | Path                  | Description                                                                                                                                                                                                   |
| :---------- | :-------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `XDG_LIB`   | `$HOME/.local/lib`    | Script and library packages installed by BashFX are copied here.                                                                                                                                              |
| `XDG_ETC`   | `$HOME/.local/etc`    | Configuration files go here ceremoniously. BashFX strongly prefers this over `~/.config`.                                                                                                                      |
| `XDG_DATA`  | `$HOME/.local/data`   | Meant for data libraries like database files, dictionaries, and reference JSONs.                                                                                                                              |
| `XDG_BIN`   | `$HOME/.local/bin`    | A script is considered installed if it's symlinked here. Executables are typically symlinked directly into this path to maintain a flat, discoverable binary path.                                             |
| `XDG_TMP`   | `$HOME/.cache/tmp`    | The designated local temporary folder to use instead of `/tmp`.                                                                                                                                               |
| `XDG_HOME`  | `$HOME/.local`        | Generally considered the base for BashFX's local resolution of `XDG+` paths.                                                                                                                                  |

BashFX is strongly against adding *any* file directly to the user's root `$HOME` directory. Temporary development files may be permitted to spill over when `XDG` pathing is unavailable for specific setups, but such files must be manually cleaned up or subject to automated cleanup routines. Scripts created by other people will presumably have their own organization space, or alternatively a `my` space.

Important Update: Note that all XDG+ variable paths use XDG_VAR_HOME pattern to indicate the standard XDG pattern for installed applications and user data, Linux systems use a XDG_VAR_DIR setup for user folders like Desktop and Downloads that are only available on *Desktop* distros. 

On that note, first-class fx scripts (scripts create by/for Bashfx) typically install into the `XDG_LIB_HOME\fx` directory in a folder under their explicit app name space. Example the padlock script  `XDG_LIB_HOME\fx\padlock\padlock.sh`. When scripts are linked to the fx bin path `XDG_BIN_HOME\fx` the links are all flattened into the fx namespace and do not use the .sh extension.

`XDG_LIB_HOME\fx\padlock\padlock.sh` -> installs via link to -> `XDG_BIN_HOME\fx\padlock` (no .sh)


### 2.3 Directory Awareness

We leverage standard directory names to maintain consistency with ancient patterns that remain relevant. This principle extends to other well-established folder naming conventions not explicitly listed here. When files are added to system-level paths, this standard requires proper use of directories as implied by their name.

**Linux Standard Directories - DIR(0)**

This refers to the general use of standard names for derived pathing, often found in traditional Unix-like file systems.

| Name   | Purpose                                     |
| :----- | :------------------------------------------ |
| `etc`  | Configuration files                         |
| `data` | Variable data files                         |
| `lib`  | Essential shared libraries and modules      |
| `tmp`  | Temporary files                             |
| `var`  | Variable data, like logs and spools         |

*(Note: These conventions align with historical FHS - Filesystem Hierarchy Standard - principles for system-wide directories, adapted here for user-specific contexts.)*

**BashFX Standard Directories - DIR(1)**

These are additional standardized directory names integrated over the years, and are considered standard if their use case arises within BashFX.

| Name   | Purpose                                                                                                                                                                                                  |
| :----- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `www`  | Web root directories, typically used instead of `public`.                                                                                                                                                |
| `env`  | Environment variables, profile-scoped variables, and preferences.                                                                                                                                        |
| `cdn`  | Static assets like CSS, JavaScript, and images.                                                                                                                                                          |
| `repos`| A top-level directory for Git repositories, often namespaced.                                                                                                                                            |
| `my`   | User-specific customizations, personal dotfiles, or a custom user root.                                                                                                                                  |
| `dx`   | User-specific code and code configuration.                                                                                                                                                               |
| `zero` | Housing new/fresh user-preferred system configurations for migrations.                                                                                                                                   |
| `x` or `root` | A pseudo top-level "mount point" in `$HOME` for all user-specific data, allowing for clean removal, syncing, or backup. Items from this directory are typically symlinked into `$HOME` if needed. |






# Part III: The Standard Interface & Conventions

### 3.0 The Standard Interface

This section defines the core components of a BashFX script, from variable naming conventions to the required function skeleton.

**Standard Variables**

-   **Known Globals & Modes:** A concerted effort is made to respect community-accepted global variables (`DEBUG`, `NO_COLOR`). BashFX further defines these standardized modes, which act as high-level state toggles. Unless provided by a library or framework, they are generally regarded as implementation interfaces, and others may be implemented as needed.

| Mode         | Description                                                                                                                                                                                                                                                        |
| :----------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DEV_MODE`   | Enables developer-specific logic. The presence of this mode is often checked by `is_dev` or `is_user` **guard** functions. Guards are typically verb-like logic checks (e.g., `is_*`) that are often library-defined. If an application defines its own guards, it should follow the `is_` pattern to maintain library-compatibility, which also serves as a reminder to consider if they can be ported to a library. |
| `QUIET_MODE` | Disables most `stderr` messages.                                                                                                                                                                                                                                   |
| `DEBUG_MODE` | Toggles execution paths for diagnostics.                                                                                                                                                                                                                           |
| `TEST_MODE`  | Enables test-specific logic.                                                                                                                                                                                                                                       |

-   **Variable Case by Scope:**
    -   **ALL_CAPS_VARIABLES**: Represent one of two things: either a configuration value inherited from a session/setting file, or a pseudo-constant.
    -   **lowercase_variables**: Imply a more ephemeral, local scope (e.g., function arguments, local variables).
    -   **Example:** `OPT_DEBUG` and `opt_debug` may exist concurrently. `OPT_DEBUG` would be a framework-level or inherited setting, while `opt_debug` would be the function-local state variable derived from a command-line flag.

-   **Standard Prefixes:**

| Prefix        | Description                                                                                              |
| :------------ | :------------------------------------------------------------------------------------------------------- |
| `opt_`        | For argument flag states, typically set by the `options()` function.                                     |
| `dev_`        | For functions intended for internal testing or potentially destructive operations.                       |
| `fx_`/`FX_`   | **Reserved for the BashFX framework itself**, for package and dependency orchestration.                    |
| `fxi_`/`FXI_` | For the setup/installer context within the BashFX framework.                                             |
| `T_`          | Optional prefix for a temporary variable, explicitly marking it for a short lifecycle.                   |
| `T_this`/`THIS_`/`this_` | For the "Thisness" context pattern (see Part IV).                                              |
| `_name` / `__name` | Prefixes denoting pseudo-private helper functions, tied to Function Ordinality (see Part IV).        |
| `__NAME__`    | A double-bound underscore denotes a template or sentinel value.                                          |
| `____`        | The underbar blank often denotes a "poorman's this" or the immediate context.                            |

-   **Predictable Local Variables ("Lazy" Naming):** A predictable set of local variable names is consistently used for common tasks.
    > I'm lazy and naming things is hard.

| Category    | Variables        | Description                               |
| :---------- | :--------------- | :---------------------------------------- |
| Status      | `ret`, `res`     | Return status code, result/value          |
| Strings     | `str`, `msg`, `lbl`  | Generic strings, messages, labels       |
| Paths       | `src`, `dest`, `path` | Source, destination, generic path      |
| Iterables   | `arr`, `grp`, `list` | Arrays, groups, lists                   |
| Identity    | `this`, `that`, `ref`, `self` | References to objects or contexts     |
| Iterators   | `i`, `j`, `k`    | Loop counters                             |
| Spatial     | `x`, `y`, `z`    | Positional or coordinate markers        |
| Comparison  | `a`, `b`, `c`    | Variables for comparison or sets        |
| Logic       | `p`, `q`, `r`    | Grammatical or logical markers          |
| Cursors     | `curr`, `next`, `prev` | Pointers in loops or sequences        |
(New local variables should follow this paradigm where existing patterns are insufficient.)

**Standard Functions**

-   **Core Principles:**
    -   **Return Status:** Always return `1` (failure, implied default) or `0` (success, explicit).
    -   **Stream Usage:** `stderr` (`>&2`) is for human-readable messages. `stdout` is for machine-capturable data (`$(...)`).

-   **Function Naming (Public vs. Pseudo-Private):**
    -   **Public/Dispatchable:** Functions called by `dispatch` should be prefixed with `do_` or a script-specific vanity prefix (e.g., `bookdb_`).
    -   **Pseudo-Private:** Helper functions should be prefixed with `_` (mid-level) or `__` (low-level). See Part IV, Section 4.0 for a detailed explanation of Function Ordinality.

-   **Example Function Template:** This demonstrates the standard structure, including predictable local variables and explicit returns.
    ```bash
    function my_public_function() {
        local path="$1";
        local ret=1; # Default to failure
        local res="";  # For storing a result

        if _my_helper_is_valid "$path"; then
            res=$(__my_literal_get_data "$path");
            if [[ -n "$res" ]]; then
                ret=0; # Success
            fi;
        fi;
        
        printf "%s" "$res"; # Output result to stdout
        return "$ret";
    }
    ```

-   **Standard Function Roster:** A "Proper Script" is built from a predictable set of high-order functions.

| Function | Type        | Description                                                     |
| :------- | :---------- | :-------------------------------------------------------------- |
| `main()`   | Super-Ordinal | The primary entrypoint. Orchestrates the script's lifecycle.      |
| `dispatch()`| Super-Ordinal | The command router. Executes `do_*` functions.                  |
| `usage()`  | High-Order  | Displays detailed help text.                                    |
| `dev_*()`  | High-Order  | For development and testing. Must contain user-level guards.    |
| `is_*()`   | Guard       | Verb-like logic checks for validating state.                    |

### 3.1 Options & Argument Parsing

-   **`options()`:** This function is solely responsible for parsing command-line flags and setting `opt_*` state variables. It is considered an "independent" function, callable by `main` before any state-dependent logic.

-   **Standard Flags & Behavior:**

| Flag      | Variable      | Description                                                                 |
| :-------- | :------------ | :-------------------------------------------------------------------------- |
| `-d`      | `opt_debug`   | Enables first-level verbose messages (`info`, `warn`, `okay`).              |
| `-t`      | `opt_trace`   | Enables second-level messages (`trace`, `think`); often enables `-d` as well. |
| `-q`      | `opt_quiet`   | Silences all output except `error` and `fatal`. Overrides other log flags. |
| `-f`      | `opt_force`   | Bypasses safety guards or non-critical error checks.                      |
| `-y`      | `opt_yes`     | Automatically answers "yes" to all user confirmation prompts.               |
| `-D`      | `opt_dev`     | A master developer flag, often enabling other flags like `-d` and `-t`.     |

-   **Notes on Implementation:**
    -   Current implementations do not support combo flags like `-df` and avoid external parsers like `argparse`. Instead, capital case flags can be used to flip multiple other flags, as in the case of `-D`.
    -   BashFX's logging libraries standardize the following assumptions:
        -   **Semi-Quiet by Default:** If no logging flag is set by `options()`, only `error` and `fatal` messages are visible. The minimal `-d` flag is required to see first-level output (`info`, etc.), and `-t` for second-level.
        -   **Forced Output:** `-f` can override an inherited quiet mode.
        -   **Dev Mode:** The `-D` flag is used in conjunction with `dev_*` functions and `dev_required` guards to enable developer-specific output.

### 3.2 Printing & Output Conventions

This section governs all human-readable output.
-   **Output UX:** A suite of standardized printing utilities (`stderr.sh`, `escape.sh`) provides functions for different log levels (`info`, `warn`, `error`), visual elements (banners, boxes), and user prompts.
-   **Silenceability (`QUIET(n)`):** All printer functions have a defined quietness level, controlled by flags (`opt_debug`, `opt_trace`) or modes (`QUIET_MODE`, `DEBUG_MODE`), ensuring predictable output behavior.

**Sentinels: Markers of Ownership & State**

A sentinel is a unique marker or string delimiter used to indicate ownership, state, or a location for automated processing. They are the backbone of rewindable operations and allow scripts to modify files without corrupting them.
-   **Flag/Tag:** A comment on the same line as code (e.g., `source file.sh # My Sentinel`). Used for line-based linking and unlinking.
-   **Banner:** A full line that is itself a sentinel (e.g., `#### my_banner ####`).
-   **Block:** A section of code or text enclosed by banner-style sentinels.
-   **File Sentinels:** The presence of a file itself (e.g., a `.rc` file or a cursor file) can act as a sentinel, indicating a specific application or session state.




# Part IV: Architectural Patterns

### 4.0 Function Ordinality & The Call Stack Hierarchy

Function Ordinality defines a strict hierarchy for function types, establishing a predictable call stack and a clear separation of concerns. This model dictates where specific types of logic, especially error handling and user-level guards, should be implemented.

-   **High-Order vs. Low-Level Functions:** A fundamental distinction is made between functions that interact with the user and those that perform raw system tasks.
    -   **High-Order Functions (`do_*`, `dev_*`, `lib_*`):** These are orchestrators, composable entry points, or sub-dispatchers. They are responsible for interpreting user intent, managing the workflow, and applying user-level guards.
    -   **Low-Level Functions (`_*`, `__*`):** These are "close to the metal" helpers that perform a single, literal job. They trust their inputs and are only responsible for guarding against system-level errors (e.g., a file not being writable).

-   **System-Level vs. User-Level Errors:**
    -   **System-Level Errors:** Defects that cause the system to fail regardless of user input.
    -   **User-Level Errors:** Undesirable states caused by user input. The responsibility for preventing these lies exclusively with High-Order functions.

-   **The Ordinal Hierarchy:** The following table illustrates the typical call stack and defines the function types within it.

| Ordinality | Function Type        | Example Name(s)         | Typical Call Path / Usage                                      |
| :--------- | :------------------- | :---------------------- | :------------------------------------------------------------- |
| **Entry**  | Script Entrypoint    | `(script execution)`    | `main "$@"`                                                    |
| **Super**  | Core Orchestrator    | `main`, `dispatch`      | `main` calls `dispatch` to route commands.                     |
| **High**   | Independent Function | `options`, `install`, `usage` | `main` -> `options`. Does not depend on runtime state.          |
| **High**   | Dispatchable Function| `do_action`, `bookdb_add` | `dispatch` -> `do_action`. The primary entry point for user commands. |
| **Mid**    | Subroutine / Helper  | `_validate_input`     | `do_action` -> `_validate_input`. Breaks down complex logic.  |
| **Low**    | Literal Function     | `__write_to_file`     | `_validate_input` -> `__write_to_file`. Performs a single, raw task. |

-   **How Ordinality is Determined:** A function's position in the call stack, not just its name, determines its ordinality. A prefix is a hint, but the execution path is the truth.
    -   The key determinant is **dispatchability**. Any function directly callable by `dispatch` (e.g., `do_*` or a vanity-prefixed function) is considered **High-Order**. Any function called by a High-Order function is, by definition, of a lower ordinality.
    -   **Library functions** (`lib_*` or other vanity prefixes) are not inherently low-level. If a dispatcher calls a library function directly, that function is High-Order for that specific execution and is responsible for any necessary user-level guards. If it's called by another `do_*` function, it is acting as a lower-ordinality helper.

-   **Independent Functions:** A special class of high-order functions (like `options()` or administrative commands like `install` and `reset`) that can be called by `main` *before* `dispatch`.
    -   These functions must not depend on any application state that would normally be set up for a dispatchable command. For example, they cannot assume a configuration file has been loaded or a database connection is active.
    -   They are **prohibited from calling dispatchable (`do_*`) functions** precisely because those functions *do* depend on that runtime state.
    -   Simple utility scripts often consist entirely of independent functions, as they may not track state.
    -   The `usage` function is typically independent. However, if a script requires `usage` to display dynamic, state-dependent information (e.g., a list of available items from a database), a separate `status` or `dashboard` command should be created as a dispatchable function instead. This keeps `usage` clean and state-independent.

-   **Why Ordinality Matters: A Framework for Predictable Flow**
    Function Ordinality is a meta-pattern that provides a predictable, structured flow for the entire application. It defines an implied call stack, ensuring that logic is placed at the appropriate level of abstraction. This structure is critical for several reasons:
    -   **Maintainability:** By knowing a function's ordinality, a developer immediately understands its purpose, its allowed dependencies, and where to find the relevant user-level guards. It prevents "spaghetti code" where low-level functions make high-level decisions.
    -   **Testability:** High-order functions can be tested by simulating user input, while low-level functions can be unit-tested with known good data, as they don't need to handle user error.
    -   **Security & Safety:** It enforces the principle that all user input is sanitized and validated at the highest possible level before being passed down to "literal" functions that perform potentially destructive actions. A `__write_to_file` function should never have to worry about what's in the string it's writing; that's the job of the `do_save_data` function that called it.

-   **Enforceability**
    The ordinal rules provide a structure/framework for how to organize code and what scope to implement certain patterns. There is no checker, linter or validator (yet), instead these are principles and standards to be followed to help ensure that code is easier to understand, with a clear path of execution, and contextual hints towards good practices.

### 4.1 Standard Patterns

-   **Proper Script**: A fully self-contained script that implements the BashFX Standard Interface (set of functions), and supports the Standard Patterns (especially XDG+), as needed. As the library and standard patterns are further cleaned up, the definition of proper script may expand. "Proper" here implying that a script is fully featured and compatible with the BashFX framework.

-   **Dynamic Pathing**: Most pathing invocations start from a relative root usually `$SOMETHING_ROOT` or `$SOMETHING_HOME`, from which all other subpaths derive. This is in line with BashFX's principle of self-containment because it contains everything downstream. Historically most paths have been relative to `$HOME`, but are now using the `XDG` root which is `~/.local`.

-   **RC Files**: BashFX uses rcfiles (`*.rc`) to indicate state or demark a session.
    -   **Stateful**: Rcfiles are treated as mini sub-profiles that switch a user into a branched sub-session by setting certain environment variables, defining aliases and functions, or writing other state files. The presence or lack of an rcfile indicates a start or end state respectively, and any set of variables within the rcfile can indicate other interstitial states.
    -   **Linking**: Rather than writing data directly to a user's `.profile`, BashFX uses a linking system (`link`, `unlink`, `haslink`) via `sed` or `awk` to link its master rcfile (`.fxrc`); any additional linking by its packaged scripts can treat `.fxrc` as the master session and be enabled (`link`) or disabled (`unlink`) simply by removing their link lines, usually indicated by a label.
    -   **Canonical Profile**: The true location of a user's profile may vary, but only so many locations are viable. Since the main profile acts as the source of state truth (via linking), it's important to map the correct one, and alternatively allow for virtual profiles for testing.

-   **XDG Variables for Awareness**: Scripts should use `XDG_*` variables for startup and system awareness, ensuring they place files in predictable, user-approved locations.

### 4.2 Advanced & Experimental Patterns

-   **Embedded Docs ("Comment Hacks"):** This powerful but potentially brittle pattern uses sentinels to embed documentation, templates, and other metadata directly within a script's comments. As comments, these sections are out-of-scope unless activating scripts are applied to them. While useful for self-contained tools, its reliance on specific `sed`/`awk` parsing can be fragile and is considered an advanced technique rather than a baseline standard.
    -   **Some variants:**
        *   **Logo Hack** - In a proper script, commented lines under the shebang often feature some sort of branding or ASCII art. The line numbers are globbed and the comment prefix stripped and later printed to screen as an intro.
        -   **Meta Hack** - Key-value pairs embedded in a comment like `# key: value`, used for things like naming, versioning, and other meta-data.
        -   **Line Hack** - Dropping a commented line that sources another file into an active file.
        -   **Block Hack** - A sentinel-bound scriplet, usually used to print the `usage()` documentation or the state saving rcfile. This method is preferred for `usage` blocks over heredocs due to indentation flexibility. Block sentinels usually look like ` #### label ####` or have an HTML-like open and close tag.

-   **Thisness:** This experimental pattern uses a set of `THIS_*` prefixed variables to simulate instance-specific scope for generalized library functions. A mainline script can call its own `[namespace]_this_context` to define these variables for use in shared library scripts. This enables a higher degree of code reuse, as well-defined functions don't have to be included every time just to accommodate a different namespace. Using thisness is only ideal in a single script context, where `THIS_*` values are unlikely to be clobbered.







# Part V: Coding Style & Best practices

This section outlines explicit stylistic and structural requirements for all BashFX code, ensuring readability, maintainability, and consistency.

### 5.0 Coding Style & Best Practices

-   **0. Instructions are Debatable:** Sometimes errors pop their head into an unexpected context. If you encounter a rule or instruction that causes syntax errors or defects by virtue of its definition, then please flag your coding partner about the inconsistent rule before following blindly. If a rule causes an unexpected defect downsteam that you are aware of, also flag that!

-   **1. Semicolon Usage:** A semicolon **must** be used to terminate a statement when it is followed by another command on the same line (e.g., `command1; command2`) or when it's syntactically required by Bash (e.g., before `;;` in `case` statements). The lack of semicolons in chained commands (e.g., with `&&`, `||`, or `|`) is a common source of preventable errors. Logic block keywords (`fi`, `done`) do not take a trailing semicolon.

    **Examples:**
    ```bash
    # Same-line termination
    ret=0; log "Success";

    # Chained commands (required for correctness)
    mkdir -p "$dir" && cd "$dir" || fatal "Could not create or enter directory";
    ```

-   **2. Block Termination:** `if`, `while`, `for`, `until` logic blocks **must** be terminated with `fi`, `done`, `done`, `done` respectively. Do not use a trailing semicolon after these keywords. Function definitions are terminated with `}`.

    **Examples:**
    ```bash
    # Simple 'if' block
    if [[ -n "$var" ]]; then
        log "Variable is not empty";
    fi

    # Simple 'while' block
    while read -r line; do
        log "Read line: $line";
    done < "file.txt"
    ```

-   **3. Case Statements:** `case` statements **must** enclose patterns in parentheses (`(pattern)`) and use double semicolons (`;;`) for termination of each pattern block.

    **Example:**
    ```bash
    case "$command" in
        (start)
            do_start_service;
            ;;
        (stop)
            do_stop_service;
            ;;
        (*)
            usage;
            ;;
    esac
    ```

-   **4. Function Granularity:** Prioritize breaking down large functions into smaller helpers, adhering to the principles of **Function Ordinality (see Section 4.0)**. This separation of concerns is key to maintainability.

| Function Type       | Example Name          | Responsibility                                          |
| :------------------ | :-------------------- | :------------------------------------------------------ |
| **High-Order**      | `do_process_file`     | Manages user interaction, guards, and orchestrates the flow. |
| **Mid-Level Helper**  | `_read_file_lines`    | Performs a discrete sub-task, like reading a file into an array. |
| **Low-Level Literal** | `__count_array_items` | Performs a single, "close to the metal" task, like counting array elements. |

-   **5. Underscore Naming Convention:** The number of leading underscores on a function name is a strong hint about its ordinality and intended use.

| Pattern                  | Example               | Usecase / Ordinality                                                     |
| :----------------------- | :-------------------- | :----------------------------------------------------------------------- |
| **Zero Underscores**     | `do_action`, `bookdb_add` | **High-Order**. Public, dispatchable function.                           |
| `_one_underscore`        | `_helper_function`    | **Mid-Ordinal**. A standard subroutine or helper.                        |
| `__two_underscores`      | `__literal_function`  | **Low-Ordinal**. A "close to the metal" function performing a raw task.    |
| `___three_underscores`   | `___desperate_case`   | Used sparingly, when desperate, for an even lower level of abstraction.    |
| `__TEMPLATE__`           | `__CONFIG_TPL__`      | A double-bound underscore denotes a template or sentinel value for substitution. |

-   **6. Guard Placement by Ordinality:** A **guard** is a conditional check that validates state or permissions before executing a piece of logic. The placement of guards is strictly determined by function ordinality.

| Guard / Mode         | Description                                                                 | Example Usage                                                  |
| :------------------- | :-------------------------------------------------------------------------- | :------------------------------------------------------------- |
| **`DEV_MODE`**       | A global mode enabling developer-specific logic.                              | `if is_dev; then dev_log "Running in dev mode"; fi`            |
| **`SAFE_MODE`**      | A global mode that can trigger extra safety checks, like automatic backups.   | `if is_safe_mode; then do_backup; fi`                          |
| **`__confirm_action`** | A high-order helper function that prompts the user for a yes/no confirmation. | `if __confirm_action "Delete all data?"; then rm -rf ...; fi` |
| **`is_*`**           | Generic guard functions that check a specific state (e.g., file existence).   | `if ! is_file "$path"; then fatal "File not found"; fi`        |

-   **7. Predictable Local Variables:** Every function **must** strictly adhere to the `Predictable Local Variables` paradigm (`ret`, `res`, `str`, `path`, `this`, etc.) as defined in **Part III, Section 3.0.1**.

-   **8. Readability & Visual Clarity:** Variable names and code structure should be legible and intuitive for visual thinkers and those with dyslexia.

-   **9. External Commands & Builtins Tracking:** At the top of each script, include a concise comment block listing external commands and Bash builtins used. This facilitates future portability analysis.
    
    **Example:**
    ```bash
    #!/usr/bin/env bash
    #
    # My Awesome Script
    #
    # portable: awk, sed, grep, curl, git
    # builtins: printf, read, local, declare, case, if, for, while
    #

    # ... rest of script
    ```

-   **10. String Templating:** Leverage string templates and helper functions (e.g., `printf -v`) to construct messages or content efficiently.

-   **11. Printing to File:** Any function that generates and writes content to a file **must** be contained within its own helper function, typically prefixed with `__print_`. Parameters should be passed positionally.

    **Example of Parameterized Printing:**
    ```bash
    # Low-ordinal helper function for printing
    # Arguments:
    #   1: file_path (string) - Destination file
    #   2: user_name (string) - User's name
    #   3: user_id (integer)   - User's ID
    __print_user_profile() {
        local path="$1";
        local name="$2";
        local id="$3";
        local content;

        printf -v content "USER_NAME=%s\nUSER_ID=%d\n" "$name" "$id";
        printf "%s" "$content" > "$path";
        return $?;
    }

    # High-ordinal dispatchable function
    function do_create_user_profile() {
        local dest_path="${XDG_DATA}/my_app/profile.conf";
        local current_user="Shebang";
        local current_id=777;

        # Call the print helper, mapping variables to positional args
        # Args: 1:path, 2:name, 3:id
        if __print_user_profile "$dest_path" "$current_user" "$current_id"; then
            okay "Profile written to %s" "$dest_path";
        else
            error "Failed to write profile.";
        fi;
    }
    ```

-   **12. Logic Guards & Reusability:** Create concise `is_` guard functions to avoid reimplementing complex logic blocks.

-   **13. Function Grouping:** Group similar functions together within the script.

-   **14. Commenting Functions:** Each major function **must** have a consistently formatted comment bar above it for readability.

    **Example:**
    ```bash
    ################################################################################
    #
    #  my_awesome_function
    #
    ################################################################################


    function my_awesome_function() {
        # ... function logic ...
    }
    ```
    -   Internal or partial helper functions (e.g., `_mix_batter`) can be grouped directly under their main parent function's comment bar for simple organization.
    -   Minor, standalone utility functions can be grouped under a common comment bar denoting their type.

-   **15. Identation:** Make sure that the inside body of a function is properly indented (as well as other blocks), for IDEs that have code folding; this is key for manual editing.



#### **5.1 Examples**

These examples illustrate the application of BashFX coding style rules. They demonstrate preferred patterns (`GOOD`) and highlight common pitfalls (`BAD`). Please note there may have been some flux in these examples, they may not be entirely accurate, you can compare them against the rules and pillars as a quick test for yourself:

##### **5.1.1 Semicolon Usage & Block Termination**

Consistency and clarity in terminating commands and logic blocks.

```bash
# BAD: Missing semicolons, incorrect block termination
function bad_func() {
    if [ -n "$1" ]
    then; # bad: Sntax Error
        echo "Argument provided: $1"
    fi;  # bad: Sntax Error
    for i in {1..3}
    do
        echo "Loop iter: $i"
    done; # bad: Sntax Error 
} ; # Incorrect function termination and missing semicolons

# GOOD: Proper semicolon usage and block termination
function good_func() {
    local arg="$1"; # Semicolon for inline command
    if [ -n "$arg" ]; then # Semicolon after condition for inline 'then'
        stderr "Argument provided: $arg";
    fi # Proper 'if' block termination

    for i in {1..3}; do # Semicolon after loop header for inline 'do'
        stderr "Loop iter: $i";
    done # Proper 'for' block termination
} # Correct function termination
```

##### **5.1.2 Case Statements**

Patterns must be enclosed in parentheses.

```bash
# BAD: Missing parentheses for case patterns
case "$mode" in
    init)
        stderr "Initializing..." ;; # bad: Sntax Error
    start)
        stderr "Starting service..." ;;
    (act) stdrrr "Activate thing!" ;; # bad: Syntax Error on one liner, missing semicolon
    *)
        stderr "Unknown mode: $mode" ;;
esac

# GOOD: Correct parentheses for case patterns
case "$mode" in
    (init)
        stderr "Initializing...";
        ;; # Double semicolon for case pattern termination
    (start)
        stderr "Starting service...";
        ;;
    (act) stdrrr "Activate thing!"; ;; #one-liner termination
    (*)
        stderr "Unknown mode: $mode";
        ;;
esac
```

##### **5.1.3 Predictable Local Variables & Function Granularity (`_internal_name`, `___private_name`)**

Using standardized local variable names and breaking down complex tasks into smaller, organized functions.

```bash
# BAD: Overly long function, unclear variable names, no internal helpers
function process_data_long_name_bad() {
    local count_val=0;
    local temp_result="";
    # ... lots of complex logic ...
    for x_idx in $(seq 1 5); do
        if [ "$x_idx" -gt 2 ]; then
            count_val=$((count_val + 1));
            temp_result="${temp_result} processed:$x_idx";
        fi;
    done;
    if [ "$count_val" -gt 0 ]; then
        stderr "Processed count: $count_val. Final results: $temp_result";
    fi;
    return 0;
}

# GOOD: Modular, clear variable names, private helper function
################################################################################
#
#  ___process_data
#
################################################################################
# Description: Helper function to iterate and collect data for process_data_good.
# Arguments:
#   1: idx (integer) - Current index for processing.
#   2: count (nameref) - Name of variable to increment count.
#   3: str (nameref) - Name of variable to append result string.
# Returns: 0 on success (if condition met), 1 otherwise.
# Local Variables: idx, count, str
___process_data() {
    local idx="$1";
    local count="$2";    # Nameref for count
    local str="$3";  # Nameref for result string
    local ret=1; # Initialize return status

    if [ "$idx" -gt 2 ]; then
        count=$((count + 1));
        str="${str} processed:$idx";
        ret=0; # Success
    fi;
    return "$ret";
} # Correct function termination

################################################################################
#
#  process_data_good
#
################################################################################
# Description: Main function to process data using a private helper.
# Returns: 0 on success, 1 on failure.
# Local Variables: ret, count, res_str, i
function process_data_good() {
    local ret=1;     # Initialize return status
    local count=0;   # Predictable local variable for count
    local res=""; # Predictable local variable for result string

    local i; # Predictable local for iterator
    for i in {1..5}; do
        # Call the private helper function, passing variables by name for nameref
        ___process_data "$i" count res;
    done;

    # Final reporting logic
    if [ "$count" -gt 0 ]; then
        stderr "Processed count: $count. Final results: ${res}";
    fi;

    ret=0; # Overall success
    return "$ret";
} # Correct function termination
```




##### **5.1.4 Printing to File (`__print_` helper functions)**

Centralizing file content generation and writing.

```bash
# BAD: Inline heredoc for file content and direct printing
function create_config_bad() {
    local config_path="/tmp/myconfig.conf";
    local user_name="Shebang";
    local log_level="debug";

    cat << EOF > "$config_path"
# Config file for $user_name
LOG_LEVEL=$log_level
ENABLED=true
EOF
    stderr "Config written to: $config_path";
    return 0;
}

# GOOD: Dedicated __print_ helper with positional arguments and comments
################################################################################
#
#  __print_config
#
################################################################################
# Description: Generates and writes configuration content to a specified file.
# Arguments:
#   1: file (string) - Path to write the config file.
#   2: user (string) - User name for config header.
#   3: level (string) - Desired log level.
# Returns: 0 on success, 1 on failure.
# Local Variables: file, user, level, config_content
__print_config() {
    local file="$1";
    local user="$2";
    local level="$3";
    local ret=1; # Initialize return status

    printf -v config "%s\n%s\n%s\n" \
        "# Config file for ${user}" \
        "LOG_LEVEL=${level}" \
        "ENABLED=true";

    # Ensure the directory exists before writing
    mkdir -p "$(dirname "$file")";
    printf "%s" "$config" > "$file";
    ret="$?"; # Capture return status of printf
    return "$ret";
} # Correct function termination

################################################################################
#
#  create_config_good
#
################################################################################
# Description: Orchestrates creation of an application config file.
# Returns: 0 on success, 1 on failure.
# Local Variables: ret, config_dest, current_user, app_log_level
function create_config_good() {
    local ret=1;
    local dest="${XDG_ETC}/my_app/config.conf"; # Use XDG+ paths
    local user="$(whoami)";
    local level="info";

    # Call the print helper, mapping variables to positional args
    # Args: 1: file_path, 2: user_name, 3: log_level
    __print_config "$config_dest" "$current_user" "$app_log_level";
    if [ $? -eq 0 ]; then
        stderr "Config written to: ${config_dest}";
        ret=0;
    else
        error "Failed to write config to: ${config_dest}";
    fi;
    return "$ret";
} # Correct function termination
```



##### **5.1.5 Standard Stream Usage (`stderr`)**

All user/developer messages go to `stderr`; `stdout` is for capture.

```bash
# BAD: Mixing messages with stdout output
function get_version_bad(){
    echo "Checking version..."; # Message to stdout
    echo "1.0.0"; # Actual output to stdout
}

# GOOD: Messages to stderr, output to stdout
function get_version_good(){
    stderr "Checking version..."; # Message to stderr
    printf "%s\n" "1.0.0"; # Actual output to stdout
    return 0;
}

# Usage example to demonstrate separation
# bad_ver=$(get_version_bad) # Will capture "Checking version..." and "1.0.0"
# good_ver=$(get_version_good) # Will only capture "1.0.0", message goes to stderr
```



#### **5.2 Basic Script Structure**

This section outlines the standard organization and components expected within different types of BashFX scripts. The order presented reflects the general flow from top to bottom within a file.

##### **5.2.0 Component Definitions**

This lists and defines common structural components used across various BashFX script types.

**Framework**

**BashFX Framework** - is a full featured framework that includes dev tools, package management, a suite of libraries and modules, as well as well-defined patterns like escapes, printers, hooks, dispatchers, bootstrapping, advanced includes, advanced path resolution, and powerful utilities. As this still in development some patterns and tools are still emerging, while some historic patterns linger and are being refactored. As such it is considered alpha, but some functions and includes are used manually in MVP scripts. Generally when the architecture/guides mention includes or specific libraries its referring to assets from this framework. Most new MVP scripts and utilities, will manually copy key standard functions or implement key patterns or simple sets of functions that mimick the same signature footprint or use case for later integration. Stderr is big example of this. As of now the framework is housed in a repo called `fx-catalog` and is in a large state of flux with a handful of stable features.


**Script Types**

**Major Script** - is a fully featured set of tooling with a clear rewindable life cycle (install, setup, reset etc). They can be standalone or integrated with the BashFX Framework. Certain advanced features may not be available if the script is not using the framework. Major Scripts are considered complete if the featureset implements fully rewindable and symmetrical functions. CRUD is a standard baseline for most implementations, as well as installing to the XDG+ Lib location and linking itself to the XDG+ Bin location. These scripts will also keep track of state via their own rcfile and use other data/cache files following XDG+.

**Utility Script** - is a standalone script, with generally a much smaller featureset than a Major. Typically, a utility will have one major baseline feature, and a handful of other support, small life cycle, and helper functions (but not necessarily, there is no clear limit to the main features it can support but a heavy dispatcher is usually a sign of a utlity script growing up). Usually they are composable via pipes and can implement a small dispatcher when the featureset calls for it. Utilities sometimes graduate into major scripts, when a need for a wider featureset arises, so its important the utilities are constructed for evolution. Utilies may also memoize or store information in rcfiles or data files, or add files to a local directory. `countx` utility for example creates a `.counter` file where its invoked and stores it counter files in a manifest `.count-manifest` in the users home. Utilities are manually installed and linked as they dont provide an installation interface. They can borrow functions from BashFX via being copied, but generally dont load any of the FX bootstrappers. They may also implement a driver to quickly test its feature assumptions.

**Library Script** - generally a library script will be created for use in the BashFX framework, but may be implemented independently in support of a Major Script or too offset reusabel code patterns that are likely to be provided by the framework later. They usually feature an explicit load guard or may use a load guard function from the framework, this prevents circular referencing. The script will set a var and alert the dev that it has been loaded to activate the load guard if its called again. Most library functions will have a similar namespace, but should not use the `do_` or `fx_` prefixes which are reserved. They can implement their own private/internal functions as needed.

**Test Script** - A script specifically designed to run tests for other BashFX components or external software. Usually invoked by the frameworks `driver` tool. Generally test scripts shouldnt try to alter the user environment, and instead hook into configurations 

**Key Script Sections**
Inclusive but not necessarily exhaustive, there may be outliers misisng from this list.

-   **shebang**: `#!/usr/bin/env bash` or `#!/bin/bash`. The interpreter directive.
-   **logo/figlet**: Optional ASCII art branding, typically a commented block at the top (see Part IV, 4.0 Embedded Docs - Logo Hack).
-   **meta**: Key-value pairs embedded in comments for script metadata (e.g., `# name: my_script`, `# version: 1.0.0`; see Part IV, 4.0 Embedded Docs - Meta Hack).
-   **portable**: A commented block listing external commands (e.g., `awk`, `sed`, `git`) and Bash builtins (e.g., `printf`, `read`) used by the script, facilitating portability analysis (see Part V, 5.0.7). 
-   **load guard**: For library scripts, a mechanism to prevent multiple sourcing (e.g., `if [ -z "$MYLIB_LOADED" ]; then MYLIB_LOADED=true; fi`).
-   **readonly**: Global constants declared as `readonly` variables. These are usually self reference variables used for the script to operate on itself via identity parameters or provide namespacing like SELF_PID or SELF_SRC, SELF_PREFIX, SELF_NAME. However, note that SELF_ prefix is ephemeral and a script should use its own namespace to initialize these types of values. BOOK_PID, BOOK_PREFIX, are examples of this. Global readonly vars typical mark values that will not change during the scripts life cycle.
-   **config**: Variables defining configuration settings for the script or application, especially ones that can be overriden by a user or environment variable. with the exception of XDG+ compliant pathing or other fragile variables should be overridable. Its important to add a mechanism for switching the *base* XDG path from which the others are derived so that test suites, can properly mimick/virtualize an environment without being destructive. 
-   **bootstrap**: Initial setup, environment checks, and early-stage variable initialization.
-   **simple stderr**: Optional inclusion of minimal `stderr` functions if the full `stderr.sh` library is not sourced, to provide basic message output.
-   **includes**: Sourcing declarations for required external libraries, typically from `pkgs/inc/` when used withe BashFX framework. In script templates, an include/source invocation may phsyically insert file contents at the specific line banner;in this case the includes section listed here are the top-level includes that are not meant to be inserted.
-   **use_apps**: Initialization or setup for other BashFX applications, utilities or modules utilized by a larger script. Generally utilities communicate via composable pipes and not through the explicit use_app interface defined by the framework.-   **vars**: Script-scoped or library-scoped variables. For a library sometimes this is a mechanism for introducing new variables into a larger scope.
-   **simple helpers**: Small, general utility functions, often using `_internal_name` prefix,  may also include guard functions like `is_empty`. In framework enabled libraries these are generally only permissible if a library does not already implement it.
-   **complex helpers**: Larger, more involved helper functions, often using `___private_name` prefix.
-   **api functions (dispatchable)**: Primary functions invoked by the `dispatch` mechanism (e.g., `do_action`, `fx_command`).
-   **setup functions**: Functions specifically for installation, uninstallation, or first-time setup logic.
-   **test helpers**: Specific functions for assertions, comparisons, and reporting within a test script.
-   **tests**: The actual test cases or test suite definitions.
-   **dispatch**: The command router, typically a `case` block, that directs control to `api functions` based on command-line input (see Part III, 3.0.5). A well-defined, dense dispatcher can be a sign of a mature script, and generally undesirable in a utility script. In this case, a utility script with a large dispatcher is a sign that its begging to be refactored into a full Major Script. Neglected utilities often exhibit these signs.
-   **usage**: The function that displays detailed help text to the user (see Part III, 3.0.5).
-   **options**: The argument parser function responsible for processing command-line flags (see Part III, 3.0.5).
-   **main**: The primary entrypoint function for the script, orchestrating its core lifecycle (see Part III, 3.0.5). Generally all initilazation, and awareness tests should be invoked from within main and not in the script body itself, the only exception to this is in smaller utility scripts that dont have a well defined dispatcher.
-   **driver**: A dedicated function or section for development-time testing and demonstration, typically invoked by `cmd driver [name]`. Major Scripts can implement a driver if its featurset surface is simple enough, otherwise an external test script is preferred. Standalone libraries *can* implement a local driver when bundled as a module, but it has to be properly namespaced. Generally library drivers should be deferred to the framework test suite.
-   **resolution**: only used in library scripts, sometimes state or properties need to be massaged in order to allow for proper sourcing/bundling of a library. The resolution segments adds a spot for such adjustments.
-   **load mark**: For library scripts, a marker/variable indicating successful loading (e.g., `echo "LIB_LOADED" >&2`).
-   **main invokation**: The final line that calls the `main` function to start script execution (e.g., `main "$@"`).

**Script General Templates**

Please note that these may not be precise or exhaustive, and may change over time. If you witness a script that deviates from this convention it may be old/legacy, partial state of being brought into compliance, or in need of refactoring. You may flag any scripts that fail this structural requirement.

Sections of code that may or may not used are denoted as optional, whereas the rest are generally considered to be required, but may be depenedent on unnoted use cases. Preferred section means a script is more architecutrally aligned if it uses this pattern but we leave room in case its not feasable at the time. MVP scripts will often eskew super alignment in favor of an MVP-grade alignment and denote what it is implementing and whether its full partial or none.

For scripts lacking a preferred or optional section, a comment bar can denote its absence.


##### **5.2.1 Major Script (App)**

```bash
# shebang
# logo/figlet (preffered)
# meta
# portable 
# readonly
# config
# bootstrap (preffered)
# simple stderr (optional)
# includes (preffered)
# use_apps (optional as needed)
# simple helpers (optional as needed)
# complex helpers (optional as needed)
# api functions 
# dev functions (optional)
# setup functions
# dispatch
# usage
# options
# driver (optional**)
# main
# main invokation
```

##### **5.2.2 Utility Script**

```bash
# shebang
# logo/figlet (optional)
# meta
# portable
# readonly (optional)
# config
# options (optional as needed)
# simple stderr (preffered)
# includes (optional)
# simple helpers
# usage
# main
# driver (optional)
# main invokation
```
##### **5.2.3 Library Script**

```bash
# shebang
# meta
# portable
# load guard
# readonly
# vars
# lib functions
# resolution (optional)
# driver (sometimes)
# load mark
```

##### **5.2.4 Test Script**

```bash
# shebang
# meta
# portable
# readonly
# vars
# simple stderr (optional)
# includes (optional)
# simple helpers (optional)
# complex helpers (optional)
# test helpers
# tests
# options (optional)
# dispatch (optional)
# usage
# main
# main invokation
```

##### **5.2.5 (NEW) Function Scripts**

A function file is a new type of script for isolated development and iteration of individual functions, the are usually named `func_name.func.sh`. They do not include a traditional bash shebang first line. And are used to stub out, iterate and correct functions without having to parse the entire code. These can be created manually or using the `func` tool if its available on `PATH`. Once a function is deemed complete it can be integrated back into the code at a designated comment marker. See the `func` usage docs or `ADM.md` for details.

```bash
# ! NO SHEBANG
# function ONLY
```

##### **5.2.6 Script Templates**

Not expanded upon here, but generally construct into one of the above types via an insertion and hydration mechanism.





# Part VI: General Principles for AI-Assisted Development



1.  **Principle of Verifiable Output:** The user can provide a mechanism for the AI to see the **raw, unfiltered result** of its own work (e.g., a stack trace, a `set -x` log, a screenshot). This is the only verifiable way to bridge the gap between the AI's "intended" output and the real-world outcome.

2.  **Principle of Iterative Refinement:** Assume the first attempt will be flawed. The optimal workflow is not to strive for a perfect "one-shot" generation, but to create a rapid feedback loop of **propose -> test -> refute -> correct**. The goal is velocity, not immediate perfection.

3.  **Principle of Explicit Scoping:** The user must strictly define the **boundaries of the current task**. "Generate Part I only," "Propose the outline first," "Fix only this function." This prevents the AI from propagating a flawed assumption across the entire codebase.

4.  **Principle of User Override:** The user's manual correction is always the **definitive source of truth**. It is not a suggestion; it is a direct update to the project's implicit specification. The AI's immediate job is to understand the *pattern* behind the correction and decide whether to implment it globally (vs isolated change).

5.  **Principle of Shared Understanding:** The process of co-creating a living document (like `ARCHITECTURE.md`) is as important as the code itself. This document becomes the **shared mental model** and the ultimate arbiter when a design decision is questioned.

6.  **Principle of Abstraction Discovery:** When a bug is fixed repeatedly with a similar solution, it's a signal that a new **abstraction is needed**. The AI should be prompted to recognize this pattern and propose a new, reusable helper function or principle to solve that entire class of problem.

7.  **Principle of Directness:** Ambiguity is the enemy of efficiency. Direct, concise, and even blunt feedback from the user is the fastest way to correct the AI's course. Politeness is less important than clarity.

8.  **Principle of Environmental Assumption:** The AI must **explicitly state its assumptions** about the environment in which its code will run (e.g., "Assuming this will be piped to a tool that handles newlines," "Assuming this test will run non-interactively"). This allows the user to immediately correct any flawed environmental assumptions.

9.  **Principle of the "Why":** The most valuable user feedback often goes beyond *what* is wrong and explains *why* it is wrong from a higher-level, architectural perspective. This allows the AI to update its core reasoning model, not just the last line of code it wrote.

10. **Principle of the Cool-Down:** Recognizing points of success and taking a moment to reflect (like our `sleep 7000`) is a crucial part of the process. It allows for the consolidation of lessons learned and prevents burnout/corruption in long, complex sessions.


--- END OF FILE ARCHITECTURE.md --
