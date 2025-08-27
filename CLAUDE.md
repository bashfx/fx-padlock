
## Important 
padlock.sh is built via build.sh from ./parts
do not read/edit it directly you must change the part files



## Context 


## Tools 
you have local commands available that you should use in your work and analysis

## **Func Tool Mini Manual: `func` (Analysis & Manipulation)**

The `func` utility is your specialized, high-precision instrument for interacting with shell script source code. It is designed to be safer and more accurate than general-purpose parsing.

### **4.1. Primary Use Cases & Priority**

*   **Primary Analysis Tool (Highest Priority):** `func` is your **default and mandatory tool** for all shell function analysis. You MUST prioritize `func ls`, `func where`, and `func spy` over your own internal parsers for acquiring data points about shell functions.
*   **FIIP Workflow Engine:** It is the engine that drives the **Function Isolation & Integration Protocol (FIIP)**. The `copy`, `flag`, and `insert` commands are the sanctioned methods for performing safe, iterative refactoring.

### **4.2. API Reference (v4.0)**

| Command | Arguments | Description & (Cost Level) |
| :--- | :--- | :--- |
| `ls` | `<src> [--bash]` | **(Level 1)** Lists all function names in a file. Your first step for codebase reconnaissance. |
| `find` | `<pattern> <src> [--bash]` | **(Level 1)** Filters the function list by a pattern. Useful for finding related functions. |
| `where` | `<func> <src> [--bash]` | **(Level 1)** Gets the starting line number of a function. Critical for existence checks. |
| `spy` | `<func> <src>` | **(Level 2)** Extracts the full body of a single function. Your primary tool for targeted code analysis. |
| `copy` | `<func> <src> [--alias <new>] [-f]`| Executes FIIP Phase 1: Creates the `./func/*.orig.sh` and `./func/*.edit.sh` workspace. |
| `flag` | `<func> <new> <src>` | Executes FIIP Phase 3: Inserts the `# FUNC_INSERT` marker into the source code. |
| `insert` | `<new_func> <src> [-y] [-f]`| Executes FIIP Phase 4: Inserts the verified function from the workspace into the source code. |
| `check` | `<func_name>` | Verifies if the `.edit.sh` file has changes compared to its `.orig.sh` counterpart. |
| `done` | `<func_name>` | Cleans up the workspace files for a specific function after the task is complete. |
| `meta` | `<func_file.ext>` | **(Level 1)** Reads the `# FUNC_META` header from a file in the `./func/` directory. |```


- gitsim (can crate a virtual home and project folder for testing)

use the help command to see more indepth apis.
