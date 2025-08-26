# Padlock - Git Repository Security Orchestrator
## Product Requirements Document v1.0

### Executive Summary

Padlock is a BASHFX-compliant security orchestrator that provides seamless, transparent encryption for sensitive files in git repositories using modern `age` encryption. It implements a "locker pattern" where sensitive content is stored in plaintext locally for development but automatically encrypted as opaque binary blobs in git history.

### Problem Statement

**Current Pain Points:**
- Developers need to store sensitive files (API keys, LLM prompts, internal docs) in git repos
- Existing solutions (git-crypt, git-secret) are complex and have poor UX
- Repository scrapers and bots can harvest sensitive information from git history
- Team sharing of encrypted content requires complex key management
- LLM development requires protecting proprietary prompts and training data

**Target Users:**
- Software developers working with sensitive configuration
- AI/ML engineers protecting LLM training prompts and system instructions
- Teams needing to share encrypted content via git repositories
- Commercial projects requiring IP protection in version control

### Solution Overview

Padlock transforms any git repository into a "vault-enabled" repository with one deployment command, providing:

1. **Transparent Encryption**: Edit files normally in `locker/`, automatically encrypted in git
2. **Complete Opacity**: Repository scrapers see only opaque binary blobs, no metadata leakage
3. **Team-Friendly**: Simple public key sharing, no GPG complexity
4. **LLM Compatible**: Works in automated environments (Claude, Cursor, CI/CD)
5. **Self-Contained**: Each repo becomes autonomous with its own padlock installation

### Core Architecture

#### The Locker Pattern

**Local Development (Unlocked State):**
```
myproject/
├── locker/                    # Plaintext folder (never committed)
│   ├── prompts_sec/          # LLM guidance files
│   ├── docs_sec/             # Sensitive documentation  
│   ├── conf_sec/             # API keys, secrets
│   └── .padlock              # Crypto configuration
├── bin/padlock               # Self-contained tools
└── .locked                   # Absent (unlocked)
```

**Git Repository (Locked State):**
```
myproject/
├── locker.age               # Single encrypted binary blob
├── bin/padlock              # Self-contained tools (plaintext)
├── .locked                  # Unlock script (present)
└── .padlock                 # Absent (locked)
```

#### State Toggle Mechanism

The system uses **mutually exclusive state files**:
- **Unlocked**: `locker/` directory exists with `.padlock` config file
- **Locked**: `.locked` script exists, `locker/` directory absent

This creates an intuitive "key" metaphor - only one state file exists at a time.

### Technical Implementation

#### Encryption Engine
- **Algorithm**: Age (modern, audited, scriptable)
- **Key Management**: Public-key (recommended) or symmetric
- **Format**: Binary blobs with ~200 bytes overhead per recipient
- **Compression**: Built-in tar+gzip for folder archiving

#### Git Integration
- **Clean Filter**: `locker/` → `locker.age` (encrypt on commit)
- **Smudge Filter**: `locker.age` → `locker/` (decrypt on checkout)
- **Hooks**: Automatic encryption/decryption triggers
- **Attributes**: `.gitignore` prevents accidental plaintext commits

#### BASHFX Compliance
- **XDG+ Standards**: All files in `~/.local/` hierarchy
- **Function Ordinality**: Proper `do_`, `_`, `__` organization
- **Rich Output**: Color-coded, glyphed logging with debug levels
- **Self-Contained**: No external dependencies beyond `age`

### User Experience

#### Developer Workflow
```bash
# One-time deployment
padlock clamp /my/repo --global-key

# Normal development
cd /my/repo
echo "You are an AI expert" > locker/prompts_sec/system.md
echo "API_KEY=secret123" > locker/conf_sec/.env

# Commit (automatic encryption)
git add . && git commit -m "Add secure config"
# → locker/ disappears, locker.age + .locked appear

# Unlock after checkout/pull
source .locked
# → locker.age disappears, locker/ reappears
```

#### Team Sharing
```bash
# Add teammate's public key
padlock key --add-recipient age1abc123...

# Share your public key
padlock key --show-global
```

### Command Interface

#### Deployment Commands
- `padlock clamp <repo>` - Deploy padlock to repository
  - `--global-key` - Use/create global key
  - `--generate` - Generate repo-specific key
  - `--key <key>` - Use explicit key

#### Daily Operations  
- `padlock lock` - Encrypt locker/ → locker.age
- `padlock unlock` - Decrypt locker.age → locker/
- `padlock status` - Show current state
- `source .locked` - Unlock and load environment

#### Key Management
- `padlock key --set-global <key>` - Store global key
- `padlock key --show-global` - Display global key  
- `padlock key --generate-global` - Create new global key

### Security Characteristics

#### What's Protected
- **File Content**: Completely encrypted using modern age algorithm
- **Directory Structure**: Folder organization hidden in single blob
- **File Metadata**: Sizes, counts, timestamps obscured
- **Access Patterns**: No indication of what types of secrets exist

#### What's Visible
- **Presence**: That encrypted content exists (`locker.age` blob)
- **Size**: Approximate size of encrypted content
- **Tool Usage**: That padlock is in use (visible scripts)

#### Threat Model
- **✅ Protects Against**: Repository scrapers, casual browsing, bot harvesting
- **✅ Suitable For**: Commercial IP, LLM prompts, API keys, internal docs
- **❌ Not Suitable For**: Nation-state threats, formal compliance requirements

### Installation & Dependencies

#### System Requirements
- **OS**: Linux, macOS (Windows via WSL)
- **Shell**: Bash 4.0+
- **Git**: Any modern version
- **Age**: Auto-installed by padlock

#### Installation Methods
```bash
# Package managers (preferred)
apt install age    # Debian/Ubuntu
brew install age   # macOS
pacman -S age      # Arch

# Binary download (fallback)
# Automatic via padlock if package manager unavailable
```

### Deployment Architecture

#### First-Class FX Script Installation
```bash
# Installation location
$XDG_LIB_HOME/fx/padlock/padlock.sh

# Symlinked binary (flattened namespace)  
$XDG_BIN_HOME/fx/padlock
```

#### Per-Repository Deployment
```bash
repo/
├── bin/padlock              # Self-contained copy
├── bin/age-wrapper          # Git filter interface
├── .githooks/              # Repository hooks
├── .gitattributes          # Filter configuration  
└── .gitignore              # Locker exclusion
```

### File Templates

#### Generated Files
- **SECURITY.md**: User documentation (removable)
- **locker/docs_sec/AGENT.md**: AI instruction template
- **locker/conf_sec/project.conf**: Configuration template
- **locker/.padlock**: Crypto configuration (unlocked state)
- **.locked**: Unlock script (locked state)

#### Git Configuration
- **Attributes**: `locker.age filter=locker-crypt`
- **Ignore**: `locker/` (never commit plaintext)
- **Hooks**: Pre-commit, post-checkout, post-merge
- **Filters**: Clean/smudge for automatic encryption

### Success Metrics

#### Technical Metrics
- **Zero Plaintext Leaks**: No sensitive files in git history
- **Transparent UX**: Normal git workflow unchanged
- **Team Adoption**: Easy key sharing and onboarding
- **Automation Compatible**: Works in CI/CD and LLM environments

#### User Satisfaction
- **Setup Time**: < 5 minutes for new repository
- **Learning Curve**: Minimal beyond basic git knowledge
- **Error Recovery**: Clear guidance when crypto fails
- **Performance**: Negligible impact on git operations

### Future Enhancements

#### Planned Features
- **Key Rotation**: Automated recipient updates
- **Audit Logging**: Track access and modifications
- **Integration**: Vault, AWS Secrets Manager support
- **Mobile**: Git client compatibility improvements

#### Experimental Features
- **Hardware Keys**: YubiKey support via age plugins
- **Remote Unlock**: Network-based key retrieval
- **Selective Encryption**: File-level rather than folder-level

### Risk Assessment

#### Technical Risks
- **Key Loss**: Unrecoverable without backup (by design)
- **Age Dependency**: Reliance on external crypto tool
- **Git Filter Complexity**: Potential for filter chain failures

#### Mitigation Strategies
- **Clear Documentation**: Backup procedures and recovery guides
- **Graceful Degradation**: Repository remains functional if crypto fails
- **Multiple Installation Methods**: Reduce dependency on single package source

### Competitive Analysis

| Solution | Pros | Cons |
|----------|------|------|
| **git-crypt** | Mature, GPG integration | Complex setup, poor UX |
| **git-secret** | Explicit control | Manual hide/reveal workflow |
| **blackbox** | VCS agnostic | External dependency chain |
| **Padlock** | Modern crypto, transparent UX | New, age dependency |

### Conclusion

Padlock provides a modern, user-friendly solution for repository encryption that balances security with developer experience. Its transparent workflow, team-friendly key management, and automation compatibility make it ideal for protecting commercial IP, LLM prompts, and sensitive configuration in git repositories.

The locker pattern creates an intuitive mental model while the BASHFX architecture ensures maintainability and extensibility. By focusing on the 80% use case of protecting content from casual access rather than sophisticated attackers, Padlock delivers maximum value with minimal complexity.

---

**Document Version**: 1.0  
**Last Updated**: Current Session  
**Next Review**: After initial testing phase