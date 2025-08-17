# Padlock - Git Repository Security Orchestrator

Padlock provides seamless, transparent encryption for sensitive files in git repositories using modern `age` encryption. It implements a "locker pattern" where sensitive content is stored in plaintext locally for development but automatically encrypted as an opaque binary blob in git history.

This tool is designed to be self-contained, team-friendly, and compatible with automated environments like CI/CD and AI agents.

## Core Concepts

-   **The Locker Pattern**: Instead of encrypting individual files, Padlock treats a dedicated `locker/` directory as a single unit. This entire directory is archived and encrypted into a single `locker.age` file. This approach hides not only file contents but also the directory structure, file names, and file counts.
-   **State-Aware Files**: The state of the repository (locked or unlocked) is managed by the presence of mutually exclusive files:
    -   **Unlocked**: The plaintext `locker/` directory exists. Inside it is a `.padlock` configuration file.
    -   **Locked**: The `locker/` directory is gone, replaced by the encrypted `locker.age` blob and a `.locked` script used for decryption.
-   **BashFX Compliant**: Padlock follows the BashFX architecture standards, storing its own configuration, keys, and manifest in the `~/.local/etc/padlock` directory, ensuring it doesn't pollute your home directory.

## Quick Start

### 1. Installation

Run the following command to install `padlock` to `~/.local/bin/fx/padlock` for global access:

```bash
./padlock.sh install
```

You may need to add the installation directory to your shell's `PATH`. The script will provide instructions if necessary.

### 2. Deploying to a Repository

Navigate to the root of any `git` (or `gitsim`) repository and run the `clamp` command.

```bash
# In the root of your git repository
padlock clamp . --generate
```

This command performs a one-time setup:
-   It creates the `locker/` directory with some starter files.
-   It generates a new encryption keypair for the repository.
-   It sets up the necessary git hooks and attributes to automate the encryption/decryption process.

### 3. Basic Workflow

-   **Add secrets**: Place any files you want to encrypt into the `locker/` directory.
-   **Work normally**: Edit the files in `locker/` as you normally would.
-   **Commit your changes**: When you `git commit`, a `pre-commit` hook will automatically run `padlock lock`, which encrypts the entire `locker/` directory into `locker.age` before the commit proceeds.
-   **Unlock after clone/pull**: After cloning or pulling a repository, if the locker is locked, simply run `source .locked` to decrypt `locker.age` back into the `locker/` directory.

## Command Reference

### Core Commands

-   `padlock clamp <path> [options]`
    Deploys the padlock infrastructure to a target repository.
    -   `--generate`: Generate a new, repository-specific keypair.
    -   `--global-key`: Use the global keypair (will generate one if it doesn't exist).
    -   `--key <key>`: Use an explicit public key for encryption.

-   `padlock lock`
    Manually encrypts the `locker/` directory into `locker.age` and creates the `.locked` script.

-   `padlock unlock`
    Manually decrypts `locker.age` back into the `locker/` directory. This is the command run by `source .locked`.

-   `padlock status`
    Shows the current state (locked/unlocked) of the repository's locker.

-   `padlock setup`
    A lower-level command to configure encryption, typically called by `clamp`.

### Key Management

-   `padlock key [options]`
    -   `--generate-global`: Creates a new global keypair.
    -   `--show-global`: Displays the global public key.
    -   `--set-global <key>`: Sets the provided key as the global key.

### Installation

-   `padlock install`
    Installs the `padlock.sh` script to a standard user-local directory (`~/.local/lib` and `~/.local/bin`) for easy global access.

-   `padlock uninstall [options]`
    Removes the globally installed `padlock` script.
    -   **Safety Check**: By default, this command will fail if you have any clamped repositories listed in the manifest file (`~/.local/etc/padlock/manifest.txt`).
    -   `--purge-all-data`: When run with the `-D` (dev mode) flag, this will bypass the safety check and permanently delete all padlock data, including keys and the manifest. **Use with extreme caution.**

### Other Commands

-   `padlock help`
    Shows the help text.
-   `padlock version`
    Shows the script version.

## Flags

-   `-d`: Enable debug output.
-   `-t`: Enable trace output (more verbose).
-   `-q`: Quiet mode (suppresses all but `error` and `fatal` messages).
-   `-f`: Force operations (not currently used).
-   `-y`: Auto-answer "yes" to prompts (not currently used).
-   `-D`: Enable Developer Mode for dangerous operations like purging data.

## File Structure

### In a Clamped Repository

-   `locker/`: (Unlocked state) Contains your plaintext secrets.
-   `locker/.padlock`: (Unlocked state) Configuration file with encryption keys for this repo.
-   `locker.age`: (Locked state) The encrypted archive of the `locker/` directory.
-   `.locked`: (Locked state) The script used to unlock the locker (`source .locked`).
-   `bin/padlock`: A local copy of the `padlock` script for this repository.
-   `.githooks/`: Directory containing the hooks that automate locking/unlocking.

### In Your Home Directory

Padlock follows the BashFX standard and keeps all its global files under `~/.local/`:

-   `~/.local/lib/fx/padlock/padlock.sh`: The installed script file.
-   `~/.local/bin/fx/padlock`: A symlink to the script for global access.
-   `~/.local/etc/padlock/`: Directory for all padlock configuration and data.
-   `~/.local/etc/padlock/manifest.txt`: A list of all repositories you have clamped.
-   `~/.local/etc/padlock/keys/`: Directory where generated keypairs are stored.
